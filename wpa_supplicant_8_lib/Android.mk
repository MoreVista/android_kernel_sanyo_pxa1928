# Device-local wpa_supplicant/hostapd nl80211 "driver_cmd" private lib for the
# Marvell sd8887 (mwifiex). The stock tree only builds lib_driver_cmd_bcmdhd, and
# that module lives under hardware/broadcom/wlan/bcmdhd whose Android.mk is gated by
# `ifeq ($(BOARD_WLAN_DEVICE),bcmdhd)` -- so with BOARD_WLAN_DEVICE := mrvl it is
# never parsed and wpa_supplicant/hostapd fail to link (undefined reference to
# wpa_driver_nl80211_driver_cmd). This builds the identical generic nl80211
# implementation under our own module name lib_driver_cmd_mrvl, referenced by
# BOARD_WPA_SUPPLICANT_PRIVATE_LIB / BOARD_HOSTAPD_PRIVATE_LIB in BoardConfig.mk.
LOCAL_PATH := $(call my-dir)

ifeq ($(WPA_SUPPLICANT_VERSION),VER_0_8_X)

ifneq ($(BOARD_WPA_SUPPLICANT_DRIVER),)
  CONFIG_DRIVER_$(BOARD_WPA_SUPPLICANT_DRIVER) := y
endif

WPA_SUPPL_DIR = external/wpa_supplicant_8
WPA_SRC_FILE :=

include $(WPA_SUPPL_DIR)/wpa_supplicant/android.config

WPA_SUPPL_DIR_INCLUDE = $(WPA_SUPPL_DIR)/src \
	$(WPA_SUPPL_DIR)/src/common \
	$(WPA_SUPPL_DIR)/src/drivers \
	$(WPA_SUPPL_DIR)/src/l2_packet \
	$(WPA_SUPPL_DIR)/src/utils \
	$(WPA_SUPPL_DIR)/src/wps \
	$(WPA_SUPPL_DIR)/wpa_supplicant

ifdef CONFIG_DRIVER_NL80211
WPA_SUPPL_DIR_INCLUDE += external/libnl/include
WPA_SRC_FILE += driver_cmd_nl80211.c
endif

ifeq ($(TARGET_ARCH),arm)
# To force sizeof(enum) = 4
L_CFLAGS += -mabi=aapcs-linux
endif

ifdef CONFIG_ANDROID_LOG
L_CFLAGS += -DCONFIG_ANDROID_LOG
endif

ifdef CONFIG_P2P
L_CFLAGS += -DCONFIG_P2P
endif

########################

include $(CLEAR_VARS)
LOCAL_MODULE := lib_driver_cmd_mrvl
LOCAL_SHARED_LIBRARIES := libc libcutils
LOCAL_CFLAGS := $(L_CFLAGS)
LOCAL_SRC_FILES := $(WPA_SRC_FILE)
LOCAL_C_INCLUDES := $(WPA_SUPPL_DIR_INCLUDE)
include $(BUILD_STATIC_LIBRARY)

########################

endif
