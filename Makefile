#!/usr/bin/make -f

KB := $(shell expr 1024)
MB := $(shell expr 1024 \* 1024)
GB := $(shell expr 1024 \* 1024 \* 1024)
SECTOR_SIZE_BT := 512
FAT32_SIZE_BT := $(shell expr 16 \* $(MB))
FAT32_SIZE_SC := $(shell expr $(FAT32_SIZE_BT) / $(SECTOR_SIZE_BT))
FAT32_OFFSET_SC := 2048
MBR_SIZE_SC := $(shell expr $(FAT32_SIZE_SC) + $(FAT32_OFFSET_SC))
MBR_SIZE_BT := $(shell expr $(MBR_SIZE_SC) \* $(SECTOR_SIZE_BT))

img/mbr.img: directories bin/moondcr0.bin img/fat32.img gen/mbr.fdisk
	if [ ! -f img/mbr.img ]; then \
		dd if=/dev/zero of=img/mbr.img bs=$(SECTOR_SIZE_BT) count=$(MBR_SIZE_SC) || { rm -f img/mbr.img; exit 1; }; \
		REAL_INFO=$$(fdisk img/mbr.img < gen/mbr.fdisk | grep -o -E 'mbr.img1[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+' | xargs) || { rm -f img/mbr.img; exit 1; }; \
		REAL_FAT32_OFFSET=$$(echo $$REAL_INFO | cut -d ' ' -f 2); \
		REAL_FAT32_SIZE=$$(echo $$REAL_INFO | cut -d ' ' -f 4); \
		echo REAL_FAT32_OFFSET=$$REAL_FAT32_OFFSET; \
		echo REAL_FAT32_SIZE=$$REAL_FAT32_SIZE; \
		if [ $$REAL_FAT32_OFFSET != $(FAT32_OFFSET_SC) ]; then rm -f img/mbr.img; exit 1; fi; \
		if [ $$REAL_FAT32_SIZE != $(FAT32_SIZE_SC) ]; then rm -f img/mbr.img; exit 1; fi; \
	fi
	dd if=img/fat32.img of=img/mbr.img seek=$(FAT32_OFFSET_SC) bs=$(SECTOR_SIZE_BT) count=$(FAT32_SIZE_SC) conv=notrunc || { rm -f img/mbr.img; exit 1; }
	dd if=bin/moondcr0.bin of=img/mbr.img bs=1 count=440 conv=notrunc || { rm -f img/mbr.img; exit 1; }

img/fat32.img: directories bin/moondcr1.bin
	if [ ! -f img/fat32.img ]; then \
		dd if=/dev/zero of=img/fat32.img bs=1M count=16 || { rm -f img/fat32.img; exit 1; }; \
		mformat -v 'MOONDNCR' -F -i img/fat32.img || { rm -f img/fat32.img; exit 1; }; \
		REAL_SECTOR_SIZE=$$(dd if=img/fat32.img skip=11 bs=1 count=2 | od -An -t u1 | xargs); \
		REAL_SECTOR_SIZE_LOW=$$(echo $$REAL_SECTOR_SIZE | cut -d ' ' -f 1); \
		REAL_SECTOR_SIZE_HIGH=$$(echo $$REAL_SECTOR_SIZE | cut -d ' ' -f 2); \
		REAL_SECTOR_SIZE=$$(expr 256 \* $$REAL_SECTOR_SIZE_HIGH + $$REAL_SECTOR_SIZE_LOW); \
		if [ $$REAL_SECTOR_SIZE != $(SECTOR_SIZE_BT) ]; then rm -f img/fat32.img; exit 1; fi; \
	fi
	mcopy bin/moondcr1.bin :: -i img/fat32.img -o || { rm -f img/fat32.img; exit 1; }

bin/moondcr0.bin: directories src/moondcr0.asm
	nasm src/moondcr0.asm -f bin -o bin/moondcr0.bin
	REAL_SIZE=$$(stat bin/moondcr0.bin --printf="%s"); \
	echo Size: $$REAL_SIZE bytes; \
	if [ $$REAL_SIZE -gt 440 ]; then rm -f bin/moondcr0.bin; exit 1; fi

gen/moondcr0.elf.asm: directories src/moondcr0.asm
	cat src/moondcr0.asm | grep -v '\[org 0\]' > gen/moondcr0.elf.asm

obj/moondcr0.elf: directories src/moondcr0.elf.asm
	nasm src/moondcr0.elf.asm -f elf -g -F dwarf -o obj/moondcr0.o

bin/moondcr1.bin: directories src/moondcr1.asm
	nasm src/moondcr1.asm -f bin -o bin/moondcr1.bin

gen/moondcr1.elf.asm: directories src/moondcr1.asm
	cat src/moondcr1.asm | grep -v '\[org 0\]' > gen/moondcr1.elf.asm

obj/moondcr1.elf: src/moondcr1.elf.asm
	nasm src/moondcr1.elf.asm -f elf -g -F dwarf -o obj/moondcr1.o

gen/mbr.fdisk: directories
	echo o 	>  gen/mbr.fdisk 	#New MBR
	echo n 	>> gen/mbr.fdisk	#New partition
	echo p 	>> gen/mbr.fdisk	#Primary
	echo 1 	>> gen/mbr.fdisk	#Partition 1
	echo   	>> gen/mbr.fdisk	#Default start sector
	echo   	>> gen/mbr.fdisk	#Default end sector
	echo t 	>> gen/mbr.fdisk	#Type
	echo 0b >> gen/mbr.fdisk	#FAT32
	echo p  >> gen/mbr.fdisk	#Print
	echo w  >> gen/mbr.fdisk	#Write

all: img/mbr.img

.PHONY: run
run: img/mbr.img
	qemu-system-x86_64 -drive file=img/mbr.img,index=0,media=disk,format=raw

.PHONY: debug
debug: img/mbr.img obj/moondcr0.o
	qemu-system-x86_64 -drive file=img/mbr.img,index=0,media=disk,format=raw -S -s &
	gdb -ex "target remote :1234" -ex "symbol-file obj/moondcr0.o" -ex "break *0x7c00" -ex "continue"

.PHONY: directories
directories:
	mkdir -p bin
	mkdir -p gen
	mkdir -p img
	mkdir -p obj

.PHONY: clean
clean:
	rm -rf bin
	rm -rf gen
	rm -rf img
	rm -rf obj