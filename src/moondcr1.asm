;#########
;# Setup #
;#########

[cpu 8086]
[bits 16]
%include "src/moondcr0.inc"
%include "gen/moondcr0.inc"
%ifndef ELF
   [org FILE_BASE]
%else
   times FILE_BASE nop
%endif

not byte [bp]

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

;###########
;# Filling #
;###########

moondcr1_end:
times 512-($-$$) nop