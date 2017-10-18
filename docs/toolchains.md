
# Toolchain overview


---
# Introduction
[toolchain.mk](toolchain.mk) is used to setup cross compilers for the build system.

---
# Output variables
[toolchain.mk](toolchain.mk) will set two public variables on output:
* AARCH32_CROSS_COMPILE
* AARCH64_CROSS_COMPILE
* GOOGLE32_CROSS_COMPILE (union only for now)

It can be done by typing

    make toolchains

Typically, do it the first before make any other targets, however this is not mandatory when USE_LOCAL_GCC=1, see [Flag USE_LOCAL_GCC](#Flag-USE_LOCAL_GCC).  

Users can manage to set these two variables by command line whatever, in which case [toolchain.mk](toolchain.mk) becomes NOPs.

    make AARCH32_CROSS_COMPILE=xxx AARCH64_CROSS_COMPILE=###

---
# Flag USE_LOCAL_GCC

Flag USE_LOCAL_GCC is tested when set up cross compilers (aarch64 and aarch32). If it is set to 1 then build system will try using the locally installed toolchains:

    AARCH32: arm-linux-gnueabihf-gcc
    AARCH64: aarch64-linux-gnu-gcc
    GOOGLE32: armv7a-cros-linux-gnueabi-gcc
Otherwise 'make toolchains' must be invoked firstly and build system will try downloading toolchains remotely as indicated by [Guidance on sdesigns ARM GNU/Linux toolchain](http://avenue.sdesigns.com/depts/RD/Teams/DTV/Wiki/Guidance%20on%20sdesigns%20ARM%20GNU%20Linux%20toolchain.aspx). i.e.

    make toolchains USE_LOCAL_GCC=0
USE_LOCAL_GCC flag default to 1.

