/* --------------------------------------------------------------------------
 * Linker script for FRDM-KL25Z (MKL25Z128VLK4)
 * 
 * Requires linking with ARM GNU Toolchain. Tested with v14.2.rel1. and v14.3.rel1.
 *
 * Project: KL25Z Minimal Build
 * File kl25z.ld
 *
 * Hardware contract: Physical memory regions of the MCU
 * FLASH: 0x0000_0000 .. 0x0001_FFFF (128 KB)
 * SRAM_L: 0x1FFF_F000 .. 0x1FFF_FFFF (4 KB)
 * SRAM_U: 0x2000_0000 .. 0x2000_2FFF (12 KB)
 *
 * ABI contract:
 *  - Includes compat. for EABI frame unwinding
 *  - Includes compat. for C++ constructors and destructors
 *  - Nano uses same hooks as libc to run C++ c'tors, d'tors
 *  - Does not include symbols for deprecated ABI compat.; so no .ctors, .dtors, .init, .fini
 *  - Provides symbols for heap checking (tool diagnostics), but doesn't support heap allocation.
 *  - Align SP to 8-byte boundary
 *
 * Targeted memory map
 *
 *  FLASH                          
 *  +-----------------------------+ <- 0x0000_0000: VECTOR_TABLE
 *  | Vector table (.isr_vector)  |
 *  +-----------------------------+ <- FCF
 *  | Flash config field (FCF)    |
 *  +-----------------------------+ <- FLASH_TEXT
 *  | Code (.text)                |
 *  | Inline and weak code        |
 *  +-----------------------------+
 *  | .rodata                     |
 *  | .eh_frame (if generated)    |
 *  +-----------------------------+
 *  | .ARM.extab (optional)       |     => detailed unwind tables (ARM EABI)
 *  +-----------------------------+
 *  | .ARM.exidx                  |     => index (used by unwinder)
 *  +-----------------------------+ <- __preinit_array_start
 *  | .preinit_array (optional)   |     => C++ init hooks
 *  +-----------------------------+ <- __preinit_array_end = __init_array_start
 *  | .init_array                 |     => C++ c'tor (__libc_init_array)
 *  +-----------------------------+ <- __init_array_end = __fini_array_start
 *  | .fini_array                 |     => C++ d'tor (__libc_fini_array)
 *  +-----------------------------+ <-- __fini_array_end = __etext
 *  | .data (copied to SRAM)      | 
 *  +-----------------------------+ 
 *  | Potentially unused          | 
 *  +-----------------------------+ <- 0x0002_0000
 *                                 
 *
 * SRAM                            
 *  +-----------------------------+ <- 0x1FFF_F000: __data_start__ 
 *  | .data (copied from Flash)   |     <= includes __boot_marker (startup .boot_marker )
 *  +-----------------------------+ <- __data_end__ = __bss_start__
 *  | .bss                        |  
 *  +-----------------------------+ <- __bss_end__ = __HeapBase
 *  | .heap                       | 
 *  +-----------------------------+ <- __HeapLimit = __StackLimit
 *  | .stack                      | 
 *  +-----------------------------+ <- 0x2000_3000: __StackBase => __StackTop (initial SP with empty stack)
 *
 * Janus, October 2025
 */

/* --------------------------------------------------------------------------
 *  Mark the entrypoint for debuggers
 * -------------------------------------------------------------------------- */
ENTRY(Reset_Handler);

MEMORY
{
  VECTOR_TABLE  (rx)  : ORIGIN = 0x00000000, LENGTH = 0x00000400              /* Up to FCF, some wastage here */
  FCF           (r)   : ORIGIN = 0x00000400, LENGTH = 0x10                    /* 0x0000_0400 - 0x0000_0410 */
  FLASH_TEXT    (rx)  : ORIGIN = 0x00000410, LENGTH = 0x00020000-0x00000410   /* Rest of 128 KB flash */
  SRAM          (rw)  : ORIGIN = 0x1FFFF000, LENGTH = 0x4000                  /* Full 16 KB */
}

/* --------------------------------------------------------------------------
 *  Implement fixed size heap and stack. 
 *
 *  ARMv6 call convention requires 8-byte alignment.
 *
 *  It is safe to provide __StackTop at one-past, as first push will 
 *  advance SP into writable region.
 * -------------------------------------------------------------------------- */
HEAP_SIZE = 2K;

STACK_SIZE = 2K;                                      /* tunable parameter, must be 8-byte divisible */
__StackBase = (ORIGIN(SRAM) + LENGTH(SRAM)) & ~7;     /* higher 8-byte aligned stack boundary */ 
__StackLimit = __StackBase - STACK_SIZE;              /* lower stack boundary */
PROVIDE(__StackTop = (ORIGIN(SRAM) + LENGTH(SRAM)));  /* one-past, emit for initialization of MSP */


SECTIONS
{
/* --------------------------------------------------------------------------
 *  Vector table must be at 0x0000_0000 to match contract with VTOR
 *  Word 0: MSP
 *  Word 1: Reset_Handler
 * -------------------------------------------------------------------------- */
  .isr_vector :
  {
    KEEP(*(.isr_vector))
  } > VECTOR_TABLE


/* --------------------------------------------------------------------------
 *  Config from startup must be exactly at 0x0000_0400 to avoid bricking device
 * -------------------------------------------------------------------------- */
  .FlashConfig 0x00000400 :
  {
    KEEP(*(.FlashConfig))
  } > FCF


/* --------------------------------------------------------------------------
 *  Executable code is kept in Flash as we have XIP support
 * -------------------------------------------------------------------------- */
  .text :
  {
    . = ALIGN(4);
    *(.text*)                 /* Executable code */
    *(.gnu.linkonce.t*)       /* Deduplicated executable code (inlined/weak) */
    *(.glue_7*) *(.glue_7t*)  /* ARM-Thumb ISA glue (Thumb-1 only, then empty) */
  } > FLASH_TEXT


/* --------------------------------------------------------------------------
 *  Read-only statically allocated constants also includes the eh_frame
 *  for C++ exception handling (legacy).
 * -------------------------------------------------------------------------- */
  .rodata :
  {
    . = ALIGN(4);
    *(.rodata*)               /* Read-only data */
    *(.gnu.linkonce.r*)       /* Deduplicated read-only data */
    *(.eh_frame*)             /* GNU may use this for C++ exception handling frame (empty iff -fno-exceptions) */
    . = ALIGN(4);
  } > FLASH_TEXT

/* --------------------------------------------------------------------------
 *  EABI exception and stack-unwind 
 *  (empty iff -fno-unwind-tables -fno-asynchronous-unwind-tables)
 * -------------------------------------------------------------------------- */
  .ARM.extab :
  {
    . = ALIGN(4);
    KEEP(*(.ARM.extab*))                      /* EHABI32 */
    KEEP(*(.gnu.linkonce.armextab.*))         /* Deduplicated */
    . = ALIGN(4);
  } > FLASH_TEXT

  /* Unwinder indices and required symbols */
  .ARM.exidx :
  {
    . = ALIGN(4);
    __exidx_start = .;                        /* Required linker-provided symbol */
    KEEP(*(.ARM.exidx*))                      /* EHABI32 */
    KEEP(*(.gnu.linkonce.armexidx.*))         /* Deduplicated */
    __exidx_end = .;                          /* Required linker-provided symbol */
    . = ALIGN(4);
  } > FLASH_TEXT


/* --------------------------------------------------------------------------
 *  Support C++: Populate the sections for preinit (early init), 
 *  static/global constructors and destructors. RO sections.
 *  The libc will use these symbol ranges upon invoking __libc_init_array().
 * -------------------------------------------------------------------------- */
  .preinit_array :
  {
    . = ALIGN(4);
    PROVIDE_HIDDEN(__preinit_array_start = .);
    KEEP(*(.preinit_array*))                  /* Pointers to early initialization functions */
    PROVIDE_HIDDEN(__preinit_array_end = .);
    . = ALIGN(4);
  } > FLASH_TEXT

  .init_array :
  {
    . = ALIGN(4);
    PROVIDE_HIDDEN(__init_array_start = .);  /* Constructors to run before main() */ 
    KEEP (*(SORT(.init_array.*)))             /* Priority-sorted like .init_array.00099 */
    KEEP (*(.init_array*))                    /* Without priority */
    PROVIDE_HIDDEN(__init_array_end = .);
    . = ALIGN(4);
  } > FLASH_TEXT
 
 .fini_array :
  {
    . = ALIGN(4);
    PROVIDE_HIDDEN (__fini_array_start = .);  /* Destructors to run after main() */
    KEEP (*(SORT(.fini_array.*)))
    KEEP (*(.fini_array*))
    PROVIDE_HIDDEN (__fini_array_end = .);
    . = ALIGN(4);
  } > FLASH_TEXT

/* --------------------------------------------------------------------------
 *  Set __etext as LMA to mark start of region as copy source from Flash
 * -------------------------------------------------------------------------- */
  .end_of_text :
  {
    . = ALIGN(4);
    __etext = .;               /* Mark location to begin copying */
  } > FLASH_TEXT

/* --------------------------------------------------------------------------
 * Emit symbols for .data boundaries as markers for copy destination in SRAM
 * Note: LMA and VMA splits here
 *  - LMA: Load loc. from Flash, begins at __etext.
 *  - VMA: Store loc. in SRAM, begins at ORIGIN(SRAM).
 * -------------------------------------------------------------------------- */
  .data : AT(__etext)
  {
    . = ALIGN(4);
    __data_start__ = .;       /* VMA */
    *(.data*)                 /* Initialized data */
    *(.gnu.linkonce.d*)       /* Deduplicated initialized data */

 /* --------------------------------------------------------------------------
  *  Will resolve __boot_marker, which exists to verify with debugger 
  * that startup code ran successfully. It's init value is copied with
  * other data
  * -------------------------------------------------------------------------- */
    KEEP(*(.boot_marker))

    . = ALIGN(4);             /* .data ends on a 4-byte boundary */
    __data_end__ = .;         /* one byte past last data addr */
  } > SRAM


 /* --------------------------------------------------------------------------
  *  Emit symbols for GNU/CMSIS compatibility
  * -------------------------------------------------------------------------- */
  PROVIDE(_sidata = LOADADDR(.data));                   /* LMA of .data, start */
  PROVIDE(__data_load__ = LOADADDR(.data));             /* Same */
  PROVIDE(_sdata  = __data_start__);                    /* VMA of .data, start */
  PROVIDE(_edata  = __data_end__);                      /* VMA of .data, end */

 /* --------------------------------------------------------------------------
  * Emit symbols for .bss boundaries, so startup can zero whole region.
  * -------------------------------------------------------------------------- */
  .bss (NOLOAD) :
  {
    . = ALIGN(4);
    __bss_start__ = .;
    *(.bss*) 
    *(COMMON)
    . = ALIGN(4);
    __bss_end__ = .;
  } > SRAM

  PROVIDE(_sbss   = __bss_start__);
  PROVIDE(_ebss   = __bss_end__);

/* --------------------------------------------------------------------------
 * Reserve a fixed size heap, so we can test that it works
 * AAPCS32 requires 8-byte alignment
 * -------------------------------------------------------------------------- */
  .heap (NOLOAD) : 
  {
    . = ALIGN(8);
    __heap_start__ = .;
    . += HEAP_SIZE;
    __heap_end__ = .;
  } > SRAM

  PROVIDE(__end__       = __heap_start__);    /* Heap symbol for malloc, etc. from libstdc++ */
  PROVIDE(end           = __heap_start__);    /* _sbrk from libnosys */
  PROVIDE(__HeapBase    = __heap_start__);
  PROVIDE(__HeapLimit   = __heap_end__);

/* --------------------------------------------------------------------------
 * Reserve a fixed size stack at the calculated __StackLimit -> __StackBase
 * AAPCS32 requires 8-byte alignment
 * Emit __StackTop required by startup for MSP init.
 * -------------------------------------------------------------------------- */
  .stack __StackLimit (NOLOAD) :
  {
    /* ASSERT (. <= __StackLimit, "Other sections overflow into stack region."); */
    __stack_start__ = .;    /* low watermark */
    . += STACK_SIZE;        /* reserve full size */
    __stack_end__ = .;      
  } > SRAM

  PROVIDE(__StackTop  = __StackBase);                   /* CMSIS alias, initial MSP loaded at reset */
  PROVIDE(__stack     = __StackBase);                   /* Same */


 /* --------------------------------------------------------------------------
  * Force a diagnostics section. It will be placed somewhere in vacant Flash
  * -------------------------------------------------------------------------- */
  .report (NOLOAD) :
  {
    LONG(ORIGIN(SRAM));
    LONG(LENGTH(SRAM));
    LONG(__boot_marker);
    LONG(__heap_start__);
    LONG(__heap_end__);
    LONG(__StackBase);
    LONG(__StackLimit);
    LONG(__stack_start__);
    LONG(__stack_end__);
  }

 /* --------------------------------------------------------------------------
  * Capture orphan sections to avoid the being dumped into image
  * -------------------------------------------------------------------------- */
  /DISCARD/ :
  {
    *(.comment)
    *(.report*)
    *(.note*)
    *(.gnu.debuglto_*)
  }
}

/* --------------------------------------------------------------------------
 * Safety checks to ensure invariants
 * -------------------------------------------------------------------------- */
/* Vector table checks */
ASSERT(SIZEOF(.isr_vector) == 48*4,                     ".isr_vector must be 48 vectors x 4 bytes (192 bytes).");
ASSERT((ADDR(.isr_vector) & 0xFF) == 0,                 "Vector table must be 256-byte aligned for Cortex-M0+");

/* Flash config checks */
ASSERT(SIZEOF(.FlashConfig) == 16,                      ".FlashConfig must be 16 bytes.");

/* .data checks */
ASSERT( (__etext >= 0x00000410),                        "Vector table/FCF must not overlap .text" );
ASSERT((__data_end__ - __data_start__) % 4 == 0,        ".data section size must be multiple of 4 bytes");

/* Space */
ASSERT(__data_start__ >= ORIGIN(SRAM),                  "DATA not in SRAM.");
ASSERT(__data_end__ < (ORIGIN(SRAM) + LENGTH(SRAM)),    "DATA too big for SRAM.");

/* .bss checks */
ASSERT(__bss_start__ >= __data_end__,                   "BSS does not follow DATA.");
ASSERT(__bss_end__ <= (ORIGIN(SRAM) + LENGTH(SRAM)) ,   "BSS too big for SRAM.");

/* Heap checks */
ASSERT(__HeapLimit >= __HeapBase,                       "Heap underflows!");

/* Stack checks */
ASSERT(__HeapLimit <= __StackLimit,                     "Heap overlaps stack!");
ASSERT((STACK_SIZE & 7) == 0,                           "Stack must be 8-byte aligned.");
ASSERT((__StackBase & 7) == 0,                          "__StackBase must be 8-byte aligned.");
ASSERT(__StackBase == __StackTop,                       "__StackBase and __StackTop must be equal.");
ASSERT(__stack_end__ == __StackBase,                    ".stack must end at __StackBase.");
ASSERT(__stack_end__ <= ORIGIN(SRAM) + LENGTH(SRAM),    "SRAM overflow");