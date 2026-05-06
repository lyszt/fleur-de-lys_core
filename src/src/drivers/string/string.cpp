#include "./string.h"

size_t strlen(const char* s) {
    const char* start = s;

    // align pointer to 8 bytes
    while ((uintptr_t)s & 7) {
        if (*s == '\0') return s - start;
        s++;
    }

    // scan 8 bytes at a time
    const uint64_t* p = (const uint64_t*)s;

    while (1) {
        uint64_t x = *p;

        // magic zero-byte detection
        if ((x - 0x0101010101010101ULL) & ~x & 0x8080808080808080ULL) {
            // find exact byte
            const char* c = (const char*)p;
            for (int i = 0; i < 8; i++) {
                if (c[i] == '\0') {
                    return (c + i) - start;
                }
            }
        }

        p++;
    }
}
