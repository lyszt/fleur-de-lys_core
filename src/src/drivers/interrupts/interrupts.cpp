#include "../../interrupts/interrupts.h"
#include "../../uart/print/print.h"

__attribute__((interrupt("machine")))
void trap_handler() {
  unsigned long cause = read_mcause();
  unsigned long epc = read_mepc();

  printf("MCAUSE : 0x%x\n", cause);
  printf("MEPC   : 0x%x\n", epc);
  printf("System Halted.\n");

  while (true) {
    asm volatile("wfi");
  }
}

unsigned long read_mcause(){
  unsigned long x;
  asm volatile("csrr %0, mcause" : "=r" (x));
  return x;
}

unsigned long read_mepc() {
  unsigned long x;
  asm volatile("csrr %0, mepc" : "=r" (x));
  return x;
}

void write_mtvec(unsigned long x) {
        asm volatile("csrw mtvec, %0" : : "r" (x));
}

void init_trap() {
        write_mtvec((unsigned long)trap_handler);
}
