#!/bin/bash
# safari-bridge.sh — Layer 2: Execute inspect.js in Safari via osascript
#
# Usage:
#   bash safari-bridge.sh [--selector '<CSS selector>'] [--tab <index>]
#
# Output: JSON to stdout. Pipe to file:
#   bash safari-bridge.sh --selector 'header' > /tmp/ios-inspect.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSPECT_JS="$SCRIPT_DIR/inspect.js"

SELECTOR=""
TAB_INDEX=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --selector)
      if [[ $# -lt 2 ]]; then
        echo "Error: --selector requires a value" >&2
        exit 1
      fi
      SELECTOR="$2"
      shift 2
      ;;
    --tab)
      if [[ $# -lt 2 ]]; then
        echo "Error: --tab requires a value" >&2
        exit 1
      fi
      TAB_INDEX="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: safari-bridge.sh [--selector '<CSS selector>'] [--tab <index>]"
      echo ""
      echo "Options:"
      echo "  --selector  CSS selector to inspect (default: all visible elements)"
      echo "  --tab       Safari tab index, 1-based (default: front tab)"
      echo ""
      echo "Output: JSON to stdout"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Validate --tab is a positive integer
if [[ -n "$TAB_INDEX" ]]; then
  if ! [[ "$TAB_INDEX" =~ ^[0-9]+$ ]] || [[ "$TAB_INDEX" == "0" ]]; then
    echo "Error: --tab must be a positive integer" >&2
    exit 1
  fi
fi

# Verify inspect.js exists
if [[ ! -f "$INSPECT_JS" ]]; then
  echo "Error: inspect.js not found at $INSPECT_JS" >&2
  exit 1
fi

# Check Safari is running
if ! osascript -e 'tell application "System Events" to (name of processes) contains "Safari"' 2>/dev/null | grep -q true; then
  echo "Error: Safari is not running. Open Safari and navigate to the target page first." >&2
  exit 1
fi

# Check Safari has at least one tab
TAB_COUNT=$(osascript -e 'tell application "Safari" to count of tabs of front window' 2>/dev/null || echo "0")
if [[ "$TAB_COUNT" == "0" ]]; then
  echo "Error: Safari has no open tabs." >&2
  exit 1
fi

# Build the JavaScript to execute.
# Strategy: write inspect.js + invocation to a temp file, read it via osascript
# to avoid shell expansion and AppleScript string escaping issues entirely.
TMPJS=$(mktemp /tmp/ios-inspect-exec.XXXXXX.js)
trap 'rm -f "$TMPJS"' EXIT

# Write inspect.js content verbatim
cat "$INSPECT_JS" > "$TMPJS"

# Append the invocation. Use JSON.stringify-style escaping for the selector
# by letting node handle it (if available) or a safe printf fallback.
if [[ -z "$SELECTOR" ]]; then
  printf '\nJSON.stringify(iosWebInspect({ selector: null }));' >> "$TMPJS"
else
  # Escape selector for safe embedding in JS string literal:
  # Replace \ with \\, then ' with \'
  ESCAPED_SELECTOR=$(printf '%s' "$SELECTOR" | sed "s/\\\\/\\\\\\\\/g" | sed "s/'/\\\\'/g")
  printf "\nJSON.stringify(iosWebInspect({ selector: '%s' }));" "$ESCAPED_SELECTOR" >> "$TMPJS"
fi

# Read the JS file content and pass to Safari via osascript.
# Use osascript's ability to read from a heredoc with the JS as a variable,
# avoiding direct string interpolation of JS content in AppleScript.

# Determine tab target
if [[ -n "$TAB_INDEX" ]]; then
  TAB_TARGET="tab $TAB_INDEX of front window"
else
  TAB_TARGET="current tab of front window"
fi

# Execute: read JS from temp file, pass to Safari via osascript
# We use 'read' in AppleScript to get the file contents safely
RESULT=$(osascript <<APPLESCRIPT
set jsFile to POSIX file "$TMPJS"
set jsCode to read jsFile as «class utf8»
tell application "Safari"
  set jsResult to do JavaScript jsCode in $TAB_TARGET
  return jsResult
end tell
APPLESCRIPT
)

if [[ -z "$RESULT" ]]; then
  echo "Error: JavaScript execution returned empty result. Check if the page is loaded." >&2
  exit 1
fi

# Output JSON
echo "$RESULT"
