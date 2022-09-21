#
# Copyright 2019-2021 Xilinx, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# makefile-generator v1.0.3
#

############################## Help Section ##############################
ifneq ($(findstring Makefile, $(MAKEFILE_LIST)), Makefile)
help:
	$(ECHO) "Makefile Usage:"
	$(ECHO) "  make all TARGET=<sw_emu/hw_emu/hw> PLATFORM=<FPGA platform> EDGE_COMMON_SW=<rootfs and kernel image path>."
	$(ECHO) "      Command to generate the design for specified Target and Shell."
	$(ECHO) ""
	$(ECHO) "  make clean "
	$(ECHO) "      Command to remove the generated non-hardware files."
	$(ECHO) ""
	$(ECHO) "  make cleanall"
	$(ECHO) "      Command to remove all the generated files."
	$(ECHO) ""
	$(ECHO) "  make test PLATFORM=<FPGA platform>"
	$(ECHO) "      Command to run the application. This is same as 'run' target but does not have any makefile dependency."
	$(ECHO) ""
	$(ECHO) "  make sd_card TARGET=<sw_emu/hw_emu/hw> PLATFORM=<FPGA platform> EDGE_COMMON_SW=<rootfs and kernel image path>"
	$(ECHO) "      Command to prepare sd_card files."
	$(ECHO) ""
	$(ECHO) "  make run TARGET=<sw_emu/hw_emu/hw> PLATFORM=<FPGA platform> EMU_PS=<X86/QEMU> EDGE_COMMON_SW=<rootfs and kernel image path>"
	$(ECHO) "      Command to run application in emulation.Default sw_emu will run on x86 ,to launch on qemu specify EMU_PS=QEMU. "
	$(ECHO) ""
	$(ECHO) "  make build TARGET=<sw_emu/hw_emu/hw> PLATFORM=<FPGA platform> EDGE_COMMON_SW=<rootfs and kernel image path>"
	$(ECHO) "      Command to build xclbin application."
	$(ECHO) ""
	$(ECHO) "  make host PLATFORM=<FPGA platform> EDGE_COMMON_SW=<rootfs and kernel image path>"
	$(ECHO) "      Command to build host application."
	$(ECHO) "      EDGE_COMMON_SW is required for SoC shells. Please download and use the pre-built image from - "
	$(ECHO) "      https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/embedded-platforms.html"
	$(ECHO) ""
endif

############################## Setting up Project Variables ##############################
TARGET := hw
SYSROOT := $(EDGE_COMMON_SW)/sysroots/cortexa72-cortexa53-xilinx-linux
SD_IMAGE_FILE := $(EDGE_COMMON_SW)/Image

include ./utils.mk

TEMP_DIR := ./_x.$(TARGET).$(XSA)
BUILD_DIR := ./build_dir.$(TARGET).$(XSA)

LINK_OUTPUT := $(BUILD_DIR)/apply_watermark_GOOD.link.xsa

EMU_PS := QEMU
ifeq ($(TARGET), sw_emu)
EMU_PS := X86
endif

# SoC variables
RUN_APP_SCRIPT = ./run_app.sh
PACKAGE_OUT = ./package.$(TARGET)

LAUNCH_EMULATOR = $(PACKAGE_OUT)/launch_$(TARGET).sh
RESULT_STRING = TEST PASSED

VPP_PFLAGS := 
CMD_ARGS = -x $(BUILD_DIR)/apply_watermark_GOOD.xclbin -i $(XF_PROJ_ROOT)/common/data/xilinx_img.bmp -c ./data/golden.bmp
SD_CARD := $(PACKAGE_OUT)
vck190_dfx_hw := false
dfx_chk := $(shell $(XF_PROJ_ROOT)/common/utility/custom_dfx_check.sh $(PLATFORM) $(XF_PROJ_ROOT))

ifeq ($(EMU_PS), X86)
CXXFLAGS += -I$(XILINX_XRT)/include -I$(XILINX_VIVADO)/include -Wall -O0 -g -std=c++1y
LDFLAGS += -L$(XILINX_XRT)/lib -pthread -lOpenCL
else
CXXFLAGS += -I$(SYSROOT)/usr/include/xrt -I$(XILINX_VIVADO)/include -Wall -O0 -g -std=c++1y
LDFLAGS += -L$(SYSROOT)/usr/lib -pthread -lxilinxopencl
endif
VPP_PFLAGS+=--package.sd_dir /proj/xbuilds/2022.2_daily_latest/internal_platforms/sw/versal/xrt

ifeq ($(TARGET),$(filter $(TARGET),sw_emu))
VPP_PFLAGS+= --package.emu_ps qemu
endif

#Check for EMU_PS
ifeq ($(TARGET), $(filter $(TARGET),hw_emu hw))
ifeq ($(EMU_PS), X86)
$(error For hw_emu and hw, the design has to run on QEMU. Thus, please give EMU_PS=QEMU for these targets.)
endif
endif

########################## Checking if PLATFORM in allowlist #######################
PLATFORM_BLOCKLIST += nodma 
############################## Setting up Host Variables ##############################
#Include Required Host Source Files
CXXFLAGS += -I$(XF_PROJ_ROOT)/common/includes/xcl2
CXXFLAGS += -I$(XF_PROJ_ROOT)/common/includes/cmdparser
CXXFLAGS += -I$(XF_PROJ_ROOT)/common/includes/logger
CXXFLAGS += -I$(XF_PROJ_ROOT)/common/includes/bitmap
HOST_SRCS += $(XF_PROJ_ROOT)/common/includes/xcl2/xcl2.cpp $(XF_PROJ_ROOT)/common/includes/cmdparser/cmdlineparser.cpp $(XF_PROJ_ROOT)/common/includes/logger/logger.cpp $(XF_PROJ_ROOT)/common/includes/bitmap/bitmap.cpp ./src/host.cpp 
# Host compiler global settings
CXXFLAGS += -fmessage-length=0
LDFLAGS += -lrt -lstdc++ 
ifneq ($(EMU_PS), X86)
LDFLAGS += --sysroot=$(SYSROOT)
endif
############################## Setting up Kernel Variables ##############################
# Kernel compiler global settings
VPP_FLAGS += -t $(TARGET) --platform $(PLATFORM) --save-temps 
VPP_FLAGS_apply_watermark +=  -DBAD_DESIGN=0


EXECUTABLE = ./critical_path
EMCONFIG_DIR = $(TEMP_DIR)

############################## Setting Targets ##############################
.PHONY: all clean cleanall docs emconfig
ifeq ($(EMU_PS), X86)
all: check-platform check-device $(EXECUTABLE) $(BUILD_DIR)/apply_watermark_GOOD.xclbin emconfig
else
all: check-platform check-device check_edge_sw $(EXECUTABLE) $(BUILD_DIR)/apply_watermark_GOOD.xclbin emconfig sd_card
endif

.PHONY: host
host: $(EXECUTABLE)

.PHONY: build
build: check-vitis check-device $(BUILD_DIR)/apply_watermark_GOOD.xclbin

.PHONY: xclbin
xclbin: build

############################## Setting Rules for Binary Containers (Building Kernels) ##############################
$(TEMP_DIR)/apply_watermark.xo: src/apply_watermark.cpp
	mkdir -p $(TEMP_DIR)
	v++ $(VPP_FLAGS) $(VPP_FLAGS_apply_watermark) -c -k apply_watermark --temp_dir $(TEMP_DIR)  -I'$(<D)' -o'$@' '$<'

$(BUILD_DIR)/apply_watermark_GOOD.xclbin: $(TEMP_DIR)/apply_watermark.xo
	mkdir -p $(BUILD_DIR)
	v++ $(VPP_FLAGS) -l $(VPP_LDFLAGS) --temp_dir $(TEMP_DIR) -o'$(LINK_OUTPUT)' $(+)
ifeq ($(EMU_PS), X86)
	v++ -p $(LINK_OUTPUT) $(VPP_FLAGS) -o $(BUILD_DIR)/apply_watermark_GOOD.xclbin
endif
############################## Preparing sdcard ##############################
.PHONY: sd_card
sd_card: gen_run_app $(SD_CARD)

$(SD_CARD): $(BUILD_DIR)/apply_watermark_GOOD.xclbin $(EXECUTABLE)
ifeq ($(dfx_chk), true)
ifeq ($(TARGET),$(filter $(TARGET), hw))
	v++ $(VPP_FLAGS) -p $(LINK_OUTPUT) -o $(BUILD_DIR)/apply_watermark_GOOD.xclbin 
	v++ $(VPP_PFLAGS) $(VPP_FLAGS) -p --package.out_dir $(PACKAGE_OUT) --package.rootfs $(EDGE_COMMON_SW)/rootfs.ext4 --package.sd_file $(SD_IMAGE_FILE) --package.sd_file xrt.ini --package.sd_file $(RUN_APP_SCRIPT) --package.sd_file $(EXECUTABLE) --package.sd_file $(XF_PROJ_ROOT)/common/data/xilinx_img.bmp --package.sd_file ./data/golden.bmp --package.sd_file $(BUILD_DIR)/apply_watermark_GOOD.xclbin
vck190_dfx_hw := true
endif
endif
ifeq ($(vck190_dfx_hw), false)
	v++ $(VPP_PFLAGS) -p $(LINK_OUTPUT) $(VPP_FLAGS) --package.out_dir $(PACKAGE_OUT) --package.rootfs $(EDGE_COMMON_SW)/rootfs.ext4 --package.sd_file $(SD_IMAGE_FILE) --package.sd_file xrt.ini --package.sd_file $(RUN_APP_SCRIPT) --package.sd_file $(EXECUTABLE) --package.sd_file $(EMCONFIG_DIR)/emconfig.json --package.sd_file $(XF_PROJ_ROOT)/common/data/xilinx_img.bmp --package.sd_file ./data/golden.bmp -o $(BUILD_DIR)/apply_watermark_GOOD.xclbin
endif

############################## Setting Rules for Host (Building Host Executable) ##############################
$(EXECUTABLE): $(HOST_SRCS)
ifeq ($(EMU_PS), X86)
	$(CXX) -o $@ $^ $(CXXFLAGS) $(LDFLAGS)
else
	make check_edge_sw
	make check-vitis
	$(XILINX_VITIS)/gnu/aarch64/lin/aarch64-linux/bin/aarch64-linux-gnu-g++ -o $@ $^ $(CXXFLAGS) $(LDFLAGS)
endif

emconfig:$(EMCONFIG_DIR)/emconfig.json
$(EMCONFIG_DIR)/emconfig.json:
	emconfigutil --platform $(PLATFORM) --od $(EMCONFIG_DIR)

############################## Setting Essential Checks and Running Rules ##############################
run: all
ifeq ($(TARGET),$(filter $(TARGET),sw_emu hw_emu))
ifeq ($(EMU_PS), X86)
	cp -rf $(EMCONFIG_DIR)/emconfig.json .
	XCL_EMULATION_MODE=$(TARGET) $(EXECUTABLE) $(CMD_ARGS)
else
	$(LAUNCH_EMULATOR) -run-app $(RUN_APP_SCRIPT) | tee run_app.log; exit $${PIPESTATUS[0]}
endif
else
	$(ECHO) "Please copy the content of sd_card folder and data to an SD Card and run on the board"
endif

.PHONY: test
test: $(EXECUTABLE)
ifeq ($(TARGET),$(filter $(TARGET),sw_emu hw_emu))
ifeq ($(EMU_PS), X86)
	XCL_EMULATION_MODE=$(TARGET) $(EXECUTABLE) $(CMD_ARGS)
else
	$(LAUNCH_EMULATOR) -run-app $(RUN_APP_SCRIPT) | tee run_app.log; exit $${PIPESTATUS[0]}
endif
else
	$(ECHO) "Please copy the content of sd_card folder and data to an SD Card and run on the board"
endif

check_edge_sw:
ifndef EDGE_COMMON_SW
	$(error EDGE_COMMON_SW variable is not set, please download and use the pre-built image from https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/embedded-platforms.html)
endif

############################## Cleaning Rules ##############################
# Cleaning stuff
clean:
	-$(RMDIR) $(EXECUTABLE) $(XCLBIN)/{*sw_emu*,*hw_emu*} 
	-$(RMDIR) profile_* TempConfig system_estimate.xtxt *.rpt *.csv 
	-$(RMDIR) src/*.ll *v++* .Xil emconfig.json dltmp* xmltmp* *.log *.jou *.wcfg *.wdb

cleanall: clean
	-$(RMDIR) build_dir* sd_card*
	-$(RMDIR) package.*
	-$(RMDIR) _x* *xclbin.run_summary qemu-memory-_* emulation _vimage pl* start_simulation.sh *.xclbin
	-$(RMDIR) ./output.bmp 
