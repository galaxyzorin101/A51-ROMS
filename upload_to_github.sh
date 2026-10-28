#!/bin/bash
# ==============================================================================
# Part 2: Upload Compiled Artifacts to GitHub Repository / Releases
# Repo: galaxyzorin101/A51-ROMS
# Branch: Evolution-X-12-cnb-unofficial
# ==============================================================================

set -e

WORK_DIR="/mnt/volume/evo"
OUT_DIR="$WORK_DIR/out/target/product/a51"
REPO_NAME="galaxyzorin101/A51-ROMS"
TARGET_BRANCH="Evolution-X-12-cnb-unofficial"

echo "=== [1/3] Locating Compiled Zip & Images ==="
cd "$OUT_DIR"

ROM_ZIP=$(find . -maxdepth 1 -name "*.zip" ! -name "*ota*.zip" 2>/dev/null | head -n 1)

if [ -z "$ROM_ZIP" ]; then
    echo "ERROR: No flashable ROM zip found in $OUT_DIR!"
    exit 1
fi

echo "Found output ROM: $ROM_ZIP"

# Generate SHA256 Checksum
echo "Generating SHA256 checksum..."
sha256sum "$ROM_ZIP" > checksum.txt

echo "=== [2/3] Authenticating GitHub CLI ==="
# Ensure GitHub CLI is installed and logged in
if ! gh auth status &>/dev/null; then
    echo "Please authenticate with GitHub. Run: gh auth login"
    gh auth login
fi

echo "=== [3/3] Uploading Release Artifacts to $REPO_NAME ==="
RELEASE_TAG="evo-12-a51-$(date +%Y%m%d)"

gh release create "$RELEASE_TAG" "$ROM_ZIP" checksum.txt \
    --repo "$REPO_NAME" \
    --target "$TARGET_BRANCH" \
    --title "Evolution X 12 (Android 17) Unofficial for Galaxy A51" \
    --notes "Unofficial Evolution X 12 build compiled for Samsung Galaxy A51 4G (SM-A515F). Maintainer: GalaxyZorin101. Features: Working VoLTE/IMS, KernelSU Next pre-integrated, SkiaGL smooth UI optimizations."

echo "===================================================="
echo " UPLOAD COMPLETE!"
echo " Check your GitHub Releases tab on $REPO_NAME"
echo "===================================================="
