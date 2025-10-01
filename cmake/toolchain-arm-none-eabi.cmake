# Toolchain for NXP FRDM-KL25Z
# Cortex-M0+ without FPU 
# Cross-compilation with Arm Toolchain 14.3.rel1
# Targets C++20 features
# Updated October 2025, Janus

# Cross-compile to Arm bare-metal
set(CMAKE_SYSTEM_NAME       Generic)
set(CMAKE_SYSTEM_PROCESSOR  arm)
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

# TOOLS: Must be on path
set(CMAKE_C_COMPILER    arm-none-eabi-gcc)
set(CMAKE_CXX_COMPILER  arm-none-eabi-g++)
set(CMAKE_ASM_COMPILER  arm-none-eabi-gcc)

# COMPILE: Armv6-M with thumb instruction set, no fpu. Policy: ban exceptions and RTTI. Separate sections for each function and data.
set(COMMON_FLAGS "-mcpu=cortex-m0plus -mthumb -ffunction-sections -fdata-sections -fno-exceptions -fno-rtti")
set(CMAKE_C_FLAGS_INIT      "${COMMON_FLAGS}")
set(CMAKE_CXX_FLAGS_INIT    "${COMMON_FLAGS} -std=c++20")
set(CMAKE_ASM_FLAGS_INIT    "${COMMON_FLAGS}")

# LINK: Link newlib-nano C++ runtime, plus C and math libs, stub out syscalls, have linker garbage-collect dead/unreferenced code to prune size
set(CMAKE_EXE_LINKER_FLAGS_INIT "-Wl, --gc-sections -specs=nano.specs -lc -lm -lnosys")
