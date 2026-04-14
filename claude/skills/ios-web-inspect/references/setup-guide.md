# iOS Web Inspect — Setup Guide

## Layer 1: Manual (Zero Setup)

No setup required. Just need:
1. A Mac with Safari installed
2. iOS device or Simulator with Web Inspector enabled

### Enable Web Inspector on iOS Device
1. Settings > Safari > Advanced > Web Inspector → ON
2. Connect device to Mac via USB/Lightning
3. On Mac Safari: Develop menu > [Device Name] > [Page]

### Enable Web Inspector on iOS Simulator
1. Launch Simulator (Xcode > Open Developer Tool > Simulator)
2. Open Safari in Simulator, navigate to target URL
3. On Mac Safari: Develop menu > Simulator > [Page]

### Enable Develop Menu in macOS Safari
1. Safari > Settings > Advanced > "Show features for web developers" → ON

## Layer 2: osascript (Minimal Setup)

### Requirements
- macOS Safari with Develop menu enabled (see above)
- Target page open in Safari (macOS or bridged from device/simulator)

### Verification
```bash
# Check Safari is running and has a page
osascript -e 'tell application "Safari" to name of front document'
# Should return the page title

# Test JavaScript execution
osascript -e 'tell application "Safari" to do JavaScript "document.title" in current tab of front window'
```

## Layer 3: safaridriver (Full Automation)

### One-Time Setup

```bash
# 1. Enable safaridriver (requires macOS admin password via GUI dialog)
safaridriver --enable

# 2. Verify it works
safaridriver --version
```

### iOS Simulator Setup

```bash
# List available simulators
xcrun simctl list devices available

# Boot a simulator (example: iPhone 15 Pro)
xcrun simctl boot "iPhone 15 Pro"

# Open a URL in Simulator Safari
xcrun simctl openurl booted 'http://localhost:3000'

# Take a screenshot (useful alongside inspection)
xcrun simctl io booted screenshot /tmp/sim-screenshot.png
```

### Verification

```bash
# Quick test: inspect example.com on macOS Safari
node scripts/webdriver-exec.js --platform mac --url 'https://example.com' --selector 'body'
cat /tmp/ios-inspect-*.json | head -20

# iOS Simulator test (simulator must be booted with Safari open)
node scripts/webdriver-exec.js --platform ios --url 'http://localhost:3000'
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `safaridriver --enable` fails | Run in Terminal.app (not VS Code terminal). Enter macOS password when prompted. |
| "Could not create a session" on iOS | Verify simulator is booted: `xcrun simctl list devices booted` |
| "Could not create a session" on mac | Close any existing Safari WebDriver sessions. Restart Safari. |
| osascript returns empty | Page may still be loading. Wait and retry. |
| "Execution returned empty result" | Selector matched no elements. Try broader selector or `null`. |
| Permission denied on safari-bridge.sh | `chmod +x scripts/safari-bridge.sh` |

## Future: Real Device via ios-webkit-debug-proxy

For inspecting real iOS devices without macOS Safari bridging:

```bash
# Install
brew install ios-webkit-debug-proxy

# Start proxy (device must be connected via USB)
ios_webkit_debug_proxy -f chrome-devtools://devtools/bundled/inspector.html

# Default endpoints:
#   http://localhost:9221  — device list
#   http://localhost:9222+ — per-tab debug endpoints
```

This exposes Chrome DevTools Protocol, enabling programmatic inspection
via WebSocket. Not yet implemented in this skill but planned for v2.

## JSON Output Schema Reference

```typescript
interface InspectResult {
  meta: {
    url: string;
    title: string;
    timestamp: string;           // ISO 8601
    viewport: { width: number; height: number };
    scrollPosition: { x: number; y: number };
    documentSize: { width: number; height: number };
    devicePixelRatio: number;
    mediaQueries: Record<string, boolean>;
  };
  elements: Array<{
    tag: string;
    id: string | null;
    classes: string[];
    role: string | null;
    selector: string;            // Full CSS selector path
    rect: { x: number; y: number; width: number; height: number };
    styles: Record<string, string>;  // Only non-default values
    parentSelector: string | null;
    depth: number;
    textContent: string;         // First 100 chars
    childCount: number;
    // Optional fields (tag-dependent):
    href?: string;               // <a> elements
    src?: string;                // <img> elements
    alt?: string;                // <img> elements
    type?: string;               // <input> elements
    name?: string;               // <input> elements
  }>;
  issues: Array<{
    type: 'overflow-x' | 'overflow-y' | 'viewport-overflow'
        | 'touch-target' | 'text-overflow' | 'page-overflow';
    element: string;             // CSS selector
    detail: string;              // Human-readable description
  }>;
}
```
