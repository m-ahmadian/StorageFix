#!/bin/zsh

set -u

readonly EXIT_USAGE=64
readonly EXIT_BLOCKED=75
readonly FORMAT_HUMAN="human"
readonly FORMAT_JSON="json"

format="$FORMAT_HUMAN"
mode="scan"
requested_categories=()

usage() {
  cat <<'EOF'
Usage:
  storage-fix.sh --scan [--format human|json]
  storage-fix.sh --clean <category-id> [<category-id> ...] [--format human|json]

Categories:
  xcode-derived-data   Safe default. Rebuildable Xcode build output.
  swiftpm-cache        Safe default. Re-downloadable SwiftPM caches.
  npm-cache            Safe default. Re-downloadable npm and npx caches.
  xcodebuildmcp-cache  Safe default. XcodeBuildMCP build output and logs.
  google-cache         Safe default. Rebuildable Google application caches.
  claude-cache         Safe default. Rebuildable Claude desktop caches.
  xcode-doc-cache      Safe default. Re-downloadable Xcode documentation cache.
  app-logs             Safe default. Application diagnostic logs.
  adobe-cache          Safe default. Rebuildable Adobe caches.
  node-gyp-cache       Safe default. Re-downloadable node-gyp headers.
  codex-runtime-cache  Optional. Re-downloadable Codex runtime cache.
  user-cache-files     Optional. User application caches; quit apps first.
  simulator-contents   Optional. Erases simulator apps and settings.
  ios-device-support   Optional. Xcode may download these files again.
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --scan)
      mode="scan"
      shift
      ;;
    --clean)
      mode="clean"
      shift
      while (( $# > 0 )) && [[ "$1" != --* ]]; do
        requested_categories+=("$1")
        shift
      done
      ;;
    --format)
      (( $# >= 2 )) || { usage >&2; exit "$EXIT_USAGE"; }
      format="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      print -u2 "Unknown argument: $1"
      usage >&2
      exit "$EXIT_USAGE"
      ;;
  esac
done

[[ "$format" == "$FORMAT_HUMAN" || "$format" == "$FORMAT_JSON" ]] || {
  print -u2 "Unsupported format: $format"
  exit "$EXIT_USAGE"
}

if [[ "$mode" == "clean" && ${#requested_categories[@]} -eq 0 ]]; then
  print -u2 "At least one cleanup category is required."
  exit "$EXIT_USAGE"
fi

category_ids=(
  "xcode-derived-data"
  "swiftpm-cache"
  "npm-cache"
  "xcodebuildmcp-cache"
  "google-cache"
  "claude-cache"
  "xcode-doc-cache"
  "app-logs"
  "adobe-cache"
  "node-gyp-cache"
  "codex-runtime-cache"
  "user-cache-files"
  "simulator-contents"
  "ios-device-support"
)
category_names=(
  "Xcode Derived Data"
  "Swift Package Manager Cache"
  "npm and npx Cache"
  "XcodeBuildMCP Build Cache"
  "Google Application Cache"
  "Claude Desktop Cache"
  "Xcode Documentation Cache"
  "Application Logs"
  "Adobe Cache"
  "node-gyp Cache"
  "Codex Runtime Cache"
  "Other Application Caches"
  "Simulator Contents"
  "iOS Device Support"
)
category_paths=(
  "$HOME/Library/Developer/Xcode/DerivedData"
  "$HOME/Library/Caches/org.swift.swiftpm"
  "$HOME/.npm"
  "$HOME/Library/Developer/XcodeBuildMCP/workspaces"
  "$HOME/Library/Caches/Google"
  "$HOME/Library/Application Support/Claude"
  "$HOME/Library/Developer/Xcode/DocumentationCache"
  "$HOME/Library/Logs"
  "$HOME/Library/Caches/Adobe"
  "$HOME/Library/Caches/node-gyp"
  "$HOME/.cache/codex-runtimes"
  "$HOME/Library/Caches"
  "$HOME/Library/Developer/CoreSimulator/Devices"
  "$HOME/Library/Developer/Xcode/iOS DeviceSupport"
)
category_targets=(
  "$HOME/Library/Developer/Xcode/DerivedData"
  "$HOME/Library/Caches/org.swift.swiftpm"
  "$HOME/.npm"
  "$HOME/Library/Developer/XcodeBuildMCP/workspaces"
  "$HOME/Library/Caches/Google"
  "$HOME/Library/Application Support/Claude/Cache|$HOME/Library/Application Support/Claude/Code Cache|$HOME/Library/Application Support/Claude/GPUCache|$HOME/Library/Application Support/Claude/DawnGraphiteCache|$HOME/Library/Application Support/Claude/DawnWebGPUCache"
  "$HOME/Library/Developer/Xcode/DocumentationCache"
  "$HOME/Library/Logs"
  "$HOME/Library/Caches/Adobe"
  "$HOME/Library/Caches/node-gyp"
  "$HOME/.cache/codex-runtimes"
  "$HOME/Library/Caches"
  "$HOME/Library/Developer/CoreSimulator/Devices"
  "$HOME/Library/Developer/Xcode/iOS DeviceSupport"
)
category_safe_defaults=("true" "true" "true" "true" "true" "true" "true" "true" "true" "true" "false" "false" "false" "false")
category_warnings=(
  ""
  ""
  "npm packages and npx tools will be downloaded again when needed."
  "Close XcodeBuildMCP first. Workspace state is preserved."
  "Close Google applications first. Cached web content will be recreated."
  "Close Claude first. Cached desktop content will be recreated."
  "Xcode documentation will be downloaded again when needed."
  "Diagnostic logs will be permanently removed."
  "Close Adobe applications first. Cached content will be recreated."
  "Node headers will be downloaded again when native packages build."
  "Close Codex first. Runtime dependencies will be downloaded again when needed."
  "Optional: quit applications first. This removes their cached files and they may need to rebuild or sign in again."
  "Installed simulator apps, app data, and simulator settings will be erased."
  "Debug support files for connected devices will be downloaded again when needed."
)

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  printf '%s' "$value"
}

bytes_for_path() {
  local path="$1"
  if [[ -e "$path" && ! -L "$path" ]]; then
    /usr/bin/du -sk "$path" 2>/dev/null | /usr/bin/awk '{print $1 * 1024}'
  else
    printf '0'
  fi
}

bytes_for_category() {
  local id="$1"
  local targets_spec="$2"
  local total=0 path size
  local -a targets

  if [[ "$id" == "user-cache-files" ]]; then
    while IFS= read -r path; do
      size="$(bytes_for_path "$path")"
      total=$(( total + size ))
    done < <(/usr/bin/find "$targets_spec" -mindepth 1 -maxdepth 1 \
      ! -name org.swift.swiftpm ! -name Google ! -name Adobe ! -name node-gyp -print 2>/dev/null)
  elif [[ "$id" == "xcodebuildmcp-cache" ]]; then
    while IFS= read -r path; do
      size="$(bytes_for_path "$path")"
      total=$(( total + size ))
    done < <(/usr/bin/find "$targets_spec" -mindepth 2 -maxdepth 2 -type d \
      \( -name DerivedData -o -name result-bundles -o -name logs \) -print 2>/dev/null)
  else
    targets=("${(@s:|:)targets_spec}")
    for path in "${targets[@]}"; do
      size="$(bytes_for_path "$path")"
      total=$(( total + size ))
    done
  fi
  printf '%s' "$total"
}

free_bytes() {
  /bin/df -k "$HOME" | /usr/bin/awk 'NR == 2 {print $4 * 1024}'
}

is_requested() {
  local expected="$1"
  local requested
  for requested in "${requested_categories[@]}"; do
    [[ "$requested" == "$expected" ]] && return 0
  done
  return 1
}

validate_requested_categories() {
  local requested known id
  for requested in "${requested_categories[@]}"; do
    known="false"
    for id in "${category_ids[@]}"; do
      [[ "$requested" == "$id" ]] && known="true"
    done
    [[ "$known" == "true" ]] || {
      print -u2 "Unknown cleanup category: $requested"
      exit "$EXIT_USAGE"
    }
  done
}

block_reason_for_category() {
  local id="$1"
  case "$id" in
    xcode-derived-data|xcode-doc-cache|ios-device-support)
      /usr/bin/pgrep -x Xcode >/dev/null 2>&1 && {
        printf 'Xcode is running'
        return
      }
      /usr/bin/pgrep -f '/usr/bin/xcodebuild|/usr/bin/swiftc|/usr/bin/clang' >/dev/null 2>&1 && {
        printf 'an Xcode build process is running'
        return
      }
      ;;
    swiftpm-cache)
      /usr/bin/pgrep -f '/usr/bin/swift-build|/usr/bin/swift package|/usr/bin/swift test' >/dev/null 2>&1 && {
        printf 'a Swift Package Manager process is running'
        return
      }
      ;;
    npm-cache|node-gyp-cache)
      /usr/bin/pgrep -f '(^|/)npm( |$)|(^|/)npx( |$)|node-gyp' >/dev/null 2>&1 && {
        printf 'a Node package process is running'
        return
      }
      ;;
    xcodebuildmcp-cache)
      /usr/bin/pgrep -fi 'XcodeBuildMCP' >/dev/null 2>&1 && {
        printf 'XcodeBuildMCP is running'
        return
      }
      /usr/bin/pgrep -f '/usr/bin/xcodebuild|/usr/bin/swiftc|/usr/bin/clang' >/dev/null 2>&1 && {
        printf 'an Xcode build process is running'
        return
      }
      ;;
    google-cache)
      /usr/bin/pgrep -fi 'Google Chrome|Google Drive|GoogleUpdater' >/dev/null 2>&1 && {
        printf 'a Google application is running'
        return
      }
      ;;
    claude-cache)
      /usr/bin/pgrep -fi 'Claude.app|Claude Helper' >/dev/null 2>&1 && {
        printf 'Claude is running'
        return
      }
      ;;
    adobe-cache)
      /usr/bin/pgrep -fi 'Adobe|Creative Cloud|Illustrator|Photoshop' >/dev/null 2>&1 && {
        printf 'an Adobe application is running'
        return
      }
      ;;
    codex-runtime-cache)
      /usr/bin/pgrep -fi 'Codex.app|com.openai.codex' >/dev/null 2>&1 && {
        printf 'Codex is running'
        return
      }
      ;;
    simulator-contents)
      /usr/bin/pgrep -f 'Simulator.app|CoreSimulatorService' >/dev/null 2>&1 && {
        printf 'Simulator services are running'
        return
      }
      ;;
  esac
}

clean_path() {
  local path="$1"
  [[ -e "$path" ]] || return 0
  [[ -d "$path" && ! -L "$path" ]] || return 1
  # Reject redirected ancestor folders as well as a symlink at the target.
  [[ "${path:A}" == "${path:a}" ]] || return 1
  /usr/bin/find "$path" -mindepth 1 -maxdepth 1 -exec /bin/rm -rf -- {} +
}

clean_category() {
  local id="$1"
  local targets_spec="$2"
  local path
  local -a targets

  if [[ "$id" == "user-cache-files" ]]; then
    [[ -d "$targets_spec" ]] || return 0
    [[ "${targets_spec:A}" == "${targets_spec:a}" ]] || return 1
    /usr/bin/find "$targets_spec" -mindepth 1 -maxdepth 1 \
      ! -name org.swift.swiftpm ! -name Google ! -name Adobe ! -name node-gyp \
      -exec /bin/rm -rf -- {} +
  elif [[ "$id" == "xcodebuildmcp-cache" ]]; then
    while IFS= read -r path; do
      clean_path "$path" || return 1
    done < <(/usr/bin/find "$targets_spec" -mindepth 2 -maxdepth 2 -type d \
      \( -name DerivedData -o -name result-bundles -o -name logs \) -print 2>/dev/null)
  else
    targets=("${(@s:|:)targets_spec}")
    for path in "${targets[@]}"; do
      clean_path "$path" || return 1
    done
  fi
}

validate_requested_categories

before_free="$(free_bytes)"
result_before_sizes=()
result_after_sizes=()
result_reclaimed_sizes=()
result_statuses=()
result_messages=()
had_failure="false"
had_blocked="false"

for index in {1..${#category_ids[@]}}; do
  id="${category_ids[$index]}"
  name="${category_names[$index]}"
  path="${category_paths[$index]}"
  targets="${category_targets[$index]}"
  safe_default="${category_safe_defaults[$index]}"
  warning="${category_warnings[$index]}"
  before_size="$(bytes_for_category "$id" "$targets")"
  after_size="$before_size"
  item_status="scanned"
  message=""

  if [[ "$mode" == "clean" ]] && is_requested "$id"; then
    block_reason="$(block_reason_for_category "$id")"
    if [[ -n "$block_reason" ]]; then
      item_status="blocked"
      message="Skipped because $block_reason."
      had_blocked="true"
    elif clean_category "$id" "$targets"; then
      after_size="$(bytes_for_category "$id" "$targets")"
      item_status="cleaned"
      message="Cleanup completed."
    else
      after_size="$(bytes_for_category "$id" "$targets")"
      item_status="failed"
      message="Path was unsafe or could not be removed."
      had_failure="true"
    fi
  fi

  reclaimed=$(( before_size - after_size ))
  (( reclaimed < 0 )) && reclaimed=0
  result_before_sizes+=("$before_size")
  result_after_sizes+=("$after_size")
  result_reclaimed_sizes+=("$reclaimed")
  result_statuses+=("$item_status")
  result_messages+=("$message")
done

after_free="$(free_bytes)"
free_delta=$(( after_free - before_free ))
(( free_delta < 0 )) && free_delta=0
[[ "$mode" == "scan" ]] && free_delta=0

if [[ "$format" == "$FORMAT_JSON" ]]; then
  printf '{"mode":"%s","freeBytesBefore":%s,"freeBytesAfter":%s,"freeBytesReclaimed":%s,"categories":[' \
    "$mode" "$before_free" "$after_free" "$free_delta"
  separator=""
  for index in {1..${#category_ids[@]}}; do
    id="${category_ids[$index]}"
    name="${category_names[$index]}"
    path="${category_paths[$index]}"
    safe_default="${category_safe_defaults[$index]}"
    warning="${category_warnings[$index]}"
    before_size="${result_before_sizes[$index]}"
    after_size="${result_after_sizes[$index]}"
    reclaimed="${result_reclaimed_sizes[$index]}"
    item_status="${result_statuses[$index]}"
    message="${result_messages[$index]}"
    printf '%s{"id":"%s","name":"%s","path":"%s","safeDefault":%s,"warning":"%s","bytesBefore":%s,"bytesAfter":%s,"bytesReclaimed":%s,"status":"%s","message":"%s"}' \
      "$separator" "$(json_escape "$id")" "$(json_escape "$name")" "$(json_escape "$path")" "$safe_default" \
      "$(json_escape "$warning")" "$before_size" "$after_size" "$reclaimed" "$(json_escape "$item_status")" "$(json_escape "$message")"
    separator=","
  done
  printf ']}\n'
else
  printf 'StorageFix %s\n' "$mode"
  printf 'Free space before: %s bytes\n' "$before_free"
  for index in {1..${#category_ids[@]}}; do
    name="${category_names[$index]}"
    before_size="${result_before_sizes[$index]}"
    item_status="${result_statuses[$index]}"
    message="${result_messages[$index]}"
    printf '%-28s %12s bytes  %s\n' "$name" "$before_size" "$item_status"
    [[ -n "$message" ]] && printf '  %s\n' "$message"
  done
  printf 'Free space after:  %s bytes\n' "$after_free"
  printf 'Free space gained: %s bytes\n' "$free_delta"
fi

[[ "$had_failure" == "true" ]] && exit 1
[[ "$had_blocked" == "true" ]] && exit "$EXIT_BLOCKED"
exit 0
