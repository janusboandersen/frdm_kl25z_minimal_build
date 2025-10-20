# Top-level build system generator for KL25Z
#
# Usage:
# Configure:
#   cmake -S . -B build -G Ninja
#
# Build ELF, BIN and HEX
#   cmake --build build -v
#
# Build documentation
#   cmake --build build --target readme
#
# Janus, October 2025

# Configure phase
cmake_minimum_required(VERSION 3.20)
set(CMAKE_TOOLCHAIN_FILE    "${CMAKE_SOURCE_DIR}/cmake/toolchain-arm-none-eabi.cmake")

# Generate phase
project(firmware C CXX ASM)
set(CMAKE_C_STANDARD 99)
set(CMAKE_CXX_STANDARD 20)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")
include(firmware_management)

include(cmake/readme_docs.cmake)

add_executable(firmware
    startup/startup_kl25z.S
    system/system_kl25z.cpp
    src/main.cpp
)

set(LINKER_SCRIPT "${CMAKE_SOURCE_DIR}/linker/linker_kl25z.ld")
target_link_options(firmware PRIVATE "-T${LINKER_SCRIPT}")

add_firmware_management(firmware)