#!/usr/bin/env python3
import json
import sys
from collections import defaultdict
from pathlib import Path
import re


HIGH_RISK_PERMISSIONS = {
    "android.permission.READ_SMS",
    "android.permission.RECEIVE_SMS",
    "android.permission.SEND_SMS",
    "android.permission.REQUEST_INSTALL_PACKAGES",
    "android.permission.SYSTEM_ALERT_WINDOW",
    "android.permission.QUERY_ALL_PACKAGES",
    "android.permission.MANAGE_EXTERNAL_STORAGE",
    "android.permission.BIND_ACCESSIBILITY_SERVICE",
}

SECRET_IGNORE_EXACT = {
    "password",
    "show password",
    "profile / password",
    "this password is too short",
    "enter new password for",
    "mostra password",
    "ipakita ang password",
    "password_toggle",
    "passwordlayout",
    "passwordinputlayout",
    "design_password_eye",
    "prompt_password",
    "must_change_password",
    "error_invalid_password",
    "firebase_database_url",
    "google_api_key",
    "google_crash_reporting_api_key",
}

SECRET_IGNORE_SUBSTRINGS = (
    "firebase-",
    ".properties",
    "passwordtoggle",
    "path_password",
    "avd_hide_password",
    "avd_show_password",
    "hide_password_duration",
    "show_password_duration",
    "wrong username or password",
    "internalpathiteratorrawsize",
)


def classify_secret_hits(secret_observations):
    strong = []
    config = []
    ignored = []
    for obs in secret_observations:
        value = obs["attributes"].get("value", "")
        norm = value.strip().lower()
        if not norm:
            ignored.append(obs)
            continue
        if norm in SECRET_IGNORE_EXACT or any(token in norm for token in SECRET_IGNORE_SUBSTRINGS):
            ignored.append(obs)
            continue
        if re.search(r'https?://', value, re.I):
            config.append(obs)
            continue
        if re.search(r'(api[_-]?key|client[_-]?secret|bearer|authorization|token|secret)', value, re.I):
            if re.search(r'[:=][A-Za-z0-9/_+.-]{8,}', value) or re.search(r'[A-Za-z0-9/+_=.-]{20,}', value):
                strong.append(obs)
            else:
                config.append(obs)
            continue
        ignored.append(obs)
    return strong, config, ignored


def load_jsonl(path: Path):
    if not path.exists():
        return []
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def make_finding(counter, rule_id, control_id, severity, title, summary, why, subject, evidence_ids, observation_ids, remediation, tags, status="confirmed"):
    return {
        "finding_id": f"F-{counter:06d}",
        "rule_id": rule_id,
        "control_id": control_id,
        "severity": severity,
        "status": status,
        "title": title,
        "summary": summary,
        "why_it_matters": why,
        "subject": subject,
        "evidence_ids": sorted(set(evidence_ids)),
        "observation_ids": sorted(set(observation_ids)),
        "remediation": remediation,
        "tags": tags,
    }


def main():
    run_dir = Path(sys.argv[1])
    observations = load_jsonl(run_dir / "normalized" / "observations.jsonl")
    run = json.loads((run_dir / "run.json").read_text(encoding="utf-8"))
    package_name = run["target"]["value"]

    by_type = defaultdict(list)
    for obs in observations:
        by_type[obs["type"]].append(obs)

    findings = []
    counter = 1

    exported = [
        obs for obs in by_type["android.manifest.component"]
        if str(obs["attributes"].get("effective_exported", "")).lower() == "true"
    ]
    public_first_party = []
    for obs in exported:
        attrs = obs["attributes"]
        if attrs.get("owner") != "first_party":
            continue
        if attrs.get("component_type") == "activity" and attrs.get("name", "").endswith(".MainActivity"):
            intent_filters = [
                item for item in by_type["android.manifest.intent_filter"]
                if item["attributes"].get("component_name") == attrs.get("name")
            ]
            launcher_only = any(
                "android.intent.category.LAUNCHER" in item["attributes"].get("categories", [])
                for item in intent_filters
            )
            if launcher_only:
                continue
        public_first_party.append(obs)
    if public_first_party:
        findings.append(make_finding(
            counter, "F-EXPORT-001", "CTRL-EXPORT-001", "medium",
            "First-party exported entry points present in manifest",
            f'{len(public_first_party)} first-party manifest components are externally reachable.',
            "Exported Android components increase the remotely reachable attack surface.",
            {"kind": "package", "id": package_name},
            [eid for obs in public_first_party for eid in obs["source_evidence_ids"]],
            [obs["observation_id"] for obs in public_first_party],
            "Review whether each exported component needs external reachability and gate it with permissions where possible.",
            ["exported", "manifest", "attack-surface"],
        ))
        counter += 1

    deep_links = []
    for obs in by_type["android.manifest.intent_filter"]:
        attrs = obs["attributes"]
        if "android.intent.category.BROWSABLE" in attrs.get("categories", []) or attrs.get("schemes"):
            deep_links.append(obs)
    if deep_links:
        findings.append(make_finding(
            counter, "F-DEEPLINK-001", "CTRL-DEEPLINK-001", "medium",
            "Browsable or externally invokable intent filters observed",
            f'{len(deep_links)} intent filters expose browsable or URI-based entry points.',
            "Browsable activities and URI handlers are callable from browsers and other apps.",
            {"kind": "package", "id": package_name},
            [eid for obs in deep_links for eid in obs["source_evidence_ids"]],
            [obs["observation_id"] for obs in deep_links],
            "Verify host, scheme, and path validation and confirm exported entry points are intentional.",
            ["deeplink", "intent", "attack-surface"],
        ))
        counter += 1

    package_meta = by_type["android.manifest.package_meta"]
    if package_meta:
        meta = package_meta[0]["attributes"]
        if str(meta.get("uses_cleartext_traffic", "")).lower() == "true":
            findings.append(make_finding(
                counter, "F-CLEARTEXT-001", "CTRL-NET-001", "medium",
                "Application manifest allows cleartext traffic",
                "The manifest sets usesCleartextTraffic=true.",
                "Allowing cleartext traffic weakens transport guarantees and can expose credentials or business data on hostile networks.",
                {"kind": "package", "id": package_name},
                package_meta[0]["source_evidence_ids"],
                [package_meta[0]["observation_id"]],
                "Confirm whether all cleartext destinations are necessary and prefer TLS-only transport policy.",
                ["network", "cleartext", "manifest"],
            ))
            counter += 1

    risky_permissions = [
        obs for obs in by_type["android.permission.requested"]
        if obs["attributes"].get("name") in HIGH_RISK_PERMISSIONS
    ]
    if risky_permissions:
        findings.append(make_finding(
            counter, "F-PERM-001", "CTRL-PERM-001", "medium",
            "High-risk permissions requested",
            "The package requests one or more Android permissions that materially expand device access.",
            "Broad or sensitive permissions raise abuse potential and should be justified in the triage record.",
            {"kind": "package", "id": package_name},
            [eid for obs in risky_permissions for eid in obs["source_evidence_ids"]],
            [obs["observation_id"] for obs in risky_permissions],
            "Confirm least privilege and test whether the package still functions if unnecessary permissions are revoked.",
            ["permissions", "privacy", "android"],
        ))
        counter += 1

    secret_hits = by_type["android.strings.secret_like"]
    strong_secret_hits, config_secret_hits, ignored_secret_hits = classify_secret_hits(secret_hits)
    if strong_secret_hits:
        findings.append(make_finding(
            counter, "F-SECRET-001", "CTRL-SECRET-001", "medium",
            "Potential embedded credential material detected in APK content",
            f'{len(strong_secret_hits)} string hits look like credential or token material after noise filtering.',
            "Hard-coded credentials or tokens can leak trust material to reverse engineers and malware.",
            {"kind": "package", "id": package_name},
            [eid for obs in strong_secret_hits for eid in obs["source_evidence_ids"]],
            [obs["observation_id"] for obs in strong_secret_hits],
            "Validate whether matched strings are real secrets or placeholders and move live credentials server-side.",
            ["secrets", "static-analysis", "credentials"],
        ))
        counter += 1
    elif config_secret_hits:
        findings.append(make_finding(
            counter, "F-CONFIG-001", "CTRL-CONFIG-001", "info",
            "Backend configuration identifiers detected in APK content",
            f'{len(config_secret_hits)} filtered string hits suggest backend endpoint or config identifiers rather than embedded credentials.',
            "Backend identifiers are useful analyst context, but they are not by themselves evidence of an exposed secret.",
            {"kind": "package", "id": package_name},
            [eid for obs in config_secret_hits for eid in obs["source_evidence_ids"]],
            [obs["observation_id"] for obs in config_secret_hits],
            "Review exposed endpoints and confirm any associated credentials are not embedded in the client.",
            ["config", "backend", "static-analysis"],
        ))
        counter += 1

    webview_hits = by_type["android.strings.webview_indicator"]
    if webview_hits:
        findings.append(make_finding(
            counter, "F-WEBVIEW-001", "CTRL-WEBVIEW-001", "medium",
            "WebView-relevant indicators detected",
            f'{len(webview_hits)} WebView-related indicators were found in strings output.',
            "Embedded browser features are common sources of Android trust-boundary bugs.",
            {"kind": "package", "id": package_name},
            [eid for obs in webview_hits for eid in obs["source_evidence_ids"]],
            [obs["observation_id"] for obs in webview_hits],
            "Review WebView hardening settings, JavaScript exposure, and file/content URL handling.",
            ["webview", "static-analysis", "android"],
        ))
        counter += 1

    storage_hits = [
        obs for obs in by_type["android.storage.entry"]
        if obs["attributes"].get("section") == "shared_prefs"
    ]
    if storage_hits:
        findings.append(make_finding(
            counter, "F-STORAGE-001", "CTRL-STORAGE-001", "low",
            "Application storage was readable through run-as",
            "The triage session was able to enumerate application-private storage via run-as.",
            "Readable preferences and files are useful evidence and may expose plaintext secrets or sensitive state.",
            {"kind": "package", "id": package_name},
            [eid for obs in storage_hits for eid in obs["source_evidence_ids"]],
            [obs["observation_id"] for obs in storage_hits],
            "Review shared preferences and file contents for plaintext secrets, tokens, or unsafe debug artifacts.",
            ["storage", "run-as", "local-data"],
        ))
        counter += 1

    out_path = run_dir / "findings" / "findings.jsonl"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8") as fh:
        for item in findings:
            fh.write(json.dumps(item, sort_keys=True))
            fh.write("\n")
    stats = {
        "secret_hits_total": len(secret_hits),
        "secret_hits_strong": len(strong_secret_hits),
        "secret_hits_config": len(config_secret_hits),
        "secret_hits_ignored": len(ignored_secret_hits),
    }
    (run_dir / "findings" / "rule_stats.json").write_text(json.dumps(stats, indent=2), encoding="utf-8")
    print(str(out_path))


if __name__ == "__main__":
    main()
