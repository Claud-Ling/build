# Build System Design

---
## Contents
1. [Directory](#1-Directory)
2. [Components](#2-Components)
3. [Build targets](#3-Build-targets)

---
# 1. Directory

    build
      |----build_macros.mk              # build macro helper, common to chips
      |----common.mk                    # common make helper, common to chips
      |----docs                         # documentation folder
      |----Makefile                     # symbolic link to current selected chip make helper
      |----README.md                    # README
      |----toolchain.mk                 # toolchain make helper, common to chips
      |----union.mk                     # make helper for union, chip specific

---
# 2. Components

* [build_macros.mk](build_macros.mk)
* [common.mk](common.mk)
* [toolchain.mk](toolchain.mk)
* chip specific make helper, i.e. [union.mk](union.mk)
* Makefile

---
# 3. Build targets
* **toolchains**

  set up cross_compilers for the build system

      make toolchains
  
* **uboot**  

  build u-boot by

      make uboot

* **arm-tf**  

  build arm trusted firmware by

      make arm-tf

  it implicitly enables target: *uboot*   
additionally plus *optee-os* if

      make arm-tf OPTEE=1

* **optee-os**  

  build optee_os by

      make optee-os

* **optee-client**  

  build optee_client by

      make optee-client

* **xtest**  

  build optee test suite by

      make xtest

  it implicitly enables following targets: *optee-os* and *optee-client*.

* **optee-sdk**  

  make optee sdk by

      make optee-sdk

  it implicitly enables following targets: *optee-os*, *optee-client*, and *xtest*.

* **linux**  

  build linux kernel by

      make linux

* **all**  

  this is the default rule and it will implicitly enables following targets: *arm-tf*, *uboot*, and *linux*

      make all or make

  addtionally plus *optee-os*, *optee-client*, and *xtest* if

      make OPTEE=1


* **clean**  

  cleanup all object files by

      make clean

* **cleaner**  

  cleanup all object, configure, and output files by

      make cleaner


