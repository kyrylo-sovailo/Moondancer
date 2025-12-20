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

.PHONY: debug
debug: img/mbr.img obj/moondcr0.elf
	@printf $(BEGIN_PHONY)$@$(END)
	qemu-system-x86_64 -machine accel=tcg -drive file=img/mbr.img,if=ide,media=disk,format=raw -S -s &
	gdb -ex "target remote :1234" -ex "symbol-file obj/moondcr0.elf" -ex "break *0x7c00" -ex "continue"

.PHONY: run_floppy
run_floppy: img/fat32.img
	@printf $(BEGIN_PHONY)$@$(END)
	qemu-system-x86_64 -machine accel=tcg -drive file=img/fat32.img,if=floppy,media=disk,format=raw

.PHONY: debug_floppy
debug_floppy: img/fat32.img obj/moondcrf.elf
	@printf $(BEGIN_PHONY)$@$(END)
	qemu-system-x86_64 -machine accel=tcg -drive file=img/fat32.img,if=floppy,media=disk,format=raw -S -s &
	gdb -ex "target remote :1234" -ex "symbol-file obj/moondcrf.elf" -ex "break *0x7c00" -ex "continue"

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
img/mbr.img: bin/notboot0.bin bin/moondcr0.bin bin/moondcr1.bin bin/notbootf.bin bin/moondcrf.bin bin/moondcrg.bin
	@printf $(BEGIN)$@$(END)
	mkdir -p img
	src/helper.sh create_mbr img/mbr.img

# FAT32 image
img/fat32.img: bin/notboot0.bin bin/moondcr0.bin bin/moondcr1.bin bin/notbootf.bin bin/moondcrf.bin bin/moondcrg.bin
	@printf $(BEGIN)$@$(END)
	mkdir -p img
	src/helper.sh create_fat32 img/fat32.img

############
# Binaries #
############

# Stubs
bin/notboot0.bin: src/notboot0.asm src/macro.inc
	@printf $(BEGIN)$@$(END)
	mkdir -p bin
	nasm src/notboot0.asm -DMBR_BINARY -f bin -o bin/notboot0.bin

bin/notbootf.bin: src/notboot0.asm src/macro.inc
	@printf $(BEGIN)$@$(END)
	mkdir -p bin
	nasm src/notboot0.asm -DFAT32_BINARY -f bin -o bin/notbootf.bin

obj/notboot0.elf: src/notboot0.asm src/macro.inc
	@printf $(BEGIN)$@$(END)
	mkdir -p obj
	nasm src/notboot0.asm -DMBR_BINARY -DDEBUG_ELF -f elf -g -F dwarf -o obj/notboot0.elf

obj/notbootf.elf: src/notboot0.asm src/macro.inc
	@printf $(BEGIN)$@$(END)
	mkdir -p obj
	nasm src/notboot0.asm -DFAT32_BINARY -DDEBUG_ELF -f elf -g -F dwarf -o obj/notbootf.elf

# First stage
obj/moondcr0.elf: src/moondcr0.asm src/macro.inc
	@printf $(BEGIN)$@$(END)
	mkdir -p obj
	nasm src/moondcr0.asm -DMBR_BINARY -DENABLE_LBA -DENABLE_MBR -DDEBUG_ELF -f elf -g -F dwarf -o obj/moondcr0.elf

obj/moondcrf.elf: src/moondcr0.asm src/macro.inc
	@printf $(BEGIN)$@$(END)
	mkdir -p obj
	nasm src/moondcr0.asm -DFAT32_BINARY -DENABLE_CHS -DENABLE_DIVISION_ERROR -DDEBUG_ELF -f elf -g -F dwarf -o obj/moondcrf.elf

bin/moondcr0.bin gen/moondcr0.inc: src/moondcr0.asm src/macro.inc
	@printf $(BEGIN)$@$(END)
	mkdir -p bin && mkdir -p gen
	nasm src/moondcr0.asm -DMBR_BINARY -DENABLE_LBA -DENABLE_MBR -f bin -o bin/moondcr0.bin -l gen/moondcr0.lst
	echo $$(src/helper.sh get_offset_dec gen/moondcr0.lst moondcr0_end) / 440
	: > gen/moondcr0.inc
	for f in infinite_loop read_sectors; do \
		echo $$f equ $$(src/helper.sh get_offset gen/moondcr0.lst "$$f") >> gen/moondcr0.inc ; \
	done

bin/moondcrf.bin gen/moondcrf.inc: src/moondcr0.asm src/macro.inc
	@printf $(BEGIN)$@$(END)
	mkdir -p bin && mkdir -p gen
	nasm src/moondcr0.asm -DFAT32_BINARY -DENABLE_CHS -DENABLE_DIVISION_ERROR -f bin -o bin/moondcrf.bin -l gen/moondcrf.lst
	echo $$(expr $$(src/helper.sh get_offset_dec gen/moondcrf.lst moondcr0_end) - 90) / 420
	: > gen/moondcrf.inc
	for f in infinite_loop read_sectors; do \
		echo $$f equ $$(src/helper.sh get_offset gen/moondcrf.lst "$$f") >> gen/moondcrf.inc ; \
	done

# Second stage
obj/moondcr1.elf: src/moondcr1.asm src/macro.inc gen/moondcr0.inc
	@printf $(BEGIN)$@$(END)
	mkdir -p obj
	nasm src/moondcr1.asm -DENABLE_LBA -DENABLE_MBR -DDEBUG_ELF -f elf -g -F dwarf -o obj/moondcr1.elf

obj/moondcrg.elf: src/moondcr1.asm src/macro.inc gen/moondcrf.inc
	@printf $(BEGIN)$@$(END)
	mkdir -p obj
	nasm src/moondcr1.asm -DENABLE_CHS -DENABLE_DIVISION_ERROR -DDEBUG_ELF -f elf -g -F dwarf -o obj/moondcrg.elf

bin/moondcr1.bin: src/moondcr1.asm src/macro.inc gen/moondcr0.inc
	@printf $(BEGIN)$@$(END)
	mkdir -p bin
	nasm src/moondcr1.asm -DENABLE_LBA -DENABLE_MBR -f bin -o bin/moondcr1.bin

bin/moondcrg.bin: src/moondcr1.asm src/macro.inc gen/moondcrf.inc
	@printf $(BEGIN)$@$(END)
	mkdir -p bin
	nasm src/moondcr1.asm -DENABLE_CHS -DENABLE_DIVISION_ERROR -f bin -o bin/moondcrg.bin

#########
# Extra #
#########

obj/print_mbr.elf: src/print_mbr.c
	@printf $(BEGIN)$@$(END)
	mkdir -p obj
	$(CC) src/print_mbr.c -o obj/print_mbr.elf
