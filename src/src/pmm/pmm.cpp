#include "pmm.h"

FreeBlock* lists[MAX_ORDER] = {};

void PMMinit() {
  volatile char* end = &_end;

  uintptr_t start = ((uintptr_t)&_end + PAGE_SIZE - 1) & ~(PAGE_SIZE- 1);
  while((uintptr_t)start < 0x88000000) {
    FreeBlock* block = (FreeBlock*)end;
    block->next = lists[0];
    lists[0] = block;
    end += PAGE_SIZE;
  }
}

void* alloc(int order){
  FreeBlock* head = lists[order];
  if (!head) return nullptr;
  lists[order] = head->next;
  return head;
}

void free() {

}
