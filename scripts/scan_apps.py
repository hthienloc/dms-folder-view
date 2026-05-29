#!/usr/bin/env python3
import os
import json
import re

DESKTOP_DIRS = [
    "/usr/share/applications",
    "/usr/local/share/applications",
    os.path.expanduser("~/.local/share/applications"),
    "/var/lib/flatpak/exports/share/applications",
    os.path.expanduser("~/.local/share/flatpak/exports/share/applications"),
    "/var/lib/snapd/desktop/applications"
]

CATEGORY_MAPPING = {
    "Development": "Development",
    "Game": "Game",
    "Graphics": "Graphics",
    "Network": "Internet",
    "Internet": "Internet",
    "WebBrowser": "Internet",
    "Office": "Office",
    "System": "System",
    "TerminalEmulator": "System",
    "FileManager": "System",
    "Audio": "Multimedia",
    "Video": "Multimedia",
    "AudioVideo": "Multimedia",
    "Player": "Multimedia",
    "Utility": "Utility",
    "Settings": "System"
}

def parse_desktop_file(filepath):
    if not os.path.exists(filepath) or not filepath.endswith(".desktop"):
        return None
    
    app_data = {
        "name": "",
        "icon": "",
        "exec": "",
        "filepath": filepath,
        "categories": [],
        "no_display": False,
        "hidden": False
    }
    
    try:
        with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
            in_entry = False
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                
                if line == "[Desktop Entry]":
                    in_entry = True
                    continue
                elif line.startswith("[") and line.endswith("]"):
                    in_entry = False
                    continue
                
                if in_entry:
                    if "=" in line:
                        key, val = line.split("=", 1)
                        key = key.strip()
                        val = val.strip()
                        
                        if key == "Name":
                            app_data["name"] = val
                        elif key == "Icon":
                            app_data["icon"] = val
                        elif key == "Exec":
                            # Strip field codes like %u, %F, %U, %f, etc.
                            val_clean = re.sub(r'%[fFuUiIcDkKvV]', '', val).strip()
                            app_data["exec"] = val_clean
                        elif key == "Categories":
                            cats = [c.strip() for c in val.split(";") if c.strip()]
                            mapped_cats = set()
                            for c in cats:
                                if c in CATEGORY_MAPPING:
                                    mapped_cats.add(CATEGORY_MAPPING[c])
                                elif c.startswith("X-") and c[2:] in CATEGORY_MAPPING:
                                    mapped_cats.add(CATEGORY_MAPPING[c[2:]])
                            app_data["categories"] = list(mapped_cats)
                        elif key == "NoDisplay":
                            app_data["no_display"] = val.lower() == "true"
                        elif key == "Hidden":
                            app_data["hidden"] = val.lower() == "true"
                            
    except Exception:
        return None
        
    if not app_data["name"] or not app_data["exec"] or app_data["no_display"] or app_data["hidden"]:
        return None
        
    # If no mapped categories found, default to Utility
    if not app_data["categories"]:
        app_data["categories"] = ["Utility"]
        
    return app_data

def scan_applications():
    apps = {}
    for d in DESKTOP_DIRS:
        if not os.path.exists(d):
            continue
        for filename in os.listdir(d):
            if filename.endswith(".desktop"):
                filepath = os.path.join(d, filename)
                data = parse_desktop_file(filepath)
                if data:
                    # Prefer user overrides over system-wide apps
                    key = data["name"].lower()
                    if d.startswith("/home") or key not in apps:
                        apps[key] = data
                        
    return sorted(apps.values(), key=lambda x: x["name"].lower())

if __name__ == "__main__":
    app_list = scan_applications()
    print(json.dumps(app_list, ensure_ascii=False, indent=2))
