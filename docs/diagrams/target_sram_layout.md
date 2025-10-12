Figure 2: Target SRAM memory layout after bring-up
──────────────────────────────────────────────────────────────────────────────────────────────────────
   KL25Z SRAM (16 KB)                                    Physical Addr.    VMA Addr.      LMA Address
──────────────────────────────────────────────────────────────────────────────────────────────────────
   ┌──────────────────────────────────────────────────┐  0x1FFF_F000       __data_start   __etext
   │ .data                                            │
   │ - Statically allocated pre-init. variables       │
   │ - Copied from flash by startup                   │
   └──────────────────────────────────────────────────┘  <-                __data_end__
   ┌──────────────────────────────────────────────────┐  <-                __bss_start__
   │ .bss                                             │
   │ - Statically allocated uninit. variables         │
   │ - Cleared to 0 by startup code                   │
   └──────────────────────────────────────────────────┘  <-                __bss_end__
   ┌──────────────────────────────────────────────────┐  <-                __HeapBase
   │ .heap                                            │
   │ - Managed by malloc/new if dynamic memory used   │
   │ - Heap grows toward higher addr.                 │
   └──────────────────────────────────────────────────┘  <-                __HeapLimit
   ┌──────────────────────────────────────────────────┐ 
   │ Potentially unused space                         │
   └──────────────────────────────────────────────────┘              
   ┌──────────────────────────────────────────────────┐  <-                __StackLimit
   │ .stack                                           │
   │ - Local variables and function frames            │
   │ - 8-byte aligned for call convention             │
   │ - Stack grows toward lower addr.                 │
   └──────────────────────────────────────────────────┘ 0x2000_2FFF        __StackBase
──────────────────────────────────────────────────────────────────────────────────────────────────────