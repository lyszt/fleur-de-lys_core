#include "./math.h"

int log2i(unsigned long long n) {
    return 63 - __builtin_clzll(n);
}

static const unsigned long long pow10_table[] = {
    1ULL,
    10ULL,
    100ULL,
    1000ULL,
    10000ULL,
    100000ULL,
    1000000ULL,
    10000000ULL,
    100000000ULL,
    1000000000ULL,
    10000000000ULL,
    100000000000ULL,
    1000000000000ULL,
    10000000000000ULL,
    100000000000000ULL,
    1000000000000000ULL,
    10000000000000000ULL,
    100000000000000000ULL,
    1000000000000000000ULL,
    10000000000000000000ULL,
};

static const int log2_to_log10[] = {
    0,  0,  0,  0,  1,  1,  1,  2,  2,  2,
    3,  3,  3,  3,  4,  4,  4,  5,  5,  5,
    6,  6,  6,  6,  7,  7,  7,  8,  8,  8,
    9,  9,  9,  9, 10, 10, 10, 11, 11, 11,
    12, 12, 12, 12, 13, 13, 13, 14, 14, 14,
    15, 15, 15, 15, 16, 16, 16, 17, 17, 17,
    18, 18, 18, 18
};

int log10i(unsigned long long n) {
    int approx = log2_to_log10[log2i(n)];
    return approx + (n >= pow10_table[approx + 1] ? 1 : 0);
}
