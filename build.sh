#!/usr/bin/env bash
set -e

echo "=== Setting up environment variables ==="
git config --global user.name 'build'
git config --global user.email 'build@local'
export BUILD_USERNAME=android-build
export BUILD_HOSTNAME=crave
export USE_CCACHE=0

echo "=== Writing local manifest for Galaxy A51 ==="
rm -rf .repo/local_manifests
mkdir -p .repo/local_manifests

cat << 'EOF' > .repo/local_manifests/a51.xml
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <remote name="Development" fetch="https://github.com/Exynos9611Development/" revision="lineage-23.2" />
  <remote name="los" fetch="https://github.com/LineageOS/" revision="lineage-23.2" />

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
EOF

echo "=== Initializing Repo & Syncing Source ==="
repo init -u https://github.com/Evolution-X/manifest.git -b bka --git-lfs --no-repo-verify
/opt/crave/resync.sh

echo "=== Preparing Device Tree & Patching Makefiles ==="
BASE_MK=$(find device/samsung/a51 -maxdepth 1 -name '*a51*.mk' | head -n 1)
if [ -n "$BASE_MK" ] && [ ! -f device/samsung/a51/evo_a51.mk ]; then
    cp "$BASE_MK" device/samsung/a51/evo_a51.mk
    sed -i 's/vendor\/lineage/vendor\/evolution/g' device/samsung/a51/evo_a51.mk
    sed -i 's/lineage_/evo_/g' device/samsung/a51/evo_a51.mk
fi
[ -f device/samsung/a51/AndroidProducts.mk ] && sed -i 's/lineage_a51/evo_a51/g' device/samsung/a51/AndroidProducts.mk || true

echo "=== Injecting IMS & VoLTE Properties ==="
cat << 'EOF' >> device/samsung/a51/evo_a51.mk

# IMS & VoLTE Settings
PRODUCT_PACKAGES += ImsService TeleService
PRODUCT_PROPERTY_OVERRIDES += \
    persist.vendor.radio.ims_available=1 \
    persist.vendor.radio.ims.disabled=0 \
    persist.dbg.ims_volte_enable=1 \
    persist.dbg.volte_avail_ovr=1 \
    persist.dbg.vt_avail_ovr=1
EOF

echo "=== Integrating KernelSU Next ==="
mkdir -p device/samsung/a51/prebuilts/app/KernelSU
KSUN_URL=$(curl -s https://api.github.com/repos/KernelSU-Next/KernelSU-Next/releases/latest | grep browser_download_url | grep -i 'release.apk' | head -n 1 | cut -d '"' -f 4)
[ -z "$KSUN_URL" ] && KSUN_URL="https://github.com/KernelSU-Next/KernelSU-Next/releases/download/v3.4.1/KernelSU_Next_v3.4.1_33333-release.apk"
curl -sL -o device/samsung/a51/prebuilts/app/KernelSU/KernelSU.apk "$KSUN_URL"

cat << 'EOF' > device/samsung/a51/prebuilts/app/KernelSU/Android.mk
LOCAL_PATH := $(call my-dir)
include $(CLEAR_VARS)
LOCAL_MODULE := KernelSU
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_CLASS := APPS
LOCAL_CERTIFICATE := PLATFORM
LOCAL_SRC_FILES := KernelSU.apk
LOCAL_MODULE_SUFFIX := $(COMMON_ANDROID_PACKAGE_SUFFIX)
include $(BUILD_PREBUILT)
EOF

echo 'PRODUCT_PACKAGES += KernelSU' >> device/samsung/a51/evo_a51.mk

echo "=== Starting Build Process ==="
source build/envsetup.sh
lunch evo_a51-bp4a-userdebug
mka evo 2>&1 | tee build.log
