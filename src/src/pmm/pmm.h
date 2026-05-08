#pragma once

#include <stdint.h>
#include <stddef.h>

extern char _end;

constexpr int PAGE_SIZE = 4096;
constexpr int MAX_ORDER = 10;

struct FreeBlock {
    FreeBlock *next;
};

void PMMinit();
