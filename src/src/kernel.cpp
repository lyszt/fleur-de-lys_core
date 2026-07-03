#include "drivers/uart/print/print.h"
#include "drivers/interrupts/interrupts.h"
#include "pmm/pmm.h"

extern "C" {
  void kernel_main();
}


void kernel_main() {
  // QEMU Uart Chip
  volatile char *uart = (volatile char *)0x10000000;
  init_trap();
  PMMinit();

  printf("Fleur de Lys s'est fait initialisée.\n");

  while(true) {
    asm volatile("wfi");
  }
}
