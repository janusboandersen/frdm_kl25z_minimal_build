# Automated firmware verification for KL25Z Cortex-M0+ (ARMv6)
#
# Janus, October 2025

# --- Meta data and compile target ---
def test_elf_is_32bit_little_endian_for_arm(parsed_elf):
    assert parsed_elf.header.ei_class == "ELFCLASS32"   # 32-bit
    assert parsed_elf.header.ei_data == "ELFDATA2LSB"   # Little-endian encoded
    assert parsed_elf.header.e_machine == "EM_ARM"

def test_architecture_is_armv6_cm0p(parsed_elf):
    # Build attributes AAELF32 -> Addenda32 sec. 3 (Build attributes)
    ARMv6SM = 0x0C      # p.20: Architecture v6S-M, with system extensions, e.g. M0+ adds system features like VTOR and low-power improvements)
    MCU_PROFILE = 0x4D  # p.20: 'M', e.g. for Cortex-M0+
    THUMB1_ONLY = 0x01  # p.20: (deprecated) The user permitted this entity to use 16-bit Thumb instructions (including BL)

    tags = parsed_elf.arm_attributes.tags
    assert tags["TAG_CPU_ARCH"] == ARMv6SM,             f'Unexpected CPU Architecture {tags["TAG_CPU_ARCH"]}'
    assert tags["TAG_CPU_ARCH_PROFILE"] == MCU_PROFILE, f'Unexpected CPU Profile {tags["TAG_CPU_ARCH_PROFILE"]}'
    assert tags["TAG_THUMB_ISA_USE"] == THUMB1_ONLY,    f'Unexpected ISA tag {tags["TAG_THUMB_ISA_USE"]}'


# --- Vector table / isr-vector ---
def test_isr_vector_symbol(parsed_elf):
    symbol_name = "__isr_vector"
    isr = parsed_elf.require_unique_symbol(symbol_name)
    assert isr.addr == 0x0000_0000, f"{symbol_name} addr={isr.addr:010x}"
    assert isr.size == 192,         f"{symbol_name} size={isr.size}"
    assert isr.typ == "STT_OBJECT", f"{symbol_name} type={isr.typ}"

def test_isr_vector_section(parsed_elf):
    section_name = ".isr_vector"
    isr = parsed_elf.require_section(section_name)
    assert isr.addr == 0x0000_0000,     f"{section_name} addr={isr.addr:010x}"
    assert isr.size == 192,             f"{section_name} size={isr.size}"
    assert isr.typ == "SHT_PROGBITS",   f"{section_name} type={isr.typ}"
    assert isr.is_allocatable,          f"{section_name} flags={isr.flags}"
    assert isr.align == 4,              f"{section_name} align={isr.align}"


# --- Flash configuration ---
def test_flash_configuration_symbol(parsed_elf):
    symbol_name = "__FlashConfig"
    fcf = parsed_elf.require_unique_symbol(symbol_name)
    assert fcf.addr == 0x0000_0400, f"{symbol_name} addr={fcf.addr:010x}"
    assert fcf.size == 16,          f"{symbol_name} size={fcf.size}"
    assert fcf.typ == "STT_OBJECT"

def test_flash_configuration_section(parsed_elf):
    section_name = ".FlashConfig"
    fcf = parsed_elf.require_section(section_name)
    assert fcf.addr == 0x0000_0400,     f"{section_name} addr={fcf.addr:010x}"
    assert fcf.size == 16,              f"{section_name} size={fcf.size}"
    assert fcf.typ == "SHT_PROGBITS",   f"{section_name} type={fcf.typ}"
    assert fcf.is_allocatable,          f"{section_name} flags={fcf.flags}"
    assert fcf.align == 4,              f"{section_name} align={fcf.align}"


# --- Reset_Handler ---
def test_reset_handler(parsed_elf):
    symbol_name = "Reset_Handler"
    rst = parsed_elf.require_unique_symbol(symbol_name)
    assert rst.typ == "STT_FUNC"


# --- glibc / C++ runtime ---
def test_init_fini_arrays(parsed_elf):

    # .init_array must always be present, referenced by crtbegin.o
    init_sec = parsed_elf.require_section(".init_array")
    init_start = parsed_elf.require_unique_symbol("__init_array_start")
    init_end = parsed_elf.require_unique_symbol("__init_array_end")
    assert (init_end.addr - init_start.addr) == init_sec.size
    assert parsed_elf.has_symbol("__libc_init_array")

    # .fini_array must always be present, but may be empty
    fini_sec = parsed_elf.require_section(".fini_array")
    assert fini_sec.is_allocatable and fini_sec.is_writable
    assert fini_sec.align % 4 == 0

    # __fini_* symbols are often not referenced on bare-metal (run-forever), unless exiting
    libc_needs_fini = parsed_elf.has_symbol("__libc_fini_array") or \
                      parsed_elf.has_symbol("exit") or \
                      parsed_elf.has_symbol("_exit") or \
                      parsed_elf.has_symbol("__call_exitprocs") or \
                      parsed_elf.has_symbol("__register_exitproc") or \
                      parsed_elf.has_symbol("__aeabi_atexit")

    if fini_sec.size > 0 and libc_needs_fini:
        # The markers for destructors must be available to runtime, because we will call exit
        fini_start = parsed_elf.require_unique_symbol("__fini_array_start")
        fini_end = parsed_elf.require_unique_symbol("__fini_array_end")
        assert (fini_end.addr - fini_start.addr) == fini_sec.size


# --- Heap and stack ---
def test_heap_does_not_overflow_stack(parsed_elf):
    heap_end = parsed_elf.require_unique_symbol("__HeapLimit")
    stack_end = parsed_elf.require_unique_symbol("__StackLimit")
    assert heap_end.addr <= stack_end.addr


# --- Magic runtime test symbol ---
def test_bootmarker_exists(parsed_elf):
    assert parsed_elf.has_symbol("__boot_marker")