;#########
;# Notes #
;#########

; On memory organization:
; All segments are set to 0x07C0: CS = DS = ES = SS = 0x07C0
; This gives me 0x10000 = 65536 bytes of space
; Memory is linear and accessible through offset 0 to 0x10000
; From now on, addresses refer to this offset
; 0x0000 - 0x01FF - code, loaded by BIOS
; 0x0200 - 0x03FF - first disk sector
; 0x0400 - 0x05FF - first filesystem sector
; 0x0600 - 0x07FF - partial loads of FAT table
; 0x0800 - ...... - file data
; ...... - 0xFFFF - stack

; Register organization:
; BP is used as general purpose register
; ES is needed only for cmps
; FS is used for storage
; GS is unused

; On BIOS assumptions:
; int 0x13, ah 0x42: affects ah, assumed change flags
; int 0x10, dl 0x0E: assumed change flags

; On "mov r16" vs "mov r8":
; To reduce program size, "mov r8" is preferred over "mov r16"
; If h16h is guaranteed to be zero (for example, print is guaranteed to leave cx at zero), "mov r8" is used
; There cases are marked with "Guaranteed zero"

; On print format:
; A+ on success, A- on error
; / - read root directory
; 1 - read stage 1
; R - read disk
; S - check boot signature
; F - check FAT32 signature
; M - check if enough memory to load cluster
; L - check if file is stage 1

; On desired features:
; - porting to 8086
; - probing all partitions
; - probing all disks or current disk only
; - handling non-512 sectors
; - handling of too big files

;################
;# Specify mode #
;################

[cpu 386]
[bits 16]

;#####################################
;# Setup segment registers and stack #
;#####################################

[org 0x0000]
jmp 0x07C0:start
start:
mov ax, cs
mov ds, ax
mov es, ax  ; Needed for cmps
mov ss, ax
xor sp, sp  ; Acceptable since 'push' decrements the register first
cld

;####################
;# Greeting message #
;####################

mov cx, id_moondcr
;mov al, 1  ; Guaranteed non-zero
call print_success_failure

;############
;# Read MBR #
;############

xor dx, dx
xor ax, ax
mov si, 0x200
call read_sector_signature

;#####################
;# Read FAT32 header #
;#####################

mov ax, [0x03C6]     ; 0x03C6 = 0x200 + 454   = 0x200 + 446+8  , first partition's starting sector, low
mov dx, [0x03C8]     ; 0x03C8 = 0x200 + 454+2 = 0x200 + 446+8+2, first partition's starting sector, high
mov si, 0x0400
call read_sector_signature

mov si, string_fat32_begin
mov di, 0x0452       ; 0x0452 = 0x0400 + 82, address of the "FAT32   " signature
mov cl, 8            ; Not cx because guaranteed zero
repe cmpsb
setz al
mov cx, id_fat32
call print_success_failure

;#############################
;# Read FAT32 root directory #
;#############################

mov ax, [0x042C]     ; 0x042C = 0x0400 + 44   = 0x0400 + 44  , address of root cluster, low
mov dx, [0x042E]     ; 0x042E = 0x0400 + 44+2 = 0x0400 + 44+2, address of root cluster, high
call read_file
mov dx, si           ; Long-term save
mov cx, id_root
call print_success_failure

mov bp, 0x07E0       ; 0x07E0 = 0x0800 + 0 - 32, file name, 32 to be added
file_search_loop:
   add bp, 32
   cmp bp, dx        ; Long-term compare
   setb al
   mov cx, id_search
   call print_success_failure

   mov si, bp
   mov di, string_moondcr_begin
   mov cl, 12        ; Not cx because guaranteed zero
   repe cmpsb
   jnz file_search_loop

;###################
;# Read FAT32 file #
;###################

mov ax, [bp + 26]    ; address of file cluster, low
mov dx, [bp + 20]    ; address of file cluster, high
call read_file
mov cx, id_moondcr1bin
call print_success_failure
jmp 0x0800            ; Leap of faith

;###################
;# Disk operations #
;###################

; Reads FAT32 file
; Footprint: ax, bx, cx, dx, si, di, bp, fs
; read_file(uint16_t start_ct_high, uint16_t start_ct_low) -> void*
; read_file(dx, ax) -> si
read_file:
   mov si, 0x0800

   read_file_loop:
      ; bp:di = cluster
      mov di, ax
      mov bp, dx

      ; dx:ax = cluster-2
      sub ax, 2
      sbb dx, 0
      
      ; dx:ax = (cluster-2) * sectors_per_cluster
      ;xor cx, cx       ; Guaranteed zero, both memcmp and print leave ax zero
      mov cl, [0x040D]  ; 0x040D = 0x0400 + 13, address of cluster size in sectors
      call multiply
      push dx
      push ax

      ; dx:ax = fat_size * fat_number
      %define CONSIDER_SMALL_FAT_SIZE
      %ifdef CONSIDER_SMALL_FAT_SIZE
      xor dx, dx
      mov ax, [0x0416]     ; 0x0416 = 0x0400 + 22   = 0x0400 + 22  , FAT size, low
      or ax, ax
      jnz read_file_loop_small_fat_size
      %endif
         mov ax, [0x0424]  ; 0x0424 = 0x0400 + 36   = 0x0400 + 36  , extended FAT size, low
         mov dx, [0x0426]  ; 0x0426 = 0x0400 + 36+2 = 0x0400 + 36+2, extended FAT size, high
      read_file_loop_small_fat_size:
      mov cl, [0x0410]     ; 0x0410 = 0x0400 + 16, number of FAT tables
      call multiply
      
      ; dx:ax = fat_size * fat_number + (cluster-2) * sectors_per_cluster
      pop bx
      pop cx
      call add
      
      ; cx:bx = partition_begin + reserved_size
      mov bx, [0x03C6]     ; 0x03C6 = 0x200 + 454   = 0x200 + 446+8  , first partition's starting sector, low
      mov cx, [0x03C8]     ; 0x03C8 = 0x200 + 454+2 = 0x200 + 446+8+2, first partition's starting sector, high
      add bx, [0x040E]     ; 0x040E = 0x0400 + 14   = 0x0400 + 14  , number of reserved sectors
      adc cx, 0
      push cx
      push bx

      ; dx:ax = partition_begin + reserved_size + fat_size * fat_number + (cluster-2) * sectors_per_cluster
      call add

      ; Read file at dx:ax
      xor cx, cx
      mov cl, [0x040D]     ; 0x040D = 0x0400 + 13, cluster size in sectors
      push cx
      push si
      call read_sectors
      pop si
      pop cx
      shl cx, 9            ; 9 = log2(512)
      add si, cx
      mov fs, si           ; Store bypassing stack and ax,bx,cx,dx,si,di,bp

      ; dx:ax = partition_begin + reserved_size + cluster / (512 / sizeof(uint32_t))
      mov ax, di
      mov dx, bp
      shrd ax, dx, 7       ; 7 = log2(512 / sizeof(uint32_t)) = log2(128)
      shr dx, 7
      pop bx
      pop cx
      call add

      ; Load relevant FAT part at dx:ax
      mov si, 0x0600
      mov cx, 1
      call read_sectors

      ; di = cluster % (512 / sizeof(uint32_t)) * sizeof(uint32_t)
      and di, 0x7F      ; 0x7F = 01111111b, 7 = log2(512 / sizeof(uint32_t)) = log2(128)
      shl di, 2         ; 2 = log2(sizeof(uint32_t))
      
      ; Check if next cluster is invalid and quit
      mov ax, [0x0600 + di]
      mov dx, [0x0602 + di]
      mov si, fs        ; Restore bypassed si
      and dx, 0x0FFF
      cmp dx, 0x0FFF
      jb read_file_loop
      cmp ax, 0xFFF7
      jb read_file_loop
      ret

; Reads sector at start_sc_high:start_sc_low and places it to destination, then checks 0xAA55 signature
; Footprint: ax, bx, cx, dx, si
; read_sector_signature(uint16_t start_sc_high, uint16_t start_sc_low, void *destination)
; read_sector_signature(dx, ax, si)
read_sector_signature:
   push si
   mov cx, 1
   call read_sectors
   pop si
   mov ax, 0XAA55
   cmp ax, [si + 0x01FE]
   setz al
   mov cx, id_boot
   call print_success_failure
   ; No ret, proceed to add (ax and dx are discarded anyway)

; Adds number to other number
; Footprint: ax, dx
; add(uint16_t high, uint16_t low, uint16_t other_high, uint16_t other_low)
; add(dx, ax, cx, bx)
add:
   add ax, bx
   adc dx, cx
   ret

; Reads count sectors starting with sector start_sc_high:start_sc_low and places them to destination
; Footprint: ax, bx, cx, dx, si
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
   mov dl, 0x80
   mov si, sp
   int 0x13
   setnc al
   mov cx, id_read
   call print_success_failure
   add sp, 16
   ; No ret, proceed to multiply (ax and dx are discarded anyway)

; Multiplies number by other number
; Footprint: ax, bx, dx
; multiply(uint16_t high, uint16_t low, uint16_t count)
; multiply(dx, ax, cx)
multiply:
   push ax
   mov ax, dx
   mul cx            ; Multiply original dx by cx
   mov bx, ax
   pop ax
   mul cx            ; Multiply ax by cx
   add dx, bx
   ret

;####################
;# String functions #
;####################

; Prints a number
; Footprint: ax, bx, cx, dx
; print_uint(uint16_t number)
; print_uint(ax)
; %define DEBUG 1
%ifdef DEBUG
print_uint:
   mov cx, 4
   mov dx, ax
   print_uint_loop:
      rol dx, 4
      mov al, dl
      and al, 0x0F

      cmp al, 10
      jb print_uint_digit
         add al, 7   ; 55 = 'A' - 10, 7 = 55 - 48
      print_uint_digit:
      add al, 48     ; 48 = '0' - 0

      mov ah, 0x0E
      xor bx, bx
      int 0x10
      loop print_uint_loop
      ret
%endif

; Prints 1-terminated string
; Footprint: ax, bx, cx, si
; print(uint16_t id)
; print(cx)
print:
   movzx si, ch
   add si, string_bank_begin
   xor ch, ch

   print_loop:
      lodsb
      mov ah, 0x0E
      xor bx, bx
      int 0x10
      loop print_loop
      ret

; Prints 1-terminated string and success/failure message message
; Footprint: ax, bx, cx, si
; print_success_failure(uint16_t id, bool success)
; print_success_failure(cx, al)
print_success_failure:
   push ax
   call print
   pop ax
   or al, al
   jz print_success_failure_failure
      mov cx, id_success
      call print
      ret
   print_success_failure_failure:
      mov cx, id_failure
      call print
      ; No ret, proceed to infinite loop

;#################
;# Infinite loop #
;#################

infinite_loop:
jmp infinite_loop

;#################
;# Text messages #
;#################

string_bank_begin:

string_moondcr_begin:   db 'MOONDCR'   ; Printed once started
string_moondcr_end:     db '1BIN'      ; Printed once file is read
string_moondcr1bin_end: db 0x20        ; (doubles as attribute, 0x20 = archive)
string_moondcr1bin20_end:
string_boot_begin:      db 'BOOT'      ; Printed once 0xAA55 signature is read
string_boot_end:
string_fat32_begin:     db 'FAT32'     ; Printed once FAT32 signature is read
string_fat32_end:       db '   '       ; (doubles as filesystem label)
string_fat32space_end:
string_root_begin:      db 'ROOT'      ; Printed once root directory is read
string_root_end:
string_read_begin:      db 'READ'      ; Printed every time a segment is read
string_read_end:
string_search_begin:    db 'LIST'      ; Printed on every comparison of file name
string_search_end:
string_success_begin:   db 13, 10      ; Printed after each success message
string_success_end:
%define HARDCODE_ERROR
%ifndef HARDCODE_ERROR
string_failure_begin:   db '+'        ; Printed after final failure message
string_failure_end:
%endif

id_moondcr     equ (((string_moondcr_begin - string_bank_begin) << 8) | (string_moondcr_end     - string_moondcr_begin))
id_moondcr1bin equ (((string_moondcr_begin - string_bank_begin) << 8) | (string_moondcr1bin_end - string_moondcr_begin))
id_boot        equ (((string_boot_begin    - string_bank_begin) << 8) | (string_boot_end        - string_boot_begin))
id_fat32       equ (((string_fat32_begin   - string_bank_begin) << 8) | (string_fat32_end       - string_fat32_begin))
id_root        equ (((string_root_begin    - string_bank_begin) << 8) | (string_root_end        - string_root_begin))
id_read        equ (((string_read_begin    - string_bank_begin) << 8) | (string_read_end        - string_read_begin))
id_search      equ (((string_search_begin  - string_bank_begin) << 8) | (string_search_end      - string_search_begin))
id_success     equ (((string_success_begin - string_bank_begin) << 8) | (string_success_end     - string_success_begin))
%ifndef HARDCODE_ERROR
id_failure     equ (((string_failure_begin - string_bank_begin) << 8) | (string_failure_end     - string_failure_begin))
%else
id_failure     equ 0x36
%endif
