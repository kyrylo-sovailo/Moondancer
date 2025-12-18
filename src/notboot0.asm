;#########
;# Setup #
;#########

[cpu 8086]
[bits 16]
%include "src/macro.inc"
%ifdef DEBUG_ELF
   times 0x07C0 nop
   MANUAL_OFFSET equ FILE_BASE
%else
   [org 0x07C0]
   MANUAL_OFFSET equ 0
%endif
%ifdef FLAT_BINARY
   %error "notboot0.asm cannot be assembled with FLAT_BINARY"
%endif
%ifdef MBR_BINARY
   ; Do nothing
%endif
%ifdef FAT32_BINARY
   jmp fat32_start
   times 3-($-$$-MANUAL_OFFSET) nop
   times 87 nop
   fat32_start:
%endif

;####################
;# Greeting message #
;####################

jmp 0x0000:start
start:
xor bx, bx
mov ds, bx
cld

mov si, string_notboot
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

%ifdef MBR_BINARY
   string_notboot db 'notboot0.bin booted correctly, but carries no payload', 13, 10, 0
%endif
%ifdef FAT32_BINARY
   string_notboot db 'notbootf.bin booted correctly, but carries no payload', 13, 10, 0
%endif

;###########
;# Filling #
;###########

noboot_end:
%ifdef MBR_BINARY
   times 440-($-$$-MANUAL_OFFSET) nop  ; Fill code with nop
   db 'MDCR'                           ; Unique ID
   db 0, 0                             ; Signature
   times 510-440-6 db 0                ; Partition table
   db 0x55, 0xAA                       ; Boot signature
%endif
%ifdef FAT32_BINARY
   times 510-($-$$-MANUAL_OFFSET) nop  ; Fill code with nop
   db 0x55, 0xAA                       ; Boot signature
%endif