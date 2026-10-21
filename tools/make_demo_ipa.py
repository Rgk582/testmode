"""Builds the demo IPA from two inputs, so no Test Mode files ever need to live in this repo.

  python3 make_demo_ipa.py <your Test Mode .ipa> <shell .ipa from this repo's release> <output .ipa>

It copies the shell app, then adds the www-secure web files and the app icons from your Test Mode IPA.
"""
import plistlib
import sys
import zipfile

ICON_KEYS = ("CFBundleIcons", "CFBundleIcons~ipad")


def app_prefix(names):
    for name in names:
        parts = name.split("/")
        if len(parts) > 2 and parts[0] == "Payload" and parts[1].endswith(".app"):
            return "Payload/" + parts[1] + "/"
    sys.exit("No .app folder found inside the IPA")


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    original_path, shell_path, out_path = sys.argv[1:4]
    original, shell = zipfile.ZipFile(original_path), zipfile.ZipFile(shell_path)
    orig_prefix, shell_prefix = app_prefix(original.namelist()), app_prefix(shell.namelist())

    web = [n for n in original.namelist() if n.startswith(orig_prefix + "www-secure/") and not n.endswith("/")]
    if not any(n.endswith("www-secure/index.html") for n in web):
        sys.exit("www-secure/index.html is not in the Test Mode IPA")

    orig_info = plistlib.loads(original.read(orig_prefix + "Info.plist"))
    shell_info = plistlib.loads(shell.read(shell_prefix + "Info.plist"))

    icon_names = set()
    for key in ICON_KEYS:
        primary = orig_info.get(key, {}).get("CFBundlePrimaryIcon", {})
        icon_names.update(primary.get("CFBundleIconFiles", []))
        if key in orig_info:
            primary = dict(primary)
            primary.pop("CFBundleIconName", None)  # the icon catalog is not copied, only loose PNGs
            shell_info[key] = {"CFBundlePrimaryIcon": primary}

    icons = [
        n for n in original.namelist()
        if n.startswith(orig_prefix) and "/" not in n[len(orig_prefix):] and n.endswith(".png")
        and any(n[len(orig_prefix):].startswith(i) for i in icon_names)
    ]

    with zipfile.ZipFile(out_path, "w", zipfile.ZIP_DEFLATED) as out:
        for info in shell.infolist():
            data = shell.read(info)
            if info.filename == shell_prefix + "Info.plist":
                data = plistlib.dumps(shell_info, fmt=plistlib.FMT_BINARY)
            out.writestr(info, data)
        for name in web + icons:
            entry = zipfile.ZipInfo(shell_prefix + name[len(orig_prefix):], date_time=(2026, 1, 1, 0, 0, 0))
            entry.external_attr = 0o644 << 16
            entry.compress_type = zipfile.ZIP_DEFLATED
            out.writestr(entry, original.read(name))

    print(f"Wrote {out_path}: {len(web)} web files, {len(icons)} icon files added to {shell_prefix}")


main()
