; Binary format: FLAT_BINARY (default), MBR_BINARY, FAT32_BINARY
%ifdef FLAT_BINARY
    %ifdef MBR_BINARY
        %error "FLAT_BINARY is incompatible with MBR_BINARY"
    %endif
    %ifdef FAT32_BINARY
        %error "FLAT_BINARY is incompatible with FAT32_BINARY"
    %endif
%endif
%ifdef MBR_BINARY
    %ifdef FAT32_BINARY
        %error "MBR_BINARY is incompatible with FAT32_BINARY"
    %endif
%endif

%ifndef FLAT_BINARY
    %ifndef MBR_BINARY
        %ifndef FAT32_BINARY
            %define FLAT_BINARY
        %endif
    %endif
%endif

; Disk access mode: ENABLE_LBA (default), ENABLE_CHS
%ifdef ENABLE_LBA
    %ifdef ENABLE_CHS
        %error "ENABLE_LBA is incompatible with ENABLE_CHS"
    %endif
%endif

%ifndef ENABLE_LBA
    %ifndef ENABLE_CHS
        %define ENABLE_LBA
    %endif
%endif

; Binary flags: DEBUG_ELF, ENABLE_MBR