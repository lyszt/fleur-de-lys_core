#pragma once

#include "../../types/types.h"

extern "C" {
    void print_char(char c);
    void print_str(const char* str, size_t bytes, volatile char* uart_addr);
    void print_cstr(const char* str);
    void print_int(long num, int base);
    int printf(const char* format, ...);
}
