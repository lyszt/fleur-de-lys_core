#include "pmm.h"

FreeBlock* lists[MAX_ORDER] = {};

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
  while(!lists[order]) {
    order += 1;
    if (order == MAX_ORDER + 1) return nullptr;
  }

  head = lists[order];
  lists[order] = head->next;

  while(order != og_order) {
    order -= 1;
    size_t half_size = 1 << order;
    // Push the right buddy onto the free list of the current order
    FreeBlock* right_buddy = (FreeBlock*)((char*)head + half_size);
    right_buddy->next = lists[order];
    lists[order] = right_buddy;
  }
  return head;
}

void free(void *ptr, int order) {
  FreeBlock block = (FreeBlock*)ptr;
  block->next = lists[order];
  lists[order] = block;
}
