TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = MobilePhone InCallService
# Bỏ dòng dưới nếu máy jailbreak rootful (palera1n rootful...)
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Phone26 Phone26InCall

Phone26_FILES = Tweak.x
Phone26_CFLAGS = -fobjc-arc -Wno-deprecated-declarations

Phone26InCall_FILES = InCall.x
Phone26InCall_CFLAGS = -fobjc-arc -Wno-deprecated-declarations

include $(THEOS_MAKE_PATH)/tweak.mk
