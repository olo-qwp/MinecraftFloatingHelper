# 项目名称
TWEAK_NAME = MinecraftFloatingHelper

# 目标架构 - A11需要arm64, Dopamine支持arm64e
ARCHS = arm64 arm64e

# iOS目标版本 - 专注Dopamine (iOS 15+)
TARGET = iphone:clang:latest:15.0

# 引入Theos公共配置
include $(THEOS)/makefiles/common.mk

# 源文件
$(TWEAK_NAME)_FILES = Tweak.xm

# 链接的框架
$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore

# 启用ARC，忽略不必要的警告
$(TWEAK_NAME)_CFLAGS = -fobjc-arc -Wno-c99-designator -Wno-unused-variable -Wno-deprecated-declarations

# 引入tweak构建规则
include $(THEOS_MAKE_PATH)/tweak.mk

# 安装后杀掉Minecraft PE进程
after-install::
	install.exec "killall -9 Minecraft"