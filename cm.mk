# CM 12.1 product for Benesse TAB-A03-BS (Marvell PXA1928 / Vivante GC5000).
# Wi-Fi-only tablet (SDIO 8887); no telephony despite the stock radio partition.

# 32-bit PRIMARY / 64-bit secondary (ro.zygote=zygote32_64), matching stock
# 01.16.000 exactly. This is a 64-bit board (TARGET_ARCH=arm64 in BoardConfig) but
# the runtime is run 32-bit-primary on purpose:
#   * system_server (forked from the 32-bit primary zygote=app_process32) is 32-bit,
#     so it can load the stock Marvell BT HAL -- bluetooth.default.so AND
#     libbt-vendor.so ship 32-bit ONLY. A 64-bit system_server (zygote64_32) cannot
#     dlopen them, which is exactly why the Bluetooth toggle grayed out.
#   * 2 GB RAM (mem=2032M): a 64-bit userspace thrashed lowmemorykiller and crashed
#     everything but the setup wizard. 32-bit apps halve pointer/heap pressure.
# This is a hand-rolled equivalent of AOSP core_64_bit.mk but selecting the
# 32/64 startup script. It MUST be inherited BEFORE full_base, because ro.zygote is
# a default-property override where the FIRST inheritor wins (core_minimal, pulled
# by full_base, sets ro.zygote=zygote32).
PRODUCT_COPY_FILES += system/core/rootdir/init.zygote32_64.rc:root/init.zygote32_64.rc
PRODUCT_DEFAULT_PROPERTY_OVERRIDES += ro.zygote=zygote32_64
TARGET_SUPPORTS_32_BIT_APPS := true
TARGET_SUPPORTS_64_BIT_APPS := true

# Default USB gadget = MTP + ADB (bring-up convenience). Must be set HERE, before
# full_base, for the same first-wins reason as ro.zygote: a base mk sets
# persist.sys.usb.config=none, so setting it in device.mk (inherited last) loses and
# the device comes up charge-only with no adb. init.usb.rc propagates
# persist.sys.usb.config -> sys.usb.config, which the pxa1928 android_usb rc turns
# into a gadget + adbd.
PRODUCT_DEFAULT_PROPERTY_OVERRIDES += persist.sys.usb.config=mtp,adb

# Inherit the AOSP full base. CM's vendor/cm/config/common*.mk chain does NOT pull
# an AOSP base, so without this init.rc / init.environ.rc / sepolicy / *_contexts
# are never added to PRODUCT_PACKAGES and the boot ramdisk comes out missing them
# -> init "Could not open sepolicy" -> reboot to recovery. (The omni TWRP product
# inherits full_base.mk for the same reason.)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base.mk)

# Inherit CM common (wifi-only tablet) config.
$(call inherit-product, vendor/cm/config/common_full_tablet_wifionly.mk)

# Inherit device configuration.
$(call inherit-product, device/benesse/TAB_A03_BS/device.mk)

PRODUCT_DEVICE := TAB_A03_BS
PRODUCT_NAME := cm_TAB_A03_BS
PRODUCT_BRAND := benesse
PRODUCT_MODEL := TAB-A03-BS
PRODUCT_MANUFACTURER := benesse

# Fingerprint / build-prop identity mirrors the stock 01.16.000 fingerprint so
# apps and Vivante blobs that key off ro.product.* behave as they did on stock.
PRODUCT_BUILD_PROP_OVERRIDES += \
    PRODUCT_NAME=TAB_A03_BS \
    TARGET_DEVICE=TAB_A03_BS

# CM release identifier (cm_TAB_A03_BS in lunch).
PRODUCT_GMS_CLIENTID_BASE := android-benesse
