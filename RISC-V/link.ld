OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 16K
}

SECTIONS
{
    /* Ibex starts execution at boot_addr_i + 0x80. */
    .text ORIGIN(RAM) + 0x80 : {
        KEEP(*(.text.entry))
        *(.text*)
        *(.rodata*)
        *(.srodata*)
    } > RAM

    .data : {
        PROVIDE(__global_pointer$ = . + 0x800);
        *(.data*)
        *(.sdata*)
    } > RAM

    .bss (NOLOAD) : {
        . = ALIGN(4);
        __bss_start = .;
        *(.bss*)
        *(.sbss*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > RAM

    _stack_top = ORIGIN(RAM) + LENGTH(RAM);
    ASSERT(__bss_end < _stack_top - 1024, "Firmware leaves too little stack space")
}
