;#################
;# Flag checking #
;#################

; Binary format: FLAT_BINARY (default), MBR_BINARY, FAT32_BINARY
%ifdef FLAT_BINARY
    %ifdef MBR_BINARY
        %error "FLAT_BINARY is incompatible with MBR_BINARY"
    %endif
    %ifdef FAT32_BINARY
        %error "FLAT_BINARY is incompatible with FAT32_BINARY"
    %endif
%endif
%ifdef MBR_BINARY
    %ifdef FAT32_BINARY
        %error "MBR_BINARY is incompatible with FAT32_BINARY"
    %endif
%endif

%ifndef FLAT_BINARY
    %ifndef MBR_BINARY
        %ifndef FAT32_BINARY
            %define FLAT_BINARY
        %endif
    %endif
%endif

; Disk access mode: ENABLE_LBA (default), ENABLE_CHS
%ifdef ENABLE_LBA
    %ifdef ENABLE_CHS
        %error "ENABLE_LBA is incompatible with ENABLE_CHS"
    %endif
%endif

%ifndef ENABLE_LBA
    %ifndef ENABLE_CHS
        %define ENABLE_LBA
    %endif
%endif

; Binary flags: DEBUG_ELF, ENABLE_MBR


;#############
;# Constants #
;#############

COMMON_BASE         equ 0x0500
COMMON_SIZE         equ 0x0200

MBR_BASE            equ COMMON_BASE + 0 * COMMON_SIZE   ; 0x0500 - 0x06FF - first disk sector
BPB_BASE            equ COMMON_BASE + 1 * COMMON_SIZE   ; 0x0700 - 0x08FF - first filesystem sector
FAT_BASE            equ COMMON_BASE + 2 * COMMON_SIZE   ; 0x0900 - 0x0AFF - buffer for FAT
DATA_STACK_BASE     equ COMMON_BASE + 3 * COMMON_SIZE   ; 0x0B00 - 0x0CFF - data and stack
STAGE0_COPY_BASE    equ COMMON_BASE + 4 * COMMON_SIZE   ; 0x0D00 - 0x0EFF - code of stage 0, relocated by stage 1
STAGE1_BASE         equ COMMON_BASE + 5 * COMMON_SIZE   ; 0x0F00 - 0x10FF - code of stage 1
STAGE2_BASE         equ COMMON_BASE + 6 * COMMON_SIZE   ; 0x1100 - 0x12FF - code of stage 2
STAGE0_BASE         equ 0x7C00                          ; 0x7C00 - 0x7DFF - code of stage 0, loaded by BIOS

MBR_SIZE            equ COMMON_SIZE
BPB_SIZE            equ COMMON_SIZE
FAT_SIZE            equ COMMON_SIZE
DATA_STACK_SIZE     equ COMMON_SIZE
STAGE0_COPY_SIZE    equ COMMON_SIZE
STAGE1_SIZE         equ COMMON_SIZE
STAGE2_SIZE         equ COMMON_SIZE
STAGE0_SIZE         equ COMMON_SIZE