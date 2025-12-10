;#########
;# Notes #
;#########

; On memory organization:
%include "src/moondcr0.inc"

;#########
;# Setup #
;#########

[cpu 8086]
[bits 16]
[org CODE_BASE]

;####################
;# Greeting message #
;####################
mov si, string_moondcr
call print
infinite_loop:
jmp infinite_loop

;####################
;# String functions #
;####################

; Prints message
; Footprint: ax, bx, si
; print(const char *message)
; print(si)
print:
   cld
   print_loop:
      lodsb
      or al, al
      jz print_loop_exit
      mov ah, 0x0E
      xor bx, bx
      int 0x10
      jmp print_loop

      print_loop_exit:
      ret

;#################
;# Text messages #
;#################

string_moondcr db 'Moondancer stage 1 loaded', 13, 10, 0

;###########
;# Filling #
;###########

moondcr1_end:
times 512-($-$$) nop