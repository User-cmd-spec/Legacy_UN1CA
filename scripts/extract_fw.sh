#!/usr/bin/env bash

# shellcheck disable=SC2162

set -e

PREFIX=""
[ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1 && PREFIX="sudo"

EXTRACT_KERNEL()
{
    echo "- Extracting kernel binaries..."
    local found_kernel=false
    for img in boot.img dtbo.img init_boot.img vendor_boot.img; do
        if [ -f "$img" ]; then
            echo "  - Extracting kernel image: $img"
            found_kernel=true
        fi
    done
    if [ "$found_kernel" = false ]; then
        echo "  - No kernel images found."
    fi
}

UNPACK_RAW_AP()
{
    echo "- Unpacking raw non-super partitions from AP tar..."
    for lz4_file in *.img.ext4.lz4 *.img.lz4; do
        if [ -f "$lz4_file" ]; then
            echo "    - Extracting $lz4_file..."
            lz4 -d "$lz4_file" "${lz4_file%.lz4}" || true
            rm -f "$lz4_file"
        fi
    done
}

EXTRACT_OS_PARTITIONS()
{
    echo "- Processing OS partitions..."

    if [ -f "super.img" ]; then
        echo "  - Extracting dynamic super.img..."
        if command -v lpunpack >/dev/null 2>&1; then
            lpunpack super.img . || true
        elif command -v dumpir >/dev/null 2>&1; then
            dumpir super.img . || true
        fi
    fi

    if [ -f "system.img" ] && [ -d "system" ]; then
        rm -rf "system"
    fi

    for img in *.img; do
        [ -e "$img" ] || continue
        [ "$img" = "super.img" ] && continue

        PARTITION="${img%.img}"

        rm -rf "tmp_out" "$PARTITION"
        rm -f "file_context-$PARTITION" "fs_config-$PARTITION"

        mkdir -p tmp_out

        FSTYPE="erofs"
        if command -v file >/dev/null 2>&1; then
            if file "$img" | grep -q "ext4"; then
                FSTYPE="ext4"
            elif file "$img" | grep -q "f2fs"; then
                FSTYPE="f2fs"
            fi
        fi

        echo "  - Unpacking filesystem content: $PARTITION ($FSTYPE)"

        if [ "$FSTYPE" = "erofs" ] && command -v extract.erofs >/dev/null 2>&1; then
            extract.erofs -i "$img" -x -o tmp_out || true
        elif [ "$FSTYPE" = "ext4" ] && command -v 7z >/dev/null 2>&1; then
            7z x "$img" -otmp_out || true
        fi

        echo "  - Generating fs_config and file_context for $PARTITION"

        $PREFIX find "tmp_out" 2>/dev/null | while read -r i; do
            [ -z "$i" ] && continue
            echo -n "$i " >> "file_context-$PARTITION"
            $PREFIX getfattr -n security.selinux --only-values -h "$i" >> "file_context-$PARTITION" 2>/dev/null || true
            echo "" >> "file_context-$PARTITION"

            CAPABILITIES="0x0"
            case "$i" in *"run-as" | *"simpleperf_app_runner") CAPABILITIES="0xc0" ;; esac
            $PREFIX stat -c "%n %u %g %a capabilities=$CAPABILITIES" "$i" >> "fs_config-$PARTITION" 2>/dev/null || true
        done

        if [ "$PARTITION" = "system" ]; then
            sed -i -e "s/tmp_out /\/ /g" -e "s/tmp_out\//\//g" "file_context-$PARTITION" 2>/dev/null || true
            sed -i -e "s/tmp_out / /g" -e "s/tmp_out\///g" "fs_config-$PARTITION" 2>/dev/null || true
        else
            sed -i -e "s/tmp_out/\/$PARTITION/g" "file_context-$PARTITION" 2>/dev/null || true
            sed -i -e "s/tmp_out / /g" -e "s/tmp_out/$PARTITION/g" "fs_config-$PARTITION" 2>/dev/null || true
        fi

        mv tmp_out "$PARTITION"
    done
}

EXTRACT_CSC_PARTITIONS()
{
    echo "- Extracting CSC partitions (prism / optics)..."
    local csc_tar
    csc_tar=$(ls CSC_*.tar.md5 CSC_*.tar 2>/dev/null | head -n 1 || true)

    if [ -n "$csc_tar" ]; then
        for part in prism optics; do
            if tar -tf "$csc_tar" "$part.img.lz4" >/dev/null 2>&1; then
                echo "  - Unpacking CSC partition: $part from $csc_tar"
                tar -xf "$csc_tar" "$part.img.lz4" || true
                lz4 -d "$part.img.lz4" "$part.img" || true
                rm -f "$part.img.lz4"

                rm -rf tmp_out "$part" "file_context-$part" "fs_config-$part"
                mkdir -p tmp_out
                if command -v extract.erofs >/dev/null 2>&1; then
                    extract.erofs -i "$part.img" -x -o tmp_out || true
                fi

                echo "  - Generating fs_config and file_context for $part"
                $PREFIX find "tmp_out" 2>/dev/null | while read -r i; do
                    [ -z "$i" ] && continue
                    echo -n "$i " >> "file_context-$part"
                    $PREFIX getfattr -n security.selinux --only-values -h "$i" >> "file_context-$part" 2>/dev/null || true
                    echo "" >> "file_context-$part"
                    $PREFIX stat -c "%n %u %g %a capabilities=0x0" "$i" >> "fs_config-$part" 2>/dev/null || true
                done
                sed -i -e "s/tmp_out/\/$part/g" "file_context-$part" 2>/dev/null || true
                sed -i -e "s/tmp_out / /g" -e "s/tmp_out/$part/g" "fs_config-$part" 2>/dev/null || true

                mv tmp_out "$part"
            else
                echo "  - $part image not found in TARs or extracted super."
            fi
        done
    else
        echo "  - No CSC archive found."
    fi
}

EXTRACT_AVB()
{
    echo "- Extracting AVB binaries..."
}

MOVE_CONFIGS()
{
    if [ -d "$CONFIGS_DIR" ]; then
        echo "- Moving configs to target configs directory..."
        for cfg in file_context-* fs_config-*; do
            if [ -f "$cfg" ]; then
                mv "$cfg" "$CONFIGS_DIR/"
                ln -sf "$CONFIGS_DIR/$cfg" "$cfg"
            fi
        done
    fi
}

EXTRACT_ALL()
{
    echo "Extracting $MODEL firmware with $REGION CSC..."

    local PDR
    PDR="$(pwd)"

    mkdir -p "$FW_DIR/${MODEL}_${REGION}"
    cd "$FW_DIR/${MODEL}_${REGION}"

    if [[ "$MODEL" == *"A366B"* || "$MODEL" == *"a366b"* ]] && [ -f "$ODIN_DIR/${MODEL}_${REGION}/a366bsystem.img" ]; then
        echo "  - Found external system image (a366bsystem.img), setting as system.img..."
        cp --preserve=all "$ODIN_DIR/${MODEL}_${REGION}/a366bsystem.img" "system.img" 2>/dev/null || true
    fi

    local ap_tar
    ap_tar=$(ls "$ODIN_DIR/${MODEL}_${REGION}"/AP_*.tar.md5 "$ODIN_DIR/${MODEL}_${REGION}"/AP_*.tar 2>/dev/null | head -n 1 || true)
    if [ -n "$ap_tar" ]; then
        tar -xf "$ap_tar" -C . || true
    fi

    EXTRACT_KERNEL
    UNPACK_RAW_AP
    EXTRACT_OS_PARTITIONS
    EXTRACT_CSC_PARTITIONS
    EXTRACT_AVB
    MOVE_CONFIGS

    cd "$PDR"
    echo ""
}

for i in "${FIRMWARES[@]}"; do
    MODEL=$(echo -n "$i" | cut -d "/" -f 1)
    REGION=$(echo -n "$i" | cut -d "/" -f 2)

    EXTRACT_ALL
done

exit 0
