ENTRY(_start)

SECTIONS
{
  /* The QEMU virt machine's RAM starts at this physical address */
  . = 0x80000000;

  .text : ALIGN(4K)
  {
    *(.text)  
  }
  /* read only data */
  .rodata : ALIGN(4K)
  {
    (*.rodata)
  }

  .data : ALIGN(4K)
    {
        *(.data)
    }

    /* Uninitialized variables and the stack */
    .bss : ALIGN(4K)
    {
        *(COMMON)
        *(.bss)
    }
}
