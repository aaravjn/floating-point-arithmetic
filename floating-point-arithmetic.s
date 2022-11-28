.section .data

number1: .word 0x00220000
number2: .word 0x00240000
result: .byte 0, 0, 0, 0
extract_multiplication: .word 0x0007ffff, 0x0000007f, 0x0000003f, 0x7ff80000, 0x80000000
extract_addition: .word 0x7ff80000, 0x0007ffff ,0x80000000, 0x7ff80000

.section .text
.global _start


@ r1 will contain the result of arithmetic operation of two numbers
@ r0 will contain the address of numbers
@ r2 will contain number1
@ r7 will contain number2
@ r3 will always contain parts of number1
@ r4 will always contain parts of number2
@ r5 will contain the partial result of the arithmetic on both r3 and r4
@ r9 will contain the number for extract


@ method of rounding-off: Truncation
store:
    stmfd sp!, {r0, r2, r3, lr}
    
    mov r0, #4
    mov r2, r1
    ldr r1, =result
    add r1, r1, #3
    loop:
        and r3, r2, #0xff
        strb r3, [r1], #-1
        lsr r2, #8
        subs r0, r0, #1
        bne loop
    strb r3, [r1]
    ldmfd sp!, {r0, r2, r3, pc}


multiply:
    stmfd sp!, {r0, r2-r9, lr}
    
    ldr r0, =number1
    ldr r2, [r0]
    ldr r0, =number2
    ldr r7, [r0]
    
    ldr r0, =extract_multiplication

    @ multiply mantissa

    ldr r9, [r0], #4
    and r3, r9, r2
    and r4, r9, r7

    mov r6, #1
    lsl r6, r6, #19
    add r3, r3, r6
    add r4, r4, r6
    umull r5, r1, r3, r4

    ldr r9, [r0], #4
    mov r8, #0
    if: cmp r9, r1
    bgt else
    add r8, r8, #1
    else:
        ldr r9, [r0], #4

    and r1, r1, r9
    lsl r1, #13
    lsr r5, #19
    lsr r5, r8
    lsr r1, r8
    add r1, r1, r5

    @ addition/substraction of the exponents

    ldr r9, [r0], #4

    and r3, r2, r9
    and r4, r7, r9
    
    lsl r8, #19
    add r3, r3, r8  @ add the exponent because of renormalisation

    lsl r3, #1
    lsl r4, #1
    lsr r3, #20
    lsr r4, #20

    add r5, r3, r4

    lsl r5, #19
    and r5, r5, r9 @ for overflow purposes and to discard the last bit of the extended sign
    add r1, r1, r5 

    @ XOR of the sign bits
    
    ldr r9, [r0], #4
    
    and r3, r2, r9 
    and r4, r7, r9
    eor r5, r3, r4
    add r1, r1, r5
    
    bl store
    ldmfd sp!, {r0, r2-r9, pc}

addition:
    stmfd sp!, {r0, r2-r9, lr}
    
    @ Load the numbers from memory

    ldr r0, =number1
    ldr r2, [r0]
    ldr r0, =number2
    ldr r7, [r0]

    ldr r0, =extract_addition

    @ extract the exponents

    ldr r9, [r0], #4
    and r3, r2, r9
    and r4, r7, r9
    
    cmp r3, r4
    bgt cont

    mov r8, r2
    mov r2, r7
    mov r7, r8
    
    mov r8, r3
    mov r3, r4
    mov r4, r8
    
    cont:
        mov r1, #0
    sub r8, r3, r4
    lsr r8, #19
    add r1, r1, r3
    
    @ extract mantissa

    ldr r9, [r0], #4
    and r3, r2, r9
    and r4, r7, r9
    mov r6, #1
    lsl r6, #19
    add r3, r3, r6
    add r4, r4, r6
    
    lsr r4, r8

    @ extract signbits to change the signs of the mantissas
    
    ldr r9, [r0], #4
    and r5, r2, r9
    and r6, r7, r9


    @ taking 2's compliment of mantissa according to the sign bits
    
    mov r8, #-1
    cmp r5, #0
    beq skip1
    mul r3, r3, r8
    skip1:
        cmp r6, #0
    beq skip2
    mul r4, r4, r8
    
    skip2: 
        add r5, r3, r4
    
    @ checking whether r5 is negative, if so, making it unsinged
    
    and r4, r5, r9
    add r1, r1, r4
    cmp r5, #0
    mov r6, #0
    bgt skip3
    mul r5, r5, r8
    mov r6, #1

    @ renormalisation

    skip3:
        mov r3, #1
    lsl r3, #20
    mov r8, #1
    
    renom_loop:
        ands r4, r3, r5
        lsr r3, #1
        sub r8, r8, #1
        beq renom_loop
    
    lsl r3, #1
    add r8, r8, #1

    bic r5, r5, r3

    @ modifying the exponent after renormalization
    
    lsl r8, #19
    add r1, r1, r8
    ldr r9, [r0], #4
    and r1, r1, r9

    cmp r8, #1
    bmi skip4
    lsr r5, #1

    skip4:
        @ adding mantissa to final answer
        add r1, r1, r5
        lsl r6, #31
        add r1, r1, r6
    
    bl store
    ldmfd sp!, {r0, r2-r9, pc}

_start:
    bl addition