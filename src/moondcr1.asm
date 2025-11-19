;################
;# Specify mode #
;################

[bits 16]

;#####################################
;# Setup segment registers and stack #
;#####################################

[org 0x0800]
jmp 0x07C0:start
start:
mov ax, cs
mov ds, ax
mov es, ax
mov ss, ax
xor sp, sp
cld

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