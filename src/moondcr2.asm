;#########
;# Setup #
;#########

[cpu 8086]
[bits 16]
%include "src/common.inc"
%ifdef DEBUG_ELF
   times STAGE2_BASE nop
   MANUAL_OFFSET equ STAGE2_BASE
%else
   [org STAGE2_BASE]
   MANUAL_OFFSET equ 0
%endif
%ifndef FLAT_BINARY
   %error "moondcr2.asm must be built with FLAT_BINARY"
%endif

;####################
;# Greeting message #
;####################

jmp 0:start
start:
xor bx, bx
mov ds, bx
cld

mov si, string_moondcr
print_loop:
   lodsb
   or al, al
   jz infinite_loop
   mov ah, 0x0E
   int 0x10
   jmp print_loop

infinite_loop:
   hlt
   jmp infinite_loop

;#################
;# Text messages #
;#################

string_moondcr db 13, 10, 'Moondancer stage 2 loaded', 13, 10, 0