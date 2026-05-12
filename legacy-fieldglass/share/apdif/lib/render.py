#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


FRIENDLY_TITLES = {
    "device info": "Device and Session Context",
    "doctor": "Dependency and Environment Doctor",
    "permissions": "Requested Permission Footprint",
    "runtime perms": "Runtime Permission State",
    "appops": "AppOps Runtime Controls",
    "exported": "Exported Component Surface",
    "deep links": "Deep Link Entry Points",
    "storage": "Local Storage Review",
    "webview": "WebView Behavior Indicators",
    "runtime snapshot": "Runtime Snapshot",
    "manifest": "Manifest and Package Identity",
    "components": "Component Exposure Review",
    "secret-like strings": "Embedded Secret Indicators",
    "webview indicators": "WebView Runtime Indicators",
    "shared prefs": "Shared Preferences",
    "databases": "Local Databases",
    "files": "Application Files",
    "process list": "Observed Processes",
    "files via run-as": "Files Accessible via run-as",
    "activity resolver table": "Launchable and Addressable Activities",
    "receiver resolver table": "Broadcast Receivers and Event Hooks",
    "service resolver table": "Background Services and Entry Points",
    "registered contentproviders": "Registered Content Providers",
    "contentprovider authorities": "Provider URI Namespaces",
}

SECTION_ORDER = [
    "device info",
    "permissions",
    "runtime perms",
    "appops",
    "exported",
    "deep links",
    "storage",
    "webview",
    "runtime snapshot",
]

SEVERITY_LABELS = {
    "critical": "🔴 CRITICAL",
    "review": "🟠 REVIEW",
    "info": "🟡 INFO",
    "raw": "⚪ RAW",
}


def slugify(value: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    return slug or "section"


def friendly_title(name: str) -> str:
    return FRIENDLY_TITLES.get(name.strip().lower(), name.strip().title())


def severity_rank(value: str) -> int:
    return {"critical": 0, "review": 1, "info": 2, "raw": 3}.get(value, 2)


def split_named_sections(raw_text: str, allowed_names: set[str] | None = None) -> list[tuple[str, str]]:
    sections: list[tuple[str, str]] = []
    current_name: str | None = None
    current_lines: list[str] = []

    for line in raw_text.splitlines():
        match = re.match(r"^==\s+(.+?)\s+==$", line.strip())
        if match:
            candidate = match.group(1).strip()
            if allowed_names is not None and candidate.lower() not in allowed_names:
                current_lines.append(line)
                continue
            if current_name is not None:
                sections.append((current_name, "\n".join(current_lines).strip("\n")))
            current_name = candidate
            current_lines = []
            continue
        current_lines.append(line)

    if current_name is not None:
        sections.append((current_name, "\n".join(current_lines).strip("\n")))

    return sections


def parse_key_values(raw_text: str) -> dict[str, str]:
    result: dict[str, str] = {}
    for line in raw_text.splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        result[key.strip()] = value.strip()
    return result


def parse_list_items(raw_text: str) -> list[str]:
    items: list[str] = []
    for line in raw_text.splitlines():
        value = line.strip()
        if value:
            items.append(value)
    return items


def parse_runtime_permissions(raw_text: str) -> list[dict[str, str]]:
    perms: list[dict[str, str]] = []
    for line in raw_text.splitlines():
        match = re.match(r"^\s*([A-Za-z0-9._]+):\s*(.+)$", line)
        if match:
            perms.append({"permission": match.group(1), "state": match.group(2).strip()})
    return perms


def parse_appops(raw_text: str) -> list[dict[str, str]]:
    appops: list[dict[str, str]] = []
    for line in raw_text.splitlines():
        match = re.match(r"^\s*([A-Z0-9_]+):\s*(.+)$", line)
        if match:
            appops.append({"name": match.group(1), "state": match.group(2).strip()})
    return appops


def parse_exported_groups(raw_text: str) -> dict[str, list[str]]:
    groups: dict[str, list[str]] = {}
    current: str | None = None
    for line in raw_text.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        heading = stripped.rstrip(":").strip()
        if stripped.endswith(":") and heading.lower() in {
            "activity resolver table",
            "receiver resolver table",
            "service resolver table",
            "registered contentproviders",
            "contentprovider authorities",
        }:
            current = heading
            groups.setdefault(current, [])
            continue
        if current is not None:
            groups[current].append(stripped)
    return groups


def parse_env_status(raw_text: str) -> tuple[list[dict[str, str]], list[dict[str, str]]]:
    checks: list[dict[str, str]] = []
    findings: list[dict[str, str]] = []
    for line in raw_text.splitlines():
        match = re.match(r"^\[(FOUND|MISSING|OPTIONAL)\]\s+([A-Za-z0-9._+-]+)(?:\s*->\s*(.+))?$", line.strip())
        if not match:
            continue
        status, tool, resolved = match.groups()
        item = {"tool": tool, "status": status.lower(), "path": (resolved or "").strip()}
        checks.append(item)
        if status == "MISSING":
            findings.append(
                finding(
                    "review",
                    f"Missing dependency: {tool}",
                    f"{tool} was not resolved from PATH or common Android SDK locations.",
                    "doctor",
                )
            )
        if status == "OPTIONAL" and not item["path"]:
            findings.append(
                finding(
                    "info",
                    f"Optional dependency unavailable: {tool}",
                    f"{tool} is optional and was not found on this host.",
                    "doctor",
                )
            )
    return checks, findings


def parse_storage_nested(raw_text: str) -> dict[str, list[str]]:
    nested = {name: parse_list_items(body) for name, body in split_named_sections(raw_text)}
    return nested


def finding(severity: str, title: str, details: str, evidence_section: str) -> dict[str, str]:
    return {
        "severity": severity,
        "label": SEVERITY_LABELS[severity],
        "title": title,
        "details": details,
        "evidence_section": evidence_section,
    }


def summarize_lines(lines: list[str], limit: int = 8) -> str:
    if not lines:
        return "- No evidence captured."
    clipped = lines[:limit]
    suffix = []
    if len(lines) > limit:
        suffix.append(f"- ... {len(lines) - limit} additional lines preserved in raw evidence.")
    return "\n".join(f"- {line}" for line in clipped + suffix)


def section_payload(name: str, raw_text: str) -> tuple[dict[str, object], list[dict[str, str]]]:
    key = name.strip().lower()
    title = friendly_title(name)
    findings: list[dict[str, str]] = []
    severity = "info"
    summary = "Captured raw evidence."
    body = summarize_lines(parse_list_items(raw_text))

    if key == "device info":
        device = parse_key_values(raw_text)
        lines = [f"{k}: {v}" for k, v in device.items()]
        summary = f"Captured {len(device)} device identity fields."
        body = summarize_lines(lines)

    elif key == "permissions":
        perms = [line.strip() for line in raw_text.splitlines() if line.strip().startswith(("android.", "moe.", "com."))]
        summary = f"Observed {len(perms)} declared permissions."
        body = summarize_lines(perms)
        sensitive = [perm for perm in perms if perm.endswith("WRITE_SECURE_SETTINGS") or perm.endswith(".permission.MANAGER")]
        if sensitive:
            severity = "critical"
            findings.append(
                finding(
                    "critical",
                    "High-privilege permission declared",
                    f"Sensitive permissions present: {', '.join(sensitive)}.",
                    key,
                )
            )
        elif perms:
            severity = "review"

    elif key == "runtime perms":
        perms = parse_runtime_permissions(raw_text)
        granted = [item["permission"] for item in perms if "granted=true" in item["state"]]
        summary = f"{len(granted)} runtime permissions granted out of {len(perms)} observed."
        body = summarize_lines([f'{item["permission"]}: {item["state"]}' for item in perms])
        if granted:
            severity = "review"
            findings.append(
                finding(
                    "review",
                    "Runtime permissions granted",
                    f"Granted runtime permissions: {', '.join(granted)}.",
                    key,
                )
            )

    elif key == "appops":
        ops = parse_appops(raw_text)
        allow = [item["name"] for item in ops if "allow" in item["state"].lower()]
        ignored = sum(1 for item in ops if "ignore" in item["state"].lower())
        summary = f"{len(allow)} app-ops allow entries and {ignored} ignored entries observed."
        body = summarize_lines([f'{item["name"]}: {item["state"]}' for item in ops if "allow" in item["state"].lower()] or [f"{ignored} app-ops entries are set to ignore."])
        if allow:
            severity = "review"

    elif key == "exported":
        groups = parse_exported_groups(raw_text)
        rendered: list[str] = []
        total = 0
        for group_name, entries in groups.items():
            interesting = [entry for entry in entries if "/" in entry or "Provider{" in entry]
            total += len(interesting)
            rendered.append(f"{friendly_title(group_name)}: {len(interesting)} entries")
            rendered.extend(interesting[:5])
        summary = f"Observed {total} exported or addressable surface entries."
        body = summarize_lines(rendered, limit=10)
        if total:
            severity = "review"
            findings.append(
                finding(
                    "review",
                    "Exported component surface present",
                    f"Found {total} activity, receiver, service, or provider entries exposed in dumpsys output.",
                    key,
                )
            )

    elif key == "deep links":
        lines = [line.strip() for line in raw_text.splitlines() if line.strip()]
        summary = "Deep-link related lines were captured from the package dump."
        body = summarize_lines(lines)
        if lines:
            severity = "review"

    elif key == "storage":
        nested = parse_storage_nested(raw_text)
        prefs = len(nested.get("shared prefs", []))
        dbs = len(nested.get("databases", []))
        files = len(nested.get("files", []))
        summary = f"Storage review found {prefs} shared-pref lines, {dbs} database lines, and {files} file lines."
        rendered = [
            f"Shared Preferences: {prefs} lines",
            f"Local Databases: {dbs} lines",
            f"Application Files: {files} lines",
        ]
        for nested_name in ("shared prefs", "databases", "files"):
            items = nested.get(nested_name, [])
            rendered.extend(items[:4])
        body = summarize_lines(rendered, limit=12)
        if prefs or dbs or files:
            severity = "review"

    elif key == "webview":
        indicators = [line.strip() for line in raw_text.splitlines() if line.strip()]
        summary = f"Observed {len(indicators)} WebView-related indicators."
        body = summarize_lines(indicators)
        if indicators:
            severity = "review"
            findings.append(
                finding(
                    "review",
                    "WebView indicators present",
                    "Static or dynamic evidence references WebView-related APIs or URI handling paths.",
                    key,
                )
            )

    elif key == "runtime snapshot":
        nested = split_named_sections(raw_text)
        rendered = []
        for nested_name, nested_body in nested:
            lines = parse_list_items(nested_body)
            rendered.append(f"{friendly_title(nested_name)}: {len(lines)} lines")
            rendered.extend(lines[:4])
        summary = f"Captured {len(nested)} runtime snapshot subsections."
        body = summarize_lines(rendered, limit=12)
        if nested:
            severity = "review"

    elif key in {"secret-like strings", "secrets"}:
        items = parse_list_items(raw_text)
        summary = f"Observed {len(items)} secret-like string matches."
        body = summarize_lines(items)
        if items:
            severity = "critical"
            findings.append(
                finding(
                    "critical",
                    "Secret-like constants detected",
                    "Static strings matched secret, token, password, or key indicators.",
                    key,
                )
            )

    elif key in {"components", "component extraction"}:
        items = parse_list_items(raw_text)
        summary = f"Component extraction returned {len(items)} relevant lines."
        body = summarize_lines(items)
        if items:
            severity = "review"

    elif key in {"doctor", "dependency and environment doctor"}:
        checks, doctor_findings = parse_env_status(raw_text)
        found = sum(1 for item in checks if item["status"] == "found")
        missing = sum(1 for item in checks if item["status"] == "missing")
        optional = sum(1 for item in checks if item["status"] == "optional" and not item["path"])
        summary = f"Resolved {found} tools, {missing} missing requirements, and {optional} optional gaps."
        body = summarize_lines(
            [
                f"{item['status'].upper()}: {item['tool']}" + (f" -> {item['path']}" if item["path"] else "")
                for item in checks
            ],
            limit=20,
        )
        findings.extend(doctor_findings)
        severity = "critical" if missing else ("info" if optional else "info")

    else:
        lines = parse_list_items(raw_text)
        if any(token in raw_text for token in ("WRITE_SECURE_SETTINGS", "addJavascriptInterface", "BROWSABLE", "exported")):
            severity = "review"
        summary = f"Captured {len(lines)} evidence lines."
        body = summarize_lines(lines)

    payload = {
        "id": slugify(key),
        "title": title,
        "severity": severity,
        "label": SEVERITY_LABELS[severity],
        "summary": summary,
        "body": body,
        "raw": raw_text,
    }
    return payload, findings


def order_sections(sections: list[dict[str, object]]) -> list[dict[str, object]]:
    order = {name: index for index, name in enumerate(SECTION_ORDER)}

    def sort_key(section: dict[str, object]) -> tuple[int, int, str]:
        key = str(section["id"]).replace("-", " ")
        return (order.get(key, len(order)), severity_rank(str(section["severity"])), str(section["title"]))

    return sorted(sections, key=sort_key)


def analyze_payload(module: str, command: str, target: str, device_serial: str, raw_text: str) -> dict[str, object]:
    errors: list[str] = []
    findings: list[dict[str, str]] = []
    sections: list[dict[str, object]] = []

    if module == "report":
        module = "triage"
        command = "run"

    allowed_names = None
    if module == "triage":
        allowed_names = set(SECTION_ORDER)
    named_sections = split_named_sections(raw_text, allowed_names=allowed_names)

    if module == "env" or command == "doctor":
        named_sections = []

    if named_sections:
        for name, body in named_sections:
            payload, section_findings = section_payload(name, body)
            sections.append(payload)
            findings.extend(section_findings)
    else:
        synthetic_name = command or module
        payload, section_findings = section_payload(synthetic_name, raw_text)
        sections.append(payload)
        findings.extend(section_findings)

    if not raw_text.strip():
        errors.append("No raw output was captured.")

    sections = order_sections(sections)
    if not device_serial:
        for section in sections:
            if section["id"] == "device-info":
                device = parse_key_values(str(section["raw"]))
                device_serial = device.get("Serial", "")
                break
    highest = min((severity_rank(str(section["severity"])) for section in sections), default=2)
    summary = {
        "command": command,
        "module_title": module.title(),
        "target": target,
        "section_count": len(sections),
        "finding_count": len(findings),
        "highest_severity": {0: "critical", 1: "review", 2: "info", 3: "raw"}.get(highest, "info"),
    }

    return {
        "module": module,
        "target": target,
        "device": {"serial": device_serial or None},
        "summary": summary,
        "findings": findings,
        "sections": sections,
        "raw": raw_text,
        "errors": errors,
    }


def render_markdown(payload: dict[str, object], case_name: str, pkg: str) -> str:
    lines = [
        "# APDIF Consolidated Report",
        "",
        "## Executive Summary",
        f"- Case: {case_name}",
        f"- Package: {pkg}",
        f"- Device Serial: {payload['device'].get('serial') or 'unknown'}",
        f"- Sections Reviewed: {payload['summary']['section_count']}",
        f"- Findings Raised: {payload['summary']['finding_count']}",
        f"- Highest Severity: {SEVERITY_LABELS[payload['summary']['highest_severity']]}",
        "",
    ]

    findings = payload.get("findings", [])
    if findings:
        lines.extend(["## Key Findings", ""])
        for item in findings:
            lines.append(f"- {item['label']}: {item['title']} — {item['details']}")
        lines.append("")
    else:
        lines.extend(["## Key Findings", "", "- 🟡 INFO: No automated findings were raised from the captured evidence.", ""])

    lines.append("## Evidence Review")
    lines.append("")
    for section in payload.get("sections", []):
        lines.append(f"### {section['label']} {section['title']}")
        lines.append("")
        lines.append(section["summary"])
        lines.append("")
        lines.append(section["body"])
        lines.append("")

    lines.extend(
        [
            "## Raw Evidence",
            "",
            "### ⚪ RAW Complete Original Output",
            "",
            "```text",
            str(payload.get("raw", "")).rstrip(),
            "```",
            "",
        ]
    )

    return "\n".join(lines).rstrip() + "\n"


def load_raw_text(path: str) -> str:
    return Path(path).read_text(encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="mode", required=True)

    module_parser = subparsers.add_parser("module-json")
    module_parser.add_argument("--module", required=True)
    module_parser.add_argument("--command", required=True)
    module_parser.add_argument("--target", default="")
    module_parser.add_argument("--device-serial", default="")
    module_parser.add_argument("--raw-file", required=True)

    report_json_parser = subparsers.add_parser("report-json")
    report_json_parser.add_argument("--case", required=True)
    report_json_parser.add_argument("--pkg", required=True)
    report_json_parser.add_argument("--device-serial", default="")
    report_json_parser.add_argument("--raw-file", required=True)

    report_md_parser = subparsers.add_parser("report-markdown")
    report_md_parser.add_argument("--case", required=True)
    report_md_parser.add_argument("--pkg", required=True)
    report_md_parser.add_argument("--device-serial", default="")
    report_md_parser.add_argument("--raw-file", required=True)

    args = parser.parse_args()

    if args.mode == "module-json":
        payload = analyze_payload(args.module, args.command, args.target, args.device_serial, load_raw_text(args.raw_file))
        print(json.dumps(payload, indent=2))
        return

    payload = analyze_payload("report", "build", args.pkg, args.device_serial, load_raw_text(args.raw_file))
    payload["module"] = "report"
    payload["summary"]["case"] = args.case
    payload["summary"]["report_format"] = "json" if args.mode == "report-json" else "md"

    if args.mode == "report-json":
        print(json.dumps(payload, indent=2))
        return

    print(render_markdown(payload, args.case, args.pkg), end="")


if __name__ == "__main__":
    main()
