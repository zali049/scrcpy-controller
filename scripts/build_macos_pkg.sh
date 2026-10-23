#!/usr/bin/env bash
# =============================================================================
# ScrcpyController macOS PKG Builder
# Usage: ./scripts/build_macos_pkg.sh [version]
# Example: ./scripts/build_macos_pkg.sh 1.0.1
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VERSION="${1:-1.0.0}"
APP_NAME="ScrcpyController"
BUNDLE_ID="com.scrcpycontroller.app"

BIN_SRC="$PROJECT_DIR/assets/bin/macos"
BUILD_DIR="$PROJECT_DIR/build/macos/Build/Products/Release"
APP_SRC="$BUILD_DIR/scrcpy_gui_controller.app"
DIST_DIR="$PROJECT_DIR/dist"
PKG_STAGE="$DIST_DIR/pkg_stage"
PKG_OUT="$DIST_DIR/${APP_NAME}-${VERSION}.pkg"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ScrcpyController macOS PKG Builder v$VERSION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "▶ [1/4] Building Flutter macOS release..."
cd "$PROJECT_DIR"
flutter build macos --release

echo ""
echo "▶ [2/4] Embedding scrcpy binaries into .app bundle..."
BIN_DEST="$APP_SRC/Contents/Resources/bin"
mkdir -p "$BIN_DEST"

cp "$BIN_SRC/scrcpy"         "$BIN_DEST/scrcpy"
cp "$BIN_SRC/adb"            "$BIN_DEST/adb"
cp "$BIN_SRC/scrcpy-server"  "$BIN_DEST/scrcpy-server"

chmod +x "$BIN_DEST/scrcpy"
chmod +x "$BIN_DEST/adb"
chmod 644 "$BIN_DEST/scrcpy-server"

xattr -rd com.apple.quarantine "$APP_SRC" 2>/dev/null || true
ls -lh "$BIN_DEST"

echo ""
echo "▶ [3/4] Staging PKG structure..."
rm -rf "$PKG_STAGE"
mkdir -p "$PKG_STAGE/Applications"
cp -R "$APP_SRC" "$PKG_STAGE/Applications/$APP_NAME.app"

echo ""
echo "▶ [4/4] Building PKG installer..."
rm -f "$PKG_OUT"
pkgbuild \
  --root "$PKG_STAGE" \
  --identifier "$BUNDLE_ID" \
  --version "$VERSION" \
  --install-location "/" \
  --ownership recommended \
  "$PKG_OUT"

rm -rf "$PKG_STAGE"

SIZE=$(ls -lh "$PKG_OUT" | awk '{print $5}')
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PKG ready: $PKG_OUT ($SIZE)"
echo "  Install: sudo installer -pkg \"$PKG_OUT\" -target /"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
