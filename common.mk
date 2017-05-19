################################################################################
# build verbose
################################################################################

ifeq ("$(origin V)", "command line")
  BUILD_VERBOSE	= $(V)
endif
ifndef BUILD_VERBOSE
  BUILD_VERBOSE	= 0
endif

ifeq ($(BUILD_VERBOSE),1)
  Q =
else
  Q = @
endif

################################################################################
# Include
################################################################################
-include build_macros.mk

#
# Common definition to all platforms
#

BASH ?= bash
ROOT ?= $(shell pwd)/..

BUILD_PATH			?= $(ROOT)/build
OUT_PATH			?= $(ROOT)/out
LINUX_PATH			?= $(ROOT)/linux
UBOOT_PATH			?= $(ROOT)/u-boot
UBOOT_BIN			?= $(UBOOT_PATH)/u-boot.bin
OPTEE_GENDRV_MODULE		?= $(LINUX_PATH)/drivers/tee/optee/optee.ko
OPTEE_OS_PATH			?= $(ROOT)/optee_os
OPTEE_CLIENT_PATH		?= $(ROOT)/optee_client
OPTEE_CLIENT_EXPORT		?= $(OPTEE_CLIENT_PATH)/out/export
OPTEE_TEST_PATH			?= $(ROOT)/optee_test
OPTEE_TEST_OUT_PATH 		?= $(ROOT)/optee_test/out
HELLOWORLD_PATH			?= $(ROOT)/hello_world
OPTEE_SDK_PATH			?= $(OUT_PATH)/optee_sdk_$(call lowercase,$(SOC))
OPTEE_NAME			?= OP-TEE

# default ta load location for sdk
CFG_TEE_CLIENT_LOAD_PATH	?= /opt/Misc

# override TEE FS subpath
CFG_TEE_FS_SUBPATH		?= /protect

# default high verbosity. slow uarts shall specify lower if prefered
CFG_TEE_CORE_LOG_LEVEL		?= 2

CCACHE ?= $(shell which ccache) # Don't remove this comment (space is needed)

################################################################################
# Check coherency of compilation mode
################################################################################

ifneq ($(COMPILE_NS_USER),)
ifeq ($(COMPILE_NS_KERNEL),)
$(error COMPILE_NS_KERNEL must be defined as COMPILE_NS_USER=$(COMPILE_NS_USER) is defined)
endif
ifeq (,$(filter $(COMPILE_NS_USER),32 64))
$(error COMPILE_NS_USER=$(COMPILE_NS_USER) - Should be 32 or 64)
endif
endif

ifneq ($(COMPILE_NS_KERNEL),)
ifeq ($(COMPILE_NS_USER),)
$(error COMPILE_NS_USER must be defined as COMPILE_NS_KERNEL=$(COMPILE_NS_KERNEL) is defined)
endif
ifeq (,$(filter $(COMPILE_NS_KERNEL),32 64))
$(error COMPILE_NS_KERNEL=$(COMPILE_NS_KERNEL) - Should be 32 or 64)
endif
endif

ifeq ($(COMPILE_NS_KERNEL),32)
ifneq ($(COMPILE_NS_USER),32)
$(error COMPILE_NS_USER=$(COMPILE_NS_USER) - Should be 32 as COMPILE_NS_KERNEL=$(COMPILE_NS_KERNEL))
endif
endif

ifneq ($(COMPILE_S_USER),)
ifeq ($(COMPILE_S_KERNEL),)
$(error COMPILE_S_KERNEL must be defined as COMPILE_S_USER=$(COMPILE_S_USER) is defined)
endif
ifeq (,$(filter $(COMPILE_S_USER),32 64))
$(error COMPILE_S_USER=$(COMPILE_S_USER) - Should be 32 or 64)
endif
endif

ifneq ($(COMPILE_S_KERNEL),)
OPTEE_OS_COMMON_EXTRA_FLAGS ?= O=out/arm
OPTEE_OS_BIN		    ?= $(OPTEE_OS_PATH)/out/arm/core/tee.bin
ifeq ($(COMPILE_S_USER),)
$(error COMPILE_S_USER must be defined as COMPILE_S_KERNEL=$(COMPILE_S_KERNEL) is defined)
endif
ifeq (,$(filter $(COMPILE_S_KERNEL),32 64))
$(error COMPILE_S_KERNEL=$(COMPILE_S_KERNEL) - Should be 32 or 64)
endif
endif

ifeq ($(COMPILE_S_KERNEL),32)
ifneq ($(COMPILE_S_USER),32)
$(error COMPILE_S_USER=$(COMPILE_S_USER) - Should be 32 as COMPILE_S_KERNEL=$(COMPILE_S_KERNEL))
endif
endif

################################################################################
# set the compiler when COMPILE_xxx are defined
################################################################################
CROSS_COMPILE_NS_USER   ?= "$(CCACHE)$(AARCH$(COMPILE_NS_USER)_CROSS_COMPILE)"
CROSS_COMPILE_NS_KERNEL ?= "$(CCACHE)$(AARCH$(COMPILE_NS_KERNEL)_CROSS_COMPILE)"
CROSS_COMPILE_S_USER    ?= "$(CCACHE)$(AARCH$(COMPILE_S_USER)_CROSS_COMPILE)"
CROSS_COMPILE_S_KERNEL  ?= "$(CCACHE)$(AARCH$(COMPILE_S_KERNEL)_CROSS_COMPILE)"

ifeq ($(COMPILE_S_USER),32)
OPTEE_OS_TA_DEV_KIT_DIR	?= $(OPTEE_OS_PATH)/out/arm/export-ta_arm32
endif
ifeq ($(COMPILE_S_USER),64)
OPTEE_OS_TA_DEV_KIT_DIR	?= $(OPTEE_OS_PATH)/out/arm/export-ta_arm64
endif

ifeq ($(COMPILE_S_KERNEL),64)
OPTEE_OS_COMMON_EXTRA_FLAGS	+= CFG_ARM64_core=y
endif

################################################################################
# defines, macros, configuration etc
################################################################################
define KERNEL_VERSION
$(shell cd $(LINUX_PATH) && $(MAKE) --no-print-directory kernelversion)
endef
DEBUG ?= 0

################################################################################
# default target is all
################################################################################
all:

################################################################################
# U-boot
################################################################################
UBOOT_COMMON_FLAGS ?= LOCALVERSION=

uboot-common: uboot-defconfig
	$(MAKE) -C $(UBOOT_PATH) $(UBOOT_COMMON_FLAGS)

$(UBOOT_PATH)/.config: $(UBOOT_DEFCONFIG)
	$(MAKE) -C $(UBOOT_PATH) $(UBOOT_DEFCONFIG)
		
uboot-defconfig-clean-common:
	rm -f $(UBOOT_PATH)/.config

# UBOOT_CLEAN_COMMON_FLAGS can be defined in specific makefiles (union.mk,...)
# if necessary

uboot-clean-common: uboot-defconfig-clean
	$(MAKE) -C $(UBOOT_PATH) $(UBOOT_CLEAN_COMMON_FLAGS) clean

# UBOOT_CLEANER_COMMON_FLAGS can be defined in specific makefiles (union.mk,...)
# if necessary

uboot-cleaner-common: uboot-defconfig-clean
	$(MAKE) -C $(UBOOT_PATH) $(UBOOT_CLEANER_COMMON_FLAGS) distclean

################################################################################
# Linux
################################################################################
LINUX_COMMON_FLAGS ?= LOCALVERSION= CROSS_COMPILE=$(CROSS_COMPILE_NS_KERNEL) ARCH=$(LINUX_ARCH)

linux-common: linux-defconfig
	$(MAKE) -C $(LINUX_PATH) $(LINUX_COMMON_FLAGS)

$(LINUX_PATH)/.config: $(LINUX_DEFCONFIG)
	$(MAKE) -C $(LINUX_PATH) ARCH=$(LINUX_ARCH) $(LINUX_DEFCONFIG)
		
linux-defconfig-clean-common:
	rm -f $(LINUX_PATH)/.config

# LINUX_CLEAN_COMMON_FLAGS can be defined in specific makefiles (union.mk,...)
# if necessary

linux-clean-common: linux-defconfig-clean
	$(MAKE) -C $(LINUX_PATH) ARCH=$(LINUX_ARCH) $(LINUX_CLEAN_COMMON_FLAGS) clean

# LINUX_CLEANER_COMMON_FLAGS can be defined in specific makefiles (union.mk,...)
# if necessary

linux-cleaner-common: linux-defconfig-clean
	$(MAKE) -C $(LINUX_PATH) ARCH=$(LINUX_ARCH) $(LINUX_CLEANER_COMMON_FLAGS) distclean

################################################################################
# OP-TEE
################################################################################

OPTEE_OS_COMMON_FLAGS ?= \
	$(OPTEE_OS_COMMON_EXTRA_FLAGS) \
	CROSS_COMPILE=$(CROSS_COMPILE_S_USER) \
	CROSS_COMPILE_core=$(CROSS_COMPILE_S_KERNEL) \
	CROSS_COMPILE_ta_arm64=$(AARCH64_CROSS_COMPILE) \
	CROSS_COMPILE_ta_arm32=$(AARCH32_CROSS_COMPILE) \
	CFG_TEE_CORE_LOG_LEVEL=$(CFG_TEE_CORE_LOG_LEVEL) \
	DEBUG=$(DEBUG)

optee-os-common:
	$(MAKE) -C $(OPTEE_OS_PATH) $(OPTEE_OS_COMMON_FLAGS)

OPTEE_OS_CLEAN_COMMON_FLAGS ?= $(OPTEE_OS_COMMON_EXTRA_FLAGS)

optee-os-clean-common: xtest-clean
	$(MAKE) -C $(OPTEE_OS_PATH) $(OPTEE_OS_CLEAN_COMMON_FLAGS) clean

OPTEE_CLIENT_COMMON_FLAGS ?= CFG_TEE_CLIENT_LOAD_PATH=$(CFG_TEE_CLIENT_LOAD_PATH)
ifneq ("$(origin CFG_TEE_EXTRA_CLIENT_LOAD_PATH)","undefined")
OPTEE_CLIENT_COMMON_FLAGS += CFG_TEE_EXTRA_CLIENT_LOAD_PATH=$(CFG_TEE_EXTRA_CLIENT_LOAD_PATH)
endif
OPTEE_CLIENT_COMMON_FLAGS += CFG_TEE_FS_SUBPATH=$(CFG_TEE_FS_SUBPATH)

optee-client-common:
	$(MAKE) -C $(OPTEE_CLIENT_PATH) $(OPTEE_CLIENT_COMMON_FLAGS)	\
		CROSS_COMPILE=$(CROSS_COMPILE_NS_USER)

# OPTEE_CLIENT_CLEAN_COMMON_FLAGS can be defined in specific makefiles
# (union.mk,...) if necessary

optee-client-clean-common:
	$(MAKE) -C $(OPTEE_CLIENT_PATH) $(OPTEE_CLIENT_CLEAN_COMMON_FLAGS) \
		clean

################################################################################
# xtest / optee_test
################################################################################
XTEST_COMMON_FLAGS ?= CROSS_COMPILE_HOST=$(CROSS_COMPILE_NS_USER)\
	CROSS_COMPILE_TA=$(CROSS_COMPILE_S_USER) \
	TA_DEV_KIT_DIR=$(OPTEE_OS_TA_DEV_KIT_DIR) \
	OPTEE_CLIENT_EXPORT=$(OPTEE_CLIENT_EXPORT) \
	COMPILE_NS_USER=$(COMPILE_NS_USER) \
	O=$(OPTEE_TEST_OUT_PATH)

XTEST_COMMON_FLAGS += CFG_TA_DIR=$(CFG_TEE_CLIENT_LOAD_PATH)	\
	CFG_TEE_FS_SUBPATH=$(CFG_TEE_FS_SUBPATH)

xtest-common: optee-os optee-client
	$(MAKE) -C $(OPTEE_TEST_PATH) $(XTEST_COMMON_FLAGS)

XTEST_CLEAN_COMMON_FLAGS ?= O=$(OPTEE_TEST_OUT_PATH) \
	TA_DEV_KIT_DIR=$(OPTEE_OS_TA_DEV_KIT_DIR) \

xtest-clean-common:
	$(MAKE) -C $(OPTEE_TEST_PATH) $(XTEST_CLEAN_COMMON_FLAGS) clean

XTEST_PATCH_COMMON_FLAGS ?= $(XTEST_COMMON_FLAGS)

xtest-patch-common:
	$(MAKE) -C $(OPTEE_TEST_PATH) $(XTEST_PATCH_COMMON_FLAGS) patch


################################################################################
# optee_sdk
################################################################################

#
# generating common.mk
define filechk_common.mk
	(set -e;	\
	 echo "#";	\
	 echo "# Automatically generated file. DO NOT EDIT!";		\
	 echo "#";	\
	 echo "AARCH32_CROSS_COMPILE := $(shell basename $(AARCH32_CROSS_COMPILE))";	\
	 echo "AARCH64_CROSS_COMPILE := $(shell basename $(AARCH64_CROSS_COMPILE))";	\
	 echo "TA_CROSS_COMPILE := $(shell basename $(CROSS_COMPILE_S_USER))";	\
	 echo "TA_DEV_KIT_SEL   := $(notdir $(OPTEE_OS_TA_DEV_KIT_DIR))";	\
	)
endef

#
# generating tee_release.h
define filechk_tee_release.h
	(set -e;	\
	 echo "/*";	\
	 echo " * Automatically generated file. DO NOT EDIT!";		\
	 echo " */";	\
	 echo "#ifndef $(2)";	\
	 echo "#define $(2)";	\
	 echo "";		\
	 echo "#define TEE_NAME             \"$(OPTEE_NAME)\"";	\
	 echo "#define TEE_VERSION_STR      \"$(TEE_SDK_MAJOR).$(TEE_SDK_MINOR)\"";	\
	 echo "#define TEE_VERSION_CODE     $(shell	\
				expr $(TEE_SDK_MAJOR) \* 256 + 0$(TEE_SDK_MINOR))";	\
	 echo "#define TEE_VERSION(a,b)     (((a) << 8) + (b))";	\
	 echo "";		\
	 echo "#define TEE_RELEASE_TARGET   \"$(call uppercase,$(SOC))\"";	\
	 echo "#define TEE_RELEASE_DATE     \"$(shell date +"(%b %d %C%y - %T)")\"";	\
	 echo "#define TEE_RELEASE_BY       \"$(shell whoami)@$(shell hostname)\"";	\
	 echo "";		\
	 echo "#endif /*$(2)*/";	\
	)
endef

#
# create symbolic links for optee_client libraries
# $1 - path to optee_client library
#
define optee_client_set_lib_links
	$(Q)set -e; if [ -f $(1)/libteec.so.1.0 ]; then	\
		ln -sf libteec.so.1.0 $(1)/libteec.so.1;	\
		ln -sf libteec.so.1.0 $(1)/libteec.so;	\
	    fi
endef

#
# install all *.ta from source to destination
# $1 - source path where TAs reside
# $2 - destination path
#
define optee_install_ta
	$(Q)set -e;	\
	    mkdir -p $(2);	\
	    find $(1) -name *.ta | xargs -n1 -i cp {} $(2);
endef

#
# install all core stuffs to sdk
# $1 - build type, [debug|release]
#
define optee_install_core
	$(eval NO_USE=$(or $(filter $(1),debug release),$(error unknown build type $(1) - Should be debug or release)))
	$(Q)set -e;	\
	    mkdir -p $(OPTEE_SDK_PATH)/tee/$(1)/core;	\
	    cp $(OPTEE_OS_BIN) $(OPTEE_SDK_PATH)/tee/$(1)/core;	\
	    cp -r $(OPTEE_OS_PATH)/out/arm/export-ta_* $(OPTEE_SDK_PATH)/tee/$(1);
endef

OPTEE_SDK_ARCHIVE	?= $(notdir $(OPTEE_SDK_PATH)).tgz
OPTEE_SDK_DOC		?= $(BUILD_PATH)/docs/sigmadesigns-optee-sdk-overview.md
COMMON_MK_FILE		?= $(OPTEE_SDK_PATH)/mk/common.mk
TEE_RELEASE_FILE	?= $(OPTEE_SDK_PATH)/tee_release.h

# Force check
.PHONY : $(COMMON_MK_FILE)
$(COMMON_MK_FILE) : $(BUILD_PATH)/Makefile
	$(call filechk,common.mk)

.PHONY : $(TEE_RELEASE_FILE)
$(TEE_RELEASE_FILE) : $(BUILD_PATH)/Makefile
	$(call filechk,tee_release.h,__TEE_RELEASE_H__)

# Develop build for optee_os
optee-os-dev:
	$(MAKE) -C $(OPTEE_OS_PATH) $(OPTEE_OS_COMMON_FLAGS) CFG_TEE_CORE_DEBUG=y
	$(call optee_install_core,debug)

# Product build for optee_os
optee-os-prod: optee-os
	$(call optee_install_core,release)

optee-sdk-common: optee-sdk-prepare $(COMMON_MK_FILE) $(TEE_RELEASE_FILE) optee-os-dev optee-os-prod xtest optee-sdk-doc
	$(call optee_install_ta,$(OPTEE_TEST_OUT_PATH),$(OPTEE_SDK_PATH)/ta)

optee-sdk-doc: $(OPTEE_SDK_DOC)
	$(Q)mkdir -p $(OPTEE_SDK_PATH)/docs
	$(Q)cp $(OPTEE_SDK_DOC) $(OPTEE_SDK_PATH)/docs

optee-sdk-archive: optee-sdk-common
	@echo "  GEN     $(dir $(OPTEE_SDK_PATH))/$(OPTEE_SDK_ARCHIVE)"
	$(Q)set -e;	\
	    cd $(dir $(OPTEE_SDK_PATH));	\
	    tar -czf $(OPTEE_SDK_ARCHIVE) $(notdir $(OPTEE_SDK_PATH));	\
	    cd - > /dev/null;

.PHONY : optee-sdk-prepare
optee-sdk-prepare:
	@echo "  GEN     optee-sdk"

.PHONY : optee-sdk-clean
optee-sdk-clean:
	$(Q)-rm -fr $(OPTEE_SDK_PATH)

#
# make host for optee-sdk according to specified cross_compiler
# this is mainly for release purpose only
# $1 - COMPILE NS_USER (32|64)
# $2 - CROSS_COMPILE
define build_optee_host
	$(eval NO_USE=$(or $(filter $(1),32 64),$(error COMPILE_NS_USER=$(1) - Should be 32 or 64)))
	$(eval CROSS_COMPILE_ARM$(1)	:= $(2))
	$(eval OPTEEC_OUT_ARM$(1)	:= out/arm$(1))
	$(eval OPTEEC_EXPORT_ARM$(1)	:= $(OPTEE_CLIENT_PATH)/$(OPTEEC_OUT_ARM$(1))/export)
	$(eval OPTEE_TEST_OUT_ARM$(1)	:= out/arm$(1))
	$(eval COMPILE_NSU_ARM$(1)	:= $(shell basename $(CROSS_COMPILE_ARM$(1))))
	$(eval TEE_PKG_PATH_ARM$(1)	:= $(OPTEE_SDK_PATH)/host/$(COMPILE_NSU_ARM$(1):-=))

optee-client-clean-arm$(1) :
	$(MAKE) -C $(OPTEE_CLIENT_PATH) clean

optee-client-arm$(1) :
	$(MAKE) -C $(OPTEE_CLIENT_PATH) $(OPTEE_CLIENT_COMMON_FLAGS)	\
		CROSS_COMPILE=$(CROSS_COMPILE_ARM$(1)) O=$(OPTEEC_OUT_ARM$(1))

$(eval XTEST_COMMON_FLAGS_ARM$(1) := CROSS_COMPILE_HOST=$(CROSS_COMPILE_ARM$(1))\
	CROSS_COMPILE_TA=$(CROSS_COMPILE_S_USER) \
	TA_DEV_KIT_DIR=$(OPTEE_OS_TA_DEV_KIT_DIR) \
	OPTEE_CLIENT_EXPORT=$(OPTEEC_EXPORT_ARM$(1)) \
	COMPILE_NS_USER=$(1) \
	O=$(OPTEE_TEST_PATH)/$(OPTEE_TEST_OUT_ARM$(1)))

xtest-host-arm$(1): optee-os optee-client-arm$(1)
	$(MAKE) -C $(OPTEE_TEST_PATH) $(XTEST_COMMON_FLAGS_ARM$(1)) xtest

xtest-host-clean-arm$(1):
	$(MAKE) -C $(OPTEE_TEST_PATH)/host/xtest TA_DEV_KIT_DIR=$(OPTEE_OS_TA_DEV_KIT_DIR) \
		O=$(OPTEE_TEST_PATH)/$(OPTEE_TEST_OUT_ARM$(1))/xtest q=$(Q) clean

install-optee-host-arm$(1): optee-client-arm$(1) xtest-host-arm$(1)
	@echo "  INS     arm$(1) host for optee-sdk"
	$(Q)mkdir -p $(TEE_PKG_PATH_ARM$(1))/teec
	$(Q)cp -dapr $(OPTEEC_EXPORT_ARM$(1))/* $(TEE_PKG_PATH_ARM$(1))/teec
	$(call optee_client_set_lib_links,$(TEE_PKG_PATH_ARM$(1))/teec/lib)
	$(Q)mkdir -p $(TEE_PKG_PATH_ARM$(1))/bin
	$(Q)cp $(OPTEE_TEST_PATH)/$(OPTEE_TEST_OUT_ARM$(1))/xtest/xtest $(TEE_PKG_PATH_ARM$(1))/bin

optee-sdk-common: install-optee-host-arm$(1)

optee-sdk-clean: optee-client-clean-arm$(1) xtest-host-clean-arm$(1)

endef

################################################################################
# rootfs overlay
################################################################################

ROOTFS_OVERLAY_PATH	?= $(OUT_PATH)/rootfs_overlay
OPTEE_TA_LOAD_PATH	?= $(CFG_TEE_CLIENT_LOAD_PATH)/optee_armtz

optee-rootfs-overlay-common : optee-client xtest
	$(call optee_install_ta,$(OPTEE_TEST_OUT_PATH),$(ROOTFS_OVERLAY_PATH)$(OPTEE_TA_LOAD_PATH))
	$(Q)mkdir -p $(ROOTFS_OVERLAY_PATH)/usr/lib
	$(Q)cp $(OPTEE_CLIENT_EXPORT)/lib/* $(ROOTFS_OVERLAY_PATH)/usr/lib
	$(call optee_client_set_lib_links,$(ROOTFS_OVERLAY_PATH)/usr/lib)
	$(Q)mkdir -p $(ROOTFS_OVERLAY_PATH)/usr/bin
	$(Q)cp $(OPTEE_CLIENT_EXPORT)/bin/tee-supplicant $(ROOTFS_OVERLAY_PATH)/usr/bin 
	$(Q)cp $(OPTEE_TEST_OUT_PATH)/xtest/xtest $(ROOTFS_OVERLAY_PATH)/usr/bin

rootfs-overlay-common : optee-rootfs-overlay-common
