.section .text.entry
.global _start

_start:
    /* Khởi tạo Stack Pointer ở đỉnh RAM 16KB (0x00004000) */
    lui  sp, %hi(_stack_top)
    addi sp, sp, %lo(_stack_top)

    /* GCC có thể truy cập .sdata/.sbss qua gp. */
    .option push
    .option norelax
    la   gp, __global_pointer$
    .option pop

    /* RAM không tự xóa khi reset mềm: khởi tạo .bss mỗi lần boot. */
    la   t0, __bss_start
    la   t1, __bss_end
1:
    bgeu t0, t1, 2f
    sw   zero, 0(t0)
    addi t0, t0, 4
    j    1b
2:
    
    /* Gọi hàm main */
    call main

/* Vòng lặp vô hạn phòng khi main() kết thúc */
3:  j    3b
