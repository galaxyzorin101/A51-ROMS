# PitchBlack Recovery Project for Samsung Galaxy A51 4G (`a51`)

![PBRP Banner](https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRK1HzP0IfLdIdE9dXnCJnEaHTx-CivLT2zgr6pEpkmQw&s=10)

## Device Specifications

| Feature | Specification |
| :--- | :--- |
| **Device** | Samsung Galaxy A51 4G |
| **Model** | SM-A515F / DS |
| **Chipset** | Samsung Exynos 9611 |
| **Architecture** | ARM64 |
| **Maintainer** | GalaxyZorin101 |
| **Status** | Unofficial |

---

## Device Tree Customizations & Features

* **Display & Key Config:**
  * Hardware key checking disabled (`PB_DISABLE_KEY_CHECK := true`).
  * On-screen navigation configuration (`TW_HAS_NO_PHYSICAL_BUTTONS := true`).
  * Accelerometer blacklisted to avoid unwanted screen rotations.
* **Embedded Binaries:**
  * Static ARM64 `adb` and `fastboot` binaries included directly in `/system/bin`.
* **Built-in Utils (PBRP Tools Menu):**
  * **Multidisabler v3.5** (Corsicanu) — Disables Samsung encryption, Knox, and Vaultkeeper.
  * **KernelSU v3.3.0** — Flashable kernel-level root solution.
  * **Magisk v27.0** — Flashable zip package for Magisk root.

---

## How to Build

1. **Initialize PBRP Manifest:**
   ```bash
   repo init -u [https://github.com/PitchBlackRecoveryProject/manifest_pb](https://github.com/PitchBlackRecoveryProject/manifest_pb) -b android-11.0
   repo sync -c --no-clone-bundle --no-tags --optimized-fetch --prune -j$(nproc)
