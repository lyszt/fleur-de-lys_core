#include "pmm.h"

FreeBlock* lists[MAX_ORDER] = {};
uint16_t free_map = 0;

// One free-bit per block per order, packed flat. Order k starts at word
// 1024 - (1024 >> k) and uses 512 >> k words (128 MB / 4 KB = 32768 order-0
// bits). The bit makes "is my buddy free" an O(1) test instead of a list walk.
static uint64_t free_bits[1023];

static uint64_t* bit_word(uintptr_t addr, int order) {
  return &free_bits[(1024 - (1024 >> order))
    + (((addr - RAM_BASE) >> (PAGE_SHIFT + order)) >> 6)];
}

static uint64_t bit_mask(uintptr_t addr, int order) {
  return 1ull << (((addr - RAM_BASE) >> (PAGE_SHIFT + order)) & 63);
}

static void list_push(uintptr_t addr, int order) {
  FreeBlock* block = (FreeBlock*)addr;
  block->prev = nullptr;
  block->next = lists[order];
  if (lists[order]) lists[order]->prev = block;
  lists[order] = block;
  free_map |= 1 << order;
  *bit_word(addr, order) |= bit_mask(addr, order);
}

static void list_remove(FreeBlock* block, int order) {
  if (block->prev) block->prev->next = block->next;
  else lists[order] = block->next;
  if (block->next) block->next->prev = block->prev;
  if (!lists[order]) free_map &= ~(1 << order);
  *bit_word((uintptr_t)block, order) &= ~bit_mask((uintptr_t)block, order);
}

void PMMinit() {
  // Boot by freeing the universe: hand every page to free() and let its
  // coalescing telescope them into max-order blocks, like a binary counter
  // carrying upward. Amortized O(n) over all pages.
  for (uintptr_t page = ((uintptr_t)&_end + PAGE_SIZE - 1)
      & ~(uintptr_t)(PAGE_SIZE - 1);
      page < RAM_END; page += PAGE_SIZE) {
    free((void*)page, 0);
  }
}

void* alloc(int order) {
  uint16_t search_mask = free_map & ~((1 << order) - 1);
  if (search_mask == 0) return nullptr;

  int found = __builtin_ctz(search_mask);
  FreeBlock* head = lists[found];
  list_remove(head, found);

  while (found != order) {
    found -= 1;
    list_push((uintptr_t)head + ((uintptr_t)PAGE_SIZE << found), found);
  }
  return head;
}

void free(void *ptr, int order) {
  uintptr_t addr = (uintptr_t)ptr;
  while (order < MAX_ORDER - 1) {
    uintptr_t buddy = RAM_BASE
      + ((addr - RAM_BASE) ^ ((uintptr_t)PAGE_SIZE << order));
    if (!(*bit_word(buddy, order) & bit_mask(buddy, order))) break;
    list_remove((FreeBlock*)buddy, order);
    if (buddy < addr) addr = buddy;
    order += 1;
  }
  list_push(addr, order);
}
