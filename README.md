# Moondancer

### File organization

Images:
 - `mbr.img` - MBR disk image with `moondcr0.bin` embedded (can be flashed to hard drive)
 - `fat32.img` - FAT32 image with `moondcrf.bin` embedded (can be flashed to floppy)

Binaries:
 - `notboot0.bin` - MBR-embedded stub
 - `moondcr0.bin` - MBR-embedded minimal bootable, loads `moondcr1.bin` into memory
 - `moondcr1.bin` - Second part of `moondcr0.bin`
 - `moondcr2.bin` - Main assembly, runs hardware checks and enters long mode
 - `moondcr3.bin` - Main executable, runs in long mode
 - `notbootf.bin`, `moondcrf.bin`, `moondcrg.bin` - FAT32 versions of `notboot0.bin`, `moondcr0.bin`, and `moondcr1.bin`
