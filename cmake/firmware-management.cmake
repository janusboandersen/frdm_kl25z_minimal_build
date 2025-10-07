# Emits custom build commands to a target, to manage the firmware
#
# Uses commandline tools that ship with the ARM GNU Toolchain
# 
# For generator expressions, see in particular what we can derive about the target
# https://cmake.org/cmake/help/latest/manual/cmake-generator-expressions.7.html#target-artifacts
#
# Janus, October 2025

include_guard(GLOBAL)

# TOOLS for conversion and inspection from the same toolchain. Must be on path
set(ARM_OBJCOPY arm-none-eabi-objcopy)
set(ARM_OBJDUMP arm-none-eabi-objdump)
set(ARM_READELF arm-none-eabi-readelf)
set(ARM_SIZE    arm-none-eabi-size)
set(ARM_NM      arm-none-eabi-nm)

function(add_firmware_management tgt)

    set(ELF         $<TARGET_FILE:${tgt}>)
    set(OUTDIR      $<TARGET_FILE_DIR:${tgt}>)
    set(BIN         ${OUTDIR}/${tgt}.bin)
    set(HEX         ${OUTDIR}/${tgt}.hex)
    set(DISASM      ${OUTDIR}/${tgt}.disasm)
    set(SECTTXT     ${OUTDIR}/${tgt}.sections.text)

# Flashable build artifacts
add_custom_command(TARGET ${tgt} POST_BUILD
    COMMAND ${ARM_OBJCOPY} -O binary ${ELF} ${BIN}
    COMMAND ${ARM_OBJCOPY} -O ihex   ${ELF} ${HEX}
    COMMENT "objcopy ${tgt} -> .bin/.hex"
)

endfunction()