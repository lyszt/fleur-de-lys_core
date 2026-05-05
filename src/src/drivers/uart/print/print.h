#pragma once

extern "C" {
    void print_char(char c);
    void print_str(const char* s);
    void print_int(long num, int base);

    void printf(const char* format, ...);
}
