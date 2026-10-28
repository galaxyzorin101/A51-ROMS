#!/bin/bash
# ==============================================================================
# Part 2: Package Odin Tar Files & Upload Artifacts to GitHub Releases
# Repo: galaxyzorin101/A51-ROMS
# Branch: Evolution-X-12-cnb-unofficial
# ==============================================================================

set -e

WORK_DIR="/mnt/volume/evo"
OUT_DIR="$WORK_DIR/out/target/product/a51"
REPO_NAME="galaxyzorin101/A51-ROMS"
TARGET_BRANCH="Evolution-X-12-cnb-unofficial"

echo "=== [1/4] Locating Compiled Files & Packaging Odin Tars ==="
cd "$OUT_DIR"

ROM_ZIP=$(find . -maxdepth 1 -name "*.zip" ! -name "*ota*.zip" 2>/dev/null | head -n 1)

if [ -z "$ROM_ZIP" ]; then
    echo "ERROR: No flashable ROM zip found in $OUT_DIR!"
    exit 1
fi

echo "Found ROM Zip: $ROM_ZIP"

# Package recovery.img for Odin (AP slot)
if [ -f "recovery.img" ]; then
    echo "Packaging recovery.img into evo_recovery_a51.tar..."
    tar -cf evo_recovery_a51.tar recovery.img
fi

# Package boot.img (with KernelSU Next) for Odin (AP slot)
if [ -f "boot.img" ]; then
    echo "Packaging boot.img into evo_boot_ksu_a51.tar..."
    tar -cf evo_boot_ksu_a51.tar boot.img
fi

# Generate SHA256 checksum for the ROM zip
echo "Generating SHA256 checksum..."
sha256sum "$ROM_ZIP" > checksum.txt

echo "=== [2/4] Authenticating GitHub CLI ==="
if ! gh auth status &>/dev/null; then
    echo "Please authenticate with GitHub. Run: gh auth login"
    gh auth login
fi

echo "=== [3/4] Preparing Release Assets ==="
RELEASE_TAG="evo-12-a51-$(date +%Y%m%d)"
ASSETS=("$ROM_ZIP" "checksum.txt")

if [ -f "evo_recovery_a51.tar" ]; then
    ASSETS+=("evo_recovery_a51.tar")
fi

if [ -f "evo_boot_ksu_a51.tar" ]; then
    ASSETS+=("evo_boot_ksu_a51.tar")
fi

echo "=== [4/4] Publishing Release to $REPO_NAME ==="
gh release create "$RELEASE_TAG" "${ASSETS[@]}" \
    --repo "$REPO_NAME" \
    --target "$TARGET_BRANCH" \
    --title "Evolution X 12 (Android 17) Unofficial for Galaxy A51" \
    --notes "Unofficial Evolution X 12 build compiled for Samsung Galaxy A51 4G (SM-A515F). Maintainer: GalaxyZorin101. 
    
Included Assets:
- Flashable ROM Zip
- Odin-ready Recovery Tar (`evo_recovery_a51.tar`)
- Odin-ready Boot Tar with KernelSU Next (`evo_boot_ksu_a51.tar`)
- SHA256 Checksum"

echo "===================================================="
echo " ALL FILES SUCCESSFULLY UPLOADED TO GITHUB!"
echo "===================================================="
