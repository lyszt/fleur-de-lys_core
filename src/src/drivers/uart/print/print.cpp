#include "./print.h"
#include "../../math/math.h"
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

void print_int(long num, int base){
  if(num == 0) {
    print_cstr("0");
    return;
  }

  char buf[65];
  unsigned long unum;

  if(base == 10 && num < 0) {
    print_str("-", 1, UART_BASE);
    unum = (unsigned long)(-(num + 1)) + 1;
  } else {
    unum = (unsigned long)num;
  }

  switch(base) {
    case 2: {
      int digits = 64 - __builtin_clzl(unum);
      buf[digits] = '\0';
      for(int i = digits - 1; i >= 0; i--) {
        buf[i] = '0' + (unum & 1);
        unum >>= 1;
      }
      print_cstr(buf);
      break;
    }
    case 16: {
      const char* hex = "0123456789abcdef";
      int digits = (64 - __builtin_clzl(unum) + 3) >> 2;
      buf[digits] = '\0';
      for(int i = digits - 1; i >= 0; i--) {
        buf[i] = hex[unum & 0xF];
        unum >>= 4;
      }
      print_cstr(buf);
      break;
    }
    case 10: {
      int digits = log10i(unum) + 1;
      buf[digits] = '\0';
      for(int i = digits - 1; i >= 0; i--) {
        buf[i] = '0' + (unum % 10);
        unum /= 10;
      }
      print_cstr(buf);
      break;
    }
    default: {
      const char* digits = "0123456789abcdef";
      int count = 0;
      unsigned long tmp = unum;
      do { tmp /= base; count++; } while (tmp > 0);
      buf[count] = '\0';
      for(int i = count - 1; i >= 0; i--) {
        buf[i] = digits[unum % base];
        unum /= base;
      }
      print_cstr(buf);
      break;
    }
  }
}

int printf(const char* format, ...) {
  volatile char* uart = UART_BASE;
  va_list args;
  va_start(args, format);

  while(*format) {
    if(*format != '%') {
      while (!(UART_STATUS & TX_READY));
      *uart = *format++;
      continue;
    }

    format++;

    switch(*format) {
      case 'c': {
        char c = (char)va_arg(args, int);
        while (!(UART_STATUS & TX_READY));
        *uart = c;
        break;
      }
      case 's': {
        const char* s = va_arg(args, const char*);
        print_cstr(s);
        break;
      }
      case 'd': {
        int n = va_arg(args, int);
        print_int(n, 10);
        break;
      }
      case 'x': {
        int n = va_arg(args, int);
        print_int(n, 16);
        break;
      }
      case 'o': {
        int n = va_arg(args, int);
        print_int(n, 8);
        break;
      }
      case 'b': {
        int n = va_arg(args, int);
        print_int(n, 2);
        break;
      }
      case '%': {
        while (!(UART_STATUS & TX_READY));
        *uart = '%';
        break;
      }
    }
    format++;
  }

  va_end(args);
  return 0;
}
