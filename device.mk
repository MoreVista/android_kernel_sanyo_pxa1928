# Device configuration for Benesse TAB-A03-BS (CM 12.1).
# First cut: pulls in the proprietary blobs and the obvious device traits.
# TODO (bring-up): rootdir (init.mrvl.rc / fstab.pxa1928 / ueventd), audio_policy,
# media_codecs XML wiring, sensors/keylayout, and any missing feature permissions.

# Proprietary Marvell/Vivante blobs (GPU, HALs, codecs, Wi-Fi/BT firmware).
$(call inherit-product-if-exists, vendor/benesse/TAB_A03_BS/TAB_A03_BS-vendor.mk)

# This is a tablet.
PRODUCT_CHARACTERISTICS := tablet

# Updated root CA trust store. Android 5.1's built-in system CA store predates the
# modern web's root CAs (no ISRG Root X1/X2 for Let's Encrypt, no Google Trust
# Services GTS roots, etc.), so the system WebView and any app using the platform
# trust store fail HTTPS cert validation on most modern sites:
#   cr_X509Util: Trust anchor for certification path not found
#   ssl_client_socket_impl: handshake failed; net_error -202 (ERR_CERT_AUTHORITY_INVALID)
# That -- not the GPU -- is why the WebView/Chrome could not open modern HTTPS sites
# (Firefox works because it ships its own current NSS root store). Ship a current CA
# bundle (Android format: <subject_hash_old>.0 = PEM + text) ADDED on top of the
# stock roots. Files generated from the host ca-certificates bundle. This makes the
# system WebView + all platform-trust-store apps validate today's certificates.
PRODUCT_COPY_FILES += $(foreach c,$(wildcard device/benesse/TAB_A03_BS/cacerts/*.0),\
    $(c):system/etc/security/cacerts/$(notdir $(c)))

# Screen density. Stock init.pxa1928.rc setprops ro.sf.lcd_density 160 (mdpi) for
# this 800x1280 panel, so match that for asset selection. (init still sets it at
# runtime; this only drives AAPT resource packaging.)
PRODUCT_AAPT_CONFIG := normal large xlarge mdpi hdpi
PRODUCT_AAPT_PREF_CONFIG := mdpi

# Device-specific rootdir (ramdisk). CM provides the generic init.rc, init binary,
# sepolicy and *_contexts; we only ship the pxa1928 hardware bring-up rc + fstab +
# ueventd. init.rc auto-imports init.${ro.hardware}.rc -> init.pxa1928.rc, which in
# turn imports the sensor/security/power/usb sub-rc and mount_all /fstab.pxa1928.
# (Telephony rc omitted -- this is the Wi-Fi-only SKU.)
PRODUCT_COPY_FILES += \
    device/benesse/TAB_A03_BS/rootdir/fstab.pxa1928:root/fstab.pxa1928 \
    device/benesse/TAB_A03_BS/rootdir/init.pxa1928.rc:root/init.pxa1928.rc \
    device/benesse/TAB_A03_BS/rootdir/init.pxa1928.power.rc:root/init.pxa1928.power.rc \
    device/benesse/TAB_A03_BS/rootdir/init.pxa1928.security.rc:root/init.pxa1928.security.rc \
    device/benesse/TAB_A03_BS/rootdir/init.pxa1928.sensor.rc:root/init.pxa1928.sensor.rc \
    device/benesse/TAB_A03_BS/rootdir/init.pxa1928.usb.rc:root/init.pxa1928.usb.rc \
    device/benesse/TAB_A03_BS/rootdir/ueventd.pxa1928.rc:root/ueventd.pxa1928.rc \
    device/benesse/TAB_A03_BS/rootdir/firefox-swrender.sh:system/etc/firefox-swrender.sh

# Dalvik heap tuning (hdpi tablet; CM 12.1 has no 10in-hdpi-2048 variant).
$(call inherit-product, frameworks/native/build/tablet-7in-hdpi-1024-dalvik-heap.mk)

# Vivante EGL/GLES are shipped as blobs; make sure the platform advertises HW GL.
# disable_gl_preload: the Vivante GPU context does not survive the zygote fork, so
# if zygote opens galcore during preloadOpenGL, forked children (system_server,
# apps) get ENOTTY from libGAL _ConstructOs and crash. Skip the GL preload.
PRODUCT_PROPERTY_OVERRIDES += \
    ro.opengles.version=196608 \
    ro.zygote.disable_gl_preload=true

# Wi-Fi (Marvell sd8xxx / SDIO). Kernel driver is CONFIG_MRVL_WL_* built inline;
# firmware ships via the vendor mk (system/etc/firmware/mrvl).
PRODUCT_PROPERTY_OVERRIDES += \
    wifi.interface=wlan0

# Force 32-bit-first app ABI ordering. This device runs ro.zygote=zygote32_64
# (32-bit primary system_server/apps; 64-bit zygote secondary) because every
# Marvell/Vivante HAL blob is 32-bit only. But the build auto-generates
# ro.product.cpu.abilist with arm64-v8a FIRST, so Build.SUPPORTED_ABIS[0] is arm64
# and ActivityManager launches any app with no native libs (browser, systemui,
# launcher...) as app_process64. A 64-bit process cannot load a 32-bit-only native
# library -- the modern Chromium WebView APK (com.google.android.webview, Chrome 95)
# ships armeabi-v7a only, so WebView-consuming apps crash with
# "libwebviewchromium.so is 32-bit instead of 64-bit". Override the combined abilist
# so 32-bit is preferred; abilist32/abilist64 stay correct for the per-bitness split.
# (Done as a property override, not TARGET_PREFER_32_BIT_APPS, to avoid a global
# multilib reconfigure that trips an ffmpeg arch-gating build bug -- see BoardConfig.)
PRODUCT_PROPERTY_OVERRIDES += \
    ro.product.cpu.abilist=armeabi-v7a,armeabi,arm64-v8a

# Show the on-screen navigation bar. The device only has a hardware HOME key
# (gpio_keys KEY_HOMEPAGE) + volume keys -- no Back or Recents -- so without the
# navbar the device is un-navigable. qemu.hw.mainkeys=0 forces the software navbar
# on (overrides config_showNavigationBar, which defaults false).
PRODUCT_PROPERTY_OVERRIDES += \
    qemu.hw.mainkeys=0

# Device resource overlays (storage_list.xml: emulated primary storage).
DEVICE_PACKAGE_OVERLAYS += device/benesse/TAB_A03_BS/overlay

# Input device configs (touch/keys) from stock -- CM lacks the device-specific
# elan-touchscreen.idc, so touch mapping falls back to defaults and is offset.
PRODUCT_COPY_FILES += \
    device/benesse/TAB_A03_BS/idc/elan-touchscreen.idc:system/usr/idc/elan-touchscreen.idc \
    device/benesse/TAB_A03_BS/idc/88pm80x_on.idc:system/usr/idc/88pm80x_on.idc \
    device/benesse/TAB_A03_BS/idc/gpio_keys_3.idc:system/usr/idc/gpio_keys_3.idc \
    device/benesse/TAB_A03_BS/idc/goodix_gt9xx_ts.idc:system/usr/idc/goodix_gt9xx_ts.idc

# Core hardware feature declarations (tablet). Without this NO core features are
# declared -- notably android.software.app_widgets is missing, so AppWidgetService
# never starts and Trebuchet (launcher) crash-loops on a null IAppWidgetService.
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/tablet_core_hardware.xml:system/etc/permissions/tablet_core_hardware.xml

# USB feature declarations. SystemServer starts UsbService (-> UsbDeviceManager ->
# MtpService) ONLY if FEATURE_USB_HOST or FEATURE_USB_ACCESSORY is declared
# (SystemServer.java startOtherServices). Without these, UsbService never registers
# ("Can't find service: usb"), so even though the gadget is in mtp,adb and
# /dev/mtp_usb exists, no MtpServer opens it and MTP file transfer never works.
# Stock ships both (PXA1928 supports OTG host + accessory), so declare both.
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.usb.accessory.xml:system/etc/permissions/android.hardware.usb.accessory.xml \
    frameworks/native/data/etc/android.hardware.usb.host.xml:system/etc/permissions/android.hardware.usb.host.xml

# Wi-Fi / Bluetooth feature permissions. Without android.hardware.wifi.xml,
# PackageManager.hasSystemFeature(FEATURE_WIFI) is false and the framework never
# brings Wi-Fi up ("Wi-Fi not recognized"); likewise bluetooth(_le).xml gate the
# BT adapter feature. These ship the declarations; the daemons/HAL do the work.
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.wifi.xml:system/etc/permissions/android.hardware.wifi.xml \
    frameworks/native/data/etc/android.hardware.wifi.direct.xml:system/etc/permissions/android.hardware.wifi.direct.xml \
    frameworks/native/data/etc/android.hardware.bluetooth.xml:system/etc/permissions/android.hardware.bluetooth.xml \
    frameworks/native/data/etc/android.hardware.bluetooth_le.xml:system/etc/permissions/android.hardware.bluetooth_le.xml

# Wi-Fi supplicant + AP daemon, built from CM external/wpa_supplicant_8 against our
# own libssl/libnl/libkeystore_binder (BOARD_WPA_SUPPLICANT_DRIVER := NL80211 in
# BoardConfig). The init wpa_supplicant/p2p_supplicant/hostapd services in
# init.pxa1928.rc reference /system/bin/wpa_supplicant, which did not exist before
# -> Wi-Fi could never enable. libwpa_client (framework side) already builds.
# wpa_supplicant.conf / *_overlay.conf ship as stock blobs via the vendor mk.
PRODUCT_PACKAGES += \
    wpa_supplicant \
    hostapd
