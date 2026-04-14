---
name: ios-web-inspect
description: >-
  iOS Safari DOM inspector. Captures element rects, computed styles,
  and layout data as structured JSON for precise UI fixes.
  Supports manual paste, osascript, and safaridriver automation.
triggers:
  - "inspect iOS"
  - "iOS Safari inspect"
  - "check layout"
  - "DOM inspect"
  - "web inspect"
  - "モバイルレイアウト確認"
  - "iOS確認"
  - "レイアウト確認"
  - "UIインスペクト"
---

# iOS Web Inspect

Safari Web Inspector を通じて iOS 上の Web アプリの DOM 情報（位置、サイズ、スタイル、レイアウト問題）を構造化 JSON として取得し、精密な UI 修正に活用するスキル。

## When to Activate

- User mentions checking layout on iOS Safari or mobile
- User struggles to describe a UI issue precisely
- Screenshots are insufficient for understanding layout problems
- User says "inspect", "check layout", "confirm styles", "モバイル確認"

## Skill Directory

```
$SKILL_DIR = directory containing this SKILL.md
```

All scripts are at `$SKILL_DIR/scripts/`.

## Layer Detection (MANDATORY first step)

Run these checks IN PARALLEL to determine the best available layer:

```bash
# Check Layer 2 (osascript + Safari)
osascript -e 'tell application "Safari" to name of front document' 2>&1

# Check Layer 3 (iOS Simulator)
xcrun simctl list devices booted 2>&1
```

| Layer 2 result | Layer 3 result | Use |
|---|---|---|
| Returns page title | Booted device found | Layer 3 (fullest automation) |
| Returns page title | No booted device | Layer 2 |
| Error / Safari not running | Booted device found | Layer 3 |
| Error | No booted device | Layer 1 (manual) |

## Layer 1: Manual Console Paste (Zero Dependencies)

Use when neither Safari nor Simulator is available, or for maximum reliability.

### Workflow

1. **Read** `$SKILL_DIR/scripts/inspect.js`
2. **Construct** a console snippet customized for the user's target:

```javascript
// Paste this in Safari Web Inspector Console (Develop > Device/Simulator > Page)
(function() {
  <contents of inspect.js>
  var result = iosWebInspect({ selector: '<USER_SELECTOR>' });
  copy(JSON.stringify(result, null, 2));
  console.log('✓ Inspection result copied to clipboard (' + result.elements.length + ' elements, ' + result.issues.length + ' issues)');
})();
```

3. **Tell the user**:
   > Safari の Web Inspector を開いてください（Develop メニュー > デバイス/Simulator > ページ名）。
   > Console タブに以下のスクリプトを貼り付けて実行し、クリップボードの内容をここに貼り付けてください。

4. **Parse** the returned JSON and proceed to Analysis.

### Tip for user
- If `copy()` is not available, use: `console.log(JSON.stringify(result))` and copy from console output
- For iOS device: Enable Web Inspector in Settings > Safari > Advanced > Web Inspector

## Layer 2: osascript Automation (macOS Safari)

Use when Safari is open with the target page on macOS (or Simulator page bridged via Develop menu).

### Workflow

```bash
# Basic usage
bash "$SKILL_DIR/scripts/safari-bridge.sh" --selector '<USER_SELECTOR>' > /tmp/ios-inspect-$(date +%s).json

# Inspect all visible elements
bash "$SKILL_DIR/scripts/safari-bridge.sh" > /tmp/ios-inspect-$(date +%s).json

# Target specific tab
bash "$SKILL_DIR/scripts/safari-bridge.sh" --selector 'nav' --tab 2 > /tmp/ios-inspect-$(date +%s).json
```

Then read the output JSON file and proceed to Analysis.

### Limitations
- Only works with macOS Safari (not Chrome/Firefox)
- Page must be fully loaded
- CSP-restricted pages may block execution (use Layer 1 in that case)

## Layer 3: safaridriver WebDriver (iOS Simulator)

Use when an iOS Simulator is booted. Provides full automation.

### Prerequisites (one-time)
```bash
# Enable safaridriver (requires macOS password)
safaridriver --enable

# Verify simulator is booted
xcrun simctl list devices booted
```

See `$SKILL_DIR/references/setup-guide.md` for detailed setup.

### Workflow

```bash
# Inspect on iOS Simulator (current page)
node "$SKILL_DIR/scripts/webdriver-exec.js" --platform ios --selector '<USER_SELECTOR>'

# Navigate to URL first, then inspect
node "$SKILL_DIR/scripts/webdriver-exec.js" --platform ios --url 'http://localhost:3000' --selector 'header'

# macOS Safari (for testing/debugging)
node "$SKILL_DIR/scripts/webdriver-exec.js" --platform mac --selector '.app-container'

# Custom output path
node "$SKILL_DIR/scripts/webdriver-exec.js" --platform ios --selector 'main' --output /tmp/my-inspect.json
```

Results are written to `/tmp/ios-inspect-<timestamp>.json` and stdout.
Read the output file and proceed to Analysis.

## Analysis Protocol

After obtaining the JSON result (from any layer):

### 1. Meta Review
- Report viewport size, device pixel ratio, active media queries
- Flag if viewport suggests unexpected device/orientation

### 2. Element Analysis
For the user's target area:
- Report exact positions (x, y) and dimensions (width x height) in px
- Report key styles: display mode, position, flexbox/grid properties
- Report spacing: margin and padding values
- Identify parent-child layout relationships

### 3. Issue Triage
Review the `issues` array. Prioritize:
1. **page-overflow / overflow-x** — Horizontal scroll is a critical mobile UX issue
2. **viewport-overflow** — Elements extending beyond screen edge
3. **touch-target** — Interactive elements below 44x44px iOS minimum
4. **text-overflow** — Clipped text without ellipsis handling

### 4. Actionable Fix
For each issue or user concern:
- Reference the exact element selector from the JSON
- Provide the specific CSS property change with current → target values
- Example: "`.header` の `padding: 12px 8px` を `padding: 12px 16px` に変更（左右マージンが狭すぎてタッチ対象に影響）"

## Selector Guidance

When the user describes a component vaguely, construct the selector:

| User says | Try selector |
|---|---|
| "ヘッダー" / "header" | `header, [role="banner"], .header, .navbar, nav` |
| "フッター" / "footer" | `footer, [role="contentinfo"], .footer` |
| "ボタン" / "button" | `button, [role="button"], .btn, input[type="submit"]` |
| "カード" / "card" | `.card, [class*="card"], article` |
| "フォーム" / "form" | `form, .form, [role="form"]` |
| "モーダル" / "modal" | `dialog, [role="dialog"], .modal, [class*="modal"]` |
| "サイドバー" | `aside, [role="complementary"], .sidebar, .drawer` |
| "全体" / "everything" | `null` (inspect all visible elements) |

## Output Schema

See `$SKILL_DIR/references/setup-guide.md` for the complete JSON schema reference.

### Key fields per element:
- `selector` — Full CSS selector path (usable in code)
- `rect` — `{ x, y, width, height }` in viewport pixels
- `styles` — Computed CSS properties (only non-default values)
- `parentSelector` — Parent element's selector for hierarchy
- `depth` — DOM depth from inspection root
- `textContent` — First 100 chars of direct text content

## Error Handling

| Error | Cause | Resolution |
|---|---|---|
| Safari not running | Layer 2 requires Safari | Start Safari, open target page |
| No booted simulator | Layer 3 requires simulator | `xcrun simctl boot <device>` |
| safaridriver not enabled | First-time setup needed | `safaridriver --enable` |
| Empty result | Page not loaded or selector invalid | Wait for page load, verify selector |
| CSP blocked | Page security policy | Use Layer 1 (Web Inspector bypasses CSP) |
