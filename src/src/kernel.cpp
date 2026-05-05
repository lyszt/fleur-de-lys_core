extern "C" {
  void kernel_main();
}

void kernel_main() { 
  // QEMU Uart Chip  
  volatile char *uart = (volatile char *)0x10000000;
  const char* message =   "Fleur de Lys s'est fait initialisée.";

  for (int i = 0; message[i] != '\0'; i++) {
    *uart = message[i];
  }
}
