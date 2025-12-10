;#########
;# Notes #
;#########

; On optimization:
; ch is zero everywhere, at no point the program multiplies by numbers larger than 256 or does more than 256 repetitions

; On BIOS assumptions:
; int 0x13, ah 0x42: affects ah, assumed change flags
; int 0x10, dl 0x0E: assumed change flags

; On print format:
; Uppercase on success, lowercase on error
; A - check active partition
; R - read disk
; F - check FAT32 signature
; M - check if the file is MOONDCR1.BIN
; C - check if next cluster is valid

;#########
;# Setup #
;#########

[cpu 8086]
[bits 16]
%include "src/moondcr0.inc"
%ifndef ELF
   [org CODE_BASE]
%else
   times CODE_BASE nop
%endif

jmp MOONDCR0_SEGMENT:start
start:
xor cx, cx
mov ds, cx
mov es, cx  ; Needed for cmps and few mov's
mov ss, cx
mov sp, DATA_BASE+DATA_SIZE
push dx     ; Save dx at [DATA_BASE+DATA_SIZE-2]
cld

;###################
;# Read MBR sector #
;###################

xor ax, ax
xor dx, dx
mov si, MBR_BASE
inc cl                  ; mov cx, 1 (optimized)
call read_sectors       ; Must re-read the first sector in order to be loadable by GRUB chainloader

;#########################
;# Find active partition #
;#########################

mov bp, MBR_BASE+446-16 ; 446 = first partition's attribute (minus 16 because added by add)
active_partition_loop:
   add bp, 16
   mov al, [bp]
   not al
   test al, 0x80
   stc
   mov al, 'A'
   call print_success_failure
   jz active_partition_loop_success
   cmp bp, MBR_BASE+446+3*16
   jb active_partition_loop

infinite_loop:
   hlt
   jmp infinite_loop

active_partition_loop_success:

;#####################
;# Read FAT32 header #
;#####################

mov ax, [bp+8]          ; 8   = active partition's starting sector, low
mov dx, [bp+8+2]        ; 8+2 = active partition's starting sector, high
mov si, BPB_BASE
                        ; mov cx, 1 (optimized)
call read_sectors

mov di, string_fat32
mov si, BPB_BASE+82     ; 82 = address of the "FAT32   " signature
mov cl, 8               ; mov cx, 8 (optimized)
repe cmpsb
clc
mov al, 'F'
call print_success_failure

;###################
;# Read FAT32 file #
;###################

; Loop1: Iterate over cluster chains
mov si, BPB_BASE+44
lodsw                         ; 44   = root cluster, low
mov dx, [si]                  ; 44+2 = root cluster, high (minus 2 because added by lodsw)
read_file_loop:
   xor cx, cx
   mov bx, 0x0FFF
   and dx, bx
   push dx ;stack 1
   push ax ;stack 2
   cmp dx, bx
   jb read_file_loop_bypass_low_check
      cmp ax, 0xFFF7
   read_file_loop_bypass_low_check:
   cmc                        ; CF = !CF = !below
   adc cl, 0                  ; ZF = !CF = below, CF = 0
   push ax ;stack 3
   mov al, 'C'
   call print_success_failure
   pop ax ;stack 3
   
   ; dx:ax = file_ct-2
   sub ax, 2
   sbb dx, 0

   ; dx:ax = (file_ct-2) * cluster_size_lsc
                              ; xor ch, ch (optimized)
   mov cl, [BPB_BASE+13]      ; 13 = cluster size in logical sectors
   mov di, cx
   call multiply
   push dx ;stack 3
   push ax ;stack 4

   ; dx:ax = ex_fat_size_lsc * fat_number
   mov si, BPB_BASE+36
   lodsw                      ; 36   = extended FAT size, low
   mov dx, [si]               ; 36+2 = extended FAT size, high (minus 2 because added by lodsw)
                              ; xor ch, ch (optimized)
   mov cl, [si-22]            ; 16 = number of FAT tables, -22 = 16-(36+2)
   call multiply

   ; dx:ax = ex_fat_size_lsc * fat_number + (file_ct - 2) * cluster_size_lsc
   pop bx ;stack 4
   pop cx ;stack 3
   add ax, bx
   adc dx, cx

   ; dx:ax = begin_lba_sc + logical_sector_size_sc * (reserved_size_lsc + ex_fat_size_lsc * fat_number + (root_ct - 2) * cluster_size_lsc)
   call add_multiply_add

   ; Loop 2: Iterate over physical sectors in cluster to read (doing it here because cx is set by add_multiply_add)
   ; ax = logical_sector_size_sc * cluster_size_lsc (both numbers are guaranteed to be less than 256)
   xchg ax, di                ; cluster size to ax, low sector number to di
   mul cl                     ; cx is left over add_multiply_add
   mov cx, ax
   mov ax, di                 ; low sector number to ax
   read_file_segment_loop:
      ; Read sector dx:ax
      push dx ;stack 3
      push ax ;stack 4
      push cx ;stack 5
      mov si, FILE_BASE
      mov cl, 1               ; mov cx, 1 (optimized)
      call read_sectors

      ; Check if read target file
      test byte [bp], 0x80
      jz FILE_BASE            ; Leap of faith

      ; Loop 3: Iterate over FAT records in a physical sector
      mov dx, FILE_BASE+0     ; 0 = file name (minus 32 because added by add)
      read_file_list_loop:
         mov si, dx
         mov di, string_moondcr
         mov cl, 12           ; mov cx, 12 (optimized)
         repe cmpsb
         stc
         mov al, 'M'
         call print_success_failure
         jz read_file_list_loop_success
         add dx, 32
         cmp dh, (FILE_BASE+512) >> 8
         jb read_file_list_loop

      ; moondcr1.bin not found, go to next physical sector
      pop cx ;stack 5
      pop ax ;stack 4
      pop dx ;stack 3
      inc ax
      adc dx, 0
      loop read_file_segment_loop

   ; moondcr1.bin not found and ran out of physical sectors in cluster, go to next cluster
   ; di:si = (file_ct * sizeof(uint32_t)) / 512, bx = (file_ct * sizeof(uint32_t)) % 512
   ; 0000DDDD DDDDDDDD : AAAAAAAA AAAAAAAA -> 00000000 000DDDDD : DDDDDDDA AAAAAAAA, 0000000A AAAAAA00
   pop si ;stack 2
   pop di ;stack 1
   mov bx, si
   shl bx, 1
   xor bh, bh
   shl bx, 1
   mov cl, 7                  ; mov cx, 7 (optimized)
   read_file_loop_advance_cluster_loop:
      shr di, 1
      rcr si, 1
      loop read_file_loop_advance_cluster_loop
   push bx ;stack 1
   
   ; dx:ax = begin_lba_sc + logical_sector_size_sc * (reserved_size_lsc + 0)
   xor dx, dx
   xor ax, ax
   call add_multiply_add
   
   ; dx:ax = begin_lba_sc + logical_sector_size_sc * (reserved_size_lsc + 0) + ((file_ct * sizeof(uint32_t)) / 512)
   add ax, si
   adc dx, di
   
   ; Read sector dx:ax
   mov si, FILE_BASE
   mov cl, 1                  ; mov cx, 1 (optimized)
   call read_sectors

   ; dx:ax = file_ct
   pop bx ;stack 1
   add bx, FILE_BASE
   mov ax, [bx]
   mov dx, [bx+2]
   jmp read_file_loop

; moondcr1.bin found, go to next cluster
; This piece of code does not belong to any indentation level, it is on its own
read_file_list_loop_success:
add sp, 10 ;stack 5, stack 4, stack 3, stack 2, stack 1
not byte [bp]
mov ax, [si-12+26]      ; 26 = address of file cluster, low (minus 12 because si = dx + 12 if repe cmpsb succeeds)
mov dx, [si-12+20]      ; 20 = address of file cluster, high (minus 12 because si = dx + 12 if repe cmpsb succeeds)
jmp read_file_loop

;###################
;# Disk operations #
;###################

; Reads count sectors starting with sector start_sc_high:start_sc_low and places them to destination
; Footprint: ax, bx, dl, si
; read_sectors(uint16_t start_sc_high, uint16_t start_sc_low, void *destination, uint16_t count)
; read_sectors(dx, ax, si, cx)
read_sectors:
   ; Start (8 bytes)
   xor bx, bx
   push bx
   push bx
   push dx
   push ax
   ; Destination (4 bytes)
   push ss
   push si
   ; count (2 bytes)
   push cx
   ; Signature (2 bytes)
   mov bl, 16
   push bx
   
   ; Call
   mov ah, 0x42
   mov dl, [DATA_BASE+DATA_SIZE-2]
   mov si, sp
   int 0x13
   adc bh, 0         ; ZF = !CF = !error = success, CF = 0
   mov al, 'R'
   call print_success_failure
   add sp, 16
   ret

;##################
;# Math functions #
;##################

; Performs the following calculation: address = begin_lba_sc + logical_sector_size_sc * (reserved_size_lsc + N)
; Footprint: ax, bx, cx, dx
; add_multiply_add(uint16_t high, uint16_t low) -> uint16_t high, uint16_t low, uint8_t logical_sector_size_sc
; add_multiply_add(dx, ax) -> dx, ax, cl
add_multiply_add:
   add ax, [BPB_BASE+14]   ; 14 = number of reserved logical sectors
   adc dx, 0
   
   mov bx, [BPB_BASE+11]   ; 11 = size of logical sector
   mov cl, 9               ; 9 = log2(512)
   shr bx, cl
   mov cx, bx

   call multiply

   add ax, [bp+8]          ; 8   = active partition's starting sector, low
   adc dx, [bp+8+2]        ; 8+2 = active partition's starting sector, high
   ret

; Multiplies number by other number
; Footprint: ax, bx, dx
; multiply(uint16_t high, uint16_t low, uint16_t count) -> uint16_t high, uint16_t low
; multiply(dx, ax, cx) -> dx, ax
multiply:
   push ax ;stack 1
   mov ax, dx
   mul cx            ; Multiply original dx by cx
   mov bx, ax
   pop ax ;stack 1
   mul cx            ; Multiply ax by cx
   add dx, bx
   ret

;####################
;# String functions #
;####################

; Reads count sectors starting with sector start_sc_high:start_sc_low and places them to destination
; Footprint: ax, bx
; print_success_failure(uint8_t message, bool success, bool continue_on_failure)
; print_success_failure(al, zf, cf)
print_success_failure:
   pushf ;stack 1
   jz print_success_failure_success
      add al, 0x20
   print_success_failure_success:
   mov ah, 0x0E
   xor bx, bx
   int 0x10
   popf ;stack 1
   ja infinite_loop  ; if ZF == 0 and CF == 0 (!success && !continue_on_failure)
   ret

;#################
;# Text messages #
;#################

string_moondcr:   db 'MOONDCR1BIN', 0x20
string_fat32:     db 'FAT32   '

;###########
;# Filling #
;###########

moondcr0_end:
%ifndef ELF
   times 440-($-$$) nop ; Fill code with nop
   db 'MDCR'            ; Unique ID
   db 0, 0              ; Signature
   times 510-(440) db 0 ; Partition table
   db 0x55, 0xAA        ; Boot signature
%endif