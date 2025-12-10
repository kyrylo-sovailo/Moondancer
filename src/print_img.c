#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#pragma pack(1)

#define SECTOR_SIZE 512

struct Partition
{
    uint8_t attributes;
    uint8_t begin_chs[3];
    uint8_t type;
    uint8_t end_chs[3];
    uint32_t begin_lba_sc;
    uint32_t size_ct;
};

struct MBR
{
    char code[440];
    uint32_t disk_id;
    uint16_t reserved;
    struct Partition partitions[4];
    uint16_t signature;
};

struct BPB
{
    char jump[3];
    char type[8];
    uint16_t logical_sector_size_bt;
    uint8_t cluster_size_lsc;
    uint16_t reserved_size_lsc;
    uint8_t fat_number;
    uint16_t root_number;
    uint16_t size_lsc;          //Read ex_size_sc if size_sc is zero
    uint8_t media_type;
    uint16_t fat_size_lsc;      //Read ex_fat_size_sc instead of fat_size_sc if FAT32
    uint16_t track_size_lsc;
    uint16_t head_number;
    uint32_t hidden_size_lsc;
    uint32_t ex_size_lsc;       //Read ex_size_sc if size_sc is zero
};

struct FAT32_BPB
{
    struct BPB bpb;
    uint32_t ex_fat_size_lsc;   //Read ex_fat_size_sc instead of fat_size_sc if FAT32
    uint16_t flags;
    uint8_t version[2];
    uint32_t root_ct;
    uint16_t fsinfo_lsc;
    uint16_t backup_lsc;
    char reserved[12];
    uint8_t type;
    uint8_t nt;
    uint8_t signature;
    uint32_t volume_id;
    char label[11];
    char fs[8];
    char code[420];
    uint16_t signature2;
};

struct FSINFO
{
    uint32_t signature;
    char reserved[480];
    uint32_t signature2;
    uint32_t free_ct;
    uint32_t suggestion_ct;
    char reserved2[12];
    uint32_t signature3;
};

struct FAT32_FILE
{
    char name[11];
    uint8_t attributes;
    uint8_t nt;
    uint8_t creation;
    uint16_t creation_time;
    uint16_t creation_date;
    uint16_t access_date;
    uint16_t begin_ct_high;
    uint16_t modification_time;
    uint16_t modification_date;
    uint16_t begin_ct_low;
    uint32_t size_bt;
};

void read_lba(FILE *file, uint32_t lba_sc, char buffer[SECTOR_SIZE])
{
    printf("Read %08x: %08x-%08x\n", lba_sc, lba_sc * SECTOR_SIZE, lba_sc * SECTOR_SIZE + 511);
    if (fseek(file, lba_sc * SECTOR_SIZE, SEEK_SET) < 0 || fread(buffer, SECTOR_SIZE, 1, file) != 1)
    {
        fprintf(stderr, "Error reading LBA %u\n", lba_sc);
        exit(1);
    }
}

int main(void)
{
    printf("Sizes:\n");
    printf("sizeof(struct Partition)  == %d\n", (int)sizeof(struct Partition));
    printf("sizeof(struct MBR)        == %d\n", (int)sizeof(struct MBR));
    printf("sizeof(struct BPB)        == %d\n", (int)sizeof(struct BPB));
    printf("sizeof(struct FAT32_BPB)  == %d\n", (int)sizeof(struct FAT32_BPB));
    printf("sizeof(struct FSINFO)     == %d\n", (int)sizeof(struct FSINFO));
    printf("sizeof(struct FAT32_FILE) == %d\n", (int)sizeof(struct FAT32_FILE));
    printf("\n");

    //Open file
    FILE *file = fopen("img/mbr.img", "rb");
    if (file == NULL)
    {
        fprintf(stderr, "Error opening file\n");
        exit(1);
    }

    //Read MBR
    char buffer[SECTOR_SIZE];
    read_lba(file, 0, buffer);
    const uint32_t begin_lba_sc = ((struct MBR*)buffer)->partitions[0].begin_lba_sc;
    printf("MBR:\n");
    printf("disk_id      == %08x\n", ((struct MBR*)buffer)->disk_id);
    printf("reserved     == %04x\n", ((struct MBR*)buffer)->reserved);
    printf("signature    == %04x\n", ((struct MBR*)buffer)->signature);
    printf("\n");

    printf("Record 0:\n");
    printf("attributes   == %02x\n", ((struct MBR*)buffer)->partitions[0].attributes);
    printf("begin_chs    == %u %u %u\n", ((struct MBR*)buffer)->partitions[0].begin_chs[0], ((struct MBR*)buffer)->partitions[0].begin_chs[1], ((struct MBR*)buffer)->partitions[0].begin_chs[2]);
    printf("type         == %02x\n", ((struct MBR*)buffer)->partitions[0].type);
    printf("end_chs      == %u %u %u\n", ((struct MBR*)buffer)->partitions[0].end_chs[0], ((struct MBR*)buffer)->partitions[0].end_chs[1], ((struct MBR*)buffer)->partitions[0].end_chs[2]);
    printf("begin_lba_sc == %u\n", ((struct MBR*)buffer)->partitions[0].begin_lba_sc);
    printf("size_ct      == %u\n", ((struct MBR*)buffer)->partitions[0].size_ct);
    printf("\n");
    
    read_lba(file, begin_lba_sc, buffer);
    const uint16_t logical_sector_size_bt = ((struct BPB*)buffer)->logical_sector_size_bt;
    const uint8_t cluster_size_lsc = ((struct BPB*)buffer)->cluster_size_lsc;
    const uint16_t reserved_size_lsc = ((struct BPB*)buffer)->reserved_size_lsc;
    const uint8_t fat_number = ((struct BPB*)buffer)->fat_number;
    const uint16_t ex_fat_size_lsc = ((struct FAT32_BPB*)buffer)->ex_fat_size_lsc;
    const uint32_t root_ct = ((struct FAT32_BPB*)buffer)->root_ct;
    const uint16_t fsinfo_lsc = ((struct FAT32_BPB*)buffer)->fsinfo_lsc;
    const uint8_t logical_sector_size_sc = logical_sector_size_bt / SECTOR_SIZE;
    printf("BPB:\n");
    printf("logical_sector_size_bt == %d\n", ((struct BPB*)buffer)->logical_sector_size_bt);
    printf("cluster_size_lsc       == %d\n", ((struct BPB*)buffer)->cluster_size_lsc);
    printf("reserved_size_lsc      == %d\n", ((struct BPB*)buffer)->reserved_size_lsc);
    printf("fat_number             == %d\n", ((struct BPB*)buffer)->fat_number);
    printf("root_number            == %d\n", ((struct BPB*)buffer)->root_number);
    printf("size_lsc               == %d\n", ((struct BPB*)buffer)->size_lsc);
    printf("media_type             == %02x\n", ((struct BPB*)buffer)->media_type);
    printf("fat_size_lsc           == %d\n", ((struct BPB*)buffer)->fat_size_lsc);
    printf("track_size_lsc         == %d\n", ((struct BPB*)buffer)->track_size_lsc);
    printf("head_number            == %d\n", ((struct BPB*)buffer)->head_number);
    printf("hidden_size_lsc        == %d\n", ((struct BPB*)buffer)->hidden_size_lsc);
    printf("ex_size_lsc            == %d\n", ((struct BPB*)buffer)->ex_size_lsc);
    printf("\n");

    printf("FAT32_BPB:\n");
    printf("ex_fat_size_lsc == %d\n", ((struct FAT32_BPB*)buffer)->ex_fat_size_lsc);
    printf("flags           == %04x\n", ((struct FAT32_BPB*)buffer)->flags);
    printf("version         == %d %d\n", ((struct FAT32_BPB*)buffer)->version[0], ((struct FAT32_BPB*)buffer)->version[1]);
    printf("root_ct         == %d\n", ((struct FAT32_BPB*)buffer)->root_ct);
    printf("fsinfo_lsc      == %d\n", ((struct FAT32_BPB*)buffer)->fsinfo_lsc);
    printf("backup_lsc      == %d\n", ((struct FAT32_BPB*)buffer)->backup_lsc);
    printf("type            == %02x\n", ((struct FAT32_BPB*)buffer)->type);
    printf("signature       == %02x\n", ((struct FAT32_BPB*)buffer)->signature);
    printf("volume_id       == %08x\n", ((struct FAT32_BPB*)buffer)->volume_id);
    printf("label           == %11s\n", ((struct FAT32_BPB*)buffer)->label);
    printf("fs              == %8s\n", ((struct FAT32_BPB*)buffer)->fs);
    printf("ex_signature    == %04x\n", ((struct FAT32_BPB*)buffer)->signature2);
    printf("\n");

    printf("FSINFO:\n");
    read_lba(file, begin_lba_sc + logical_sector_size_sc * fsinfo_lsc, buffer);
    printf("signature     == %08x\n", ((struct FSINFO*)buffer)->signature);
    printf("signature2    == %08x\n", ((struct FSINFO*)buffer)->signature2);
    printf("free_ct       == %u\n", ((struct FSINFO*)buffer)->free_ct);
    printf("suggestion_ct == %u\n", ((struct FSINFO*)buffer)->suggestion_ct);
    printf("signature3    == %08x\n", ((struct FSINFO*)buffer)->signature3);
    printf("\n");

    uint32_t *fat = malloc(ex_fat_size_lsc * logical_sector_size_bt);
    for (uint32_t sc = 0; sc < logical_sector_size_sc * ex_fat_size_lsc; sc++)
    {
        read_lba(file, begin_lba_sc + logical_sector_size_sc * reserved_size_lsc + sc, ((char*)fat) + sc * SECTOR_SIZE);
    }
    for (uint32_t i = 0; i < 16; i++)
    {
        printf("Cluster %08x -> %08x\n", i, fat[i]);
    }
    printf("\n");

    char *cluster = malloc(cluster_size_lsc * logical_sector_size_bt);
    for (uint32_t sc = 0; sc < logical_sector_size_sc * cluster_size_lsc; sc++)
    {
        read_lba(file, begin_lba_sc + logical_sector_size_sc * (reserved_size_lsc + ex_fat_size_lsc * fat_number + (root_ct - 2) * cluster_size_lsc) + sc, cluster + sc * SECTOR_SIZE);
    }
    uint32_t file_ct = (uint32_t)-1;
    for (uint32_t i = 0; i < 16; i++)
    {
        printf("FAT32_FILE:\n");
        printf("name          == %11s\n", ((struct FAT32_FILE*)cluster)[i].name);
        printf("attributes    == %02x\n", ((struct FAT32_FILE*)cluster)[i].attributes);
        printf("creation      == %u\n", ((struct FAT32_FILE*)cluster)[i].creation);
        printf("begin_ct_high == %u\n", ((struct FAT32_FILE*)cluster)[i].begin_ct_high);
        printf("begin_ct_low  == %u\n", ((struct FAT32_FILE*)cluster)[i].begin_ct_low);
        printf("size_bt       == %u\n", ((struct FAT32_FILE*)cluster)[i].size_bt);
        if (memcmp(((struct FAT32_FILE*)cluster)[i].name, "MOONDCR1BIN", 11) == 0)
            file_ct = ((uint32_t)((struct FAT32_FILE*)cluster)[i].begin_ct_high << 16) + (uint32_t)((struct FAT32_FILE*)cluster)[i].begin_ct_low;
    }
    printf("\n");

    printf("file_ct == %d\n", file_ct);
    for (uint32_t sc = 0; sc < logical_sector_size_sc * cluster_size_lsc; sc++)
    {
        read_lba(file, begin_lba_sc + logical_sector_size_sc * (reserved_size_lsc + ex_fat_size_lsc * fat_number + (file_ct - 2) * cluster_size_lsc) + sc, cluster + sc * SECTOR_SIZE);
    }
    const char signature[] = { 0xBE, 0x17, 0x00, 0xE8 };
    printf("moondcr1.bin read %s\n", (memcmp(cluster, signature, sizeof(signature)) == 0) ? "correctly" : "incorrectly");
}
