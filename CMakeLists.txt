# Top-level build system generator for KL25Z
#
# Usage:
# cmake -S . -B build -G Ninja
# cmake --build build -v
#
# cmake --build build --target readme
# Janus, October 2025

# Configure phase
cmake_minimum_required(VERSION 3.20)
set(CMAKE_TOOLCHAIN_FILE    "${CMAKE_SOURCE_DIR}/cmake/toolchain-arm-none-eabi.cmake")

# Generate phase
project(firmware C CXX ASM)
set(CMAKE_C_STANDARD 99)
set(CMAKE_CXX_STANDARD 20)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")
include(firmware-management)

add_executable(firmware
    startup/startup_kl25z.S
    system/system_MKL25Z4.cpp
    src/main.cpp
)

set(LINKER_SCRIPT "${CMAKE_SOURCE_DIR}/linker/kl25z.ld")
target_link_options(firmware PRIVATE "-T${LINKER_SCRIPT}")

add_firmware_management(firmware)

# --------------------------
# Documentation renderer
# --------------------------
set(DIAGRAM1         ${CMAKE_SOURCE_DIR}/docs/build_pipeline.mmd)
set(DIAGRAM2         ${CMAKE_SOURCE_DIR}/docs/target_sram_layout.md)
set(DIAGRAM3         ${CMAKE_SOURCE_DIR}/docs/target_flash_layout.md)
set(DIAGRAM4         ${CMAKE_SOURCE_DIR}/docs/abi_contracts.md)
set(DIAGRAM5         ${CMAKE_SOURCE_DIR}/docs/build_transformations.md)
set(README_TEMPLATE  ${CMAKE_SOURCE_DIR}/docs/README_template.md)
set(RENDER_SCRIPT    ${CMAKE_SOURCE_DIR}/cmake/render_readme.cmake)
set(README_OUT       ${CMAKE_SOURCE_DIR}/README.md)

# Rule to generate README.md
add_custom_command(
  OUTPUT ${README_OUT}
  COMMAND ${CMAKE_COMMAND}
          -DDIAGRAM1=${DIAGRAM1}
          -DDIAGRAM2=${DIAGRAM2}
          -DDIAGRAM3=${DIAGRAM3}
          -DDIAGRAM4=${DIAGRAM4}
          -DDIAGRAM5=${DIAGRAM5}
          -DREADME_TEMPLATE=${README_TEMPLATE}
          -DREADME_OUT=${README_OUT}
          -P ${RENDER_SCRIPT}
  DEPENDS ${DIAGRAM} ${README_TEMPLATE} ${RENDER_SCRIPT}
  COMMENT "Rendering README.md from docs/"
  VERBATIM
)

# Target you can run: `ninja readme` (or `cmake --build . --target readme`)
add_custom_target(readme DEPENDS ${README_OUT})

# Optional: rebuild README on every normal build
# add_dependencies(all readme)   # or: add_custom_target(docs ALL DEPENDS readme)