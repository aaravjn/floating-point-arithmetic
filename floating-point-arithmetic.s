.section .data

number1: .word 0x12345678       @ Please input the bigger number in number1 to avoid confusion
number2: .word 0x87654321
result: .byte 0, 0, 0, 0
extract_multiplication: .word 0x0007ffff, 0x0000007f, 0x7ff80000, 0x80000000
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
@ view the memory for final result

store:
    stmfd sp!, {r0, r2, r3, lr}
    
    @ Storing the final answer bytewise

    mov r0, #4
    ldr r2, =result
    add r2, r2, #3
    loop:
        and r3, r1, #0xff       @ Taking AND with 00000000000000000000000011111111 to extract the last byte
        strb r3, [r2], #-1      @ moving one memory location below
        lsr r1, #8
        subs r0, r0, #1
        bne loop
    strb r3, [r2]
    ldmfd sp!, {r0, r2, r3, pc}


multiply:
    stmfd sp!, {r0, r2-r9, lr}
    
    ldr r0, =number1
    ldr r2, [r0]
    ldr r0, =number2
    ldr r7, [r0]
    
    ldr r0, =extract_multiplication

    @ extract mantissa

    ldr r9, [r0], #4
    and r3, r9, r2          @ Take AND with 00000000000001111111111111111111 to extract mantissa
    and r4, r9, r7
    
    @ create significand bits

    mov r6, #1
    lsl r6, r6, #19     
    add r3, r3, r6      @ Adding with 000000000000010000000000000000000
    add r4, r4, r6
    umull r5, r1, r3, r4    @ Giving the output in 64 bits, r1 contains the MSB and r5, the LSB
    

    @ renormalization
    
    @ Only 2 cases are possible in multiplication, either the result is already normalized or it has an extra bit after decimal point
    @ If it has extra bit we need to remove the leading 1 and right shift the signficand by 1 and truncate the mantissa to 19 bits
    @ Otherwise simply truncate the significand to 19 bits
     

    ldr r9, [r0], #4     
    mov r8, #0          @ If the significand is greater than 0x0000007f, right shift by 1
    if: cmp r9, r1      
    bgt else            @ Only 2 cases possible, either to add exponent by 1, or keep it as it is
    add r8, r8, #1
    lsl r9, #1           
    else:
        lsr r9, #1      @ Take the first 6bit from LSB of the r1 register if there is no change in exponent, take first 7bits
        and r1, r1, r9
    
    lsl r1, #13      @ Add the combined significand to r1
    lsr r5, #19
    lsr r5, r8       @ This is done so that my mantissa remains within 8 bits
    lsr r1, r8
    add r1, r1, r5      @ Add the resultant mantissa to r1

    @ addition/substraction of the exponents

    ldr r9, [r0], #4    

    and r3, r2, r9      @ Extract the exponents by taking AND with 0x7ff80000
    and r4, r7, r9      
    
    lsl r8, #19
    add r3, r3, r8  @ add to the exponent because of renormalisation
    
    lsl r3, #1      @ The exponents will have a 0 bit as the MSB, thus we need to remove it
    lsl r4, #1      
    asr r3, #1      @ Extend the signbit in the exponents by 1
    asr r4, #1

    add r5, r3, r4      @ Add the exponents

    and r5, r5, r9      @ discard the first bit of the extended signbits
    add r1, r1, r5 

    @ XOR of the sign bits
    
    ldr r9, [r0], #4        @ Extract the sign bits after taking AND with 10000000000000000000000000000000
    and r3, r2, r9          
    and r4, r7, r9
    eor r5, r3, r4          @ XOR of signbits
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
    and r3, r2, r9      @ Taking AND with 01111111111110000000000000000000
    and r4, r7, r9
    
    cmp r3, r4          @ Comparing which exponent is bigger
    bgt cont

    mov r8, r2          @ Ensuring that the bigger number is always in r2, and the smaller in r7
    mov r2, r7
    mov r7, r8
    
    mov r8, r3
    mov r3, r4
    mov r4, r8
    
    cont:
        mov r1, #0      @ r1 will contain the final addition/substraction result      
    sub r8, r3, r4      @ Calculating how many bits to shift the smaller number
    lsr r8, #19
    add r1, r1, r3      @ storing the higher exponent in r1 which will be r3 always
    
    @ extract mantissa

    ldr r9, [r0], #4
    and r3, r2, r9      @ taking AND with 00000000000001111111111111111111    
    and r4, r7, r9
    mov r6, #1
    lsl r6, #19
    add r3, r3, r6      @ Adding 1 at the 20th bit to generate the significand from mantissa
    add r4, r4, r6
    
    lsr r4, r8      @ modifying mantissa of number with smaller exponent according to the bigger number

    @ extract signbits to change the signs of the mantissas
    
    ldr r9, [r0], #4  
    and r5, r2, r9      @ Taking AND with 10000000000000000000000000000000
    and r6, r7, r9


    @ taking 2's compliment of mantissa according to the sign bits
    
    mov r8, #-1
    cmp r5, #0
    beq skip_1
    mul r3, r3, r8      @ Taking 2's compliment by multiplying with -1
    
    skip_1:
        cmp r6, #0
    beq skip_2
    mul r4, r4, r8
    
    skip_2: 
        add r5, r3, r4
    
    @ checking whether r5 is negative, if so, making it unsinged by multiplying with -1
    
    and r4, r5, r9      @ r4 will contain the msb of r5 by taking it's AND with 10000000000000000000000000000000
    cmp r5, #0          @ checking if r5 is positive by comparing it with 0
    mov r6, #0          @ r6 contains the sign bit of my final number
    bgt skip3
    mul r5, r5, r8      @ r8 contains -1, multiply with r5 if it is negative
    mov r6, #1          

    @ renormalisation

    skip3:
        mov r3, #1
    lsl r3, #20
    mov r8, #1      @ Initiating r8 with 1, because this is the max right shift that we can do

    renom_loop:
        ands r4, r3, r5     @ Checking for the first 1 in the significand by taking AND with 00000000000010000000000000000000
        lsr r3, #1          @ Left shifting it to check succesive bits
        sub r8, r8, #1      @ r8 will contain the number of left/right shifts required to renormalize mantissa
        beq renom_loop
    
    lsl r3, #1
    add r8, r8, #1

    bic r5, r5, r3      @ clearing the first 1 in my significand

    @ modifying the exponent after renormalization
    
    lsl r8, #19     @ left shifting it to add with exponent in r8
    add r1, r1, r8
    ldr r9, [r0], #4
    and r1, r1, r9      @ The result can be negative, thus removing the sign bit by taking AND with 01111111111110000000000000000000

    cmp r8, #1          @ if r8 is positive right shift the significand by 1
    bmi left_shift_mantissa
    lsr r5, #1
    bl final
    
    left_shift_mantissa:    @ if r8 is negative, left shift the mantissa by r8 
        mov r9, #-1
        mul r8, r8, r9      @ As r8 will be negative, we need to multiply it by -1
        lsr r8, #19
        lsl r5, r8          

    final:
        add r1, r1, r5  @ adding mantissa to final answer

    lsl r6, #31         @ Shifting it by 31 bits to add to the answer
    add r1, r1, r6      @ adding the sign bit with r1: the final answer

    bl store
    ldmfd sp!, {r0, r2-r9, pc}

_start:
    bl addition