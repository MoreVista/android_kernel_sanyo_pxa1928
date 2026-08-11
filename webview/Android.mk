# Prebuilt WebView provider.
#
# This tree has no WebView at all: external/chromium-webview/prebuilt/* could not be
# repo-synced (see the port notes), so external/chromium-webview/Android.mk has no
# webview.apk to install and the "webview" line was dropped from core_minimal.mk.
# The result on-device was:
#   WebViewFactory: UnsatisfiedLinkError: Library webviewchromium_loader not found
#   WebViewUpdateServiceImpl: MissingWebViewPackageException: No WebView installed
# and every app that inflates a WebView (Jelly, any in-app browser) died with
#   InflateException: Error inflating class org.lineageos.jelly.webview.WebViewExt
#
# Ship Google's Chrome 95 WebView instead of the cm-14.1-era Chromium: it is the same
# APK already proven on this hardware under CM 12.1, and it renders today's web. It is
# armeabi-v7a only, which is fine because device.mk already puts 32-bit first in
# ro.product.cpu.abilist so WebView-consuming apps launch as app_process32.
#
# The APK ships its native code compressed (extractNativeLibs=true), and PackageManager
# does not extract native libs for /system apps -- so the @-prefixed LOCAL_PREBUILT_JNI_LIBS
# below makes the build pull libwebviewchromium.so out of the APK into
# system/app/WebViewGoogle/lib/arm/ at install time, which is where the loader looks.
#
# Module is NOT named "webview": that name belongs to external/chromium-webview and a
# duplicate LOCAL_MODULE would be a build error. Only the package name matters to the
# framework, and com.google.android.webview is already declared availableByDefault in
# vendor/cm/overlay/common/.../xml/config_webview_packages.xml -- no device overlay needed
# (and a device overlay would lose to vendor/cm's anyway).

LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_MODULE := WebViewGoogle
LOCAL_SRC_FILES := WebViewGoogle.apk
LOCAL_MODULE_CLASS := APPS
LOCAL_MODULE_SUFFIX := $(COMMON_ANDROID_PACKAGE_SUFFIX)
LOCAL_MODULE_TAGS := optional
LOCAL_CERTIFICATE := PRESIGNED
LOCAL_MULTILIB := 32
LOCAL_PREBUILT_JNI_LIBS := @lib/armeabi-v7a/libwebviewchromium.so
LOCAL_REQUIRED_MODULES := \
    libwebviewchromium_loader \
    libwebviewchromium_plat_support

include $(BUILD_PREBUILT)
