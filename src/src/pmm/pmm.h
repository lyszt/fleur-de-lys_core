#pragma once

#include <stdint.h>
#include <stddef.h>

extern char _end;

constexpr uintptr_t RAM_BASE = 0x80000000;
constexpr uintptr_t RAM_END  = 0x88000000;
constexpr int PAGE_SIZE  = 4096;
constexpr int PAGE_SHIFT = 12;
constexpr int MAX_ORDER  = 10;

struct FreeBlock {
    FreeBlock *next;
    FreeBlock *prev;
};

void PMMinit();
void* alloc(int order);
void free(void *ptr, int order);
