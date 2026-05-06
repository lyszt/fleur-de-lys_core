#include "drivers/uart/print/print.h"

extern "C" {
  void kernel_main();
}

void kernel_main() { 
  // QEMU Uart Chip  
  volatile char *uart = (volatile char *)0x10000000;
  const char* message =   "Fleur de Lys s'est fait initialisée.\n";

  printf(message);

  while(true) {
    asm volatile("wfi");
  }
}
