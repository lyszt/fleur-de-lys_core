#include "pmm.h"

FreeBlock* lists[MAX_ORDER] = {};
uint16_t free_map = 0;

void PMMinit() {
  uintptr_t start = ((uintptr_t)&_end + PAGE_SIZE - 1) 
  & ~(PAGE_SIZE- 1);
  while((uintptr_t)start < 0x88000000) {
    FreeBlock* block = (FreeBlock*)start;
    block->next = lists[0];
    lists[0] = block;
    start += PAGE_SIZE;
  }
}

void* alloc(int order){
  FreeBlock* head;
  int og_order = order; 

  uint16_t search_mask = free_map & ~((1 << og_order) - 1);
  if(search_mask == 0) return nullptr;

  order = __builtin_ctz(search_mask);
  head = lists[order];
  lists[order] = head->next;

  if (!lists[order]) {
      free_map &= ~(1 << order);
  }

  while(order != og_order) {
    order -= 1;
    size_t half_size = 1 << order;
    FreeBlock* right_buddy = (FreeBlock*)((char*)head + half_size);
    right_buddy->next = lists[order];
    lists[order] = right_buddy;
    
    free_map |= (1 << order);
  }
  return head;
}

void free(void *ptr, int order) {
  FreeBlock* block = (FreeBlock*)ptr;
  block->next = lists[order];
  lists[order] = block;
}
