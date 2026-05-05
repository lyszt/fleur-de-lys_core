#include "./print.h"

// riscv uart address for virtual machine 
volatile char* uart = (volatile char*)0x10000000;

typedef __builtin_va_list va_list;
#define va_start(v, l) __builtin_va_start(v, l)
#define va_arg(v, l)   __builtin_va_arg(v, l)
#define va_end(v)      __builtin_va_end(v)


void print_str(char* str, long long int bytes, long long int uart_addr) {
  volatile char* uart_des = (volatile char*)uart_addr;
  char* end = str + bytes; 
  while(str < end) {
    *uart = *str++;
  }
}

