.data
    # --- DỮ LIỆU CẦN CĂN CHỈNH (WORD-ALIGNED) ---
    .align 2  # BẮT BUỘC: Đảm bảo phần data bắt đầu được căn chỉnh 4-byte

    # Mảng và Bộ đệm
    buf_size:     .word 32768
    buffer:       .space 32768
    NUM_SAMPLES:  .word 10
    desired:      .space 40
    input:        .space 40
    crosscorr:    .space 40
    autocorr:     .space 40
    R:            .space 400
    coeff:        .space 40
    ouput:        .space 40   # Tên biến 'ouput' của bạn
    str_buf:      .space 32
    temp_str:     .space 32

    # Hằng số Float
    mmse:         .float 0.0
    zero_f:       .float 0.0
    one_f:        .float 1.0
    ten:          .float 10.0
    hundred:      .float 100.0
    half:         .float 0.5
    minus_half:   .float -0.5
    zero:         .float 0.0
    zero_thresh:  .float 0.05   # Ngưỡng làm tròn về 0 (từ logic C++)
    rounding_val: .float 0.05   # Giá trị để làm tròn 1 chữ số (từ logic C++)

    # --- CHUỖI KÝ TỰ (KHÔNG CẦN CĂN CHỈNH) ---
    # Đặt tất cả .asciiz ở cuối
    input_file:   .asciiz "input.txt"
    desired_file: .asciiz "desired.txt"
    output_file:  .asciiz "output.txt"
    header_filtered: .asciiz "Filtered output: "
    header_mmse:  .asciiz "\nMMSE: "
    space_str:    .asciiz " "
    error_open:   .asciiz "Error: Can not open file"
    error_size:   .asciiz "Error: size not match"
.text
.globl main

main:
    # --- Open and read input file for input[] ---
    # TODO
la   $a0, input_file
    la   $a1, input
    lw   $a2, NUM_SAMPLES
    jal  read_file_to_array
    move $s4, $v0   
    
    la   $a0, desired_file
    la   $a1, desired
    lw   $a2, NUM_SAMPLES
    jal  read_file_to_array
     move $s5, $v0 
     
     # --- size check ---
    lw   $t0, NUM_SAMPLES
    bne  $s4, $t0, size_error
    bne  $s5, $t0, size_error
     j    compute_all 
  size_error:
    # mở output.txt để ghi
    la   $a0, output_file
    li   $a1, 1          # write-only
    li   $a2, 0
    li   $v0, 13
    syscall
    move $s0, $v0        # fd

    # ghi đúng chuỗi "Error: size not match" (21 ký tự)
    li   $v0, 15
    move $a0, $s0
    la   $a1, error_size     # đã có sẵn trong .data
    li   $a2, 21             # chiều dài chính xác
    syscall
	
    li   $v0, 4              # Syscall 4: Print String
    la   $a0, error_size     # Load địa chỉ chuỗi lỗi
    syscall
    # đóng file và thoát
    li   $v0, 16
    move $a0, $s0
    syscall
    li   $v0, 10
    syscall
compute_all:
    # --- compute crosscorrelation ---
    la   $a0, input
    la   $a1, desired
    la   $a2, crosscorr
    lw   $a3, NUM_SAMPLES
    jal  computeCrosscorrelation

    # --- compute autocorrelation ---
    # TODO
    la   $a0, input
    la   $a1, autocorr
    lw   $a2, NUM_SAMPLES
    jal  computeAutocorrelation
    # --- create Toeplitz matrix ---
    # TODO
    la   $a0, autocorr
    la   $a1, R
    lw   $a2, NUM_SAMPLES
    jal  createToeplitzMatrix
    # --- solveLinearSystem ---
    # TODO
    la $a0, R
    la $a1, crosscorr
    la $a2, coeff
    lw $a3, NUM_SAMPLES
    jal solveLinearSystem
    # --- applyWienerFilter ---
    # TODO
    la $a0, input
    la $a1, coeff
    la $a2, ouput
    lw $a3, NUM_SAMPLES
    jal applyWienerFilter
    # --- compute MMSE ---
    # TODO
  subi $sp, $sp, 4
    la   $t0, mmse
    sw   $t0, 0($sp)

    la   $a0, desired      # d[]
    la   $a1, ouput        # y[] (output sau Wiener filter)
    lw   $a2, NUM_SAMPLES  # N

    jal  computeMMSE

    addi $sp, $sp, 4
    # --- Open output file ---
    # TODO
 la   $a0, output_file   # filename
    li   $a1, 1             # flags = write only
    li   $a2, 0
    li   $v0, 13            # syscall: open
    syscall
    move $s0, $v0 
    # --- Write "Filtered output: " ---
    # 1. Ghi ra Terminal
    li   $v0, 15
    move $a0, $s0
    la   $a1, header_filtered
    li   $a2, 17
    syscall
    # ==== PRINT TO TERMINAL ====
    li   $v0, 4
    la   $a0, header_filtered
    syscall

    # --- Write filtered outputs with 1 decimal ---
    lw   $s2, NUM_SAMPLES   # N = 10 (Sử dụng $s2)
    li   $s1, 0             # i = 0 (Sử dụng $s1)

write_outputs_loop:
    beq  $s1, $s2, done_write_outputs # ($s1 == $s2 ?)

    # load ouput[i] vào $f12
    la   $t2, ouput
    sll  $t3, $s1, 2          # $t3 = i * 4
    add  $t2, $t2, $t3
    l.s  $f12, 0($t2)

    # đổi float -> string, 1 chữ số thập phân
    la   $a0, str_buf
    li   $a1, 1             # decimals = 1
    jal  float_to_str
    move $t5, $v0           # length

    # ghi số ra file
    li   $v0, 15
    move $a0, $s0
    la   $a1, str_buf
    move $a2, $t5
    syscall
    # ==== PRINT output[i] TO TERMINAL ====
    mov.s $f12, $f12        # already loaded earlier
    jal  write_float_to_console

    # In dấu cách
    li   $a0, ' '
    li   $v0, 11           # print_char
    syscall

    # tăng i
    addi $s1, $s1, 1          # i++

    # nếu còn phần tử thì ghi một dấu cách
    slt  $t4, $s1, $s2        # i < N ?
    beq  $t4, $zero, write_outputs_loop

    li   $v0, 15
    move $a0, $s0
    la   $a1, space_str
    li   $a2, 1
    syscall

    j    write_outputs_loop

done_write_outputs:

    # --- Write "\nMMSE: " ---
    li   $v0, 15
    move $a0, $s0
    la   $a1, header_mmse
    li   $a2, 7             # "\nMMSE: "
    syscall
    # ==== PRINT "\nMMSE: " TO TERMINAL ====
    li   $v0, 4
    la   $a0, header_mmse
    syscall

    
    # --- Write MMSE with 2 decimals ---
    # 1. đọc MMSE
    l.s  $f12, mmse
    # 2. làm tròn lên 1 chữ số thập phân: 0.2510 -> 0.3
    jal  round_to_1dec        # f0 = rounded 1-dec
    mov.s $f12, $f0
    # 3. in với 1 chữ số thập phân (sẽ ra "0.3")
    la   $a0, str_buf
    li   $a1, 1             # decimals = 1 (0.3)
    jal  float_to_str
    move $t5, $v0

    li   $v0, 15
    move $a0, $s0
    la   $a1, str_buf
    move $a2, $t5
    syscall
    # ==== PRINT MMSE TO TERMINAL ====
    mov.s $f12, $f12   # MMSE has already been rounded
    jal write_float_to_console


    # --- Close output file ---
    li   $v0, 16
    move $a0, $s0
    syscall

    li   $v0, 10
    syscall
 #---------------------------------------------------------
# round_to_1dec($f12) -> $f0
# ---------------------------------------------------------
round_to_1dec:
    # f3 = f12 * 10
    # ... (code giữ nguyên)
    l.s    $f1, ten         # 10.0
    mul.s  $f3, $f12, $f1
    l.s    $f2, zero_f
    c.lt.s $f3, $f2
    bc1f   r1_pos
    l.s    $f4, half
    sub.s  $f3, $f3, $f4
    j      r1_after
r1_pos:
    l.s    $f4, half
    add.s  $f3, $f3, $f4
r1_after:
    trunc.w.s $f3, $f3
    mfc1  $t0, $f3
    mtc1  $t0, $f4
    cvt.s.w $f4, $f4
    div.s $f0, $f4, $f1
    jr    $ra


# ---------------------------------------------------------
# float_to_str(buffer $a0, value $f12, decimals $a1) -> length $v0
# ---------------------------------------------------------
float_to_str:
    # $a0 = buffer, $a1 = decimals, $f12 = value
    move $t0, $a0           # current write ptr
    li   $v0, 0             # length = 0

    # --- xử lý dấu ---
    l.s   $f0, zero_f
    c.lt.s $f12, $f0
    bc1f  ft_pos            # nếu không âm

    # số âm: ghi '-', rồi lấy trị tuyệt đối
    li   $t1, 45            # '-'
    sb   $t1, 0($t0)
    addi $t0, $t0, 1
    addi $v0, $v0, 1
    neg.s $f12, $f12

ft_pos:
    # --- phân nhánh theo số chữ số thập phân ---
    li   $t1, 1
    beq  $a1, $t1, ft_dec1
    li   $t1, 2
    beq  $a1, $t1, ft_dec2
    j    ft_dec0            # mặc định = 0

# decimals = 1
ft_dec1:
    l.s   $f2, ten
    mul.s $f4, $f12, $f2
    l.s   $f6, half
    add.s $f4, $f4, $f6
    trunc.w.s $f4, $f4
    mfc1 $t2, $f4           # N
    li   $t5, 10
    div  $t2, $t5
    mflo $t3                # intPart
    mfhi $t4                # frac1
    j    ft_after_scale

# decimals = 2
ft_dec2:
    l.s   $f2, hundred
    mul.s $f4, $f12, $f2
    l.s   $f6, half
    add.s $f4, $f4, $f6
    trunc.w.s $f4, $f4
    mfc1 $t2, $f4           # N
    li   $t5, 100
    div  $t2, $t5
    mflo $t3                # intPart
    mfhi $t6                # rem
    li   $t5, 10
    div  $t6, $t5
    mflo $t4                # frac1
    mfhi $t7                # frac2
    j    ft_after_scale

# decimals = 0: 
ft_dec0:
    l.s   $f2, half
    add.s $f4, $f12, $f2
    trunc.w.s $f4, $f4
    mfc1 $t3, $f4           # intPart
    move $a1, $zero         # decimals = 0
    j    ft_after_scale

ft_after_scale:
    # intPart nằm trong $t3
    # nếu decimals=1: frac1=$t4
    # nếu decimals=2: frac1=$t4, frac2=$t7

    # --- BẮT ĐẦU ĐOẠN CODE SỬA (Chuẩn hóa 0.0) ---
    bne  $t3, $zero, ft_skip_zero_fix  # if intPart != 0, không phải 0.0 -> bỏ qua
    li   $t1, 1
    beq  $a1, $t1, ft_check_zero_fix_dec1
    li   $t1, 2
    beq  $a1, $t1, ft_check_zero_fix_dec2
    j    ft_is_zero_fix
ft_check_zero_fix_dec1:
    bne  $t4, $zero, ft_skip_zero_fix  # if frac1 != 0, không phải 0.0 -> bỏ qua
    j    ft_is_zero_fix
ft_check_zero_fix_dec2:
    bne  $t4, $zero, ft_skip_zero_fix  # if frac1 != 0, không phải 0.0 -> bỏ qua
    bne  $t7, $zero, ft_skip_zero_fix  # if frac2 != 0, không phải 0.0 -> bỏ qua
ft_is_zero_fix:
    sub  $t5, $t0, $a0
    beq  $t5, $zero, ft_skip_zero_fix  # t0 == a0 (chưa in dấu), tốt -> bỏ qua
    move $t0, $a0                     # t0 != a0 (đã lỡ in dấu), reset...
    li   $v0, 0                       # ...reset độ dài
ft_skip_zero_fix:
    # --- KẾT THÚC ĐOẠN CODE SỬA ---

    # --- convert intPart -> chuỗi (dùng temp_str ngược) ---
    la   $t8, temp_str
    move $t9, $t3
    li   $t6, 0             # digit count
    bne  $t9, $zero, ft_int_loop
    li   $t1, '0'
    sb   $t1, 0($t8)
    addi $t8, $t8, 1
    li   $t6, 1
    j    ft_int_done
ft_int_loop:
    beq  $t9, $zero, ft_int_done
    li   $t1, 10
    div  $t9, $t1
    mflo $t9
    mfhi $t2
    addi $t2, $t2, 48       # '0' + digit
    sb   $t2, 0($t8)
    addi $t8, $t8, 1
    addi $t6, $t6, 1
    j    ft_int_loop
ft_int_done:
    la   $t1, temp_str
    add  $t1, $t1, $t6      # trỏ sau cùng
    move $t2, $zero         # i = 0
ft_copy_int_loop:
    beq  $t2, $t6, ft_int_copied
    addi $t1, $t1, -1
    lb   $t3, 0($t1)
    sb   $t3, 0($t0)
    addi $t0, $t0, 1
    addi $v0, $v0, 1
    addi $t2, $t2, 1
    j    ft_copy_int_loop
ft_int_copied:
    beq  $a1, $zero, ft_return
    li   $t1, '.'
    sb   $t1, 0($t0)
    addi $t0, $t0, 1
    addi $v0, $v0, 1
    li   $t1, 1
    beq  $a1, $t1, ft_frac1
    j    ft_frac2
ft_frac1:
    addi $t4, $t4, 48       # '0' + frac1
    sb   $t4, 0($t0)
    addi $t0, $t0, 1
    addi $v0, $v0, 1
    j    ft_return
ft_frac2:
    addi $t4, $t4, 48
    sb   $t4, 0($t0)
    addi $t0, $t0, 1
    addi $v0, $v0, 1
    addi $t7, $t7, 48
    sb   $t7, 0($t0)
    addi $t0, $t0, 1
    addi $v0, $v0, 1
    j    ft_return
ft_return:
    jr   $ra
# ---------------------------------------------------------
# computeAutocorrelation(input[], autocorr[], N)
# ---------------------------------------------------------
computeAutocorrelation:
    addi $t0, $zero, 0
autocorr_loop_k:
    beq  $t0, $a2, autocorr_done

    mtc1 $zero, $f0
    addi $t1, $zero, 0
autocorr_loop_n:
    sub  $t2, $a2, $t0
    beq  $t1, $t2, store_autocorr

    sll  $t3, $t1, 2
    add  $t3, $a0, $t3
    l.s  $f1, 0($t3)          # x[n]

    add  $t4, $t1, $t0
    sll  $t4, $t4, 2
    add  $t4, $a0, $t4
    l.s  $f2, 0($t4)          # x[n+k]

    mul.s $f3, $f1, $f2
    add.s $f0, $f0, $f3

    addi $t1, $t1, 1
    j    autocorr_loop_n

store_autocorr:
    move   $t6, $a2
    mtc1   $t6, $f4
    cvt.s.w $f4, $f4
    div.s  $f0, $f0, $f4

    sll  $t5, $t0, 2
    add  $t5, $a1, $t5
    s.s  $f0, 0($t5)

    addi $t0, $t0, 1
    j    autocorr_loop_k
autocorr_done:
    jr   $ra



# ---------------------------------------------------------
# computeCrosscorrelation(desired[], input[], crosscorr[], N)
# ---------------------------------------------------------
computeCrosscorrelation:
    addi $t0, $zero, 0
cross_loop_k:
    beq  $t0, $a3, cross_done

    mtc1 $zero, $f0
    addi $t1, $zero, 0
cross_loop_n:
    sub  $t2, $a3, $t0
    beq  $t1, $t2, store_cross

    sll  $t3, $t1, 2
    add  $t3, $a0, $t3
    l.s  $f1, 0($t3)          # x[n]

    add  $t4, $t1, $t0
    sll  $t4, $t4, 2
    add  $t4, $a1, $t4
    l.s  $f2, 0($t4)          # d[n+k]

    mul.s $f3, $f1, $f2
    add.s $f0, $f0, $f3

    addi $t1, $t1, 1
    j    cross_loop_n

store_cross:
    move  $t6, $a3
    mtc1  $t6, $f4
    cvt.s.w $f4, $f4
    div.s $f0, $f0, $f4

    sll  $t5, $t0, 2
    add  $t5, $a2, $t5
    s.s  $f0, 0($t5)

    addi $t0, $t0, 1
    j    cross_loop_k
cross_done:
    jr   $ra

# ---------------------------------------------------------
# createToeplitzMatrix(autocorr[], R[][], N)
# ---------------------------------------------------------
createToeplitzMatrix:
    addi $t0, $zero, 0          # i
toep_i:
    beq  $t0, $a2, toep_done
    addi $t1, $zero, 0          # j
toep_j:
    beq  $t1, $a2, toep_next_i

    sub  $t2, $t0, $t1          # |i-j|
    bltz $t2, toep_abs
    j    toep_abs_done
toep_abs:
    sub  $t2, $zero, $t2
toep_abs_done:
    sll  $t3, $t2, 2
    add  $t3, $a0, $t3
    l.s  $f1, 0($t3)            # autocorr[|i-j|]

    mul  $t4, $t0, $a2          # i*N + j
    add  $t4, $t4, $t1
    sll  $t4, $t4, 2
    add  $t4, $a1, $t4
    s.s  $f1, 0($t4)            # R[i][j]

    addi $t1, $t1, 1
    j    toep_j
toep_next_i:
    addi $t0, $t0, 1
    j    toep_i
toep_done:
    jr   $ra



# ---------------------------------------------------------
# solveLinearSystem(A[][], b[], x[], N)
# ---------------------------------------------------------
solveLinearSystem:
    # Forward elimination
    addi $t0, $zero, 0              # k = 0
sls_outer_k:
    beq  $t0, $a3, sls_forward_done

    # pivot = A[k][k]
    mul  $t5, $t0, $a3
    add  $t5, $t5, $t0
    sll  $t5, $t5, 2
    add  $t6, $a0, $t5
    l.s  $f20, 0($t6)

    # i = k+1..N-1
    addi $t1, $t0, 1
sls_outer_i:
    bge  $t1, $a3, sls_next_k

    mul  $t7, $t1, $a3
    add  $t7, $t7, $t0
    sll  $t7, $t7, 2
    add  $t8, $a0, $t7
    l.s  $f22, 0($t8)              # A[i][k]
    div.s $f21, $f22, $f20         # factor

    # j = k..N-1
    move $t2, $t0
sls_inner_j:
    bge  $t2, $a3, sls_elim_b

    # A[k][j]
    mul  $t3, $t0, $a3
    add  $t3, $t3, $t2
    sll  $t3, $t3, 2
    add  $t4, $a0, $t3
    l.s  $f10, 0($t4)

    # A[i][j]
    mul  $t5, $t1, $a3
    add  $t5, $t5, $t2
    sll  $t5, $t5, 2
    add  $t6, $a0, $t5
    l.s  $f11, 0($t6)

    mul.s $f12, $f21, $f10
    sub.s $f11, $f11, $f12
    s.s  $f11, 0($t6)

    addi $t2, $t2, 1
    j    sls_inner_j

# b[i] -= factor * b[k]
sls_elim_b:
    sll  $t3, $t0, 2
    add  $t3, $a1, $t3
    l.s  $f13, 0($t3)

    sll  $t4, $t1, 2
    add  $t4, $a1, $t4
    l.s  $f14, 0($t4)

    mul.s $f15, $f21, $f13
    sub.s $f14, $f14, $f15
    s.s  $f14, 0($t4)

    addi $t1, $t1, 1
    j    sls_outer_i

sls_next_k:
    addi $t0, $t0, 1
    j    sls_outer_k

sls_forward_done:
    # Back substitution
    add  $t0, $a3, $zero
    addi $t0, $t0, -1              # i = N-1
sls_back_i:
    bltz $t0, sls_done

    sll  $t1, $t0, 2
    add  $t1, $a1, $t1
    l.s  $f16, 0($t1)              # sum = b[i]

    addi $t2, $t0, 1
sls_back_j:
    bge  $t2, $a3, sls_back_div

    mul  $t3, $t0, $a3
    add  $t3, $t3, $t2
    sll  $t3, $t3, 2
    add  $t4, $a0, $t3
    l.s  $f17, 0($t4)              # A[i][j]

    sll  $t5, $t2, 2
    add  $t5, $a2, $t5
    l.s  $f18, 0($t5)              # x[j]

    mul.s $f19, $f17, $f18
    sub.s $f16, $f16, $f19

    addi $t2, $t2, 1
    j    sls_back_j

sls_back_div:
    mul  $t6, $t0, $a3
    add  $t6, $t6, $t0
    sll  $t6, $t6, 2
    add  $t7, $a0, $t6
    l.s  $f23, 0($t7)
    div.s $f24, $f16, $f23

    sll  $t8, $t0, 2
    add  $t8, $a2, $t8
    s.s  $f24, 0($t8)

    addi $t0, $t0, -1
    j    sls_back_i

sls_done:
    jr $ra


# ---------------------------------------------------------
# applyWienerFilter(input[], coefficients[], output[], N)
# ---------------------------------------------------------
applyWienerFilter:
    addi $t0, $zero, 0          # n = 0
awf_loop_n:
    beq  $t0, $a3, awf_done

    mtc1 $zero, $f0             # sum = 0.0
    addi $t1, $zero, 0          # k = 0
awf_loop_k:
    beq  $t1, $a3, awf_store

    sub  $t2, $t0, $t1          # idx = n-k
    bltz $t2, awf_next_k

    sll  $t3, $t1, 2
    add  $t3, $a1, $t3
    l.s  $f1, 0($t3)            # h[k]

    sll  $t4, $t2, 2
    add  $t4, $a0, $t4
    l.s  $f2, 0($t4)            # x[n-k]

    mul.s $f3, $f1, $f2
    add.s $f0, $f0, $f3

awf_next_k:
    addi $t1, $t1, 1
    j    awf_loop_k

awf_store:
    sll  $t5, $t0, 2
    add  $t5, $a2, $t5
    s.s  $f0, 0($t5)

    addi $t0, $t0, 1
    j    awf_loop_n
awf_done:
    jr $ra
# ---------------------------------------------------------
# computeMMSE(desired[], output[], N) -> $f0
# ---------------------------------------------------------
computeMMSE:
      # Lấy địa chỉ biến mmse từ stack
    lw   $t4, 0($sp)          # t4 = &mmse

    # sum = 0.0
    mtc1 $zero, $f10
    li   $t0, 0               # i = 0

mmse_loop:
    beq  $t0, $a2, mmse_done

    sll  $t1, $t0, 2
    add  $t2, $a0, $t1        # &desired[i]
    add  $t3, $a1, $t1        # &output[i]

    l.s  $f1, 0($t2)          # d[i]
    l.s  $f2, 0($t3)          # y[i]

    sub.s $f3, $f1, $f2       # d[i] - y[i]
    mul.s $f4, $f3, $f3       # (d[i] - y[i])^2

    add.s $f10, $f10, $f4     # sum += ...
    addi $t0, $t0, 1
    j    mmse_loop

mmse_done:
    # mmse = sum / N
    mtc1 $a2, $f5
    cvt.s.w $f5, $f5
    div.s $f10, $f10, $f5

    s.s  $f10, 0($t4)         # lưu vào biến mmse
    jr   $ra
# ---------------------------------------------------------
# read_file_to_array(char* filename, float* array, int num_samples)
# Đọc file text chứa các số float và lưu vào mảng.
# ---------------------------------------------------------
read_file_to_array:
    addi $sp, $sp, -20
    sw   $ra, 0($sp)
    sw   $s0, 4($sp) # filename
    sw   $s1, 8($sp) # array pointer
    sw   $s2, 12($sp)# num samples
    sw   $s3, 16($sp)# file descriptor

    move $s0, $a0
    move $s1, $a1
    move $s2, $a2

    # 1. Mở file (Open)
    li   $v0, 13
    move $a0, $s0
    li   $a1, 0          # Read only
    li   $a2, 0
    syscall
    move $s3, $v0        # Lưu fd
    bltz $s3, rfta_error # Nếu lỗi mở file

    # 2. Đọc toàn bộ file vào 'buffer'
    li   $v0, 14
    move $a0, $s3
    la   $a1, buffer
    lw   $a2, buf_size
    syscall
    # $v0 bây giờ chứa số byte thực tế đã đọc

    # Thêm ký tự kết thúc chuỗi null vào cuối buffer để chắc chắn
    la   $t0, buffer
    add  $t0, $t0, $v0
    sb   $zero, 0($t0)

    # 3. Đóng file
    li   $v0, 16
    move $a0, $s3
    syscall

    # 4. Parse buffer thành các số float
    la   $a0, buffer     # input string
    move $a1, $s1        # output array
    move $a2, $s2        # num samples
    jal  parse_floats_from_string

    j    rfta_done

rfta_error:
    li   $v0, 4
    la   $a0, error_open
    syscall
    li   $v0, 4
    la   $a0, header_mmse # Dùng tạm xuống dòng
    syscall
li   $v0, 10
    syscall
rfta_done:
    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    lw   $s1, 8($sp)
    lw   $s2, 12($sp)
    lw   $s3, 16($sp)
    addi $sp, $sp, 20
    jr   $ra

# ---------------------------------------------------------
# parse_floats_from_string(char* buf, float* arr, int N)
# Hàm phụ để tách các số từ chuỗi buffer
# ---------------------------------------------------------
parse_floats_from_string:
    move $t0, $a0        # $t0 = con trỏ hiện tại trong buffer
    move $t1, $a1        # $t1 = con trỏ hiện tại trong mảng float
    li   $t2, 0          # $t2 = đếm số phần tử đã parse (k)

pffs_loop:
    beq  $t2, $a2, pffs_done # Đã đọc đủ N số

    # Bỏ qua khoảng trắng, xuống dòng, tab...
skip_whitespace:
    lb   $t3, 0($t0)
    beq  $t3, $zero, pffs_done # Hết chuỗi
    li   $t4, 32         # Space
    beq  $t3, $t4, pffs_next_char
    li   $t4, 10         # \n
    beq  $t3, $t4, pffs_next_char
    li   $t4, 13         # \r
    beq  $t3, $t4, pffs_next_char
    li   $t4, 9          # \t
    beq  $t3, $t4, pffs_next_char
    j    parse_one_float # Tìm thấy ký tự đầu tiên của số

pffs_next_char:
    addi $t0, $t0, 1
    j    skip_whitespace

parse_one_float:
    # Ở đây ta cần parse 1 số float bắt đầu từ $t0
    # Để đơn giản, ta giả định định dạng là [-]D.D hoặc [-]D
    mtc1 $zero, $f0      # Kết quả float = 0.0
    li   $t5, 1          # Sign = 1 (dương)
    lb   $t3, 0($t0)

    # Kiểm tra dấu âm
    li   $t4, 45         # '-'
    bne  $t3, $t4, parse_int_part
    li   $t5, -1         # Sign = -1 (âm)
    addi $t0, $t0, 1     # Bỏ qua dấu '-'

parse_int_part:
    mtc1 $zero, $f1      # Phần nguyên = 0.0
    l.s  $f10, ten       # Hằng số 10.0

int_loop:
    lb   $t3, 0($t0)
    li   $t6, 48         # '0'
    blt  $t3, $t6, check_dot_or_end
    li   $t6, 57         # '9'
    bgt  $t3, $t6, check_dot_or_end

    # Là chữ số (0-9)
    subi $t3, $t3, 48    # Convert ASCII to int val
    mtc1 $t3, $f2
    cvt.s.w $f2, $f2     # $f2 = digit (float)

    mul.s $f1, $f1, $f10 # int_part = int_part * 10
    add.s $f1, $f1, $f2  # int_part = int_part + digit

    addi $t0, $t0, 1
    j    int_loop

check_dot_or_end:
    li   $t6, 46         # '.'
    beq  $t3, $t6, parse_frac_part
    j    finish_float    # Không có phần thập phân

parse_frac_part:
    addi $t0, $t0, 1     # Bỏ qua dấu '.'
    l.s  $f3, one_f      # Divisor = 1.0

frac_loop:
    lb   $t3, 0($t0)
    li   $t6, 48         # '0'
    blt  $t3, $t6, finish_float
    li   $t6, 57         # '9'
    bgt  $t3, $t6, finish_float

    # Là chữ số phần thập phân
    subi $t3, $t3, 48
    mtc1 $t3, $f2
    cvt.s.w $f2, $f2     # $f2 = digit

    mul.s $f3, $f3, $f10 # divisor = divisor * 10
    div.s $f2, $f2, $f3  # digit_val = digit / divisor
    add.s $f1, $f1, $f2  # int_part += digit_val

    addi $t0, $t0, 1
    j    frac_loop

finish_float:
    # Áp dụng dấu
    mtc1 $t5, $f4
    cvt.s.w $f4, $f4     # $f4 = 1.0 hoặc -1.0
    mul.s $f0, $f1, $f4  # Final value

    # Lưu vào mảng
    s.s  $f0, 0($t1)
    addi $t1, $t1, 4     # Tăng con trỏ mảng
    addi $t2, $t2, 1     # Tăng biến đếm k
    j    pffs_loop

pffs_done:
move $v0, $t2 
    jr   $ra

# ---------------------------------------------------------
# write_float_to_file(int fd, float val)
# Ghi 1 số float vào file (ĐÃ CẬP NHẬT LOGIC GIỐNG C++)
# Input: $a0 = file descriptor, $f12 = float value to write
# ---------------------------------------------------------
write_float_to_file:
    addi $sp, $sp, -12
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)
    sw   $a0, 8($sp)

    move $s0, $a0            # fd
    # -------- zero threshold --------
    l.s   $f1, zero_thresh
    abs.s $f10, $f12
    c.lt.s $f10, $f1         # if |val| < thresh
    bc1f  wftf_not_zero
    mtc1  $zero, $f12        # val = 0.0
    j     wftf_check_sign

wftf_not_zero:
    # -------- rounding +/-0.05 --------
    mtc1  $zero, $f0
    l.s   $f1, rounding_val
    c.lt.s $f12, $f0         # val < 0 ?
    bc1t  wftf_round_neg
wftf_round_pos:
    add.s $f12, $f12, $f1
    j     wftf_check_sign
wftf_round_neg:
    sub.s $f12, $f12, $f1

wftf_check_sign:
    # -------- sign --------
    mtc1 $zero, $f0
    c.lt.s $f12, $f0
    bc1f wftf_positive

    li   $t0, 45             # '-'
    sb   $t0, temp_str
    move $a0, $s0
    la   $a1, temp_str
    li   $a2, 1
    li   $v0, 15
    syscall

    neg.s $f12, $f12

wftf_positive:
    # -------- integer part --------
    trunc.w.s $f0, $f12
    mfc1 $t1, $f0            # int part
    cvt.s.w $f1, $f0         # float(int)

    move $a0, $s0
    move $a1, $t1
    jal  write_int_to_file

    # -------- '.' --------
    li   $t0, 46             # '.'
    sb   $t0, temp_str
    move $a0, $s0
    la   $a1, temp_str
    li   $a2, 1
    li   $v0, 15
    syscall

    # -------- one decimal digit --------
    sub.s $f2, $f12, $f1     # frac
    l.s   $f10, ten
    mul.s $f2, $f2, $f10     # *10
    trunc.w.s $f2, $f2
    mfc1  $t2, $f2
    abs   $t2, $t2

    move $a0, $s0
    move $a1, $t2
    jal  write_int_to_file

wftf_done:
    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    lw   $a0, 8($sp)
    addi $sp, $sp, 12
    jr   $ra

# ---------------------------------------------------------
# write_int_to_file(int fd, int val)
# Hàm phụ: Ghi một số nguyên dương vào file
# ---------------------------------------------------------
write_int_to_file:
    # Chuyển int thành chuỗi trong temp_str, rồi ghi
    # Giả sử val >= 0 (vì đã xử lý dấu ở trên rồi)
    move $t0, $a1        # Value to convert
    la   $t1, temp_str
    add  $t2, $t1, 16    # Bắt đầu từ cuối buffer (temp_str có 32 byte)
    sb   $zero, 0($t2)   # Null terminator (dù sys 15 không cần, nhưng tốt cho debug)

    # Trường hợp số 0 đặc biệt
    bnez $t0, witf_loop
    subi $t2, $t2, 1
    li   $t3, 48         # '0'
    sb   $t3, 0($t2)
    j    witf_write

witf_loop:
    beqz $t0, witf_write
    rem  $t3, $t0, 10    # Lấy chữ số cuối
    div  $t0, $t0, 10    # Bỏ chữ số cuối
    addi $t3, $t3, 48    # Convert to ASCII
    subi $t2, $t2, 1     # Lùi con trỏ buffer
    sb   $t3, 0($t2)     # Lưu ký tự
    j    witf_loop

witf_write:
    # $t2 đang trỏ đến ký tự đầu tiên của chuỗi số
    move $a0, $a0        # fd (đã có sẵn trong $a0 khi gọi hàm này)
    move $a1, $t2        # buffer bắt đầu từ $t2
    la   $t3, temp_str
    add  $t3, $t3, 16
    sub  $a2, $t3, $t2   # Độ dài = end_ptr - start_ptr
    li   $v0, 15
    syscall

    jr   $ra
write_float_to_console:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)
    
    # -------- zero threshold --------
    l.s   $f1, zero_thresh
    abs.s $f10, $f12
    c.lt.s $f10, $f1         # if |val| < thresh
    bc1f  wftc_not_zero
    mtc1  $zero, $f12        # val = 0.0
    j     wftc_check_sign

wftc_not_zero:
    # -------- rounding +/-0.05 --------
    mtc1  $zero, $f0
    l.s   $f1, rounding_val
    c.lt.s $f12, $f0         # val < 0 ?
    bc1t  wftc_round_neg
wftc_round_pos:
    add.s $f12, $f12, $f1
    j     wftc_check_sign
wftc_round_neg:
    sub.s $f12, $f12, $f1

wftc_check_sign:
    # -------- sign --------
    mtc1 $zero, $f0
    c.lt.s $f12, $f0
    bc1f wftc_positive

    li   $a0, 45             # '-'
    li   $v0, 11             # syscall 11: print_char
    syscall
    neg.s $f12, $f12

wftc_positive:
    # -------- integer part --------
    trunc.w.s $f0, $f12
    mfc1 $a0, $f0            # $a0 = int part
    li   $v0, 1              # syscall 1: print_int
    syscall
    cvt.s.w $f1, $f0         # float(int)

    # -------- '.' --------
    li   $a0, 46             # '.'
    li   $v0, 11             # syscall 11: print_char
    syscall

    # -------- one decimal digit --------
    sub.s $f2, $f12, $f1     # frac
    l.s   $f10, ten
    mul.s $f2, $f2, $f10     # *10
    trunc.w.s $f2, $f2
    mfc1  $a0, $f2
    abs   $a0, $a0
    li    $v0, 1             # syscall 1: print_int
    syscall

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra
