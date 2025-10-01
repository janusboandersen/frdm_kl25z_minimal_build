# Minimal build for FRDM-KL25Z
### Why does this project exist?
Build tools - even for simple MCUs like on the FRDM-KL25Z - tend to over-abstract and over-generalize what's needed to get going, resulting in code-bloat. 
At times, tools also rely on closed-source components.
All this makes it hard to reason about code, and hard to learn from code.

In the case of KL25Z, the MCUXpresso SDK v2.2 emits about 35 MB of files to build a hello-world. The older boards come with a closed-source PEMicro bootloader, requiring closed-source tools to flash and debug.

This project is an experiment. It aims to distill the build and bring-up to a minimal configuration, using open-source tools. Use modern CMake and C++20.


### Why use FRDM-KL25Z?
This board is low cost, and it's ideal for experimentation. Buy one, if you can.

The FRDM-KL25Z is a dev/eval board from NXP (originally Freescale) with on-board OpenSDA.
- The MCU (Kinetis L-series MKL25Z128VLK4 aka. MKL25Z4) implements
    - An Arm Cortex-M0+ core (CM0+) with ARMv6-M architecture. 
        - It's a simple 32-bit core, common in low-end and legacy devices.
        - Decodes only Thumb 16-bit instructions.
        - MMIO.
    - 16 KB SRAM and 128 KB flash on-chip.
    - All the usual basic peripherals on-chip.
- On-board OpenSDA makes it easy to flash and debug without additional hardware (Kinetis K-series K20DX128VFM5).
- Many extra fun peripherals on the board as well.

### Will the project work on my computer?
Probably. This experiment was made on an Apple Silicon host running macOS. It could be repeated on any platform with minor modifications.

Janus, October 2025.


## Tooling Prerequisites
To have a good time, make sure you get the following tooling set up first.

### Arm GNU Toolchain
- Compilers, linkers, runtime libraries, etc.
- Download directly from [Arm Developer](https://developer.arm.com/Tools%20and%20Software/GNU%20Toolchain), or
- Install using your package manager.
    - On macOS: `brew install --cask gcc-arm-embedded`.
- Make sure to have binaries in path. 
    - On macOS/Linux update your rc-file with `export PATH=/Applications/ArmGNUToolchain/14.3.rel1/arm-none-eabi/bin:$PATH`, or similar.

### DAPLink (CMSIS-DAP debug probe interface)
- Replace stock PEMicro closed-source bootloader + interface.
- Download DAPLink firmware file v0253 from [daplink.io](https://daplink.io/).
- Connect the board in bootloader/maintenance mode (hold reset and plug in OpenSDA port).
- Best done in Linux: Mount device and copy file onto the FAT16 partition.
    - On Linux: `cp 0253_k20dx_frdmkl25z_0x8000.bin /path-to-mount/BOOTLOADER/ && sync`.
- Power cycle board. It should show up as a USB MSD named DAPLink.

### PyOCD
- Communicate with CMSIS-DAP to flash and debug MCU. Provides GDB server support.
- Easiest way to install is your Python package manager. 
    - On macOS: `brew install pipx`, `pipx ensurepath`, `pipx install pyocd`.
- Plug in board and check that it enumerates: `pyocd list`.

### VS Code and VS Code extensions:
- Install the following extensions
    - C/C++ (ms-vscode.cpptools).
    - CMake Tools (ms-vscode.cmake-tools).
    - Cortex-Debug (marus25.cortex-debug).

## Documentation, references
- Hardware documentation
    - NXP: Covers their integrated peripherals (memory, timers, etc.), chip electrical characteristics, dev board.
        - Kinetis KL25 Sub-Family Reference Manual (KL25P80M48SF0RM.pdf), Rev. 3 (2012) aka. **RM** or **RefMan**.
        - Kinetis KL25 Sub-Family Technical Data Sheet (KL25P80M48SF0.pdf).
        - FRDM-KL25Z User's Manual (NXP_FRDM-KL25Z_UM.pdf).
    - ARM. Covers CM0+ core, it's peripherals (NVIC, VTOR, etc.) and the entire architecture spec.
        - Cortex-M0+ Devices Generic User Guide (ARM DUI 0662B), Issue B (2012) aka. **GUG**
        - ARMv6-M Architecture Reference Manual (ARM DDI 0419E), Issue E (2018) aka. **ArchMan**
- References and inspiration
    - SDK emitted from [MCUXpresso](http://mcuxpresso.nxp.com/)
        - CM0+ core structures (`core_cm0plus.h`)
        - Linker scripts (`devices/MKL25Z4/gcc/MKL25Z128xxx4_flash.ld` and `devices/MKL25Z4/gcc/MKL25Z128xxx4_ram.ld`).
        - Startup files (`devices/MKL25Z4/gcc/startup_MKL25Z4.S`).
        - Board files (`.c` ).

#### Note on documentation scope:
- The KL25 Reference Manual intentionally omits details about the core registers (e.g., VTOR, AIRCR, PRIMASK, CONTROL, NVIC_ISER). These belong to the ARM Cortex-M0+ architecture itself, not to NXP’s implementation.
- To understand startup, interrupt vectors, or register-level core control, consult the ARMv6-M Architecture Reference Manual (DDI 0419E) — specifically sections B3.2 (System Control Block) and B3.2.5 (VTOR).
- The NXP reference manual resumes coverage at the memory-mapped peripheral level, beginning with SIM, MCG, GPIO, TPM, etc.

#### Rule of thumb:
- If the address starts with 0xE000_Exxx, it’s ARM.
- If it starts with 0x400x_xxxx, it’s NXP.

## Top-down: What is the wanted project outcome?
In short:
1) Directory and file structure organized logically to separate concerns.
2) Just enough code to achieve bring-up of SRAM and CM0+, in order to hand control to some hello-world blinky-style action. Requires,
3) Constructing a single binary firmware `.bin` file that can be flashed to the KL25Z.

### 1. Directory structure
```
kl25z_minimal_build/
├── .vscode/
│   └── launch.json
│   └── settings.json
├── cmake/
│   └── toolchain-arm-none-eabi.cmake       ← Cross-compiler setup
├── documentation/
│   └── DDI0419E_armv6m_arm.pdf
│   └── DUI0662B_cortex_m0p_r0p1_dgug.pdf
│   └── KL25P80M48SF0.pdf
│   └── KL25P80M48SF0RM.pdf
│   └── NXP_FRDM-KL25Z_UM.pdf
├── linker/
│   └── kl25z.ld                            ← Linker script
├── startup/
│   └── startup_kl25z.S                     ← Startup code
├── system/
│   ├── system_MKL25Z4.c                    ← SystemInit()
│   └── MKL25Z4.h                           ← device header (tbd!)
├── src/
│   └── main.cpp                            ← User app source code
├── include/
│   └── project_config.h                    ← User app includes
└── build/
    └── (generated artifacts)               ← Build directory
├── CMakeLists.txt                          ← Top level build
└── README.md                               ← This file
```


### 2. Bringing up SRAM programmatically to prepare hand-off to user code...
The SRAM (volatile) is organized programmatically during bring-up.
The below structure is just the right context to hand off control to libraries, and then to user code.

```
Figure 1: Targeted SRAM memory layout after bring-up
───────────────────────────────────────────────────────────────
         KL25Z SRAM (Data Memory) — Address Low → High
───────────────────────────────────────────────────────────────
|  0x1FFF_F000 / 0x2000_0000 (start of SRAM)                  |
|  ┌───────────────────────────────────────────────────────┐  |
|  │ .data (RAM copy of initialized globals)               │  |
|  │   • Copied from flash (.data init section)            │  |
|  │   • Variables with static storage and initial value   │  |
|  └───────────────────────────────────────────────────────┘  |
|                                                             |
|  ┌───────────────────────────────────────────────────────┐  |
|  │ .bss (zero-initialized globals)                       │  |
|  │   • Cleared to 0 by startup code                      │  |
|  │   • Static / global vars without explicit init        │  |
|  └───────────────────────────────────────────────────────┘  |
|                                                             |
|  ┌───────────────────────────────────────────────────────┐  |
|  │ Heap (optional)                                       │  |
|  │   • Used by malloc/new if dynamic memory is enabled   │  |
|  │   • Grows upward ↑                                    │  |
|  └───────────────────────────────────────────────────────┘  |
|                                                             |
|  ┌───────────────────────────────────────────────────────┐  |
|  │ Stack                                                 │  |
|  │   • Starts at __StackTop                              │  |
|  │   • Grows downward ↓                                  │  |
|  │   • Used for local variables and function calls       │  |
|  └───────────────────────────────────────────────────────┘  |
|                                                             |
|  0x2000_2FFF (end of SRAM)                                  |
───────────────────────────────────────────────────────────────
```

### ...requires that nonvolatile memory is ready with the right contents...
To achieve this, nonvolatile Flash must hold the required data and instructions.
So, to get there, we need the Flash to be organized just right.

```
Figure 2: Targeted Flash memory layout to send to device
───────────────────────────────────────────────────────────────
         KL25Z FLASH (Code Memory) — Address Low → High
───────────────────────────────────────────────────────────────
|  0x0000_0000                                                |
|  ┌───────────────────────────────────────────────────────┐  |
|  │ Vector Table                                          │  |
|  │   • Initial MSP (word 0)                              │  |
|  │   • Reset_Handler (word 1)                            │  |
|  │   • Exception / IRQ vectors                           │  |
|  └───────────────────────────────────────────────────────┘  |
|                                                             |
|  ┌───────────────────────────────────────────────────────┐  |
|  │ .text                                                 │  |
|  │   • Executable code                                   │  |
|  │   • Inline literals / jump tables                     │  |
|  └───────────────────────────────────────────────────────┘  |
|                                                             |
|  ┌───────────────────────────────────────────────────────┐  |
|  │ .rodata                                               │  |
|  │   • Read-only constants                               │  |
|  │   • String literals                                   │  |
|  └───────────────────────────────────────────────────────┘  |
|                                                             |
|  ┌───────────────────────────────────────────────────────┐  |
|  │ .data (flash copy)                                    │  |
|  │   • Initial values for global/static vars             │  |
|  │   • Copied → SRAM at runtime                          │  |
|  └───────────────────────────────────────────────────────┘  |
|                                                             |
|  ┌───────────────────────────────────────────────────────┐  |
|  │ Unused / Reserved Flash                               │  |
|  │   • Free space for future code                        │  |
|  │   • Flash configuration field @ 0x0000_0400 (16B)     │  |
|  └───────────────────────────────────────────────────────┘  |
|                                                             |
───────────────────────────────────────────────────────────────
```

### ...and requires the right executable instructions to prepare the SRAM...

Startup code copies Flash `.data` into SRAM `.data`, zeros SRAM `.bss`, sets `MSP=__StackTop`, then runs `SystemInit` and enters `main()`.

```
Figure 3: Reset sequence and required operations to prepare SRAM 
┌─────────────────────────── KL25Z MEMORY OVERVIEW ─────────────────────────────────┐
│ Address grows ↓                                                                   │
│                                                                                   │
│                         FLASH (code memory, nonvolatile)                          │
│                         -------------------------------                           │
│ 0x0000_0000 ─┐  ┌────────────────────────────────────────────────────────┐        │
│              │  │ Vector Table (MSP=__StackTop, PC=Reset_Handler, IRQs)  │        │
│              │  └────────────────────────────────────────────────────────┘        │
│              │  ┌────────────────────────────────────────────────────────┐        │
│              │  │ .text (executable) + inline literals / jump tables     │        │
│              │  └────────────────────────────────────────────────────────┘        │
│              │  ┌────────────────────────────────────────────────────────┐        │
│              │  │ .rodata (read-only constants, strings)                 │        │
│              │  └────────────────────────────────────────────────────────┘        │    
│              │  ┌────────────────────────────────────────────────────────┐        │
│              │  │ .data (FLASH image of init values)                     │ ─┐     │
│              │  └────────────────────────────────────────────────────────┘  │     │
│              │                                                              │     │
│              │  [Flash Configuration Field @ 0x0000_0400 (16 B)]            │     │
│              │                                                              │     │
│ 0x0001_FFFF ─┘                                                              │     │
│                                                                             │     │
│                        SRAM (data memory, volatile, 16 KB)                  │     │
│                        -------------------------------------                │     │
│ 0x1FFF_F000/0x2000_0000 ─┐  ┌──────────────────────────────────────────┐    │     │
│                          │  │ .data (runtime storage)                  │◄───┘     │
│                          │  │  (copied from FLASH .data image)         │ COPY     │
│                          │  └──────────────────────────────────────────┘          │
│                          │  ┌──────────────────────────────────────────┐          │
│                          │  │ .bss (zero-initialized globals)          │◄─────┐   │
│                          │  │  (cleared to 0 by startup)               │ ZERO │   │
│                          │  └──────────────────────────────────────────┘      │   │
│                          │  ┌──────────────────────────────────────────┐      │   │
│                          │  │ Heap (optional, grows ↑)                 │      │   │
│                          │  └──────────────────────────────────────────┘      │   │
│                          │  ┌──────────────────────────────────────────┐      │   │
│                          │  │ Stack (MSP starts at __StackTop, grows ↓)│ ─────┘   │
│                          │  └──────────────────────────────────────────┘          │
│ 0x2000_2FFF ─────────────┘                                                        │
│                                                                                   │
│  RESET FLOW (simplified):                                                         │
│    1) SP ← Vector[0] (__StackTop)        2) PC ← Vector[1] (Reset_Handler)        │
│    3) Set VTOR to __isr_vector           4) Copy FLASH .data → SRAM .data         │
│    5) Zero SRAM .bss                     6) SystemInit (clocks, watchdog)         │
│    7) __libc_init_array (C++)            8) main()                                │
└───────────────────────────────────────────────────────────────────────────────────┘
```

### 3. Constructing the firmware file and flashing it to the device...
The figure below breaks down the required interaction chain to get the right firmware onto the device.
- From: What we have = startup code + linker script (inspired by the SDK), system header-file, etc..
- To: Where we want to end = Binary firmware consumed by MCU, code execution on CM0+.

The linker script is central here.
It resolves all symbol addresses and imposes the final memory layout.
The other parts (compiler output, startup, libraries) generate labeled, relocatable code that relies on those symbols being correctly defined and placed.

```
Figure 4: Tool invokation flow
───────────────────────────────────────────────────────────────
             BUILD CHAIN — Tool Interactions
───────────────────────────────────────────────────────────────

   ┌──────────────────────────────────────────────────────────┐
   │                 Source Files (.S/.c/.cpp)                │
   │  • Contain relocatable sections: .text, .data, .bss      │
   │  • No fixed addresses yet                                │
   └──────────────────────────────────────────────────────────┘
                    │
                    │  arm-none-eabi-gcc / g++
                    ▼
   ┌──────────────────────────────────────────────────────────┐
   │                 Object Files (.o)                        │
   │  • Each has local symbol table, relocations              │
   │  • Still no fixed memory mapping                         │
   └──────────────────────────────────────────────────────────┘
                    │
                    │  arm-none-eabi-ld (via g++ -T kl25z.ld)
                    │  Uses linker script to assign addresses
                    ▼
   ┌──────────────────────────────────────────────────────────┐
   │                 Executable and Linkable Format (.elf)    │
   │  • Absolute addresses resolved (via MEMORY + SECTIONS)   │
   │  • Includes vector table, program headers, symbols       │
   │  • Used for debugging and conversion                     │
   └──────────────────────────────────────────────────────────┘
                    │
                    │  arm-none-eabi-objcopy
                    ▼
   ┌──────────────────────────────────────────────────────────┐
   │                 Binary / Hex Image (.bin/.hex)           │
   │  • Flattened memory image (Flash layout only)            │
   │  • No symbol or relocation data                          │
   └──────────────────────────────────────────────────────────┘
                    │
                    │  pyocd flash firmware.bin
                    ▼
   ┌──────────────────────────────────────────────────────────┐
   │                 Physical Flash on KL25Z                  │
   │  • At reset, core reads vector table                     │
   │  • Begins execution from Reset_Handler                   │
   └──────────────────────────────────────────────────────────┘
───────────────────────────────────────────────────────────────
```

### ...is a series of tool calls... 

```
Figure 5: Tool calls and build artifacts
┌───────────────────────────────────────────────────────────────────────────────────────┐
│                        KL25Z BUILD & FLASH PIPELINE                                   │
└───────────────────────────────────────────────────────────────────────────────────────┘

Sources & Inputs
────────────────
  startup_kl25z.S     system_MKL25Z4.c     main.cpp (and other .c/.cpp)
  CMSIS/MKL25Z4 headers (MKL25Z4.h, core_cm0plus.h)
  Linker script: kl25z.ld
  Specs/libs: nano.specs, libgcc, newlib-nano, (libstdc++_nano if C++)

      │
      │ 1) Compile / Assemble
      │   (per-file → relocatable .o)
      ├─────────────────────────────────────────────────────────────────────────────────┐
      │  arm-none-eabi-gcc  -mcpu=cortex-m0plus -mthumb -Os -ffunction-sections         │
      │                      -fdata-sections -DNDEBUG -std=c17   -c startup_kl25z.S     │
      │                     → startup_kl25z.o                                           │
      │  arm-none-eabi-g++  -mcpu=cortex-m0plus -mthumb -Os -ffunction-sections         │
      │                      -fdata-sections -std=c++20 -fno-exceptions -fno-rtti       │
      │                      -fno-unwind-tables -fno-threadsafe-statics                 │
      │                      -c main.cpp                                                │
      │                     → main.o                                                    │
      │  arm-none-eabi-gcc  … -c system_MKL25Z4.c → system_MKL25Z4.o                    │
      └─────────────────────────────────────────────────────────────────────────────────┘
      │
      │ 2) Link
      │   (resolve symbols, place sections via kl25z.ld → ELF)
      ├─────────────────────────────────────────────────────────────────────────────────┐
      │  arm-none-eabi-g++  startup_kl25z.o main.o system_MKL25Z4.o                     │
      │    -T kl25z.ld -Wl,--gc-sections -Wl,-Map=firmware.map                          │
      │    -specs=nano.specs -lc -lm -lnosys ( + -lstdc++_nano if C++ )                 │
      │    -o firmware.elf                                                              │
      └─────────────────────────────────────────────────────────────────────────────────┘
      │
      │ 3) Convert
      │   (ELF → raw images for programmers)
      ├─────────────────────────────────────────────────────────────────────────────────┐
      │  arm-none-eabi-objcopy -O binary  firmware.elf firmware.bin                     │
      │  arm-none-eabi-objcopy -O ihex    firmware.elf firmware.hex (optional)          │
      └─────────────────────────────────────────────────────────────────────────────────┘
      │
      │ 4) Flash (CMSIS-DAP / DAPLink / PyOCD) and Debug (GDB)
      ├─────────────────────────────────────────────────────────────────────────────────┐
      │  pyocd list                                                                     │
      │  pyocd flash -t kl25z firmware.hex   # or .bin with --base-address 0            │
      │  pyocd gdbserver &  → arm-none-eabi-gdb firmware.elf  (load, run)               │
      └─────────────────────────────────────────────────────────────────────────────────┘
      │
      ▼
Running on KL25Z
  • Vector table @ 0x0000_0000 used by ROM on reset
  • .text/.rodata execute in-place from FLASH
  • Startup copies FLASH .data → SRAM, zeros .bss, sets clocks, calls main()
```

### ... creating artifacts that fulfill a set of contracts
Our job in building is to fulfill "contracts"
- Linker script must fulfill promise to CM0+ about location of items in Flash - to let it bootstrap itself.
- Startup code must fulfill promise to CM0+ about existence of a Reset_Handler - to bring up SRAM.
- Symbol coherence between linker script and startup code.
- Symbol coherence for runtime libraries, and established context (zeroed areas, etc.)

```
Figure 6: Contract set
───────────────────────────────────────────────────────────────
        CONTRACT MAP — CM0+ Boot Chain and Build Artifacts
───────────────────────────────────────────────────────────────

   ┌──────────────────────────────────────────────────────────┐
   │                  Cortex-M0+ Processor                    │
   │  • Fetches SP, PC from 0x0000_0000                       │
   │  • Begins execution at Reset_Handler                     │
   │  • Expects valid vector table in Flash                   │
   └──────────────────────────────────────────────────────────┘
                    │
                    │  (requires)
                    ▼
   ┌──────────────────────────────────────────────────────────┐
   │                     Linker Script (.ld)                  │
   │  • Defines FLASH & SRAM regions                          │
   │  • Places .isr_vector @ 0x0000_0000                      │
   │  • Emits symbols: __StackTop, __etext, __data_start__    │
   │  • Resolves all absolute addresses                       │
   └──────────────────────────────────────────────────────────┘
                    │
                    │  (startup reads symbols)
                    ▼
   ┌──────────────────────────────────────────────────────────┐
   │               Startup (Reset_Handler, .S)                │
   │  • Copies .data from Flash → SRAM                        │
   │  • Zeros .bss                                            │
   │  • Initializes MSP, VTOR                                 │
   │  • Calls SystemInit(), __libc_init_array(), main()       │
   └──────────────────────────────────────────────────────────┘
                    │
                    │  (calls)
                    ▼
   ┌──────────────────────────────────────────────────────────┐
   │                  C / C++ Runtime Libraries               │
   │  • Provide __libc_init_array, _sbrk, malloc, printf, etc.│
   │  • Assume initialized .data/.bss and valid stack         │
   │  • Rely on linker-defined symbols for heap boundaries    │
   └──────────────────────────────────────────────────────────┘
                    │
                    │  (hands control to)
                    ▼
   ┌──────────────────────────────────────────────────────────┐
   │                      User Application                    │
   │  • Implements main()                                     │
   │  • Runs on configured clock tree                         │
   │  • May call drivers, stdlib, or CMSIS APIs               │
   └──────────────────────────────────────────────────────────┘
───────────────────────────────────────────────────────────────
   ↑            ↑
   │            └────────── Library symbols resolved by linker
   │
   └──────────── Vector table + entry point consumed by hardware
───────────────────────────────────────────────────────────────
```

## Key details from the documentation

#### Memory map: MMIO, Flash and SRAM address ranges
- ARMv6-M has a 32-bit address space and word size is 32-bit / 4-byte.
- Memory is byte-addressable. So each consecutive address refers to a byte in memory.
- Byte order is little-endian.
- MMIO:
    - Peripheral region: `0x4000_0000` - `0x400F_FFFF`.
    - System control space (SysTick, NVIC): `0xE000_E000` - `0xE000_EFFF`.
- On-chip memory address ranges below are based on **RefMan** pp. 105-106:

| Memory    | From Adress   | To Address    | Size          |
|-----------|---------------|---------------|---------------|
| `FLASH`   | `0x0000_0000` | `0x0001_FFFF` | 128 KB (1, 2) |
| Config    | `0x0000_0400` | `0x0000_040F` | 16 B (2)      |
| `SRAM_L`  | `0x1FFF_F000` | `0x1FFF_FFFF` | 4 KB   (3)    |
| `SRAM_U`  | `0x2000_0000` | `0x2000_2FFF` | 12 KB         |

- Note (1): Nonvolatile storage is `128 KB * 1024 B / KB = 131,072 B`. Each byte is addressable, so we need `(131,072)_base10 = (0x0002_0000)_base16` addresses. `0x2000` different addresses are implemented by the range `0x0000_0000` to `0x0001_FFFF`.
- Note (2): Flash config section at `0x0000_0400` (16 bytes) is reserved for setting security state (SEC bits), protection (FPROT) and boot options (FOPT).
- Note (3): SRAM used as contiguous block in the memory map, but implemented as two banks with different controllers.

Memory can layed out by 8-bit (`.byte`), 16-bit (half-word `.hword`) and 32-bit (`.word` or `.long`) chunks when writing assembly code using the internal flash.

#### Vector table
- ARMv6-M needs to know the location of the vector table.
    - We will place the a vector table starting at `0x0000_0000`, i.e. offset `0x00` of the internal flash.
    - An entry in `VTOR` holds the offset to the vector table (**ArchMan** B3.2.5, p. B3-231).
    - `VTOR` is at `0xE000ED08` (**ArchMan** B3.2.2, p. B3-228).
    - So we also need to put a zero in that register.
- KL25Z implements vector table relocation.
- Table must hold internal exception vectors and external exception vectors = interrupt handlers.
- The vector table is used in the boot sequence as outlined in earlier chapter.

#### Boot sequence and bring-up
- The boot sequence is described in RM 6.3.3.
- After the system is released from reset (power, default clocking, flash init), the CM0+ bootstraps itself by starting execution at word 1.
- Our provided startup code (Reset_Handler) is vectored at word 1, and will prepare the right context in SRAM.

To bootstrap, the core needs a stack pointer (`SP`), program counter (`PC`) and link register (`LR`).
- `SP` and `PC` are read from offset `0x00` (word 0) and offset `0x04` (word 1) of the vector table, respectively.
- `LR` is init to `0xFFFF_FFFF`.
- Bootstrap is done, and startup code execution can begin; The core executes from initial `PC` location. 

Take-away: The handler at offset `0x04` is the true entry point of the firmware, because it runs immediately after the processor is bootstrapped. It is known as the `Reset_Handler`.

#### Startup file
- This file is analogous to a BIOS.
- It implements the `Reset_Handler`, whose instructions run immediately after the processor is bootstrapped from hardware reset.
- Defines

The startup file is assembler code, named `startup_kl25z.S`.

#### Reset_Handler
The `Reset_Handler` (vector at `0x04`) is invoked by the processor immediately after bootstrap.
- Runs SystemInit (clocks, watchdog, etc.).
- Copies elements from Flash to SRAM.
- Sets up handlers.
- Calls runtime libraries.
- Hands off to main.

#### Vector table: System internal exceptions
The architecture fixes 16 system vectors / exceptions (words 0-15).
- Word 0 (at offset 0): Initial `SP` (or initial main stack pointer, MSP).
- Word 1 (at offset 4): Initial `PC` (or Reset_Handler).
- Subsequent 14 words are vectors for other internal exception handlers, e.g. HardFault, SysTick.

#### Vector table: External exceptions = interrupts
The architecture supports 32 external interrupts (IRQ0-IRQ31).

#### SystemInit
Part of CMSIS

##### Clock initiation

### Linker script vs Startup
These are perhaps the hardest parts to get right. 
Link-time symbol naming should be seen as a contract between linker, startup-file and runtime.
So it's a good idea to stay with SDK naming, if you want to drop in drivers later.
But there's still a lot of redundancy to remove.

| Symbol | Purpose | Defined by | Used by |
|-----------|-----------|-----------|-----------|
| `__StackTop` | Initial MSP | kl25z.ld |  |
| `__isr_vector` ||||
| `__etext` ||||
| `__data_start__`, `__data_end__` ||||
| `__bss_start__`, `__bss_end__` ||||
| `.FlashConfig` @ 0x400 ||||




# Appendix 1: Terminology

| Term                  | Explanation                                                       |
|-----------------------|-------------------------------------------------------------------|
| bss                   | Block Starting Symbol (statically allocated, no value assigned)   |
| CM0+                  | Cortex-M0+                                                        |
| CMSIS                 | Common Microcontroller Software Interface Standard                |
| DAP                   | Debug Access Port, in DAPLink and CMSIS-DAP                       |
| ELF                   | Executable and Linkable Format                                    |
| GAS                   | GNU Assembler (assembler dialect)                                 |
| GDB                   | GNU Debugger                                                      |
| ISR                   | Interrupt Service Routine                                         |
| LR                    | Link Register                                                     |
| MCU                   | Micro-Controller Unit                                             |
| MSD                   | Mass Storage Device (USB device class)                            |
| MSP                   | Main Stack Pointer                                                |
| NVIC                  | Nested Vector Interrupt Controller                                |
| OCD                   | On-Chip Debugger                                                  |
| PC                    | Program Counter                                                   |
| SP                    | Stack Pointer                                                     |
| SDA                   | Serial Debug Adapter                                              |
| SDK                   | Software Development Kit                                          |
| SRAM                  | Static Random-Access Memory (volatile)                            |
| UAL                   | ARM syntax ~ ARM's Unified Assembler Language                     |


# Appendix 2: Linker reference - just enough syntax to write an ARM linker script

| Construct | Syntax Example | Meaning / Effect | Typical Use in KL25Z |
|------------|----------------|------------------|----------------------|
| MEMORY     | MEMORY { FLASH(rx): ORIGIN=0x0, LENGTH=128K; RAM(rwx): ORIGIN=0x20000000, LENGTH=16K; } | Declares memory regions with access flags. | Define physical memory map for Flash and SRAM. |
| SECTIONS   | SECTIONS { ... } | Defines how input sections from `.o` files map into output memory. | Core of the linker script — controls layout. |
| Assignment | `__StackTop = ORIGIN(RAM) + LENGTH(RAM);` | Defines or computes a symbol. | Creates special symbols read by startup code. |
| Location Counter | `.` (dot) | Represents current output address. Increments as bytes are placed. | Used to control layout and alignment. |
| Section Placement | `.text : { *(.text*) } > FLASH` | Places all `.text` input sections into FLASH region. | Ensures code is in nonvolatile memory. |
| Section with Load Address | `.data : AT(__etext) { *(.data*) } > RAM` | Copies `.data` section into RAM at runtime, loaded from FLASH. | Used for initialized globals. |
| NOLOAD     | `.bss (NOLOAD) : { *(.bss*) } > RAM` | Section exists in RAM but has no load image in FLASH. | Zero-initialized data, cleared by startup. |
| KEEP()     | `KEEP(*(.isr_vector))` | Prevents section from being garbage-collected by `--gc-sections`. | Protects vector table and Flash config. |
| ALIGN()    | `. = ALIGN(4)` | Rounds location counter up to next multiple of argument. | Ensure word alignment for vectors, data. |
| AT()       | `.data : AT(__etext)` | Sets load memory address (LMA) separately from execution address (VMA). | Used for RAM sections loaded from FLASH. |
| LOADADDR() | `__data_load__ = LOADADDR(.data);` | Returns the LMA of a section. | Used by startup to copy `.data` image. |
| PROVIDE()  | `PROVIDE(__heap_start__ = .);` | Defines a symbol only if not already defined elsewhere. | Safe defaults for weak symbols. |
| > REGION   | `.bss > RAM` | Directs output section to a named region from MEMORY. | Controls where code/data physically go. |
| ENTRY()    | ENTRY(Reset_Handler) | Declares program entry point (for ELF header). | Ensures correct PC value in vector table. |
| INCLUDE    | `INCLUDE board.ld` | Inserts another linker script file. | Compose SDK fragments or shared symbols. |


# Appendix 3: Assembler reference - just enough syntax to write a startup code file

Key points:
- For CM0+/ARMv6-M:
    - GAS + UAL textual language and notation, e.g. operand ordering (`.syntax unified`).
    - Thumb instructions, which are 16-bit wide total for opcode and operands (`.thumb`).
        - E.g. `MOVS Rd, #imm8` e.g. `MOVS r0 0x12`-> Opcode is 5 bits (00100), register is 3 bits (000), and 8 bits remaining for the immediate 0x12 (00010010). Must use a literal pool if larger.
    - Registers, ALU, data path are still 32 bits wide.
- Syntax points
    - Directives start with a dot. Instructions to assembler or linker, or section names.
    - Machine instructions look like ldr, str, blx, msr, b.
    - Pseudo-ops expand to real instructions or data. Examples: 
        - `.word`: `.word 0x12345678` -> little-endian literal bytes `0x78 0x56 0x34 0x12`.
        - `ldr dest, =symbol` - notice the constant is not encoded _inside_ the LDR instruction.
            - Small constant: Loads/moves the immediate if it fits. E.g. `ldr r0, =42` -> `movs r0, #42`
            - Large constant: Emits an instruction with a literal pool, if the symbol doesn't fit. E.g. `ldr r0, =0x20000000` -> `ldr r0, [pc, #offset]` + `.word 0x20000000` 
            
| Token | Type | Meaning | Why It’s Used in Startup | Notes |
|:------|:------|:---------|:--------------------------|:-------|
| .syntax unified | Directive | Use unified ARM/Thumb syntax | Standardizes operand format for ARMv6-M | Always the first line in Cortex-M assembly. |
| .arch armv6-m | Directive | Assemble for ARMv6-M instruction set | Ensures only Cortex-M0/M0+ instructions are accepted | Mandatory for KL25Z. |
| .cpu cortex-m0plus | Directive | Target CPU = Cortex-M0+ | Enables correct instruction subset | Thumb-only core. |
| .thumb | Directive | Assemble Thumb instructions | Cortex-M executes Thumb only | All code executes in Thumb state. |
| .section .FlashConfig, "a" | Directive | Create `.FlashConfig` section (alloc, read-only) | Stores Flash Configuration Field at 0x400 | Required for boot/unlock configuration. |
| .section .isr_vector, "a", %progbits | Directive | Place vector table in flash | Puts interrupt vectors at address 0x0 | Marked allocatable and read-only. |
| .align 2 | Directive | Align to 4-byte boundary | Ensures each vector entry is word-aligned | `.align 2` = 2² = 4 bytes. |
| .globl / .global | Directive | Export symbol to linker | Makes `__isr_vector`, `Reset_Handler` visible | Needed for linking. |
| .word / .long | Pseudo-op | Emit a 32-bit constant | Used to define vector entries & FCF words | Both accepted by GNU as. |
| .text | Directive | Switch to code section | Start of executable code | After vector table. |
| .thumb_func | Directive | Mark following label as Thumb function | Enables correct symbol metadata | Used before each handler. |
| .weak sym | Directive | Declare symbol as weak | Allows user to override default handlers | Used for all IRQ names. |
| .set A, B | Directive | Alias one symbol to another | Maps weak IRQs to `Default_Handler` | Compact alias pattern. |
| .type sym, %function | Directive | Mark symbol as a function | Improves debugging and symbol info | Used on `Reset_Handler`, `Default_Handler`. |
| .size sym, . - sym | Directive | Record function size | Keeps ELF symbol table clean | Used for handlers. |
| .pool | Directive | Flush literal pool | Ensures constants for `ldr =symbol` are emitted | Used once after `Reset_Handler`. |
| ldr rX, =symbol | Pseudo-op | Load address/immediate (literal pool) | Loads pointers to linker symbols (e.g. `__bss_start__`) | GAS expands this automatically. |
| ldr rX, [rY, #imm] / str rX, [rY, #imm] | Instruction | Load/store 32-bit word from memory | Copies `.data`, zeros `.bss`, writes VTOR | Core data-movement primitive. |
| msr msp, r0 | Instruction | Move register → Main Stack Pointer | Initializes MSP from vector[0] | Explicitly restores SP. |
| blx r0 | Instruction | Branch with link to address in register | Calls `SystemInit`, `__libc_init_array`, `main` | The “function call” mechanism. |
| b label | Instruction | Unconditional branch | Used in infinite loop (`hang:`) | CPU idles here if `main()` returns. |
| cmp rX, rY | Instruction | Compare registers (sets flags) | Loop control for `.data`/`.bss` copying | Used before conditional branches. |
| bcc / bcs / bgt / bge / ble / blt | Instruction | Conditional branches (unsigned/signed) | Drive copy and zero loops | Evaluate flags from `cmp`. |
| subs rX, rY, #imm | Instruction | Subtract with update flags | Used for loop index arithmetic | Reduces `r3` as counter. |
| movs rX, #imm | Instruction | Move immediate (low registers) | Initialize zero in `.bss` loop | M0+ restriction: low regs only. |
| cpsid i | Instruction | Disable interrupts | Ensures predictable startup | Mask IRQs until system is ready. |
| cpsie i | Instruction | Enable interrupts | Re-enable after init | Called just before jumping to C runtime. |


# Appendix 4: Symbol map - connecting linker, startup and runtime

| Symbol | Defined In | Used By | Purpose / Meaning |
|:--------|:------------|:--------|:------------------|
| `__isr_vector` | Startup `.S` (vector table label) | Linker (placed at `0x00000000`); also `VTOR` register | Start of interrupt vector table in Flash |
| `Reset_Handler` | Startup `.S` | Vector[1] entry; runtime entry point | First code executed after reset |
| `__StackTop` | Linker (`__StackTop = ORIGIN(RAM) + LENGTH(RAM)`) | Vector[0] in startup | Initial Main Stack Pointer (MSP) value |
| `__etext` | Linker (end of `.text` in Flash) | Startup | Load address for `.data` image in Flash |
| `__data_start__`, `__data_end__` | Linker (`.data` section) | Startup | SRAM range for initialized globals |
| `__data_load__` | Linker (`LOADADDR(.data)`) | Startup | Flash source address for `.data` copy |
| `__bss_start__`, `__bss_end__` | Linker (`.bss` section) | Startup | SRAM range to zero during init |
| `__HeapBase`, `__HeapLimit` | Linker (`PROVIDE` defaults) | `malloc`, `_sbrk()` | Defines heap boundaries for dynamic allocation |
| `__StackLimit` | Linker | Optional debug/overflow checks | Lower bound of stack area |
| `_sidata`, `_sdata`, `_edata`, `_sbss`, `_ebss` | Variant names (CMSIS style) | Startup (SDK-compatible) | Alternate naming convention for same regions |
| `_end` | Linker (after `.bss`) | `_sbrk()` syscall | Start of heap region |
| `SystemInit` | `system_MKL25Z4.c` (CMSIS system file) | Startup (`BLX SystemInit`) | Initializes clocks, watchdog, and VTOR |
| `__libc_init_array` | Newlib / C++ runtime | Startup | Runs C++ global/static constructors |
| `main` | User application | Startup | Application entry point |
| `_exit`, `_sbrk`, `_write`, `_read`, `_close`, `_lseek`, `_fstat`, `_isatty` | `syscalls.c` stubs | Newlib | Basic I/O and heap primitives required by libc |

# Other sources
https://nicopinkowski.wordpress.com/fundamentals/
https://github.com/npinkowski/tutorial_resources