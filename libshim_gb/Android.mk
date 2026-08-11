LOCAL_PATH := $(call my-dir)
include $(CLEAR_VARS)
LOCAL_MODULE := libshim_gb
LOCAL_MODULE_TAGS := optional
LOCAL_SRC_FILES := GraphicBuffer_shim.cpp
LOCAL_SHARED_LIBRARIES := libui libutils libcutils liblog
LOCAL_MULTILIB := 64
LOCAL_MODULE_RELATIVE_PATH :=
include $(BUILD_SHARED_LIBRARY)
