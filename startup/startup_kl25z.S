/* --------------------------------------------------------------------------
 *  This file provides the C runtime entry point for Cortex-M0+ without vendor startup.
 *  
 *  Requires compilation with ARM GNU Toolchain. Tested with v14.3.rel1.
 *
 *  Project: KL25Z Minimal Build
 *  File: startup_kl25z.S
 *
 *  Responsibility:
 *  - Create Vector Table
 *  - Create Flash config
 *  - Set VTOR
 *  - Establish MSP
 *  - Call SystemInit()
 *  - Copy .data from Flash to SRAM
 *  - Zero .bss in SRAM
 *  - Call __libc_init_array()
 *  - Call main()
 *
 * 
 *  Functional contract
 *  -----------------------------------------
 *  Input assumptions:
 *  - Linker script defines: 
 *      __StackTop, 
 *      __etext (LMA),
 *      __data_start__, __data__end__ (VMA),
 *      __bss_start__, __bss_end__ (VMA).
 *  - SystemInit() is implemented by system_MKL25Z4.c and safe to call with MSP set.
 *  - main() is implemented by main.cpp.
 *  - Vector table (.isr_vector) is linked at 0x00000000.
 *
 *  Postconditions:
 *  - MSP initialized to __StackTop (8-byte aligned).
 *  - Clocks and oscillators at expected frequencies.
 *  - .data copied from Flash [__etext, __etext + size) to SRAM [__data_start__, __data_end__).
 *  - .bss zeroed in SRAM [__bss_start__, __bss_end__).
 *  - C++ constructors invoked via __libc_init_array().
 *  - main() called with interrupts enabled.
 *  - __boot_marker set for debug diagnostics.
 *
 *
 *  Janus, October 2025
 * -------------------------------------------------------------------------- */


/* --------------------------------------------------------------------------
 *  UAL mode dialect
 *  For CM0+:
 *  - Assemble for ARMv6-M architecture ISA
 *  - Enable CM0+ instruction subset
 *  - Assemble in Thumb mode 16-bit ISA
 * -------------------------------------------------------------------------- */
    .syntax unified
    .arch armv6-m
    .cpu cortex-m0plus
    .thumb

/* --------------------------------------------------------------------------
 *  Expects linker to resolve
 *  SystemInit              Function to set up clocks, etc.
 *  __libc_init_array       Runtime library static init and constructors
 *  main                    User's entrypoint
 * -------------------------------------------------------------------------- */
    .extern SystemInit
    .extern __libc_init_array
    .extern main    

/* --------------------------------------------------------------------------
 *  .boot_marker section exists to verify with that startup code ran ok.
 *  In linker it is placed at the end of the data section.
 *  __boot_marker: globally visible, debuggable magic value
 * -------------------------------------------------------------------------- */
    .section .boot_marker, "aw", %progbits
    .align 2
__boot_marker:
    .word 0xA5A5A5A5
    .globl __boot_marker
    .type __boot_marker, %object
    .size __boot_marker, . - __boot_marker

/* --------------------------------------------------------------------------
 *  Flash must hold its security settings to be read at Boot ROM.
 *  If this is done wrongly, the device is bricked.
 *  RefMan p 73, Section 3.6.1.2-6 Flash Memory Map, Flash Security, etc.
 *  RefMan p 423, Section 27.3.1
 *  Emit a global symbol for debugging
 * -------------------------------------------------------------------------- */
    .section .FlashConfig, "a", %progbits
    .align 2
__FlashConfig:
    .long 0xFFFFFFFF    // Backdoor comp. key, 8 bytes
    .long 0xFFFFFFFF    // Backdoor comp. key, cont'd
    .long 0xFFFFFFFF    // FPROTO0-3, 4 bytes
    .long 0xFFFFFFFE    // FSEC=0xFE (unsec.), FOPT=0xFF, Res., Res.
    .globl __FlashConfig
    .type __FlashConfig, %object
    .size __FlashConfig, . - __FlashConfig

/* --------------------------------------------------------------------------
 *  Linker must place the vector table at 0x0000_0000, with 4-byte alignment
 *  per the ARMv6-M architecture spec.
 *  So here must also fix to 2^n=4 byte boundary.
 * -------------------------------------------------------------------------- */
    .section .isr_vector, "a", %progbits
    .align 2

/* --------------------------------------------------------------------------
 *  RefMan p. 52, table 3-7 Interrupt Vector Assignment
 *  Core Vectors, Vectors 0-15
 *  Vector     0: initial MSP = __StackTop (from linker)
 *  Vector     1: Reset_Handler
 *  Vectors 2-15: Other
 * -------------------------------------------------------------------------- */
 __isr_vector:
    .word __StackTop            /* 0: Initial SP */
    .word Reset_Handler         /* 1: Inital PC */
    .word NMI_Handler           /* 2: NMI */
    .word HardFault_Handler     /* 3: HardFault */
    .word 0                     /* 4 */
    .word 0                     /* 5 */
    .word 0                     /* 6 */
    .word 0                     /* 7 */
    .word 0                     /* 8 */
    .word 0                     /* 9 */
    .word 0                     /* 10 */
    .word SVC_Handler           /* 11: Supervisor Call */
    .word 0                     /* 12 */
    .word 0                     /* 13 */
    .word PendSV_Handler        /* 14: Pendable request for system service */
    .word SysTick_Handler       /* 15: System tick timer */
    .globl __isr_vector
/* --------------------------------------------------------------------------
 *  RefMan p. 52, table 3-7 Interrupt Vector Assignment
 *  Non-core vectors, Vectors 16-47 (IRQ0-IRQ31)
 * -------------------------------------------------------------------------- */
    .word DMA0_IRQHandler
    .word DMA1_IRQHandler
    .word DMA2_IRQHandler
    .word DMA3_IRQHandler
    .word Reserved20_IRQHandler
    .word FTFA_IRQHandler
    .word LVD_LVW_IRQHandler
    .word LLWU_IRQHandler
    .word I2C0_IRQHandler
    .word I2C1_IRQHandler
    .word SPI0_IRQHandler
    .word SPI1_IRQHandler
    .word UART0_IRQHandler
    .word UART1_IRQHandler
    .word UART2_IRQHandler
    .word ADC0_IRQHandler
    .word CMP0_IRQHandler
    .word TPM0_IRQHandler
    .word TPM1_IRQHandler
    .word TPM2_IRQHandler
    .word RTC_IRQHandler
    .word RTC_Seconds_IRQHandler
    .word PIT_IRQHandler
    .word Reserved39_IRQHandler
    .word USB0_IRQHandler
    .word DAC0_IRQHandler
    .word TSI0_IRQHandler
    .word MCG_IRQHandler
    .word LPTMR0_IRQHandler
    .word Reserved45_IRQHandler
    .word PORTA_IRQHandler
    .word PORTD_IRQHandler
    .type __isr_vector, %object
    .size __isr_vector, . - __isr_vector

/* --------------------------------------------------------------------------
 *  Executable area, thumb encodings
 * -------------------------------------------------------------------------- */
    .text
    .thumb

/* --------------------------------------------------------------------------
 *  thumb function entry: Reset_Handler
 *  global symbol table, but weak binding (can be overwritten)
 *  label as a function for elf inspection
 * -------------------------------------------------------------------------- */
    .thumb_func
    .align 2
    .globl Reset_Handler
    .weak Reset_Handler
    .type Reset_Handler, %function
Reset_Handler:
/* --------------------------------------------------------------------------
 *  Disable/mask interrupts, as we have no handlers
 *  i: PRIMASK = regular interrupts, f: FAULTMASK
 * -------------------------------------------------------------------------- */
    cpsid i

/* --------------------------------------------------------------------------
 *  KL25Z implements vector table relocation, so we must update VTOR
 *  with location offset for the vector table.
 *  Linker places at 0x0000_0000, so offset must be zero.
 *
 *  ArchMan, B3.2.2 and B3.2.5 Vector Table Offset Register, VTOR
 *  GUG, p. 4-11 sect. 4.3.4
 *  VTOR is at 0xE000_ED08 bits 31:7
 *  Vector table offset register holds the vector table offset address
 *  Store address of __isr_vector in VTOR
 * -------------------------------------------------------------------------- */
    ldr   r0, =0xE000ED08       // VTOR
    ldr   r1, =__isr_vector
    str   r1, [r0]              // VTOR now holds location of vector table

/* --------------------------------------------------------------------------
 *  Store initial stack loc in special register for stack pointer (msr)
 *  msp = __StackTop
 * -------------------------------------------------------------------------- */
    ldr   r0, =__StackTop
    msr   msp, r0

/* --------------------------------------------------------------------------
 *  Before working on SRAM, we need clocks up and COP WDT disabled
 * -------------------------------------------------------------------------- */
    ldr   r0, =SystemInit
    blx   r0

/* --------------------------------------------------------------------------
 *  Copy R/W .data from Flash -> to runtime location in SRAM.
 *  Ensures that data is localized where linker promised.
 * -------------------------------------------------------------------------- */
    ldr   r1, =__etext              // LMA in Flash
    ldr   r2, =__data_start__       // VMA dest begin
    ldr   r3, =__data_end__         // VMA dest end (1 byte past)

copy_data:
    cmp   r2, r3        // r2 - r3
    beq   init_bss      // Done copying if (r2 == r3, flag Z == 1)

    ldr   r0, [r1]      // Copy word from Flash to r0
    str   r0, [r2]      // Copy word from r0 to SRAM
    adds  r1, r1, #4    // Advance LMA one word
    adds  r2, r2, #4    // Advance VMA one word
    b     copy_data     // Repeat

/* --------------------------------------------------------------------------
 *  SRAM state after reset is undefined.
 *  Ensure zeros instead of garbage for uninitialized variables.
 * -------------------------------------------------------------------------- */
init_bss:
    ldr   r1, =__bss_start__        // VMA dest begin
    ldr   r2, =__bss_end__          // VMA dest end
    movs  r0, #0                    // Zero

zero_bss:
    cmp   r1, r2
    beq   init_runtime              // Done zero'ing

    str   r0, [r1]                  // Set SRAM word to 0
    adds  r1, r1, #4                // Advance VMA one word
    b     zero_bss                  // Repeat

/* --------------------------------------------------------------------------
 *  Must ensure that static/global initializer and C++ constructors
 *  are fired before main()
 * -------------------------------------------------------------------------- */
init_runtime:
    ldr   r0, =__libc_init_array
    blx   r0

/* --------------------------------------------------------------------------
 *  Enable interrupts for main(), to not surprise user
 *  main() should never return. If it does, catch it with infinite loop.
 * -------------------------------------------------------------------------- */
    cpsie i
    ldr   r0, =main
    blx   r0

/* --------------------------------------------------------------------------
 *  Unusual to be here on bare metal. To get __fini_array* symbols emitted,
 *  we require running the destructors.
 * -------------------------------------------------------------------------- */
deinit_runtime:
    ldr   r0, =__libc_fini_array
    blx   r0

hang:
    b     hang
    .size Reset_Handler, . - Reset_Handler
    
    .globl Reset_Handler

/* --------------------------------------------------------------------------
 *  Weak default handlers: alias all to Default_Handler unless user overrides
 * -------------------------------------------------------------------------- */
    .thumb_func
    .weak Default_Handler
    .type Default_Handler, %function
Default_Handler:
    b     hang
    .size Default_Handler, . - Default_Handler

    /* Core exception weak aliases */
    .weak NMI_Handler
    .weak HardFault_Handler
    .weak SVC_Handler
    .weak PendSV_Handler
    .weak SysTick_Handler
    .set  NMI_Handler,       Default_Handler
    .set  HardFault_Handler, Default_Handler
    .set  SVC_Handler,       Default_Handler
    .set  PendSV_Handler,    Default_Handler
    .set  SysTick_Handler,   Default_Handler

    /* IRQ weak aliases (device specific) */
    .weak DMA0_IRQHandler
    .weak DMA1_IRQHandler
    .weak DMA2_IRQHandler
    .weak DMA3_IRQHandler
    .weak Reserved20_IRQHandler
    .weak FTFA_IRQHandler
    .weak LVD_LVW_IRQHandler
    .weak LLWU_IRQHandler
    .weak I2C0_IRQHandler
    .weak I2C1_IRQHandler
    .weak SPI0_IRQHandler
    .weak SPI1_IRQHandler
    .weak UART0_IRQHandler
    .weak UART1_IRQHandler
    .weak UART2_IRQHandler
    .weak ADC0_IRQHandler
    .weak CMP0_IRQHandler
    .weak TPM0_IRQHandler
    .weak TPM1_IRQHandler
    .weak TPM2_IRQHandler
    .weak RTC_IRQHandler
    .weak RTC_Seconds_IRQHandler
    .weak PIT_IRQHandler
    .weak Reserved39_IRQHandler
    .weak USB0_IRQHandler
    .weak DAC0_IRQHandler
    .weak TSI0_IRQHandler
    .weak MCG_IRQHandler
    .weak LPTMR0_IRQHandler
    .weak Reserved45_IRQHandler
    .weak PORTA_IRQHandler
    .weak PORTD_IRQHandler

    /* Overwritable default handler */
    .set DMA0_IRQHandler,            Default_Handler
    .set DMA1_IRQHandler,            Default_Handler
    .set DMA2_IRQHandler,            Default_Handler
    .set DMA3_IRQHandler,            Default_Handler
    .set Reserved20_IRQHandler,      Default_Handler
    .set FTFA_IRQHandler,            Default_Handler
    .set LVD_LVW_IRQHandler,         Default_Handler
    .set LLWU_IRQHandler,            Default_Handler
    .set I2C0_IRQHandler,            Default_Handler
    .set I2C1_IRQHandler,            Default_Handler
    .set SPI0_IRQHandler,            Default_Handler
    .set SPI1_IRQHandler,            Default_Handler
    .set UART0_IRQHandler,           Default_Handler
    .set UART1_IRQHandler,           Default_Handler
    .set UART2_IRQHandler,           Default_Handler
    .set ADC0_IRQHandler,            Default_Handler
    .set CMP0_IRQHandler,            Default_Handler
    .set TPM0_IRQHandler,            Default_Handler
    .set TPM1_IRQHandler,            Default_Handler
    .set TPM2_IRQHandler,            Default_Handler
    .set RTC_IRQHandler,             Default_Handler
    .set RTC_Seconds_IRQHandler,     Default_Handler
    .set PIT_IRQHandler,             Default_Handler
    .set Reserved39_IRQHandler,      Default_Handler
    .set USB0_IRQHandler,            Default_Handler
    .set DAC0_IRQHandler,            Default_Handler
    .set TSI0_IRQHandler,            Default_Handler
    .set MCG_IRQHandler,             Default_Handler
    .set LPTMR0_IRQHandler,          Default_Handler
    .set Reserved45_IRQHandler,      Default_Handler
    .set PORTA_IRQHandler,           Default_Handler
    .set PORTD_IRQHandler,           Default_Handler

    .end