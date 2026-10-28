#!/bin/bash
# ==============================================================================
# Part 1: Environment Setup, Source Sync & ROM Compilation
# ==============================================================================

set -e 

echo "=== [1/8] Installing Dependencies & Google Repo Tool ==="
sudo apt update -y
sudo apt upgrade -y
sudo apt install -y \
    bc bison build-essential ccwrap curl flex g++-multilib gcc-multilib git \
    git-lfs gnupg gperf imagemagick lib32ncurses-dev lib32readline-dev \
    lib32z1-dev libelf-dev libgl1-mesa-dev libxml2-utils lz4 ncftp \
    ncurses-dev libncurses5 openjdk-17-jdk python-is-python3 python3 \
    python3-pip rsync schedtool squashfs-tools xsltproc zip zlib1g-dev gh

# Install Google repo tool
sudo curl -s https://storage.googleapis.com/git-repo-downloads/repo -o /usr/local/bin/repo
sudo chmod a+rx /usr/local/bin/repo

git config --global user.email "builds@galaxyzorin101.local" || true
git config --global user.name "GalaxyZorin101" || true

echo "=== [2/8] Setting Up Memory Swap & Working Directory ==="
if [ ! -f /swapfile ]; then
    echo "Creating 32GB swap file..."
    sudo fallocate -l 32G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=32768
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
fi

WORK_DIR="/mnt/volume/evo"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

echo "=== [3/8] Initializing Evolution X Source Tree & Manifest ==="
if [ ! -d ".repo" ]; then
    repo init -u https://github.com/Evolution-X/manifest.git -b cnb --git-lfs --no-repo-verify
fi

mkdir -p .repo/local_manifests

cat << 'EOF' > .repo/local_manifests/a51.xml
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
EOF

echo "=== [4/8] Syncing Repositories ==="
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags

echo "=== [5/8] Integrating KernelSU Next ==="
KERNEL_DIR="kernel/samsung/universal9611"
if [ -d "$KERNEL_DIR" ]; then
    if [ ! -d "$KERNEL_DIR/KernelSU-Next" ]; then
        curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next/kernel/setup.sh" | bash -s next
    fi
fi

echo "=== [6/8] Injecting IMS/VoLTE & SkiaGL Optimizations ==="
COMMON_DEVICE_DIR="device/samsung/universal9611-common"
PROP_FILE="$COMMON_DEVICE_DIR/system.prop"

if [ -f "$PROP_FILE" ]; then
    cat << 'EOF' >> "$PROP_FILE"

# VoLTE & IMS Overrides
persist.vendor.ims.play_ringback_tone=1
persist.vendor.radio.add_power_save=1
persist.dbg.volte_avail_ovr=1
persist.dbg.vt_avail_ovr=1
persist.dbg.wfc_avail_ovr=1
persist.radio.rat_on=combine
persist.radio.data_ltd_sys_ind=1
persist.radio.calls.on.ims=1
persist.radio.jbims=1
persist.radio.vrte_logic=1

# Smooth Screen & SkiaGL Rendering
debug.hwui.renderer=skiagl
debug.sf.latch_unsignaled=1
persist.sys.scrollingcache=2
ro.surface_flinger.max_frame_buffer_acquired_buffers=3
debug.cpurend.vsync=false
EOF
fi

echo "=== [7/8] Injecting Device Branding & Maintainer Info ==="
A51_DEVICE_DIR="device/samsung/a51"
if [ -d "$A51_DEVICE_DIR" ]; then
    TARGET_MAKEFILE=$(find "$A51_DEVICE_DIR" -maxdepth 1 -name "*.mk" ! -name "Android.mk" ! -name "BoardConfig*.mk" | head -n 1)
    if [ -n "$TARGET_MAKEFILE" ]; then
        sed -i '/EVO_BUILD_TYPE/d' "$TARGET_MAKEFILE"
        sed -i '/EVO_MAINTAINER/d' "$TARGET_MAKEFILE"
        sed -i '/PRODUCT_MODEL/d' "$TARGET_MAKEFILE"
        sed -i '/PRODUCT_BRAND/d' "$TARGET_MAKEFILE"
        
        cat << 'EOF' >> "$TARGET_MAKEFILE"

# Custom Maintainer & Branding
EVO_BUILD_TYPE := UNOFFICIAL
EVO_MAINTAINER := GalaxyZorin101
PRODUCT_BRAND := Samsung
PRODUCT_MODEL := Samsung Galaxy A51 4G
EOF
    fi
fi

echo "=== [8/8] Starting Compilation ==="
source build/envsetup.sh
LUNCH_TARGET=$(lunch 2>&1 | grep -oE '(evo|lineage)_a51-[a-z]+' | head -n 1 || echo "lineage_a51-userdebug")
lunch "$LUNCH_TARGET"
m evolution -j$(nproc --all)

echo "Compilation step complete! Run ./upload_to_github.sh when ready."
