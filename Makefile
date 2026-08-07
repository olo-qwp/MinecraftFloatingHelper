# 项目名称
TWEAK_NAME = MinecraftFloatingHelper

# 目标架构 - A11芯片需要arm64
ARCHS = arm64 arm64e

# iOS目标版本 - 兼容iOS 13+
TARGET = iphone:clang:latest:13.0

# 引入Theos公共配置
include $(THEOS)/makefiles/common.mk

# 源文件
$(TWEAK_NAME)_FILES = Tweak.xm

# 链接的框架
$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore

# 启用ARC
$(TWEAK_NAME)_CFLAGS = -fobjc-arc -Wno-c99-designator -Wno-unused-variable

# CFNetwork用于网络请求
$(TWEAK_NAME)_LIBRARIES = substrate

# 引入tweak构建规则
include $(THEOS_MAKE_PATH)/tweak.mk

# 安装后重启SpringBoard
after-install::
	install.exec "killall -9 SpringBoard"