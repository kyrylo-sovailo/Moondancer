; On memory organization:
MOONDCR0_SEGMENT    equ 0

%ifdef ENABLE_MBR

MBR_BASE            equ 0x0500 ; 0x0500 - 0x06FF - first disk sector
DATA_BASE           equ 0x0700 ; 0x0700 - 0x08FF - custom data and stack
BPB_BASE            equ 0x0900 ; 0x0900 - 0x0AFF - first filesystem sector
FILE_BASE           equ 0x0B00 ; 0x0B00 - 0x0CFF - file data
UNUSED_BASE         equ 0x0D00 ; 0x0D00 - 0x7BFF - file data
CODE_BASE           equ 0x7C00 ; 0x7C00 - 0x7DFF - code, loaded by BIOS

MBR_SIZE            equ 512
DATA_SIZE           equ 512
BPB_SIZE            equ 512
FILE_SIZE           equ 512
UNUSED_SIZE         equ 28416
CODE_SIZE           equ 512

%else

DATA_BASE           equ 0x0500 ; 0x0500 - 0x06FF - custom data and stack
BPB_BASE            equ 0x0700 ; 0x0700 - 0x08FF - first filesystem sector
FILE_BASE           equ 0x0900 ; 0x0900 - 0x0AFF - file data
UNUSED_BASE         equ 0x0B00 ; 0x0B00 - 0x7BFF - file data
CODE_BASE           equ 0x7C00 ; 0x7C00 - 0x7DFF - code, loaded by BIOS

DATA_SIZE           equ 512
BPB_SIZE            equ 512
FILE_SIZE           equ 512
UNUSED_SIZE         equ 28928
CODE_SIZE           equ 512

%endif