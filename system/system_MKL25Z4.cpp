/**
 * KL25Z clock-tree setup
 * 
 * Implements SysInit(), which is called by Reset_Handler.
 * 
 * Reference Manual:
 * - Section 3.4.10: Computer Operating Properly (COP) Watchdog configuration
 * - Section 3.5: Clock modules
 * - Section 24: Multipurpose Clock Generator (MCG).
 * - Section 25: Oscillator (OSC)
 * - Section 12.2.8-12: System Integration Module (SIM), System Clock...
 * 
 * Steps in this file
 * - Disable watchdog (WDOG_STCTRLH, WDOG_UNLOCK sequence)
 * - Select FLL or PLL clock source in MCG (Multipurpose Clock Generator)
 * - Set system dividers in SIM_CLKDIV1
 * - Possibly configure oscillator range / external crystal if needed
 * - Update the SystemCoreClock global variable (used by CMSIS)
 * 
 * Janus, October 2025.
 */

 extern "C" void SystemInit(void) {
    return;
 }