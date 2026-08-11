LOCAL_PATH := device/benesse/TAB_A03_BS

# Board config
TARGET_BOARD_PLATFORM := mrvl
TARGET_BOOTLOADER_BOARD_NAME := PXA1928
TARGET_NO_BOOTLOADER := true

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := generic
TARGET_CPU_SMP := true

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv7-a-neon
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := generic

# NOTE: 32-bit-first app ABI ordering is done via a ro.product.cpu.abilist override
# in device.mk (PRODUCT_PROPERTY_OVERRIDES), NOT via TARGET_PREFER_32_BIT_APPS.
# The build flag reconfigures the global multilib defaults, which invalidates the
# cached 32-bit libavcodec objects and trips a broken arch-gating bug in ffmpeg's
# Android.mk (aarch64 .S fed to the 32-bit assembler). The property override reaches
# the same runtime result (Build.SUPPORTED_ABIS[0] = armeabi-v7a) with zero rebuild
# beyond build.prop. See device.mk.

# Recovery
TARGET_USERIMAGES_USE_EXT4 := true
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 10485248
BOARD_FLASH_BLOCK_SIZE := 0
BOARD_SUPPRESS_SECURE_ERASE := true
BOARD_HAS_NO_MISC_PARTITION := true
BOARD_RECOVERY_SWIPE := true
BOARD_USES_MMCUTILS := true
BOARD_SUPPRESS_EMMC_WIPE := true
TW_THEME := landscape_hdpi

# --- Display fixes (proven on the sister TAB-A03-BR; same vx5b1d panel). ---
# vx5b1d panel needs an explicit FBIOPAN_DISPLAY to push each rendered frame
# (single-buffer path has no commit -> black even with backlight on).
TW_FBIOPAN := true
# FBIOBLANK POWERDOWN kills the vx5b1d panel and UNBLANK can't revive it, so make
# fbdev_blank() a no-op instead of the ioctl.
TW_NO_SCREEN_BLANK := true
# The panel/touch can't be woken once the blank timer sleeps it, so never sleep.
TW_NO_SCREEN_TIMEOUT := true
TW_BRIGHTNESS_PATH := "/sys/devices/platform/panel_vx5b1d.19/backlight/lcd-bl/brightness"
TW_MAX_BRIGHTNESS := 255

# --- Orientation / touch (BS-specific; differs from BR!) ---
# BS panel/FB is 800x1280 PORTRAIT (fb0 mode 800x1280, ro.boot.hwrotation=90),
# unlike BR which is landscape-native. Rotate the landscape_hdpi GUI 90deg so it
# displays correctly; gr_fb_width() then reports the logical 1280x800.
TW_ROTATION := 90
# Touch is an "elan-touchscreen" (event1, multitouch type-B, ABS_MT_POSITION_*),
# NOT BR's rohm_bu21025. Native axes: X 0..~1536 (short/portrait-horizontal),
# Y 0..~2560 (long/portrait-vertical). events.cpp maps touch to the rotated
# logical dims but does NOT consult gr_rotation, so swap X/Y to match landscape.
RECOVERY_TOUCHSCREEN_SWAP_XY := true
RECOVERY_TOUCHSCREEN_FLIP_Y := true
# No TW_TOUCH_* override: let events.cpp use the elan driver's declared ABS range.
TW_INPUT_BLACKLIST := "isl29023\x0alsm9ds1_mag"

# Trim optional extras so the image fits the ~10MB recovery partition.
#
# NOTE (2026-07-26): these are no longer necessary IF the ramdisk is xz/lzma
# compressed -- see the kernel note below. Measured on the shipped ramdisk:
#   gzip 4,990,181 -> image 10,383,360 of p7's 10,485,760 =  100 KB free
#   xz   3,219,256 -> image  8,611,840 of p7's 10,485,760 = 1.79 MB free
# That is ~1.77MB recovered, well over the ~1.4MB these exclusions save. They
# can be flipped back off once an xz/lzma ramdisk build is confirmed to boot.
TW_EXCLUDE_TWRPAPP := true
TW_EXCLUDE_BASH := true
TW_EXCLUDE_NANO := true
TW_EXCLUDE_TZDATA := true

# Kernel
#
# The shipped TWRP-TAB_A03_BS.img does NOT contain $(LOCAL_PATH)/kernel -- it
# contains stock_kernel.bin (verified by md5: the image's kernel blob ==
# stock_kernel.bin). $(LOCAL_PATH)/kernel is Mirenk's own 2020-05-07 build
# ("ma03 linux with lzma"); it is the correct board (ma03) but was never the
# one that shipped.
#
# kernel_twrp.bin (2026-07-26) is built from source -- see
# android_kernel_sanyo_pxa1928, defconfig ma03_twrp_defconfig. Versus stock it
# adds F2FS, NTFS, NLS cp932, and -- the important one -- CONFIG_RD_XZ +
# CONFIG_RD_LZMA, so the initramfs decompressor is no longer gzip-only. Stock
# has CONFIG_RD_GZIP as the ONLY decompressor, which is exactly why an lzma or
# xz ramdisk previously died with "compression method X not configured". Camera
# /V4L2 is dropped to pay for it, so the blob is the same size as stock.
#
# BLOB LAYOUT -- get this wrong and the device hangs with the boot logo still on
# screen (mrvlboot reads zeros where the FDT should be). The DTB position is
# COMPUTED, not fixed; stock_kernel.bin and Mirenk's kernel have different
# totals and different DTB offsets, which is how the rule was pinned down:
#     [0]                        uImage header(64B) + gzip payload
#     align_up(64+payload, 2048) DTB, inside a fixed 128 KiB region
#     +131072                    optional 128B signature (Mirenk leaves it all
#                                zero and still boots -> not verified)
# The first build of kernel_twrp.bin instead copied stock's ABSOLUTE DTB offset
# and total length; that put the DTB one 2048B page too late and it froze at the
# logo. See tools in the session scratchpad (packkernel.py).
#
# UNVERIFIED ON HARDWARE. Keep a UART recovery path ready before trying it.
TARGET_PREBUILT_KERNEL := $(LOCAL_PATH)/stock_kernel.bin

# ===========================================================================
# CM 12.1 full-Android build (added 2026-07-26). Only engaged for the cm_
# product; the omni/TWRP product above keeps using the prebuilt kernel.
# ===========================================================================
ifneq ($(filter cm_TAB_A03_BS,$(TARGET_PRODUCT)),)

# Kernel: use the prebuilt stock_kernel.bin (a uImage+appended-DTB blob, proven to
# boot) as the boot-image kernel for the first ROM build. CM's mkbootimg wraps it
# + the CM ramdisk exactly like the stock boot.img (whose kernel field == this
# blob). Inline from-source kernel build is deferred: the kernel tree's Marvell
# in-tree Android.mk (Android.mk.marvell-intree-DISABLED) assumes kernel/ at root
# and fights CM's kernel.mk; we build the kernel out-of-band and pack it with
# packkernel.py when we want a custom one. See cm12.1-groundwork.md.
#   (TARGET_PREBUILT_KERNEL stays = $(LOCAL_PATH)/stock_kernel.bin from above.)

# Partition geometry, verified on the BS unit (SN 0M6P034608) 2026-07-26.
# (system size == system_PRISTINE_01.16.000.img == 1941504 KB.)
BOARD_BOOTIMAGE_PARTITION_SIZE     := 16777216
BOARD_SYSTEMIMAGE_PARTITION_SIZE   := 1988100096
BOARD_USERDATAIMAGE_PARTITION_SIZE := 12348030976
BOARD_CACHEIMAGE_PARTITION_SIZE    := 1132462080
BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE  := ext4

# 64-bit userspace with 32-bit app support (arm64 + armeabi-v7a already set above).
TARGET_USES_64_BIT_BINDER := true

# Hardware-accelerated UI. CM 12.1 does not default this on, so libhwui is not
# built and libandroid_runtime fails to link (undefined android::uirenderer::
# renderthread::RenderProxy / AnimationContext / Blur). Every real device needs
# it -- the Vivante GC5000 GPU drives the UI here.
USE_OPENGL_RENDERER := true

# Recovery fstab. The device's recovery.fstab is TWRP v1 format; CM's releasetools
# (LoadRecoveryFSTab) needs fs_mgr v2, so point CM at the v2 file. Without this,
# target-files packaging dies: "malformed recovery.fstab line: /boot emmc ...".
TARGET_RECOVERY_FSTAB := $(LOCAL_PATH)/recovery.aosp.fstab

# ART image base addresses. Normally set by build/core/dex_preopt_libart.mk, but
# that include is skipped when dexpreopt is disabled, leaving art/build/
# Android.common_build.mk to error "LIBART_IMG_HOST_BASE_ADDRESS unset". Pin the
# standard AOSP 5.1 values so the build parses regardless of dexpreopt state.
LIBART_IMG_HOST_BASE_ADDRESS   := 0x60000000
LIBART_IMG_TARGET_BASE_ADDRESS := 0x70000000

# WiFi / Bluetooth (Marvell sd8887, SDIO). The kernel modules (mlan8887/sd8887/
# mbt8887) are loaded at boot by the wifi_load service in init.pxa1928.rc, which
# powers the chip on and passes cal_data_cfg (firmware init fails without it) and
# cfg80211_wext=0xc for nl80211. The framework therefore does NOT load/unload the
# driver (WIFI_DRIVER_MODULE_PATH intentionally unset), it just uses wlan0.
BOARD_WLAN_DEVICE := mrvl
WPA_SUPPLICANT_VERSION := VER_0_8_X
BOARD_WPA_SUPPLICANT_DRIVER := NL80211
BOARD_HOSTAPD_DRIVER := NL80211
# nl80211's ops struct references wpa_driver_nl80211_driver_cmd, which lives in the
# vendor "driver_cmd" private lib -- without one, wpa_supplicant AND hostapd fail to
# link ("undefined reference to wpa_driver_nl80211_driver_cmd"). Marvell ships no
# such lib in this tree; lib_driver_cmd_bcmdhd is the generic nl80211 implementation
# reused across non-Broadcom devices. Its extra private commands (SIOCDEVPRIVATE
# ioctls) just return errors on mwifiex -- non-fatal; core scan/connect use standard
# nl80211.
BOARD_WPA_SUPPLICANT_PRIVATE_LIB := lib_driver_cmd_mrvl
BOARD_HOSTAPD_PRIVATE_LIB := lib_driver_cmd_mrvl
WIFI_DRIVER_FW_PATH_STA := "/system/etc/firmware/mrvl/sd8887_uapsta_a2.bin"
WIFI_DRIVER_FW_PATH_AP  := "/system/etc/firmware/mrvl/sd8887_uapsta_a2.bin"
BOARD_HAVE_BLUETOOTH := true
BOARD_HAVE_BLUETOOTH_MARVELL := true

endif

# MUST stay empty. A non-empty value REPLACES mrvlboot's default cmdline
# (console=ttyS0,115200 mem=2032M cma=51M ioncarv=144M initrd=0x3000000,10m
# ... recovery=1) -> no console, no mem -> silent hang. The working image has
# cmdline="". androidboot.selinux=permissive was useless here anyway: stock
# init is a *user* build and ignores it (getenforce stays Enforcing even with
# ro.boot.selinux=disabled).
BOARD_KERNEL_CMDLINE :=
BOARD_KERNEL_BASE := 0x10000000
BOARD_KERNEL_PAGESIZE := 2048
BOARD_MKBOOTIMG_ARGS := --ramdisk_offset 0x01000000 --tags_offset 0x00000100
