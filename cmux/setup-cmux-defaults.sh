#!/usr/bin/env bash
set -euo pipefail

# ==========================================================
# cmux macOS defaults
# Configures cmux UI preferences via macOS defaults system.
# Usage: bash cmux/setup-cmux-defaults.sh
# ==========================================================

BUNDLE_ID="com.cmuxterm.app"

echo "Setting cmux macOS defaults..."

# Appearance: follow system light/dark mode
defaults write "$BUNDLE_ID" appearanceMode -string "system"

# App icon style
defaults write "$BUNDLE_ID" appIconMode -string "dark"

# Browser theme follows system
defaults write "$BUNDLE_ID" browserThemeMode -string "system"

# Sidebar: native style
defaults write "$BUNDLE_ID" sidebarPreset -string "nativeSidebar"
defaults write "$BUNDLE_ID" sidebarBlendMode -string "withinWindow"
defaults write "$BUNDLE_ID" sidebarState -string "followWindow"
defaults write "$BUNDLE_ID" sidebarMaterial -string "sidebar"

echo "Done. Restart cmux for changes to take effect."
