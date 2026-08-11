#!/usr/bin/env bash
#
# Copyright (C) 2023 Salvo Giangreco
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# Disable strict error halting so non-fatal command failures don't stop execution
set +e

GET_LATEST_FIRMWARE() {
    curl -s --retry 5 --retry-delay 5 "https://fota-cloud-dn.ospserver.net/firmware/$REGION/$MODEL/version.xml" 2>/dev/null | grep latest | sed -e 's/^[^>]*>//' -e 's/<.*//'
}

GET_IMG_FS_TYPE() {
    if [[ "$(xxd -p -l "2" --skip "1080" "$1" 2>/dev/null)" == "53ef" ]]; then echo "ext4"
    elif [[ "$(xxd -p -l "4" --skip "1024" "$1" 2>/dev/null)" == "1020f5f2" ]]; then echo "f2fs"
    elif [[ "$(xxd -p -l "4" --skip "1024" "$1" 2>/dev/null)" == "e2e1f5e0" ]]; then echo "erofs"
    else echo "unknown"; fi
}

_MOVE_CONFIGS() {
    mkdir -p configs 2>/dev/null
    for cfg in fs_config-* file_context-*; do
        [ -f "$cfg" ] && mv "$cfg" configs/ 2>/dev/null
    done
}

EXTRACT_KERNEL_BINARIES() {
    local PDR="$(pwd)"
    echo "- Extracting kernel binaries..."
    cd "$FW_DIR/${MODEL}_${REGION}" 2>/dev/null || return 0
    for file in boot.img.lz4 dtbo.img.lz4 init_boot.img.lz4 vendor_boot.img.lz4; do
        [ -f "${file%.lz4}" ] && continue
        tar tf "$AP_TAR" "$file" &>/dev/null || continue
        echo "  - Extracting kernel image: ${file%.lz4}"
        tar xf "$AP_TAR" "$file" 2>/dev/null && lz4 -d -q --rm "$file" "${file%.lz4}" 2>/dev/null
    done
    cd "$PDR"
}

EXTRACT_CSC_PARTITIONS() {
    local PDR="$(pwd)"
    echo "- Extracting CSC partitions..."
    cd "$FW_DIR/${MODEL}_${REGION}" 2>/dev/null || return 0
    for file in prism.img.lz4 optics.img.lz4; do
        [ -f "${file%.lz4}" ] && continue
        tar tf "$CSC_TAR" "$file" &>/dev/null || continue
        echo "  - Unpacking CSC partition: ${file%.img.lz4}"
        tar xf "$CSC_TAR" "$file" 2>/dev/null && lz4 -d -q --rm "$file" "${file%.lz4}.sparse" 2>/dev/null
        simg2img "${file%.lz4}.sparse" "${file%.lz4}" 2>/dev/null
        rm -f "${file%.lz4}.sparse"

        if [ -d "tmp_out" ]; then
            if mountpoint -q "tmp_out"; then sudo umount "tmp_out" 2>/dev/null; fi
        fi
        mkdir -p "tmp_out"

        PREFIX="sudo"
        rm -rf "${file%.img.lz4}" && mkdir -p "${file%.img.lz4}"
        $PREFIX mount -o ro "${file%.lz4}" "tmp_out" 2>/dev/null
        $PREFIX cp -a --preserve=all tmp_out/* "${file%.img.lz4}" 2>/dev/null
        
        $PREFIX find "${file%.img.lz4}" -print0 2>/dev/null | while IFS= read -r -d '' i; do
            $PREFIX chown -h "$(whoami)":"$(whoami)" "$i" 2>/dev/null || true
        done
        [[ -e "${file%.img.lz4}/lost+found" ]] && rm -rf "${file%.img.lz4}/lost+found"

        echo "  - Generating fs_config and file_context for ${file%.img.lz4}"
        rm -f "file_context-${file%.img.lz4}" "fs_config-${file%.img.lz4}"
        
        $PREFIX find "tmp_out" 2>/dev/null | while read -r i; do
            [ -z "$i" ] && continue
            echo -n "$i " >> "file_context-${file%.img.lz4}"
            $PREFIX getfattr -n security.selinux --only-values -h "$i" >> "file_context-${file%.img.lz4}" 2>/dev/null
            echo "" >> "file_context-${file%.img.lz4}"

            CAPABILITIES="0x0"
            case "$i" in *"run-as" | *"simpleperf_app_runner") CAPABILITIES="0xc0" ;; esac
            $PREFIX stat -c "%n %u %g %a capabilities=$CAPABILITIES" "$i" >> "fs_config-${file%.img.lz4}" 2>/dev/null
        done

        sed -i -e "s/tmp_out/\/${file%.img.lz4}/g" -e "s/\x0//g" -e 's/\./\\./g' -e 's/\+/\\+/g' -e 's/\[/\\[/g' "file_context-${file%.img.lz4}" 2>/dev/null
        sed -i -e "s/tmp_out / /g" -e "s/tmp_out/${file%.img.lz4}/g" "fs_config-${file%.img.lz4}" 2>/dev/null

        $PREFIX umount "tmp_out" 2>/dev/null
        rm -rf "${file%.lz4}" "tmp_out"
    done
    _MOVE_CONFIGS
    cd "$PDR"
}

EXTRACT_OS_PARTITIONS() {
    local PDR="$(pwd)" SHOULD_EXTRACT=false SHOULD_EXTRACT_SUPER=false PARTITION_MASK=".img" HAS_SUPER=false
    cd "$FW_DIR/${MODEL}_${REGION}" 2>/dev/null || return 0

    if tar tf "$AP_TAR" "super.img.lz4" >/dev/null 2>&1; then
        HAS_SUPER=true
    else
        echo "- Unpacking raw non-super partitions from AP tar..."
        for part in system vendor product odm; do
            for ext in "${part}.img.ext4.lz4" "${part}.img.lz4"; do
                if tar tf "$AP_TAR" "$ext" >/dev/null 2>&1; then
                    echo "  - Extracting ${ext}..."
                    tar xf "$AP_TAR" "$ext" 2>/dev/null
                    lz4 -d -q --rm "$ext" "${part}.img.sparse" 2>/dev/null
                    simg2img "${part}.img.sparse" "${part}.img" 2>/dev/null
                    rm -f "${part}.img.sparse"
                    break
                fi
            done
        done
    fi
    echo "- Processing OS partitions..."

    for folder in odm product system vendor; do
        [ ! -d "$folder" ] && SHOULD_EXTRACT=true
        [ ! -f "$folder.img" ] && SHOULD_EXTRACT_SUPER=true
    done

    if $SHOULD_EXTRACT; then
        if [ "$HAS_SUPER" = true ] && { [ ! -f "lpdump" ] || $SHOULD_EXTRACT_SUPER; }; then
            echo "  - Extracting dynamic super.img..."
            tar xf "$AP_TAR" "super.img.lz4" 2>/dev/null
            lz4 -d -q --rm "super.img.lz4" "super.img.sparse" 2>/dev/null
            simg2img "super.img.sparse" "super.img" 2>/dev/null
            rm -f "super.img.sparse"
            { lpunpack "super.img" > /dev/null; } 2>&1
            lpdump "super.img" > "lpdump" 2>/dev/null
            rm -f "super.img"
            [ -f "system_a.img" ] && PARTITION_MASK="_a.img"
        fi

        if [ -d "tmp_out" ]; then
            if mountpoint -q "tmp_out"; then sudo umount "tmp_out" 2>/dev/null; fi
        fi
        mkdir -p "tmp_out"

        for img in *.img; do
            [ -f "$img" ] || continue
            local PARTITION="${img%$PARTITION_MASK}" PREFIX=""
            local FS_TYPE="$(GET_IMG_FS_TYPE "$img")"

            if [ "$FS_TYPE" != "unknown" ]; then
                echo "  - Unpacking filesystem content: ${PARTITION} ($FS_TYPE)"
            fi

            case "$FS_TYPE" in
                "erofs")
                    rm -rf "$PARTITION" && mkdir -p "$PARTITION"
                    fuse.erofs "$img" "tmp_out" &>/dev/null
                    cp -a --preserve=all tmp_out/* "$PARTITION" 2>/dev/null
                    ;;
                "f2fs" | "ext4")
                    PREFIX="sudo"
                    rm -rf "$PARTITION" && mkdir -p "$PARTITION"
                    $PREFIX mount -o ro "$img" "tmp_out" 2>/dev/null
                    $PREFIX cp -a --preserve=all tmp_out/* "$PARTITION" 2>/dev/null
                    $PREFIX find "$PARTITION" -print0 2>/dev/null | while IFS= read -r -d '' i; do
                        $PREFIX chown -h "$(whoami)":"$(whoami)" "$i" 2>/dev/null || true
                    done
                    [[ -e "$PARTITION/lost+found" ]] && rm -rf "$PARTITION/lost+found"
                    ;;
                *) continue ;;
            esac

            echo "  - Generating fs_config and file_context for ${PARTITION}"
            rm -f "file_context-$PARTITION" "fs_config-$PARTITION"
            $PREFIX find "tmp_out" 2>/dev/null | while read -r i; do
                [ -z "$i" ] && continue
                echo -n "$i " >> "file_context-$PARTITION"
                $PREFIX getfattr -n security.selinux --only-values -h "$i" >> "file_context-$PARTITION" 2>/dev/null
                echo "" >> "file_context-$PARTITION"

                CAPABILITIES="0x0"
                case "$i" in *"run-as" | *"simpleperf_app_runner") CAPABILITIES="0xc0" ;; esac
                $PREFIX stat -c "%n %u %g %a capabilities=$CAPABILITIES" "$i" >> "fs_config-$PARTITION" 2>/dev/null
            done

            if [ "$PARTITION" = "system" ]; then
                sed -i -e "s/tmp_out /\/ /g" -e "s/tmp_out\//\//g" "file_context-$PARTITION" 2>/dev/null
                sed -i -e "s/tmp_out / /g" -e "s/tmp_out\///g" "fs_config-$PARTITION" 2>/dev/null
            else
                sed -i -e "s/tmp_out/\/$PARTITION/g" "file_context-$PARTITION" 2>/dev/null
                sed -i -e "s/tmp_out / /g" -e "s/tmp_out/$PARTITION/g" "fs_config-$PARTITION" 2>/dev/null
            fi
            sed -i -e "s/\x0//g" -e 's/\./\\./g' -e 's/\+/\\+/g' -e 's/\[/\\[/g' "file_context-$PARTITION" 2>/dev/null

            $PREFIX umount "tmp_out" 2>/dev/null
            rm -f "$img"
        done
        rm -rf "tmp_out"
    fi
    _MOVE_CONFIGS
    cd "$PDR"
}

EXTRACT_AVB_BINARIES() {
    local PDR="$(pwd)"
    echo "- Extracting AVB binaries..."
    cd "$FW_DIR/${MODEL}_${REGION}" 2>/dev/null || return 0
    if [ ! -f "vbmeta.img" ] && tar tf "$BL_TAR" "vbmeta.img.lz4" &>/dev/null; then
        echo "  - Extracting vbmeta.img"
        tar xf "$BL_TAR" "vbmeta.img.lz4" 2>/dev/null && lz4 -d -q --rm "vbmeta.img.lz4" "vbmeta.img" 2>/dev/null
    fi
    if [ ! -f "vbmeta_patched.img" ] && [ -f "vbmeta.img" ]; then
        echo "  - Generating vbmeta_patched.img"
        cp --preserve=all "vbmeta.img" "vbmeta_patched.img" 2>/dev/null
        printf "\x03" | dd of="vbmeta_patched.img" bs=1 seek=123 count=1 conv=notrunc &> /dev/null
    fi
    cd "$PDR"
}

EXTRACT_ALL() {
    BL_TAR=$(find "$ODIN_DIR/${MODEL}_${REGION}" -name "BL*" 2>/dev/null | head -n 1)
    CSC_TAR=$(find "$ODIN_DIR/${MODEL}_${REGION}" -name "CSC*" 2>/dev/null | head -n 1)
    AP_TAR=$(find "$ODIN_DIR/${MODEL}_${REGION}" -name "AP*" 2>/dev/null | head -n 1)

    mkdir -p "$FW_DIR/${MODEL}_${REGION}" 2>/dev/null
    EXTRACT_KERNEL_BINARIES
    EXTRACT_CSC_PARTITIONS
    EXTRACT_OS_PARTITIONS
    EXTRACT_AVB_BINARIES

    cp --preserve=all "$ODIN_DIR/${MODEL}_${REGION}/.downloaded" "$FW_DIR/${MODEL}_${REGION}/.extracted" 2>/dev/null || true
    echo ""
}

FIRMWARES=( "$SOURCE_FIRMWARE" )
IFS=':' read -a TARGET_FIRMWARE <<< "$TARGET_FIRMWARE"
[ "${#TARGET_FIRMWARE[@]}" -ge 1 ] && FIRMWARES+=("${TARGET_FIRMWARE[@]}")
IFS=':' read -a SOURCE_EXTRA_FIRMWARES <<< "$SOURCE_EXTRA_FIRMWARES"
[ "${#SOURCE_EXTRA_FIRMWARES[@]}" -ge 1 ] && FIRMWARES+=("${SOURCE_EXTRA_FIRMWARES[@]}")
IFS=':' read -a TARGET_EXTRA_FIRMWARES <<< "$TARGET_EXTRA_FIRMWARES"
[ "${#TARGET_EXTRA_FIRMWARES[@]}" -ge 1 ] && FIRMWARES+=("${TARGET_EXTRA_FIRMWARES[@]}")

FORCE=false
while [ "$#" != 0 ]; do
    case "$1" in
        "-f" | "--force") FORCE=true ;;
        *) echo -e "Usage: extract_fw [options]\n -f, --force : Force firmware extraction"; exit 0 ;;
    esac
    shift
done

mkdir -p "$FW_DIR" 2>/dev/null

for i in "${FIRMWARES[@]}"; do
    [ -z "$i" ] && continue
    MODEL=$(echo -n "$i" | cut -d "/" -f 1)
    REGION=$(echo -n "$i" | cut -d "/" -f 2)

    if [ -f "$FW_DIR/${MODEL}_${REGION}/.extracted" ]; then
        [ -z "$(GET_LATEST_FIRMWARE)" ] && continue
        if [ -f "$ODIN_DIR/${MODEL}_${REGION}/.downloaded" ] && [[ "$(cat "$ODIN_DIR/${MODEL}_${REGION}/.downloaded" 2>/dev/null)" != "$(cat "$FW_DIR/${MODEL}_${REGION}/.extracted" 2>/dev/null)" ]]; then
            if $FORCE; then
                echo "- Updating $MODEL firmware with $REGION CSC..."
                rm -rf "$FW_DIR/${MODEL}_${REGION}" && EXTRACT_ALL
            else
                echo -e "- $MODEL firmware with $REGION CSC is already extracted.\n  A newer version is available.\n  Clean extracted directory or use \"--force\"\n"
                continue
            fi
        elif [[ "$(GET_LATEST_FIRMWARE)" != "$(cat "$FW_DIR/${MODEL}_${REGION}/.extracted" 2>/dev/null)" ]]; then
            echo -e "- $MODEL firmware with $REGION CSC is already extracted.\n  A newer version is available.\n  Download firmware using \"download_fw\" first\n"
            continue
        else
            echo -e "- $MODEL firmware with $REGION CSC is already extracted. Skipping...\n"
            continue
        fi
    elif [ -f "$ODIN_DIR/${MODEL}_${REGION}/.downloaded" ]; then
        echo -e "- Extracting $MODEL firmware with $REGION CSC...\n"
        EXTRACT_ALL
    else
        echo -e "- $MODEL firmware with $REGION CSC is not downloaded.\n  Please download it first using \"download_fw\"\n"
        continue
    fi
done

exit 0
