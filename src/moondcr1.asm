;#########
;# Setup #
;#########

[cpu 8086]
[bits 16]
%include "src/macro.inc"
%include "src/moondcr0.inc"
%include "gen/moondcr0.inc"
%ifdef DEBUG_ELF
   times FILE_BASE nop
   MANUAL_OFFSET equ FILE_BASE
%else
   [org FILE_BASE]
   MANUAL_OFFSET equ 0
%endif
%ifndef FLAT_BINARY
   %error "moondcr1.asm must be built with FLAT_BINARY"
%endif

%ifdef ENABLE_MBR
not byte [bp]
%else
not bp
%endif

;####################
;# Greeting message #
;####################

mov si, string_moondcr
call print
jmp infinite_loop

;####################
;# String functions #
;####################

; Prints message
; Footprint: ax, bx, si
; print(const char *message)
; print(si)
print:
   lodsb
   or al, al
   jz print_exit
   mov ah, 0x0E
   xor bx, bx
   int 0x10
   jmp print

   print_exit:
   ret

;#################
;# Text messages #
;#################

string_moondcr db 13, 10, 'Moondancer stage 1 loaded', 13, 10, 0