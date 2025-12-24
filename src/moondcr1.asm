;#########
;# Setup #
;#########

[cpu 8086]
[bits 16]
%include "src/common.inc"
%ifdef ENABLE_MBR ;The stage 0 file is identified by ENABLE_MBR
   %include "gen/moondcr0.inc"
%else
   %include "gen/moondcrf.inc"
%endif
%ifdef DEBUG_ELF
   times STAGE1_BASE nop
   MANUAL_OFFSET equ STAGE1_BASE
%else
   [org STAGE1_BASE]
   MANUAL_OFFSET equ 0
%endif
%ifndef FLAT_BINARY
   %error "moondcr1.asm must be built with FLAT_BINARY"
%endif

mov sp, DATA_STACK_BASE+DATA_STACK_SIZE-2

xor bx, bx
mov ax, ((0x0E << 8) | 13)
int 0x10
mov al, 10
int 0x10

;######################
;# Relocating stage 0 #
;######################

mov si, STAGE0_BASE
mov di, STAGE0_COPY_BASE
mov cx, 512/2
rep movsw

%ifdef ENABLE_DIVISION_ERROR
   xor ax, ax
   xor di, di
   stosw
   mov word [di], division_failure
%endif

;###################
;# Checking memory #
;###################
clc
xor bh, bh
int 0x12
mov dx, ax
adc bh, 0                     ; ZF = !CF = !error = success, CF = 0
jnz check_memory_early_exit

sub dx, (STAGE2_BASE+1023)/1024
call get_cluster_size         ; ax = logical_sector_size_sc * cluster_size_lsc = cluster_size_sc
inc ax
shr ax, 1                     ; ax = (cluster_size_sc + 1) / 2, 2 = two sectors per kilobyte
xor cl, cl
cmp dx, ax
adc cl, 0                     ; ZF = !CF = !below, CF = 0

check_memory_early_exit:
mov al, 'E'
call print_success_failure
push dx                       ; [DATA_STACK_BASE+DATA_STACK_SIZE-4] is memory size in kilobytes

;########################################################
;# Read FAT32 file (modified version from moondcr0.asm) #
;########################################################

xor ax, ax
push ax                       ; [DATA_STACK_BASE+DATA_STACK_SIZE-6] is current segment to read into
push ax                       ; [DATA_STACK_BASE+DATA_STACK_SIZE-8] is file size in clusters

; Loop1: Iterate over cluster chains
mov si, BPB_BASE+44
lodsw                         ; 44   = root cluster, low
mov dx, word [si]             ; 44+2 = root cluster, high (minus 2 because added by lodsw)
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
   mov cl, byte [BPB_BASE+13] ; 13 = cluster size in logical sectors
   mov di, cx
   call multiply
   push dx ;stack 3
   push ax ;stack 4

   ; dx:ax = ex_fat_size_lsc * fat_number
   mov si, BPB_BASE+36
   lodsw                      ; 36   = extended FAT size, low
   mov dx, word [si]          ; 36+2 = extended FAT size, high (minus 2 because added by lodsw)
                              ; xor ch, ch (optimized)
   mov cl, byte [si-22]       ; 16 = number of FAT tables, -22 = 16-(36+2)
   call multiply

   ; dx:ax = ex_fat_size_lsc * fat_number + (file_ct - 2) * cluster_size_lsc
   pop bx ;stack 4
   pop cx ;stack 3
   add ax, bx
   adc dx, cx

   ; dx:ax = begin_lba_sc + logical_sector_size_sc * (reserved_size_lsc + ex_fat_size_lsc * fat_number + (root_ct - 2) * cluster_size_lsc)
   call add_multiply_add

   ; ax = logical_sector_size_sc * cluster_size_lsc (both numbers are guaranteed to be less than 256, product guaranteed to be less than 1024)
   xchg ax, di                ; cluster size to ax, low sector number to di
   mul cl                     ; cx is left over add_multiply_add
   mov cx, ax                 ; ATTENTION: ch may be non-zero
   mov ax, di                 ; low sector number to ax
   
   ; Read cluster dx:ax (cx segments) to es:si
   push cx ;stack 3
   mov si, STAGE2_BASE
   push es ;stack 4
   mov bx, word [DATA_STACK_BASE+DATA_STACK_SIZE-6]
   mov es, bx
   call read_sectors ; TODO: may fail for floppies if cx > 255
   pop es ;stack 4
   pop cx ;stack 3

   ; Check if read directory or target file
   %ifdef ENABLE_MBR
      test byte [bp], 0x80
      jz read_file_directory
   %else
      or bp, bp
      jnz read_file_directory
   %endif

   read_file_file:
      ; Increment counters
      mov ax, 32              ; 32 = 512 / 16 (segment multiplier)
      mul cx                  ; ax = segment_increment, dx = 0
      add word [DATA_STACK_BASE+DATA_STACK_SIZE-6], ax
      dec word [DATA_STACK_BASE+DATA_STACK_SIZE-8]
      mov dx, word [DATA_STACK_BASE+DATA_STACK_SIZE-2]
      jz STAGE2_BASE          ; Leap of faith
      jmp read_file_advance_cluster

   read_file_directory:
      ; Loop 2: Iterate over FAT records in a cluster
      mov ax, 16              ; 16 = 512 / 32 (records per sector)
      mul cx                  ; ax = number_of_records, dx = 0
      mov cx, ax
      mov dx, STAGE2_BASE+0   ; 0 = file name
      read_file_list_loop:
         push cx ;stack 3
         mov si, dx
         mov di, string_moondcr
         mov cx, 12           ; mov cx, 12 (optimized)
         repe cmpsb
         stc
         mov al, 'M'
         call print_success_failure
         jz read_file_list_loop_success
         add dx, 32
         pop cx ;stack 3
         loop read_file_list_loop

      ; moondcr2.bin not found, go to next cluster

   read_file_advance_cluster:
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
   mov si, FAT_BASE
   mov cl, 1                  ; mov cx, 1 (optimized)
   call read_sectors

   ; dx:ax = file_ct
   pop bx ;stack 1
   add bx, FAT_BASE
   mov ax, word [bx]
   mov dx, word [bx+2]
   jmp read_file_loop

; moondcr1.bin found, go to next cluster
; This piece of code does not belong to any indentation level, it is on its own
read_file_list_loop_success:
add sp, 6 ;stack 3, stack 2, stack 1
%ifdef ENABLE_MBR
   not byte [bp]
%else
   not bp
%endif
mov di, si
mov ax, word [di-12+28] ; 28 = file size, low (minus 12 because si = dx + 12 if repe cmpsb succeeds)
mov dx, word [di-12+30] ; 30 = file size, high (minus 12 because si = dx + 12 if repe cmpsb succeeds)
add ax, 511             ; dx:ax = file_size_bt + 511
adc dx, 0
mov cl, 9               ; 9 = log2(512)
read_file_size_loop:    ; dx:ax = (file_size_bt + 511) / 512 = file_size_sc
   shr dx, 1
   rcr ax, 1
   loop read_file_size_loop
or dx, dx
jnz read_file_size_early_exit
test ah, 0x80
jnz read_file_size_early_exit ; If file_size_sc is more than 2^15*512, the file is too large. If less, we forget about dx

push ax ;stack 1
call get_cluster_size   ; ax = cluster_size_sc
mov bx, ax
pop ax ;stack 1
add ax, bx
dec ax                  ; ax = file_size_sc + cluster_size_sc - 1
div bx                  ; ax = (file_size_sc + cluster_size_sc - 1) / cluster_size_sc = file_size_ct
mov [DATA_STACK_BASE+DATA_STACK_SIZE-8], ax
mul bx                  ; ax = file_size_ct * cluster_size_sc
inc ax
shr ax, 1               ; ax = (file_size_ct * cluster_size_sc + 1) / 2, 2 = two sectors pro kilobyte

xor cl, cl
cmp word [DATA_STACK_BASE+DATA_STACK_SIZE-4], ax
adc cl, 0               ; ZF = !CF = !below, CF = 0
read_file_size_early_exit:
mov al, 'E'
call print_success_failure

mov ax, word [di-12+26] ; 26 = address of file cluster, low (minus 12 because si = dx + 12 if repe cmpsb succeeds)
mov dx, word [di-12+20] ; 20 = address of file cluster, high (minus 12 because si = dx + 12 if repe cmpsb succeeds)
jmp read_file_loop

;##################
;# Math functions #
;##################

; Gets cluster size in sectors
; Footprint: ax, cl, si
; print() -> uint16_t cluster_size_sc
; print() -> ax
get_cluster_size:
   mov si, BPB_BASE+11
   lodsw                         ; 11 = size of logical sector
   mov cl, 9                     ; 9 = log2(512)
   shr ax, cl
   mul byte [si]                 ; ax = logical_sector_size_sc * cluster_size_lsc, 13 = cluster size in logical sectors
   ret

;#################
;# Text messages #
;#################

string_moondcr: db 'MOONDCR2BIN', 0x20

;###########
;# Filling #
;###########

moondcr1_end:
times 512-($-$$-MANUAL_OFFSET) nop  ; Fill code with nop