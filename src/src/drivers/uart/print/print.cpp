#include "./print.h"
#include "../../string/string.h"

#define UART_BASE    ((volatile char*)0x10000000)
#define UART_STATUS  (*(UART_BASE + 5))
#define TX_READY     (1 << 5)

typedef __builtin_va_list va_list;
#define va_start(v, l) __builtin_va_start(v, l)
#define va_arg(v, l)   __builtin_va_arg(v, l)
#define va_end(v)      __builtin_va_end(v)


void print_str(const char* str, size_t bytes, volatile char* uart_addr) {
  const char* end = str + bytes;
  while (str < end) {
    while (!(UART_STATUS & TX_READY));
    *uart_addr = *str++;
  }
}

void print_cstr(const char* str) {
  print_str(str, strlen(str), UART_BASE);
}
