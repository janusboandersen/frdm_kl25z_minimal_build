Figure 4: ABI contracts
────────────────────────────────────────────────────────────
    CONTRACT FLOW: CM0+ boot
────────────────────────────────────────────────────────────
   ┌────────────────────────────────────────────────────┐
   │ Cortex-M0+                                         │
   │  - Fetches SP, PC from 0x0000_0000                 │
   │  - Begins execution at Reset_Handler               │
   │  - Expects valid vector table in Flash             │
   └────────────────────────────────────────────────────┘
                    │
                    │  (requires)
                    ▼
   ┌────────────────────────────────────────────────────┐
   │ Linker Script (kl25z.ld)                           │
   │  - Defines FLASH & SRAM regions                    │
   │  - Places .isr_vector @ 0x0000_0000                │
   │  - Emits symbols: __StackTop, etc.                 │
   │  - Resolves all absolute addresses                 │
   └────────────────────────────────────────────────────┘
                    │
                    │  (startup reads symbols)
                    ▼
   ┌────────────────────────────────────────────────────┐
   │ Startup (Reset_Handler, startup_kl25z.S)           │
   │  - Copies .data from Flash to SRAM                 │
   │  - Zeros .bss                                      │
   │  - Initializes MSP, VTOR                           │
   │  - Calls SystemInit(), __libc_init_array(), main() │
   └────────────────────────────────────────────────────┘
                    │
                    │  (calls)
                    ▼
   ┌────────────────────────────────────────────────────┐
   │ C, C++ Runtime Libraries                           │
   │  - Provide __libc_init_array, _sbrk, malloc, etc.  │
   │  - Assume initialized .data/.bss and valid stack   │
   │  - Rely on linker-defined symbols for boundaries   │
   └────────────────────────────────────────────────────┘
                    │
                    │  (hands control to)
                    ▼
   ┌────────────────────────────────────────────────────┐
   │ User Application                                   │
   │  - Implements main()                               │
   │  - Runs on configured clock tree                   │
   │  - May call drivers, stdlib, or CMSIS APIs         │
   └────────────────────────────────────────────────────┘
────────────────────────────────────────────────────────────