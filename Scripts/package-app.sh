#!/bin/zsh

set -euo pipefail

readonly root_directory="$(cd "$(dirname "$0")/.." && pwd)"
readonly app_name="StorageFix"
readonly distribution="${DISTRIBUTION:-direct}"
[[ "$distribution" == "direct" || "$distribution" == "app-store" ]] || { print -u2 "Unsupported distribution"; exit 1; }
readonly build_suffix="$([[ "$distribution" == "app-store" ]] && print store-universal || print universal)"
readonly build_root="$root_directory/.build-$build_suffix"
readonly dist_directory="$root_directory/dist$([[ "$distribution" == "app-store" ]] && print /AppStore || true)"
readonly app_directory="$dist_directory/$app_name.app"
readonly contents_directory="$app_directory/Contents"
readonly staging_directory="$dist_directory/dmg"
readonly sign_identity="${SIGN_IDENTITY:--}"
readonly notary_profile="${NOTARY_PROFILE:-}"

if [[ "$distribution" == "app-store" && ( "$sign_identity" != "-" || -n "${APP_STORE_INSTALLER_IDENTITY:-}" ) ]]; then
  [[ "$sign_identity" != "-" && -f "${APP_STORE_PROFILE:-}" ]] || {
    print -u2 "Store submission packaging requires SIGN_IDENTITY and APP_STORE_PROFILE."
    exit 1
  }
fi

cd "$root_directory"
typeset -a build_flags
build_flags=(-c release --arch arm64 --arch x86_64 --scratch-path "$build_root")
[[ "$distribution" == "app-store" ]] && build_flags+=(-Xswiftc -DAPP_STORE)
CLANG_MODULE_CACHE_PATH=/tmp/storagefix-clang-module-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/tmp/storagefix-swiftpm-module-cache \
/usr/bin/swift build "${build_flags[@]}"
readonly build_directory="$(/usr/bin/swift build "${build_flags[@]}" --show-bin-path)"
[[ -x "$build_directory/$app_name" ]] || { print -u2 "Built executable not found: $build_directory/$app_name"; exit 1; }

/bin/rm -rf "$app_directory" "$staging_directory" "$dist_directory/$app_name.dmg"
/bin/mkdir -p "$contents_directory/MacOS" "$contents_directory/Resources" "$staging_directory"
/bin/cp "$build_directory/$app_name" "$contents_directory/MacOS/$app_name"
if [[ "$distribution" == "direct" ]]; then
  /bin/cp "Scripts/storage-fix.sh" "$contents_directory/Resources/storage-fix.sh"
  /bin/chmod +x "$contents_directory/Resources/storage-fix.sh"
fi
/bin/cp "Packaging/AppIcon.icns" "$contents_directory/Resources/AppIcon.icns"
/bin/cp "Packaging/Info.plist" "$contents_directory/Info.plist"
readonly guide="$root_directory/Packaging/$([[ "$distribution" == "app-store" ]] && print Store-Quick-Start.txt || print Quick-Start.txt)"
/bin/cp "$guide" "$contents_directory/Resources/Quick-Start.txt"
/bin/cp "Packaging/Privacy-Policy.txt" "$contents_directory/Resources/Privacy-Policy.txt"
/bin/cp "Packaging/PrivacyInfo.xcprivacy" "$contents_directory/Resources/PrivacyInfo.xcprivacy"
if [[ "$distribution" == "app-store" && -n "${APP_STORE_PROFILE:-}" ]]; then
  /bin/cp "$APP_STORE_PROFILE" "$contents_directory/embedded.provisionprofile"
fi
/bin/chmod +x "$contents_directory/MacOS/$app_name"
typeset signing_entitlements="$root_directory/Packaging/StorageFix-AppStore.entitlements"
if [[ "$distribution" == "app-store" && "$sign_identity" != "-" ]]; then
  signing_entitlements="$(/usr/bin/mktemp /tmp/storagefix-store-entitlements.XXXXXX)"
  trap '/bin/rm -f "$signing_entitlements"' EXIT
  /usr/bin/python3 "$root_directory/Scripts/verify-store.py" --prepare-entitlements "$APP_STORE_PROFILE" --output "$signing_entitlements"
fi
typeset -a signing_flags
signing_flags=(--force --options runtime --sign "$sign_identity")
[[ "$distribution" == "app-store" ]] && signing_flags+=(--entitlements "$signing_entitlements")

if [[ "$sign_identity" == "-" ]]; then
  /usr/bin/codesign "${signing_flags[@]}" "$app_directory"
else
  /usr/bin/codesign "${signing_flags[@]}" --timestamp "$app_directory"
fi

/usr/bin/codesign --verify --deep --strict --all-architectures "$app_directory"
if [[ "$distribution" == "app-store" ]]; then
  /usr/bin/python3 "$root_directory/Scripts/verify-store.py" "$app_directory"
fi
/bin/cp -R "$app_directory" "$staging_directory/"
/bin/ln -s /Applications "$staging_directory/Applications"
/bin/cp "$guide" "$staging_directory/Read Me.txt"
# Disposable nested samples exercise duplicates, file filters and map navigation.
/bin/mkdir -p "$staging_directory/Testing Samples/Exports" "$staging_directory/Testing Samples/Projects"
/bin/dd if=/dev/zero of="$staging_directory/Testing Samples/Exports/Example Original.dat" bs=1048576 count=12 2>/dev/null
/bin/cp "$staging_directory/Testing Samples/Exports/Example Original.dat" "$staging_directory/Testing Samples/Exports/Example Copy.dat"
/bin/cp "$staging_directory/Testing Samples/Exports/Example Original.dat" "$staging_directory/Testing Samples/Projects/Unique File.dat"
printf 'Unique' | /bin/dd of="$staging_directory/Testing Samples/Projects/Unique File.dat" conv=notrunc 2>/dev/null
/usr/bin/hdiutil create -volname "$app_name" -srcfolder "$staging_directory" -ov -format UDZO "$dist_directory/$app_name.dmg"
/bin/rm -rf "$staging_directory"

if [[ "$sign_identity" != "-" ]]; then
  /usr/bin/codesign --force --timestamp --sign "$sign_identity" "$dist_directory/$app_name.dmg"
fi

if [[ "$distribution" == "direct" && -n "$notary_profile" ]]; then
  [[ "$sign_identity" != "-" ]] || {
    print -u2 "NOTARY_PROFILE requires a Developer ID SIGN_IDENTITY."
    exit 1
  }
  /usr/bin/xcrun notarytool submit "$dist_directory/$app_name.dmg" \
    --keychain-profile "$notary_profile" \
    --wait
  /usr/bin/xcrun stapler staple "$dist_directory/$app_name.dmg"
  /usr/bin/xcrun stapler validate "$dist_directory/$app_name.dmg"
fi

printf 'Created %s\n' "$dist_directory/$app_name.dmg"

if [[ "$distribution" == "app-store" && -n "${APP_STORE_INSTALLER_IDENTITY:-}" ]]; then
  [[ "$sign_identity" != "-" ]] || { print -u2 "App Store package requires distribution signing."; exit 1; }
  /usr/bin/productbuild --sign "$APP_STORE_INSTALLER_IDENTITY" --component "$app_directory" /Applications "$dist_directory/StorageFix.pkg"
  /usr/bin/python3 "$root_directory/Scripts/verify-store.py" "$app_directory" --submission --package "$dist_directory/StorageFix.pkg"
fi
