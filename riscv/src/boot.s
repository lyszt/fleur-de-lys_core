.section .text
.global _start

_start:
    la sp, stack_top
    call kernel_main

    # Operating systems are not supposed to "finish" or return. 
    # If kernel_main somehow ends, we trap the CPU in an infinite loop here
    # so it doesn't start executing random garbage memory.
.hang:
    j .hang

.section .bss
.align 4
stack_bottom:
    .skip 16384 # Reserve 16 KiB of memory
stack_top:
