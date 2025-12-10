; On memory organization:
MOONDCR0_SEGMENT    equ 0
MBR_BASE            equ 0x0500 ; 0x0500 - 0x06FF - first disk sector
MBR_SIZE            equ 512
DATA_BASE           equ 0x0700 ; 0x0700 - 0x08FF - custom data and stack
DATA_SIZE           equ 512
BPB_BASE            equ 0x0900 ; 0x0900 - 0x0AFF - first filesystem sector
BPB_SIZE            equ 512
FILE_BASE           equ 0x0B00 ; 0x0B00 - 0x0CFF - file data
FILE_SIZE           equ 512
UNUSED_BASE         equ 0x0D00 ; 0x0D00 - 0x7BFF - file data
UNUSED_SIZE         equ 28416
CODE_BASE           equ 0x7C00 ; 0x7C00 - 0x7DFF - code, loaded by BIOS
CODE_SIZE           equ 512