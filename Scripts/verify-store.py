#!/usr/bin/env python3
"""Check a built Store app locally; this does not replace Apple's validation."""
import argparse
from datetime import datetime, timezone
from pathlib import Path
import plistlib
import re
import subprocess
import sys

BUNDLE_ID = "com.mehrdad.storagefix"
REQUIRED_ENTITLEMENTS = {
    "com.apple.security.app-sandbox": True,
    "com.apple.security.files.user-selected.read-write": True,
    # Remembers the one-time Home grant for cache cleanup (owner decision, October 18, 2026).
    "com.apple.security.files.bookmarks.app-scope": True,
}
OPTIONAL_ENTITLEMENTS = {
    "com.apple.application-identifier", "com.apple.developer.team-identifier",
    "keychain-access-groups",
}
API_REASONS = {
    "NSPrivacyAccessedAPICategoryUserDefaults": {"CA92.1"},
    "NSPrivacyAccessedAPICategoryDiskSpace": {"85F4.1"},
    "NSPrivacyAccessedAPICategoryFileTimestamp": {"C617.1", "3B52.1"},
}


class VerificationError(Exception):
    pass


def require(condition, message):
    if not condition:
        raise VerificationError(message)


def run(*args):
    result = subprocess.run(args, capture_output=True, check=False)
    require(result.returncode == 0,
            f"{args[0]} failed: {result.stderr.decode(errors='replace').strip()}")
    return result.stdout


def read_plist(path):
    with path.open("rb") as file:
        return plistlib.load(file)


def check_entitlements(entitlements):
    for key, value in REQUIRED_ENTITLEMENTS.items():
        require(entitlements.get(key) is value, f"Missing required entitlement: {key}")
    unexpected = set(entitlements) - set(REQUIRED_ENTITLEMENTS) - OPTIONAL_ENTITLEMENTS
    require(not unexpected, f"Unexpected Store entitlements: {sorted(unexpected)}")


def check_privacy(privacy):
    require(privacy.get("NSPrivacyTracking") is False, "Tracking must be false")
    require(privacy.get("NSPrivacyCollectedDataTypes") == [], "Review data collection declaration")
    require(privacy.get("NSPrivacyTrackingDomains", []) == [], "Unexpected tracking domains")
    entries = privacy.get("NSPrivacyAccessedAPITypes", [])
    actual = {item["NSPrivacyAccessedAPIType"]: set(item["NSPrivacyAccessedAPITypeReasons"])
              for item in entries}
    require(len(entries) == len(actual), "Duplicate required-reason API entries")
    require(actual == API_REASONS, "Required-reason API declarations differ from audited usage")


def check_profile(profile, entitlements, bundle_id, now):
    expiration = profile.get("ExpirationDate")
    require(isinstance(expiration, datetime), "Profile expiration missing")
    require(expiration.replace(tzinfo=timezone.utc) > now, "Provisioning profile expired")
    require(not profile.get("ProvisionedDevices"), "Development/ad hoc profile cannot be submitted")
    require(not profile.get("ProvisionsAllDevices"), "Developer ID profile cannot be submitted")
    permitted = profile.get("Entitlements", {})
    require(not permitted.get("get-task-allow"), "Development debugging entitlement is enabled")
    team = entitlements.get("com.apple.developer.team-identifier")
    identifier = entitlements.get("com.apple.application-identifier")
    require(team and team in profile.get("TeamIdentifier", []), "Profile and signing team differ")
    require(identifier == permitted.get("com.apple.application-identifier"), "App ID differs from profile")
    require(identifier and identifier.endswith("." + bundle_id), "Profile does not match bundle ID")


def check_submission(app, entitlements, bundle_id, package):
    signature = subprocess.run(["/usr/bin/codesign", "-dvv", str(app)], capture_output=True, check=True)
    details = signature.stderr.decode(errors="replace")
    require("Signature=adhoc" not in details, "Ad hoc builds cannot be submitted")
    require(re.search(r"Authority=(Apple Distribution:|3rd Party Mac Developer Application:)", details),
            "A Mac App Store distribution signing identity is required")
    profile_path = app / "Contents/embedded.provisionprofile"
    require(profile_path.is_file(), "Embedded App Store provisioning profile missing")
    profile = plistlib.loads(run("/usr/bin/security", "cms", "-D", "-i", str(profile_path)))
    check_profile(profile, entitlements, bundle_id, datetime.now(timezone.utc))
    team = entitlements["com.apple.developer.team-identifier"]
    require(f"TeamIdentifier={team}" in details, "App certificate and entitlement teams differ")
    require(package and package.is_file(), "Signed installer .pkg missing")
    installer = run("/usr/sbin/pkgutil", "--check-signature", str(package)).decode(errors="replace")
    require("3rd Party Mac Developer Installer:" in installer, "Mac App Store installer identity required")
    team = entitlements["com.apple.developer.team-identifier"]
    require(f"({team})" in installer, "Installer and app signing teams differ")


def verify(app, submission=False, package=None):
    info = read_plist(app / "Contents/Info.plist")
    require(info.get("CFBundleIdentifier") == BUNDLE_ID, "Unexpected bundle identifier")
    for key in ["CFBundleShortVersionString", "CFBundleVersion", "LSMinimumSystemVersion"]:
        require(bool(info.get(key)), f"Missing bundle property: {key}")
    resources = app / "Contents/Resources"
    for name in ["AppIcon.icns", "PrivacyInfo.xcprivacy", "Privacy-Policy.txt", "Quick-Start.txt"]:
        require((resources / name).is_file(), f"Missing bundle resource: {name}")
    require(not list(app.rglob("*.sh")), "Store app must not include shell cleanup scripts")
    run("/usr/bin/codesign", "--verify", "--deep", "--strict", "--all-architectures", str(app))
    entitlements = plistlib.loads(run("/usr/bin/codesign", "-d", "--entitlements", ":-", str(app)))
    check_entitlements(entitlements)
    check_privacy(read_plist(resources / "PrivacyInfo.xcprivacy"))
    executable = app / "Contents/MacOS" / info["CFBundleExecutable"]
    architectures = run("/usr/bin/lipo", "-archs", str(executable)).decode().split()
    require(set(architectures) == {"arm64", "x86_64"}, "Expected both supported architectures")
    symbols = run("/usr/bin/nm", "-u", str(executable)).decode(errors="replace")
    require(not re.search(r"\b_(posix_spawn|system|popen)\b", symbols), "Unexpected subprocess API in Store app")
    if submission:
        check_submission(app, entitlements, info["CFBundleIdentifier"], package)


def prepare_entitlements(profile_path, output):
    profile = plistlib.loads(run("/usr/bin/security", "cms", "-D", "-i", str(profile_path)))
    entitlements = dict(REQUIRED_ENTITLEMENTS)
    permitted = profile.get("Entitlements", {})
    for key in ["com.apple.application-identifier", "com.apple.developer.team-identifier"]:
        entitlements[key] = permitted.get(key)
    check_profile(profile, entitlements, BUNDLE_ID, datetime.now(timezone.utc))
    with output.open("wb") as file:
        plistlib.dump(entitlements, file)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path, nargs="?")
    parser.add_argument("--submission", action="store_true")
    parser.add_argument("--package", type=Path)
    parser.add_argument("--prepare-entitlements", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if args.prepare_entitlements and not args.output:
        parser.error("--prepare-entitlements requires --output")
    if not args.prepare_entitlements and not args.app:
        parser.error("a built .app is required")
    try:
        if args.prepare_entitlements:
            prepare_entitlements(args.prepare_entitlements, args.output)
            print("PASS: prepared team-specific entitlements from the provisioning profile.")
        else:
            verify(args.app, args.submission, args.package)
            print("PASS: local Store package checks. Apple upload validation and runtime testing remain separate.")
    except (VerificationError, OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
