#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path


COMPONENT_TYPES = {"activity", "activity-alias", "service", "receiver", "provider"}
SYSTEM_NAMESPACE_PREFIXES = (
    "com.google.",
    "com.google.android.",
    "com.google.firebase.",
    "androidx.",
    "pub.devrel.",
)


def parse_attr(line: str):
    quoted = re.match(r'A:\s+((?:android:)?[\w.:-]+).*?="([^"]*)"', line)
    if quoted:
        return quoted.group(1), quoted.group(2)
    typed = re.match(r'A:\s+((?:android:)?[\w.:-]+).*?=\(type\s+0x([0-9a-fA-F]+)\)(0x[0-9a-fA-F]+|\d+)', line)
    if typed:
        key = typed.group(1)
        type_code = typed.group(2).lower()
        raw_value = typed.group(3).lower()
        if type_code == "12":
            value = "true" if raw_value not in {"0x0", "0"} else "false"
        elif raw_value.startswith("0x"):
            value = str(int(raw_value, 16))
        else:
            value = raw_value
        return key, value
    return None, None


def normalize_manifest_text(raw_text: str, evidence_id: str, package_name: str):
    lines = raw_text.splitlines()
    observations = []
    stack = []
    root_nodes = []

    for raw in lines:
      indent = len(raw) - len(raw.lstrip(" "))
      stripped = raw.strip()
      if stripped.startswith("E: "):
          kind = stripped[3:].split()[0]
          node = {"kind": kind, "attrs": {}, "children": []}
          while stack and stack[-1][0] >= indent:
              stack.pop()
          if stack:
              stack[-1][1]["children"].append(node)
          else:
              root_nodes.append(node)
          stack.append((indent, node))
      elif stripped.startswith("A: ") and stack:
          key, value = parse_attr(stripped)
          if key:
              stack[-1][1]["attrs"][key] = value

    manifest_meta = {
        "package_name": package_name,
        "target_sdk": None,
        "min_sdk": None,
        "uses_cleartext_traffic": None,
        "allow_backup": None,
    }

    def component_owner(name: str) -> str:
        if not name:
            return "unknown"
        if name.startswith("."):
            return "first_party"
        if name.startswith(package_name):
            return "first_party"
        if name.startswith(SYSTEM_NAMESPACE_PREFIXES):
            return "third_party"
        return "third_party"

    def walk(nodes, current_component=None):
        for node in nodes:
            kind = node["kind"]
            attrs = node["attrs"]
            if kind == "uses-sdk":
                if attrs.get("android:targetSdkVersion") or attrs.get("targetSdkVersion"):
                    manifest_meta["target_sdk"] = attrs.get("android:targetSdkVersion") or attrs.get("targetSdkVersion")
                if attrs.get("android:minSdkVersion") or attrs.get("minSdkVersion"):
                    manifest_meta["min_sdk"] = attrs.get("android:minSdkVersion") or attrs.get("minSdkVersion")
            elif kind == "application":
                if "android:usesCleartextTraffic" in attrs or "usesCleartextTraffic" in attrs:
                    manifest_meta["uses_cleartext_traffic"] = attrs.get("android:usesCleartextTraffic") or attrs.get("usesCleartextTraffic")
                if "android:allowBackup" in attrs or "allowBackup" in attrs:
                    manifest_meta["allow_backup"] = attrs.get("android:allowBackup") or attrs.get("allowBackup")
            if kind in COMPONENT_TYPES:
                explicit_exported = attrs.get("android:exported") or attrs.get("exported")
                current_component = {
                    "component_type": kind,
                    "name": attrs.get("android:name") or attrs.get("name", ""),
                    "explicit_exported": explicit_exported if explicit_exported is not None else "",
                    "effective_exported": explicit_exported if explicit_exported is not None else "",
                    "export_reason": "explicit" if explicit_exported not in (None, "") else "unknown",
                    "permission": attrs.get("android:permission") or attrs.get("permission", ""),
                    "authorities": attrs.get("android:authorities") or attrs.get("authorities", ""),
                    "owner": component_owner(attrs.get("android:name") or attrs.get("name", "")),
                    "has_intent_filter": False,
                }
                observations.append({
                    "type": "android.manifest.component",
                    "subject": {"kind": "package", "id": package_name},
                    "attributes": current_component,
                    "source_evidence_ids": [evidence_id],
                    "normalizer_id": "android.aapt.manifest.v1",
                    "confidence": "high",
                    "notes": "",
                })
            elif kind == "uses-permission":
                perm_name = attrs.get("android:name") or attrs.get("name", "")
                if perm_name:
                    observations.append({
                        "type": "android.permission.requested",
                        "subject": {"kind": "package", "id": package_name},
                        "attributes": {"name": perm_name},
                        "source_evidence_ids": [evidence_id],
                        "normalizer_id": "android.aapt.manifest.v1",
                        "confidence": "high",
                        "notes": "",
                    })
            elif kind == "intent-filter" and current_component:
                current_component["has_intent_filter"] = True
                actions = []
                categories = []
                schemes = []
                hosts = []
                paths = []
                for child in node["children"]:
                    child_attrs = child["attrs"]
                    if child["kind"] == "action":
                        value = child_attrs.get("android:name") or child_attrs.get("name")
                        if value:
                            actions.append(value)
                    elif child["kind"] == "category":
                        value = child_attrs.get("android:name") or child_attrs.get("name")
                        if value:
                            categories.append(value)
                    elif child["kind"] == "data":
                        for key in ("android:scheme", "scheme"):
                            if child_attrs.get(key):
                                schemes.append(child_attrs[key])
                        for key in ("android:host", "host"):
                            if child_attrs.get(key):
                                hosts.append(child_attrs[key])
                        for key in ("android:path", "path"):
                            if child_attrs.get(key):
                                paths.append(child_attrs[key])
                if actions or categories or schemes or hosts or paths:
                    if current_component["export_reason"] == "unknown":
                        current_component["effective_exported"] = "true"
                        current_component["export_reason"] = "implicit_intent_filter"
                    observations.append({
                        "type": "android.manifest.intent_filter",
                        "subject": {"kind": "package", "id": package_name},
                        "attributes": {
                            "component_name": current_component["name"],
                            "component_type": current_component["component_type"],
                            "owner": current_component["owner"],
                            "actions": sorted(set(actions)),
                            "categories": sorted(set(categories)),
                            "schemes": sorted(set(schemes)),
                            "hosts": sorted(set(hosts)),
                            "paths": sorted(set(paths)),
                        },
                        "source_evidence_ids": [evidence_id],
                        "normalizer_id": "android.aapt.manifest.v1",
                        "confidence": "high",
                        "notes": "",
                    })
            walk(node["children"], current_component)

    walk(root_nodes)
    observations.insert(0, {
        "type": "android.manifest.package_meta",
        "subject": {"kind": "package", "id": package_name},
        "attributes": manifest_meta,
        "source_evidence_ids": [evidence_id],
        "normalizer_id": "android.aapt.manifest.v1",
        "confidence": "high",
        "notes": "",
    })
    return observations


def main():
    raw_path, evidence_id, package_name = sys.argv[1:4]
    raw_text = Path(raw_path).read_text(encoding="utf-8", errors="replace")
    observations = normalize_manifest_text(raw_text, evidence_id, package_name)
    print(json.dumps(observations, indent=2))


if __name__ == "__main__":
    main()
