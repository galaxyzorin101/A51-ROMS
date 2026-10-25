cat << 'EOF' > run_build.sh
#!/usr/bin/env bash
set -eo pipefail

# ==========================================
# CONFIGURATION
# ==========================================
export GITHUB_TOKEN="${GITHUB_TOKEN:-}"

# Branch configuration
export MY_GITHUB_BRANCH="Evolution-X-12-cnb-unofficial"  # Change branch whenever needed
export EVO_BRANCH="cnb"
export MY_GITHUB_REPO="galaxyzorin101/A51-ROMS"

if [ -z "$GITHUB_TOKEN" ]; then
    read -sp "Enter your GitHub Personal Access Token: " GITHUB_TOKEN
    echo ""
fi

# ==========================================
# STEP 1: SYSTEM SETUP & DRIVE MOUNT
# ==========================================
sudo apt-get update -y
sudo apt-get install -y git-core gnupg flex bison build-essential zip curl zlib1g-dev \
    gcc-multilib g++-multilib libc6-dev-i386 lib32ncurses-dev x11proto-core-dev \
    libx11-dev lib32z1-dev libgl1-mesa-dev libxml2-utils xsltproc unzip fontconfig \
    python3 python3-pip rsync jq rclone

sudo mkdir -p /usr/local/bin
sudo curl -s https://storage.googleapis.com/git-repo-downloads/repo > /usr/local/bin/repo
sudo chmod a+rx /usr/local/bin/repo

WORK_PATH=$(df -h | grep -i "HC_Volume" | awk '{print $6}' | head -n 1)
[ -z "$WORK_PATH" ] && WORK_PATH="/mnt/build" && sudo mkdir -p "$WORK_PATH"

if [ ! -f "$WORK_PATH/swapfile_build" ]; then
    sudo fallocate -l 32G "$WORK_PATH/swapfile_build"
    sudo chmod 600 "$WORK_PATH/swapfile_build"
    sudo mkswap "$WORK_PATH/swapfile_build"
    sudo swapon "$WORK_PATH/swapfile_build"
fi

BUILD_WORKDIR="$WORK_PATH/evo"
mkdir -p "$BUILD_WORKDIR"
cd "$BUILD_WORKDIR"

git config --global user.name "build"
git config --global user.email "build@local"
export BUILD_USERNAME=android-build
export BUILD_HOSTNAME=hetzner

# ==========================================
# STEP 2: MANIFEST & REPO SYNC
# ==========================================
repo init -u https://github.com/Evolution-X/manifest.git -b "$EVO_BRANCH" --git-lfs --no-repo-verify

rm -rf .repo/local_manifests
mkdir -p .repo/local_manifests

cat << 'MANIFEST_EOF' > .repo/local_manifests/a51.xml
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <remote name="Development" fetch="https://github.com/Exynos9611Development/" revision="lineage-24" />
  <remote name="los" fetch="https://github.com/LineageOS/" revision="lineage-24" />

  <project path="hardware/samsung" name="android_hardware_samsung" remote="los" clone-depth="1" />
  <project path="hardware/samsung_slsi/libbt" name="android_hardware_samsung_slsi_libbt" remote="los" clone-depth="1" />
  <project path="hardware/samsung_slsi/nfc" name="android_hardware_samsung_slsi_nfc" remote="los" clone-depth="1" />
  <project path="hardware/samsung_slsi/scsc_wifibt/wifi_hal" name="android_hardware_samsung_slsi_scsc_wifibt_wifi_hal" remote="los" clone-depth="1" />
  <project path="hardware/samsung_slsi/scsc_wifibt/wpa_supplicant_lib" name="android_hardware_samsung_slsi_scsc_wifibt_wpa_supplicant_lib" remote="los" clone-depth="1" />
  <project path="hardware/samsung_slsi-linaro/codec2" name="android_hardware_samsung_slsi-linaro_codec2" remote="los" clone-depth="1" />
  <project path="hardware/samsung_slsi-linaro/config" name="android_hardware_samsung_slsi-linaro_config" remote="los" clone-depth="1" />
  <project path="hardware/samsung_slsi-linaro/exynos" name="android_hardware_samsung_slsi-linaro_exynos" remote="los" clone-depth="1" />
  <project path="hardware/samsung_slsi-linaro/exynos5" name="android_hardware_samsung_slsi-linaro_exynos5" remote="los" clone-depth="1" />
  <project path="hardware/samsung_slsi-linaro/graphics" name="android_hardware_samsung_slsi-linaro_graphics" remote="los" clone-depth="1" />
  <project path="hardware/samsung_slsi-linaro/openmax" name="android_hardware_samsung_slsi-linaro_openmax" remote="los" clone-depth="1" />
  <project path="hardware/samsung_slsi-linaro/interfaces" name="android_hardware_samsung_slsi-linaro_interfaces" remote="los" clone-depth="1" />

  <project path="kernel/samsung/universal9611" name="android_kernel_samsung_universal9611" remote="Development" revision="AOSP" clone-depth="1" />

  <project path="device/samsung/universal9611-common" name="android_device_samsung_universal9611-common" remote="Development" />
  <project path="device/samsung_slsi/sepolicy" name="android_device_samsung_slsi_sepolicy" remote="los" />
  <project path="device/samsung/a51" name="android_device_samsung_a51" remote="Development" />

  <project path="vendor/samsung/universal9611-common" name="android_vendor_samsung_universal9611-common" remote="Development" clone-depth="1" />
  <project path="vendor/samsung/a51" name="android_vendor_samsung_a51" remote="Development" clone-depth="1" />
</manifest>
MANIFEST_EOF

repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags

# ==========================================
# STEP 3: DEVICE PATCHES, EXYNOS PROPS & KERNELSU
# ==========================================
BASE_MK=$(find device/samsung/a51 -maxdepth 1 -name '*a51*.mk' | head -n 1)
if [ -n "$BASE_MK" ]; then
    cp "$BASE_MK" device/samsung/a51/evo_a51.mk
    sed -i 's/vendor\/lineage/vendor\/evolution/g' device/samsung/a51/evo_a51.mk
    sed -i 's/lineage_/evo_/g' device/samsung/a51/evo_a51.mk
fi
[ -f device/samsung/a51/AndroidProducts.mk ] && sed -i 's/lineage_a51/evo_a51/g' device/samsung/a51/AndroidProducts.mk || true

cat << 'DEVICE_SPEC_EOF' >> device/samsung/a51/evo_a51.mk

# Device Branding & Model Information
PRODUCT_MODEL := Galaxy A51 4G (SM-A515F/DS)
PRODUCT_BRAND := Samsung
PRODUCT_MANUFACTURER := Samsung
PRODUCT_DEVICE := a51

# IMS / VoLTE & Exynos 9611 Performance Overrides
PRODUCT_PROPERTY_OVERRIDES += \
    ro.product.model=SM-A515F/DS \
    ro.product.brand=Samsung \
    ro.product.name=a51 \
    ro.product.device=a51 \
    ro.build.product=a51 \
    persist.vendor.radio.ims_available=1 \
    persist.vendor.radio.ims.disabled=0 \
    persist.dbg.ims_volte_enable=1 \
    persist.dbg.volte_avail_ovr=1 \
    persist.dbg.vt_avail_ovr=1 \
    debug.sf.latch_unsignaled=1 \
    debug.hwui.renderer=skiagl \
    ro.sys.fw.bg_apps_limit=32 \
    persist.sys.scrollingcache=2

PRODUCT_PACKAGES += ImsService TeleService
DEVICE_SPEC_EOF

# Pull KernelSU Next App
mkdir -p device/samsung/a51/prebuilts/app/KernelSU
KSUN_URL=$(curl -s https://api.github.com/repos/KernelSU-Next/KernelSU-Next/releases/latest | grep browser_download_url | grep -i 'release.apk' | head -n 1 | cut -d '"' -f 4)
[ -z "$KSUN_URL" ] && KSUN_URL="https://github.com/KernelSU-Next/KernelSU-Next/releases/download/v3.4.1/KernelSU_Next_v3.4.1_33333-release.apk"
curl -sL -o device/samsung/a51/prebuilts/app/KernelSU/KernelSU.apk "$KSUN_URL"

cat << 'ANDROID_MK_EOF' > device/samsung/a51/prebuilts/app/KernelSU/Android.mk
LOCAL_PATH := $(call my-dir)
include $(CLEAR_VARS)
LOCAL_MODULE := KernelSU
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_CLASS := APPS
LOCAL_CERTIFICATE := PLATFORM
LOCAL_SRC_FILES := KernelSU.apk
LOCAL_MODULE_SUFFIX := $(COMMON_ANDROID_PACKAGE_SUFFIX)
include $(BUILD_PREBUILT)
ANDROID_MK_EOF

echo 'PRODUCT_PACKAGES += KernelSU' >> device/samsung/a51/evo_a51.mk

# Export copy of local manifest into device tree for GitHub tracking
cp .repo/local_manifests/a51.xml device/samsung/a51/a51_manifest.xml

if [ -n "$GITHUB_TOKEN" ]; then
    cd device/samsung/a51
    git checkout -B "$MY_GITHUB_BRANCH"
    git add .
    git commit -m "Update A51 specs, IMS, Exynos performance props, KernelSU, and tracking manifest [skip ci]" || true
    git push https://x-access-token:${GITHUB_TOKEN}@github.com/${MY_GITHUB_REPO}.git "$MY_GITHUB_BRANCH" --force || true
    cd "$BUILD_WORKDIR"
fi

# ==========================================
# STEP 4: COMPILE ROM
# ==========================================
source build/envsetup.sh
lunch evo_a51-cp2a-userdebug || lunch evo_a51-userdebug
m evolution 2>&1 | tee build.log

# ==========================================
# STEP 5: OFFLOAD BUILD OUTPUT
# ==========================================
ZIP_FILE=$(find out/target/product/a51/ -name "evo_a51*.zip" -type f | head -n 1)

if [ -f "$ZIP_FILE" ]; then
    echo "=========================================="
    echo " Build Success! File: $ZIP_FILE"
    echo "=========================================="
    
    if command -v gdrive &> /dev/null && gdrive account list &> /dev/null; then
        echo "Uploading to Google Drive..."
        gdrive files upload "$ZIP_FILE"
    elif rclone listremotes 2>/dev/null | grep -q "gdrive:"; then
        echo "Uploading to Google Drive via rclone..."
        rclone copy "$ZIP_FILE" gdrive:/ --progress
    else
        echo "Google Drive CLI not logged in. Uploading to Pixeldrain fallback..."
        curl -F "file=@$ZIP_FILE" https://pixeldrain.com/api/file
    fi
else
    echo "=========================================="
    echo " Build Failed! Uploading log for debugging..."
    echo "=========================================="
    curl -F "file=@build.log" https://pixeldrain.com/api/file
fi
EOF

chmod +x run_build.sh
