#!/usr/bin/make -f

#########
# Setup #
#########

BEGIN="\033[00;32mBuilding "
BEGIN_PHONY="\033[00;32mTarget "
END="\033[0m\n"

###############
# End targets #
###############

all: img/mbr.img img/fat32.img
	@printf $(BEGIN_PHONY)$@$(END)

print: img/mbr.img obj/print_mbr.elf
	@printf $(BEGIN_PHONY)$@$(END)
	obj/print_mbr.elf

.PHONY: run
run: img/mbr.img
	@printf $(BEGIN_PHONY)$@$(END)
	qemu-system-x86_64 -machine accel=tcg -drive file=img/mbr.img,if=ide,media=disk,format=raw

DEBUG_ELF := obj/moondcr1.elf
.PHONY: debug
debug: img/mbr.img $(DEBUG_ELF)
	@printf $(BEGIN_PHONY)$@$(END)
	qemu-system-x86_64 -machine accel=tcg -drive file=img/mbr.img,if=ide,media=disk,format=raw -S -s &
	gdb -ex "target remote :1234" -ex "symbol-file $(DEBUG_ELF)" -ex "break *0x7c00" -ex "continue"

.PHONY: run_floppy
run_floppy: img/fat32.img
	@printf $(BEGIN_PHONY)$@$(END)
	qemu-system-x86_64 -machine accel=tcg -drive file=img/fat32.img,if=floppy,media=disk,format=raw

FLOPPY_DEBUG_ELF := obj/moondcrg.elf
.PHONY: debug_floppy
debug_floppy: img/fat32.img $(FLOPPY_DEBUG_ELF)
	@printf $(BEGIN_PHONY)$@$(END)
	qemu-system-x86_64 -machine accel=tcg -drive file=img/fat32.img,if=floppy,media=disk,format=raw -S -s &
	gdb -ex "target remote :1234" -ex "symbol-file $(FLOPPY_DEBUG_ELF)" -ex "break *0x7c00" -ex "continue"

.PHONY: clean
clean:
	@printf $(BEGIN_PHONY)$@$(END)
	rm -rf bin
	rm -rf gen
	rm -rf img
	rm -rf obj

##########
# Images #
##########

# MBR image with one FAT32 partition
img/mbr.img: bin/notboot0.bin bin/moondcr0.bin bin/moondcr1.bin bin/notbootf.bin bin/moondcrf.bin bin/moondcrg.bin bin/moondcr2.bin
	@printf $(BEGIN)$@$(END)
	mkdir -p img
	src/helper.sh create_mbr img/mbr.img

# FAT32 image
img/fat32.img: bin/notboot0.bin bin/moondcr0.bin bin/moondcr1.bin bin/notbootf.bin bin/moondcrf.bin bin/moondcrg.bin bin/moondcr2.bin
	@printf $(BEGIN)$@$(END)
	mkdir -p img
	src/helper.sh create_fat32 img/fat32.img

############
# Binaries #
############

# Stubs
bin/notboot0.bin: src/notboot0.asm src/common.inc
	@printf $(BEGIN)$@$(END)
	mkdir -p bin
	nasm $< -DMBR_BINARY -f bin -o $@

bin/notbootf.bin: src/notboot0.asm src/common.inc
	@printf $(BEGIN)$@$(END)
	mkdir -p bin
	nasm $< -DFAT32_BINARY -f bin -o $@

obj/notboot0.elf: src/notboot0.asm src/common.inc
	@printf $(BEGIN)$@$(END)
	mkdir -p obj
	nasm $< -DMBR_BINARY -DDEBUG_ELF -f elf -g -F dwarf -o $@

obj/notbootf.elf: src/notboot0.asm src/common.inc
	@printf $(BEGIN)$@$(END)
	mkdir -p obj
	nasm $< -DFAT32_BINARY -DDEBUG_ELF -f elf -g -F dwarf -o $@

# First stage
bin/moondcr0.bin gen/moondcr0.inc: src/moondcr0.asm src/common.inc
	@printf $(BEGIN)$@$(END)
	mkdir -p bin && mkdir -p gen
	nasm $< -DMBR_BINARY -DENABLE_LBA -DENABLE_MBR -f bin -o bin/moondcr0.bin -l gen/moondcr0.lst
	echo $$(src/helper.sh get_offset_dec gen/moondcr0.lst moondcr0_end) / 440
	: > gen/moondcr0.inc
	for f in add_multiply_add infinite_loop multiply print_success_failure read_sectors; do \
		OFFSET=$$(src/helper.sh get_offset gen/moondcr0.lst "$$f") ; \
		echo "$$f equ STAGE0_COPY_BASE + $$OFFSET" >> gen/moondcr0.inc ; \
	done

bin/moondcrf.bin gen/moondcrf.inc: src/moondcr0.asm src/common.inc
	@printf $(BEGIN)$@$(END)
	mkdir -p bin && mkdir -p gen
	nasm $< -DFAT32_BINARY -DENABLE_CHS -DENABLE_DIVISION_ERROR -f bin -o bin/moondcrf.bin -l gen/moondcrf.lst
	echo $$(expr $$(src/helper.sh get_offset_dec gen/moondcrf.lst moondcr0_end) - 90) / 420
	: > gen/moondcrf.inc
	for f in add_multiply_add infinite_loop multiply print_success_failure read_sectors division_failure; do \
		OFFSET=$$(src/helper.sh get_offset gen/moondcrf.lst "$$f") ; \
		echo "$$f equ STAGE0_COPY_BASE + $$OFFSET" >> gen/moondcrf.inc ; \
	done

obj/moondcr0.elf: src/moondcr0.asm src/common.inc
	@printf $(BEGIN)$@$(END)
	mkdir -p obj
	nasm $< -DDEBUG_ELF -DMBR_BINARY -DENABLE_LBA -DENABLE_MBR -f elf -g -F dwarf -o obj/moondcr0.elf

obj/moondcrf.elf: src/moondcr0.asm src/common.inc
	@printf $(BEGIN)$@$(END)
	mkdir -p obj
	nasm $< -DDEBUG_ELF -DFAT32_BINARY -DENABLE_CHS -DENABLE_DIVISION_ERROR -f elf -g -F dwarf -o obj/moondcrf.elf

# Second stage
bin/moondcr1.bin: src/moondcr1.asm src/common.inc gen/moondcr0.inc
	@printf $(BEGIN)$@$(END)
	mkdir -p bin
	nasm $< -DENABLE_LBA -DENABLE_MBR -f bin -o bin/moondcr1.bin -l gen/moondcr1.lst
	echo $$(src/helper.sh get_offset_dec gen/moondcr1.lst moondcr1_end) / 512

bin/moondcrg.bin: src/moondcr1.asm src/common.inc gen/moondcrf.inc
	@printf $(BEGIN)$@$(END)
	mkdir -p bin
	nasm $< -DENABLE_CHS -DENABLE_DIVISION_ERROR -f bin -o bin/moondcrg.bin -l gen/moondcrg.lst
	echo $$(src/helper.sh get_offset_dec gen/moondcrg.lst moondcr1_end) / 512

obj/moondcr1.elf: src/moondcr1.asm src/common.inc gen/moondcr0.inc
	@printf $(BEGIN)$@$(END)
	mkdir -p obj
	nasm $< -DDEBUG_ELF -DENABLE_LBA -DENABLE_MBR -f elf -g -F dwarf -o $@

obj/moondcrg.elf: src/moondcr1.asm src/common.inc gen/moondcrf.inc
	@printf $(BEGIN)$@$(END)
	mkdir -p obj
	nasm $< -DDEBUG_ELF -DENABLE_CHS -DENABLE_DIVISION_ERROR -f elf -g -F dwarf -o $@

# Third stage
bin/moondcr2.bin: src/moondcr2.asm src/common.inc
	@printf $(BEGIN)$@$(END)
	mkdir -p bin
	nasm $< -f bin -o $@
	stat --format="%s" $@

obj/moondcr2.elf: src/moondcr2.asm src/common.inc
	@printf $(BEGIN)$@$(END)
	mkdir -p obj
	nasm $< -DDEBUG_ELF -f elf -g -F dwarf -o $@

#########
# Extra #
#########

obj/print_mbr.elf: src/print_mbr.c
	@printf $(BEGIN)$@$(END)
	mkdir -p obj
	$(CC) src/print_mbr.c -o obj/print_mbr.elf
