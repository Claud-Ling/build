#
# $1 gcc
#
define PPROBE_GCC
	$(if $(shell $(1) -v),$(1),)
endef

# $1 - type (AARCH32|AARCH64)
# $2 - absolute path to gcc
define EXPORT_GCC
	$(eval $(1)_CROSS_COMPILE ?= $(patsubst %-gcc,%-,$2))
endef

#
# Get full path for local gcc
# $1 - type (AARCH32|AARCH64)
#
define LOCAL_GCC
	$(shell which $(LOCAL_$(1)_GCC))
endef

#
# Install GCC from remote
# $1 - type (AARCH32|AARCH64)
#
define INSTALL_GCC
	$(eval TARGET		:= $(TOOLCHAIN_ROOT)/.INSTALL_$(1))
	$(eval TMP_GCC_SRC	:= $(SRC_$(1)_GCC))
	$(eval TMP_GCC_VER	:= $($(1)_GCC_VERSION))

	$(eval $(call EXPORT_GCC,$(1),$($(1)_GCC)))

$(TARGET) :
	$(Q)mkdir -p $($(1)_PATH)
	curl -L $(TMP_GCC_SRC) -o $(TOOLCHAIN_ROOT)/$(TMP_GCC_VER).tar.xz
	tar xf $(TOOLCHAIN_ROOT)/$(TMP_GCC_VER).tar.xz -C $($(1)_PATH) --strip-components=1
	$(Q)touch $$@

toolchains : $(TARGET)
endef

#
# setup cross compiler
# $1 - type
define SETUP_GCC
	$(if $(and $(filter $(USE_LOCAL_GCC),1),$(call LOCAL_GCC,$(1))),$(call EXPORT_GCC,$(1),$(call LOCAL_GCC,$(1))),$(call INSTALL_GCC,$(1)))
endef

################################################################################
# Toolchains
################################################################################

ROOT				?= $(CURDIR)/..
TOOLCHAIN_ROOT 			?= $(ROOT)/toolchains
override TOOLCHAIN_SETS		:= AARCH32 AARCH64

# default use local installed GCC
USE_LOCAL_GCC			?= 1
LOCAL_AARCH32_GCC		?= arm-linux-gnueabihf-gcc
LOCAL_AARCH64_GCC		?= aarch64-linux-gnu-gcc

AARCH32_PATH			?= $(TOOLCHAIN_ROOT)/cross-arm
AARCH32_GCC			?= $(AARCH32_PATH)/linaro/bin/arm-linux-gnueabihf-gcc
AARCH32_GCC_VERSION 		?= linaro-5.3-2016.02-x86_64_arm-linux-gnueabihf
SRC_AARCH32_GCC 		?= http://darth/BSP/toolchain/linaro/binaries/$(AARCH32_GCC_VERSION)-sdesigns.tar.xz

AARCH64_PATH			?= $(TOOLCHAIN_ROOT)/cross-arm
AARCH64_GCC			?= $(AARCH64_PATH)/linaro64/bin/aarch64-linux-gnu-gcc
AARCH64_GCC_VERSION 		?= linaro-5.3-2016.02-x86_64_aarch64-linux-gnu
SRC_AARCH64_GCC 		?= http://darth/BSP/toolchain/linaro/binaries/aarch64/$(AARCH64_GCC_VERSION)-sdesigns.tar.xz

# default rule
.PHONY: toolchains
toolchains:

$(eval $(call assert_boolean,USE_LOCAL_GCC))
$(eval $(foreach n,$(TOOLCHAIN_SETS),$(call SETUP_GCC,$(n))))

$(info AARCH64_CROSS_COMPILE: $(AARCH64_CROSS_COMPILE))
$(info AARCH32_CROSS_COMPILE: $(AARCH32_CROSS_COMPILE))

toolchains-cleaner:
	@-rm -fr $(TOOLCHAIN_ROOT)
