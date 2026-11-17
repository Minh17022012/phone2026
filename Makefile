TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = MobilePhone InCallService
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Phone26 Phone26InCall

Phone26_FILES = Tweak.x
Phone26_CFLAGS = -fobjc-arc -I. -Wno-deprecated-declarations -Wno-error

Phone26InCall_FILES = InCall.x
Phone26InCall_CFLAGS = -fobjc-arc -I. -Wno-deprecated-declarations -Wno-error

include $(THEOS_MAKE_PATH)/tweak.mk
