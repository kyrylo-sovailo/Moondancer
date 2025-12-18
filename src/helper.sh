#!/usr/bin/env sh

# Hard constants
KB=$(expr 1024)
MB=$(expr 1024 \* 1024)
GB=$(expr 1024 \* 1024 \* 1024)
SECTOR_SIZE_BT=512

# Filesystem-related calculations
FAT32_SECTOR_SIZE_BT=512
FAT32_HEADS=2
FAT32_SECTORS_PER_TRACK=18
FAT32_CYLINDERS=80
FAT32_SIZE_SC=$(expr $FAT32_HEADS \* $FAT32_SECTORS_PER_TRACK \* $FAT32_CYLINDERS)
FAT32_SIZE_BT=$(expr $FAT32_SIZE_SC \* $SECTOR_SIZE_BT)
FAT32_OFFSET_SC=1 #Usually 2048, but 1 for small drives
FAT32_OFFSET_BT=$(expr $FAT32_OFFSET_SC \* $SECTOR_SIZE_BT)

# Disk-related calculations
MBR_SIZE_SC=$(expr $FAT32_SIZE_SC + $FAT32_OFFSET_SC)
MBR_SIZE_BT=$(expr $MBR_SIZE_SC \* $SECTOR_SIZE_BT)

die() {
    echo "helper.py: $*" >&2
    exit 1
}

# Create MBR image with one FAT32 partition
if [ "$1" = "create_mbr" ]; then
    test -n "$2" || die "File not provided"
    test -z "$3" || die "Too many arguments"
    CONTAINER="$2"
    
    trap 'rm -f "$CONTAINER"' EXIT
    if [ ! -f "$CONTAINER" ]; then
        dd if=/dev/zero bs=$SECTOR_SIZE_BT count=$MBR_SIZE_SC of="$CONTAINER" || die "dd failed"
        REAL_INFO=$(fdisk "$CONTAINER" < src/mbr.fdisk | tr -d '*' | grep -o -E '.img1[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+' | xargs) || exit 1
        REAL_FAT32_OFFSET_SC=$(echo $REAL_INFO | cut -d ' ' -f 2)
        REAL_FAT32_SIZE_SC=$(echo $REAL_INFO | cut -d ' ' -f 4)
        echo REAL_FAT32_OFFSET_SC=$REAL_FAT32_OFFSET_SC
        echo REAL_FAT32_SIZE_SC=$REAL_FAT32_SIZE_SC
        test "$REAL_FAT32_OFFSET_SC" = "$FAT32_OFFSET_SC" || die "real partition offset does not match expected offset"
        test "$REAL_FAT32_SIZE_SC" = "$FAT32_SIZE_SC" || die "real partition size does not match expected size"
        
        mformat -i "$CONTAINER"@@$FAT32_OFFSET_BT -F -v 'MOONDCR0' -M $FAT32_SECTOR_SIZE_BT -T $FAT32_SIZE_SC || die "mformat failed"
        FAT32_OFFSET_BT_11=$(expr $FAT32_OFFSET_BT + 11)
        REAL_FAT32_SECTOR_SIZE_BT=$(dd if="$CONTAINER" bs=1 skip=$FAT32_OFFSET_BT_11 count=2 | od -An -t u1 | xargs)
        REAL_FAT32_SECTOR_SIZE_BT_LOW=$(echo $REAL_FAT32_SECTOR_SIZE_BT | cut -d ' ' -f 1)
        REAL_FAT32_SECTOR_SIZE_BT_HIGH=$(echo $REAL_FAT32_SECTOR_SIZE_BT | cut -d ' ' -f 2)
        REAL_FAT32_SECTOR_SIZE_BT=$(expr 256 \* $REAL_FAT32_SECTOR_SIZE_BT_HIGH + $REAL_FAT32_SECTOR_SIZE_BT_LOW)
        echo REAL_FAT32_SECTOR_SIZE_BT=$REAL_FAT32_SECTOR_SIZE_BT
        test "$REAL_FAT32_SECTOR_SIZE_BT" = "$FAT32_SECTOR_SIZE_BT" || die "real partition's sector size does not match expected size"
    fi

    dd if=bin/moondcr0.bin bs=1 count=446 conv=notrunc of="$CONTAINER" || die "flashing moondcr0.bin failed"
    FAT32_OFFSET_BT_90=$(expr $FAT32_OFFSET_BT + 90)
    dd if=bin/notbootf.bin bs=1 seek=$FAT32_OFFSET_BT count=3 conv=notrunc of="$CONTAINER" || die "flashing notbootf.bin failed"
    dd if=bin/notbootf.bin bs=1 skip=90 seek=$FAT32_OFFSET_BT_90 count=420 conv=notrunc of="$CONTAINER" || die "flashing notbootf.bin failed"
    trap - EXIT

# Create FAT32 image
elif [ "$1" = "create_fat32" ]; then
    test -n "$2" || die "File not provided"
    test -z "$3" || die "Too many arguments"
    CONTAINER="$2"
    
    trap 'rm -f "$CONTAINER"' EXIT
    if [ ! -f "$CONTAINER" ]; then
        dd if=/dev/zero bs=$SECTOR_SIZE_BT count=$FAT32_SIZE_SC of="$CONTAINER" || die "dd failed"

        mformat -i "$CONTAINER" -F -v 'MOONDCRF' -M $FAT32_SECTOR_SIZE_BT -T $FAT32_SIZE_SC || die "mformat failed"
        REAL_FAT32_SECTOR_SIZE_BT=$(dd if="$CONTAINER" bs=1 skip=11 count=2 | od -An -t u1 | xargs)
        REAL_FAT32_SECTOR_SIZE_BT_LOW=$(echo $REAL_FAT32_SECTOR_SIZE_BT | cut -d ' ' -f 1)
        REAL_FAT32_SECTOR_SIZE_BT_HIGH=$(echo $REAL_FAT32_SECTOR_SIZE_BT | cut -d ' ' -f 2)
        REAL_FAT32_SECTOR_SIZE_BT=$(expr 256 \* $REAL_FAT32_SECTOR_SIZE_BT_HIGH + $REAL_FAT32_SECTOR_SIZE_BT_LOW)
        echo REAL_FAT32_SECTOR_SIZE_BT=$REAL_FAT32_SECTOR_SIZE_BT
        test "$REAL_FAT32_SECTOR_SIZE_BT" = "$FAT32_SECTOR_SIZE_BT" || die "real partition's sector size does not match expected size"
    fi
    dd if=bin/moondcrf.bin bs=1 count=3 conv=notrunc of="$CONTAINER" || die "flashing moondcrf.bin failed"
    dd if=bin/moondcrf.bin bs=1 skip=90 seek=90 count=420 conv=notrunc of="$CONTAINER" || die "flashing moondcrf.bin failed"
    trap - EXIT

# Copy a file into the FAT32 partition of the MBR image
elif [ "$1" = "copy_to_mbr" ]; then
    test -f "$2" || die "File does not exist"
    test -f "$3" || die "File does not exist"
    test -n "$4" || die "Destination not provided"
    test -z "$5" || die "Too many arguments"
    CONTAINER="$2"
    FILE="$3"
    DESTINATION="$4"

    trap 'rm -f "$CONTAINER"' EXIT
    mcopy -i "$CONTAINER"@@$FAT32_OFFSET_BT "$FILE" ::"$DESTINATION" -o || die "mcopy failed"
    trap - EXIT

# Copy a file into the FAT32 image
elif [ "$1" = "copy_to_fat32" ]; then
    test -f "$2" || die "File does not exist"
    test -f "$3" || die "File does not exist"
    test -n "$4" || die "Destination not provided"
    test -z "$5" || die "Too many arguments"
    CONTAINER="$2"
    FILE="$3"
    DESTINATION="$4"

    trap 'rm -f "$CONTAINER"' EXIT
    mcopy -i "$CONTAINER" "$FILE" ::"$DESTINATION" -o || die "mcopy failed"
    trap - EXIT

# Get decimal label offset/address
elif [ "$1" = "get_offset_dec" ]; then
    test -f "$2" || die "File does not exist"
    test -n "$3" || die "Label not provided"
    test -z "$4" || die "Too many arguments"
    LISTING="$2"
    LABEL="$3"

    HEX=$(grep "$LABEL:" "$LISTING" -A10 | grep -o -E '^[ ]*[0-9]+ [0-9A-F]+ [0-9A-F]+' | head -n 1 | xargs | cut -d ' ' -f 2)
    printf '%d\n' "0x$HEX"

# Get hexadecimal label offset/address
elif [ "$1" = "get_offset" ]; then
    test -f "$2" || die "File does not exist"
    test -n "$3" || die "Label not provided"
    test -z "$4" || die "Too many arguments"
    LISTING="$2"
    LABEL="$3"

    HEX=$(grep "$LABEL:" "$LISTING" -A10 | grep -o -E '^[ ]*[0-9]+ [0-9A-F]+ [0-9A-F]+' | head -n 1 | xargs | cut -d ' ' -f 2)
    echo 0x$HEX

# Invalid usage
else
    die "Invalid operation"
fi