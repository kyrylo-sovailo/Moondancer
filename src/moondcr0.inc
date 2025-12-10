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

; On custom data:
; [bp] is attributes, the highest bit is known to be 1, so it doubles as state
; [bp+66] is current cluster, low (66 = 16*4 + 2, it is the first byte guaranteed to lie in data segment)
; [bp+68] is current cluster, high
; [bp+70] is current sector, low
; [bp+72] is current sector, high
; [bp+74] is physical segment counter
; [DATA_BASE+DATA_SIZE-2] is preserved dx (can't save at bp+N because needs to be set prior to bp)
; In worst case scenario, if booted from partition 3, bp+70 == DATA_BASE + 58 == DATA_BASE + 16*3 + 10
; Which leaves us with 452 = 512 - 58 - 2 bytes for stack, which is plenty
BP_CLUSTER_LOW      equ 66
BP_CLUSTER_HIGH     equ 68
BP_SECTOR_LOW       equ 70
BP_SECTOR_HIGH      equ 72
BP_COUNTER          equ 74