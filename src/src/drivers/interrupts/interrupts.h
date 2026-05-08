#pragma once

extern "C" {
    void trap_handler();
    void init_trap();
    unsigned long read_mcause();
    unsigned long read_mepc();
    void write_mtvec(unsigned long x);
}
