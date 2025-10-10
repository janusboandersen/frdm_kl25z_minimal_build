Figure 5: Build transformations
────────────────────────────────────────────────────────────────
    BUILD CHAIN: Sources to device
────────────────────────────────────────────────────────────────
   ┌────────────────────────────────────────────────────────┐
   │ Source Files (.S/.c/.cpp)                              │   
   │  • Relocatable sections: .text, .data, .bss            │
   │  • No fixed addresses yet                              │
   └────────────────────────────────────────────────────────┘
                    │
                    │  arm-none-eabi-gcc / g++
                    ▼
   ┌────────────────────────────────────────────────────────┐
   │ Object Files (.o)                                      │
   │  • Each has local symbol table, relocations            │
   │  • Still no fixed memory mapping                       │
   └────────────────────────────────────────────────────────┘
                    │
                    │  arm-none-eabi-ld (via g++ -T kl25z.ld)
                    │  Uses linker script to assign addresses
                    ▼
   ┌────────────────────────────────────────────────────────┐
   │ Executable and Linkable Format (ELF)                   │
   │  • Absolute addresses resolved (via MEMORY + SECTIONS) │
   │  • Includes vector table, symbols                      │
   │  • Used for debugging and conversion                   │
   └────────────────────────────────────────────────────────┘
                    │
                    │  arm-none-eabi-objcopy
                    ▼
   ┌────────────────────────────────────────────────────────┐
   │ Binary / Hex Image (.bin/.hex)                         │
   │  • Flattened memory image (Flash layout only)          │
   │  • No symbol or relocation data                        │
   └────────────────────────────────────────────────────────┘
                    │
                    │  pyocd flash firmware.bin
                    ▼
   ┌────────────────────────────────────────────────────────┐
   │ Physical Flash on KL25Z                                │
   │  • At reset, core reads vector table                   │
   │  • Begins execution from Reset_Handler                 │
   │  - Hands off to main()                                 │
   └────────────────────────────────────────────────────────┘
────────────────────────────────────────────────────────────────