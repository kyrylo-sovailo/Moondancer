#!/usr/bin/make -f

KB := $(shell expr 1024)
MB := $(shell expr 1024 \* 1024)
GB := $(shell expr 1024 \* 1024 \* 1024)
SECTOR_SIZE_BT := 512
LOGICAL_SECTOR_SIZE_BT := 4096
FAT32_SIZE_BT := $(shell expr 16 \* $(MB))
FAT32_SIZE_SC := $(shell expr $(FAT32_SIZE_BT) / $(SECTOR_SIZE_BT))
FAT32_OFFSET_SC := 2048
MBR_SIZE_SC := $(shell expr $(FAT32_SIZE_SC) + $(FAT32_OFFSET_SC))
MBR_SIZE_BT := $(shell expr $(MBR_SIZE_SC) \* $(SECTOR_SIZE_BT))

BEGIN="\033[00;32mBuilding "
BEGIN_PHONY="\033[00;32mTarget "
END="\033[0m\n"

# End targets
all: img/mbr.img
	@printf $(BEGIN_PHONY)$@$(END)

print: img/mbr.img obj/print_img.elf
	@printf $(BEGIN_PHONY)$@$(END)
	obj/print_img.elf

.PHONY: run
run: img/mbr.img
	@printf $(BEGIN_PHONY)$@$(END)
	qemu-system-x86_64 -machine accel=tcg -drive file=img/mbr.img,index=0,media=disk,format=raw

.PHONY: debug
debug: img/mbr.img obj/moondcr0.o
	@printf $(BEGIN_PHONY)$@$(END)
	qemu-system-x86_64 -machine accel=tcg -drive file=img/mbr.img,index=0,media=disk,format=raw -S -s &
	gdb -ex "target remote :1234" -ex "symbol-file obj/moondcr0.o" -ex "break *0x7c00" -ex "continue"

.PHONY: clean
clean:
	@printf $(BEGIN_PHONY)$@$(END)
	rm -rf bin
	rm -rf gen
	rm -rf img
	rm -rf obj

# Construct full disk image
img/mbr.img: bin/moondcr0.bin img/fat32.img
	@printf $(BEGIN)$@$(END)
	mkdir -p img
	if [ ! -f img/mbr.img ]; then \
		dd if=/dev/zero of=img/mbr.img bs=$(SECTOR_SIZE_BT) count=$(MBR_SIZE_SC) || { rm -f img/mbr.img; exit 1; }; \
		REAL_INFO=$$(fdisk img/mbr.img < src/mbr.fdisk | grep -o -E 'mbr.img1[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+' | xargs) || { rm -f img/mbr.img; exit 1; }; \
		REAL_FAT32_OFFSET_SC=$$(echo $$REAL_INFO | cut -d ' ' -f 2); \
		REAL_FAT32_SIZE_SC=$$(echo $$REAL_INFO | cut -d ' ' -f 4); \
		echo REAL_FAT32_OFFSET_SC=$$REAL_FAT32_OFFSET_SC; \
		echo REAL_FAT32_SIZE_SC=$$REAL_FAT32_SIZE_SC; \
		if [ $$REAL_FAT32_OFFSET_SC != $(FAT32_OFFSET_SC) ]; then rm -f img/mbr.img; exit 1; fi; \
		if [ $$REAL_FAT32_SIZE_SC != $(FAT32_SIZE_SC) ]; then rm -f img/mbr.img; exit 1; fi; \
	fi
	dd if=img/fat32.img of=img/mbr.img seek=$(FAT32_OFFSET_SC) bs=$(SECTOR_SIZE_BT) count=$(FAT32_SIZE_SC) conv=notrunc || { rm -f img/mbr.img; exit 1; }
	dd if=bin/moondcr0.bin of=img/mbr.img bs=1 count=446 conv=notrunc || { rm -f img/mbr.img; exit 1; }

# Construct filesystem image
img/fat32.img: bin/moondcr1.bin
	@printf $(BEGIN)$@$(END)
	mkdir -p img
	if [ ! -f img/fat32.img ]; then \
		dd if=/dev/zero of=img/fat32.img bs=1M count=16 || { rm -f img/fat32.img; exit 1; }; \
		mformat -M $(LOGICAL_SECTOR_SIZE_BT) -v 'MOONDNCR' -F -i img/fat32.img || { rm -f img/fat32.img; exit 1; }; \
		REAL_LOGICAL_SECTOR_SIZE_BT=$$(dd if=img/fat32.img skip=11 bs=1 count=2 | od -An -t u1 | xargs); \
		REAL_LOGICAL_SECTOR_SIZE_BT_LOW=$$(echo $$REAL_LOGICAL_SECTOR_SIZE_BT | cut -d ' ' -f 1); \
		REAL_LOGICAL_SECTOR_SIZE_BT_HIGH=$$(echo $$REAL_LOGICAL_SECTOR_SIZE_BT | cut -d ' ' -f 2); \
		REAL_LOGICAL_SECTOR_SIZE_BT=$$(expr 256 \* $$REAL_LOGICAL_SECTOR_SIZE_BT_HIGH + $$REAL_LOGICAL_SECTOR_SIZE_BT_LOW); \
		echo REAL_LOGICAL_SECTOR_SIZE_BT=$$REAL_LOGICAL_SECTOR_SIZE_BT; \
		if [ $$REAL_LOGICAL_SECTOR_SIZE_BT != $(LOGICAL_SECTOR_SIZE_BT) ]; then echo rm -f img/fat32.img; exit 1; fi; \
	fi
	mcopy bin/moondcr1.bin :: -i img/fat32.img -o || { rm -f img/fat32.img; exit 1; }

# Flat binary and ELF
bin/%.bin: src/%.asm src/moondcr0.inc gen/moondcr0.inc
	@printf $(BEGIN)$@$(END)
	mkdir -p bin
	nasm src/$*.asm -f bin -o bin/$*.bin

obj/%.o: src/%.asm src/moondcr0.inc gen/moondcr0.inc
	@printf $(BEGIN)$@$(END)
	mkdir -p obj
	nasm src/$*.asm -DELF=YES -f elf -g -F dwarf -o obj/$*.o

# Special assembly for moondcr0
bin/moondcr0.bin gen/moondcr0.lst: gen/moondcr0.bin.lst ;

gen/moondcr0.bin.lst: src/moondcr0.asm src/moondcr0.inc
	@printf $(BEGIN)$@$(END)
	mkdir -p bin
	mkdir -p gen
	nasm src/moondcr0.asm -f bin -o bin/moondcr0.bin -l gen/moondcr0.lst
	grep 'moondcr0_end:' gen/moondcr0.lst -A5 | grep -o -E '^[ ]*[0-9]+ [0-9A-F]+ [0-9A-F]+' | head -n 1 | xargs | cut -d ' ' -f 2 | { read h; printf '%d\n' "0x$$h"; }
	touch $@

gen/moondcr0.inc: gen/moondcr0.bin.lst
	@printf $(BEGIN)$@$(END)
	echo infinite_loop equ 0x$$(grep 'infinite_loop:' gen/moondcr0.lst -A5 | grep -o -E '^[ ]*[0-9]+ [0-9A-F]+ [0-9A-F]+' | head -n 1 | xargs | cut -d ' ' -f 2) > gen/moondcr0.inc;
	echo read_sectors equ 0x$$(grep 'read_sectors:' gen/moondcr0.lst -A5 | grep -o -E '^[ ]*[0-9]+ [0-9A-F]+ [0-9A-F]+' | head -n 1 | xargs | cut -d ' ' -f 2) >> gen/moondcr0.inc;

# Special compilation for image printing tool
obj/print_img.elf: src/print_img.c
	@printf $(BEGIN)$@$(END)
	mkdir -p obj
	$(CC) src/print_img.c -o obj/print_img.elf
