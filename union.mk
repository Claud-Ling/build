################################################################################
# Following variables defines how the NS_USER (Non Secure User - Client
# Application), NS_KERNEL (Non Secure Kernel), S_KERNEL (Secure Kernel) and
# S_USER (Secure User - TA) are compiled
################################################################################
COMPILE_NS_USER   ?= 32
override COMPILE_NS_KERNEL := 64
COMPILE_S_USER    ?= 32
COMPILE_S_KERNEL  ?= 64

################################################################################
# Declare SoC, TEE SDK Version
################################################################################
override SOC			:= union
TEE_SDK_MAJOR			?= 1
TEE_SDK_MINOR			?= 0

################################################################################
# SoC specific variables
################################################################################

# adding TA load path for android project
CFG_TEE_EXTRA_CLIENT_LOAD_PATH	?= /system/misc

################################################################################
# Includes
################################################################################
-include common.mk
-include toolchain.mk

################################################################################
# Mandatory definition to use common.mk
################################################################################

# default not build optee os
OPTEE				?= 0

################################################################################
# Paths to git projects and various binaries
################################################################################
ARM_TF_PATH			?= $(ROOT)/arm-trusted-firmware
ifeq ($(DEBUG),1)
ARM_TF_BUILD			?= debug
else
ARM_TF_BUILD			?= release
endif

################################################################################
# Targets
################################################################################
all: prepare arm-tf linux

clean: arm-tf-clean uboot-clean linux-clean optee-os-clean optee-client-clean xtest-clean

cleaner: clean prepare-cleaner uboot-cleaner linux-cleaner toolchains-cleaner

prepare:
	@mkdir -p $(ROOT)/out

.PHONY: prepare-cleaner
prepare-cleaner:
	rm -rf $(ROOT)/out

################################################################################
# ARM Trusted Firmware
################################################################################
ARM_TF_EXPORTS ?= \
	CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"

ARM_TF_VERSION ?= $(call git_version,$(ARM_TF_PATH))

ARM_TF_FLAGS ?= \
	BL33=$(UBOOT_BIN) \
	DEBUG=$(DEBUG) \
	PLAT=$(SOC) \
	SPD=opteed \
	BUILD_STRING=$(ARM_TF_VERSION)

ifneq ($(MCU_BIN),)
ARM_TF_FLAGS += SCP_BL2=$(MCU_BIN)
endif

ifeq ($(OPTEE),1)
ARM_TF_FLAGS += \
	BL32=$(OPTEE_OS_BIN)

# add optee-os in prerequisites
arm-tf: optee-os
endif

arm-tf: uboot
	$(ARM_TF_EXPORTS) $(MAKE) -C $(ARM_TF_PATH) $(ARM_TF_FLAGS) all fip

arm-tf-install: arm-tf
	@echo "  INSTALL ATF"
	$(Q)mkdir -p $(OUT_PATH)/bin/$(ARM_TF_BUILD)
	$(Q)cp $(ARM_TF_PATH)/build/$(SOC)/$(ARM_TF_BUILD)/bl1.bin $(OUT_PATH)/bin/$(ARM_TF_BUILD)
	$(Q)cp $(ARM_TF_PATH)/build/$(SOC)/$(ARM_TF_BUILD)/fip.bin $(OUT_PATH)/bin/$(ARM_TF_BUILD)

.PHONY: arm-tf-clean
arm-tf-clean:
	$(ARM_TF_EXPORTS) $(MAKE) -C $(ARM_TF_PATH) $(ARM_TF_FLAGS) clean

################################################################################
# uboot
################################################################################

ifeq ($(BOOTDEV),nand)
UDFT_DEFCONFIG			?= $(SOC)_evb_defconfig
else ifeq ($(BOOTDEV),nor)
	ifeq ($(STORAGE),nand)
		UDFT_DEFCONFIG	?= $(SOC)_evb_defconfig
	else
		UDFT_DEFCONFIG	?= $(SOC)_emmc_defconfig
	endif
else
UDFT_DEFCONFIG			?= $(SOC)_emmc_defconfig
endif
UBOOT_DEFCONFIG			?= $(UDFT_DEFCONFIG)

UBOOT_COMMON_FLAGS += CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"

uboot-defconfig: $(UBOOT_PATH)/.config

uboot: uboot-common

.PHONY: uboot-defconfig-clean
uboot-defconfig-clean: uboot-defconfig-clean-common

.PHONY: uboot-clean
uboot-clean: uboot-clean-common

.PHONY: uboot-cleaner
uboot-cleaner: uboot-cleaner-common

################################################################################
# Linux kernel
################################################################################
LINUX_ARCH 			?= $(if $(filter $(COMPILE_NS_KERNEL),64),arm64,arm)
LINUX_DEFCONFIG			?= $(SOC)_defconfig

linux-defconfig: $(LINUX_PATH)/.config

LINUX_COMMON_FLAGS += ARCH=$(LINUX_ARCH) dtbs $(if $(filter arm,$(LINUX_ARCH)),uImage,Image)
DTB = $(LINUX_PATH)/arch/$(LINUX_ARCH)/boot/dts/trix/sigma-$(SOC)-evb.dtb

linux: linux-common

.PHONY: linux-defconfig-clean
linux-defconfig-clean: linux-defconfig-clean-common

.PHONY: linux-clean
linux-clean: linux-clean-common

.PHONY: linux-cleaner
linux-cleaner: linux-cleaner-common

################################################################################
# OP-TEE
################################################################################
OPTEE_OS_COMMON_FLAGS += PLATFORM=sigma-$(SOC)
OPTEE_OS_CLEAN_COMMON_FLAGS += PLATFORM=sigma-$(SOC)

optee-os: optee-os-common

.PHONY: optee-os-clean
optee-os-clean: optee-os-clean-common

optee-client: optee-client-common

.PHONY: optee-client-clean
optee-client-clean: optee-client-clean-common

################################################################################
# xtest / optee_test
################################################################################

# default search tee sdk firstly
SEARCH_TEE_SDK		?= 1

CROSS_COMPILE_NSU_TAG	:= $(shell basename $(CROSS_COMPILE_NS_USER))
CROSS_COMPILE_NSU_TAG	:= $(CROSS_COMPILE_NSU_TAG:-=)

ifneq ($(and $(filter $(SEARCH_TEE_SDK),1),$(wildcard $(ROOT)/optee_sdk),$(wildcard $(ROOT)/optee_sdk/host/$(CROSS_COMPILE_NSU_TAG))),)

TEE_SDK_ROOT		:= $(ROOT)/optee_sdk
TEE_SDK_CLIENT_EXPORT	:= $(TEE_SDK_ROOT)/host/$(CROSS_COMPILE_NSU_TAG)/teec
TEE_SDK_TA_DEV_KIT	:= $(TEE_SDK_ROOT)/tee/export-ta_arm$(COMPILE_S_USER)

$(if $(and $(wildcard $(TEE_SDK_CLIENT_EXPORT)),$(wildcard $(TEE_SDK_TA_DEV_KIT))),,$(error "cant locate teec or ta_dev_kit in tee sdk"))

XTEST_LOCAL_FLAGS := CROSS_COMPILE_HOST=$(CROSS_COMPILE_NS_USER)\
	CROSS_COMPILE_TA=$(CROSS_COMPILE_S_USER) \
	TA_DEV_KIT_DIR=$(TEE_SDK_TA_DEV_KIT) \
	OPTEE_CLIENT_EXPORT=$(TEE_SDK_CLIENT_EXPORT) \
	COMPILE_NS_USER=$(COMPILE_NS_USER) \
	O=$(OPTEE_TEST_OUT_PATH)

xtest:
	$(MAKE) -C $(OPTEE_TEST_PATH) $(XTEST_LOCAL_FLAGS)

else
xtest: xtest-common
endif

# FIXME:
# "make clean" in xtest: fails if optee_os has been cleaned previously
.PHONY: xtest-clean
xtest-clean: xtest-clean-common
	rm -rf $(OPTEE_TEST_OUT_PATH)

.PHONY: xtest-patch
xtest-patch: xtest-patch-common

################################################################################
# optee sdk
################################################################################

AARCH32_COMPILERS	:= $(AARCH32_CROSS_COMPILE)
AARCH64_COMPILERS	:= $(AARCH64_CROSS_COMPILE)

$(eval $(foreach n,$(AARCH32_COMPILERS),$(call build_optee_host,32,$(n))))
$(eval $(foreach n,$(AARCH64_COMPILERS),$(call build_optee_host,64,$(n))))

optee-sdk: optee-sdk-archive

################################################################################
# rootfs overlay
################################################################################

rootfs-overlay: rootfs-overlay-common

