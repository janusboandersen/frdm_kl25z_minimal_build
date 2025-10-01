cmake_minimum_required(VERSION 3.20)
project(kl25z_minimum_build C CXX ASM)
set(CMAKE_C_STANDARD 99)
set(CMAKE_CXX_STANDARD 20)

set(CMAKE_TOOLCHAIN_FILE    "${CMAKE_SOURCE_DIR}/cmake/toolchain-arm-none-eabi.cmake")
set(LINKER_SCRIPT           "${CMAKE_SOURCE_DIR}/linker/kl25z.ld")

add_executable(${PROJECT_NAME}
    startup/startup_kl25z.S
    src/main.cpp
)

target_link_options(${PROJECT_NAME} PRIVATE "-T${LINKER_SCRIPT}")

# Output .bin and .hex to flash board
add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND arm-none-eabi-size ${PROJECT_NAME}
    COMMAND arm-none-eabi-objcopy -O binary ${PROJECT_NAME} ${PROJECT_NAME}.bin
    COMMAND arm-none-eabi-objcopy -O ihex   ${PROJECT_NAME} ${PROJECT_NAME}.hex
)