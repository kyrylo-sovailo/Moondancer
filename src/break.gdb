define break0
    if $argc == 0
        break *($pc + 0x7C00)
    end
    if $argc == 1
        break *($arg0 + 0x7C00)
    end
    if $argc > 1
        printf "Invalid usage\n"
    end
end

define b0
    if $argc == 0
        break *($pc + 0x7C00)
    end
    if $argc == 1
        break *($arg0 + 0x7C00)
    end
    if $argc > 1
        printf "Invalid usage\n"
    end
end