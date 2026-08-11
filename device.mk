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
#
# These are public root certificates only -- no private keys -- so they are fine to
# publish. But generating them by sweeping the host's /etc/ssl/certs is exactly how a
# non-public certificate sneaks in: this set used to contain bfd1f08a.0
# (CN=endo-HP-Z240-SFF-Workstation), the build machine's Debian "ssl-cert" snakeoil
# certificate, whose private key lives in /etc/ssl/private on that machine. It was
# CA:FALSE with SAN DNS:endo-HP-Z240-SFF-Workstation so it could not sign anything and
# would only ever have validated a server using that hostname -- but a shipped trust
# store has no business carrying it, and it leaked the builder's hostname. Removed.
# After regenerating, verify every file is in the official bundle, e.g. compare
# `openssl x509 -in <f> -noout -fingerprint -sha256` for each cacerts/*.0 against the
# fingerprints in /etc/ssl/certs/ca-certificates.crt, and reject anything not present
# (or anything whose basicConstraints is not CA:TRUE).
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

# HWUI full-redraw: the Vivante GC5000's EGL does not honour buffer preservation
# (EGL_EXT_buffer_age / EGL_SWAP_BEHAVIOR=EGL_BUFFER_PRESERVED), so HWUI's default
# buffer-age partial rendering leaves the *changed* region flickering on every
# app-side screen update (scrolling, typing, animations) -- static frames are fine.
# (SurfaceFlinger itself never sets PARTIAL_UPDATES, so this is purely the app/HWUI
# path; confirmed on-device.) frameworks/base/libs/hwui/renderthread/EglManager.cpp
# gates buffer-age partial redraw on Properties::useBufferAge (debug.hwui.use_buffer_age,
# default true); setting it false forces a full-surface redraw each frame and removes
# the flicker (verified on-device). 5.1 did full redraws so it was never exposed.
# Slightly more GPU work. NB: debug.hwui.render_dirty_regions is NOT a real HWUI
# property (no-op); and debug.hwui.enable_partial_updates (33 chars) exceeds the
# 31-byte sysprop name limit so it can never be set -- use_buffer_age is the lever.
PRODUCT_PROPERTY_OVERRIDES += \
    debug.hwui.use_buffer_age=false

# Wi-Fi (Marvell sd8xxx / SDIO). Kernel driver is CONFIG_MRVL_WL_* built inline;
# firmware ships via the vendor mk (system/etc/firmware/mrvl).
PRODUCT_PROPERTY_OVERRIDES += \
    wifi.interface=wlan0

# NB: the 32-bit-first app ABI ordering lives in BoardConfig.mk as
# TARGET_CPU_ABI_LIST. It must NOT be done here with PRODUCT_PROPERTY_OVERRIDES:
# build.prop then contains ro.product.cpu.abilist twice (the auto-generated
# arm64-first line near the top, plus the override further down), and init refuses
# to modify a ro.* property that is already set -- so the auto-generated line wins
# and the override is silently dead. (Verified on-device: getprop returned
# arm64-v8a,... and WebView-using apps still launched as app_process64.)

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

# WebView. See prebuilt/webview/Android.mk for why we ship Google's Chrome 95 APK
# rather than the (un-syncable) cm-14.1 chromium-webview prebuilt. The two support
# libraries are platform code from frameworks/webview/chromium and are what zygote's
# preload actually dlopen()s -- without them every WebView inflate throws
# "Library webviewchromium_loader not found". libwebviewchromium_plat_support.so is
# also listed again in system/core/rootdir/etc/public.libraries.android.txt (it had
# been deleted from there back when no WebView existed, since the linker's public
# namespace refuses to start if a listed library is missing).
PRODUCT_PACKAGES += \
    WebViewGoogle \
    libwebviewchromium_loader \
    libwebviewchromium_plat_support

# Generic AOSP HAL modules (*.default.so) must be BUILT, not taken from the 5.1
# blobs. These are plain AOSP code -- shipping the 5.1 binaries means they are
# compiled against 5.1 headers while they link against our N libraries, and the
# resulting struct-size mismatches corrupt memory. The one that actually bit us:
# audio.r_submix.default.so does `new MonoPipe(...)`, sizing the object with 5.1's
# MonoPipe layout (168 bytes) while N's libnbaio.so runs the constructor with N's
# larger layout (it gained the ExtendedTimestamp SingleStateQueue members) -- so
# the constructor writes past the end of the allocation. Confirmed on-device with
# malloc_debug: "ALLOCATION 0x... SIZE 168 HAS A CORRUPTED REAR GUARD" freed from
# sp<MonoPipe>::clear() inside audio.r_submix.default.so. The victim of that
# overflow is whatever jemalloc put in the adjacent 192-byte chunk; once the
# Marvell primary HAL loads and shifts the heap layout, that neighbour became the
# AudioOut playback thread's IPCThreadState, whose mProcess got zeroed ->
# audioserver SIGSEGV in talkWithDriver -> crash loop -> no audio at all.
# The rest are removed for the same reason before they bite.
PRODUCT_PACKAGES += \
    audio.a2dp.default \
    audio.primary.default \
    audio.r_submix.default \
    audio.usb.default \
    audio_policy.default \
    gralloc.default \
    keystore.default \
    local_time.default \
    power.default \
    vibrator.default

# libxml2 must come from the platform, NOT from the stock blobs. The 5.1 vendor
# libxml2.so links against ICU 53 (ucnv_open_53, UCNV_TO_U_CALLBACK_STOP_53, ...),
# but N ships ICU 56, so the blob can never be dlopen()ed here:
#   HAL: dlopen failed: cannot locate symbol "UCNV_TO_U_CALLBACK_STOP_53"
#        referenced by "/system/lib/libxml2.so"
# Everything that pulls it in dies with it -- most visibly the Marvell audio HAL
# (audio.primary.mrvl.so -> libacm/libacoustic -> libxml2), which failed to load
# entirely, so AudioPolicyManager had NO reachable output device ("Failed to open
# primary output") and the device was completely silent. libpowerhintservice.so
# has the same dependency. external/libxml2 already has a BUILD_SHARED_LIBRARY
# rule; ship that instead (the blobs only need 11 stock libxml2 tree/parser
# entry points, all still exported). The blob is dropped from the vendor mk.
PRODUCT_PACKAGES += \
    libxml2

# Wi-Fi supplicant + AP daemon, built from CM external/wpa_supplicant_8 against our
# own libssl/libnl/libkeystore_binder (BOARD_WPA_SUPPLICANT_DRIVER := NL80211 in
# BoardConfig). The init wpa_supplicant/p2p_supplicant/hostapd services in
# init.pxa1928.rc reference /system/bin/wpa_supplicant, which did not exist before
# -> Wi-Fi could never enable. libwpa_client (framework side) already builds.
# wpa_supplicant.conf / *_overlay.conf ship as stock blobs via the vendor mk.
PRODUCT_PACKAGES += \
    wpa_supplicant \
    hostapd
