#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

CONFIGS_DIR="${CONFIGS_DIR:-configs}"

die()
{
    echo "ERROR: $*" >&2
    exit 1
}

have()
{
    command -v "$1" >/dev/null 2>&1
}

cleanup_tmp()
{
    rm -rf -- tmp_out
}

detect_fstype()
{
    local img="$1"
    local result="unknown"

    if have file; then
        result="$(file -b "$img" 2>/dev/null || true)"

        case "$result" in
            *"EROFS"*|*"EROFS filesystem"*)
                echo "erofs"
                return
                ;;
            *"ext4 filesystem"*|*"Linux rev 1.0 ext4 filesystem"*)
                echo "ext4"
                return
                ;;
            *"F2FS filesystem"*)
                echo "f2fs"
                return
                ;;
        esac
    fi

    if have xxd; then
        local magic
        magic="$(
            dd \
                if="$img" \
                bs=1 \
                skip=1024 \
                count=4 \
                2>/dev/null |
            xxd \
                -p \
                -c 4 \
            || true
        )"

        if [[ "$magic" == "e2e1f5e0" ]]; then
            echo "erofs"
            return
        fi
    fi

    echo "$result"
}

EXTRACT_KERNEL()
{
    echo "- Checking kernel images..."

    local found_kernel=false

    for img in boot.img dtbo.img init_boot.img vendor_boot.img; do
        if [[ -f "$img" ]]; then
            echo "  - Found: $img"
            found_kernel=true
        fi
    done

    if [[ "$found_kernel" == false ]]; then
        echo "  - No kernel images found."
    fi
}

UNPACK_RAW_AP()
{
    echo "- Unpacking compressed AP images..."

    local found=false

    shopt -s nullglob

    local files=(
        *.img.ext4.lz4
        *.img.lz4
        *.lz4
    )

    shopt -u nullglob

    for lz4_file in "${files[@]}"; do
        [[ -f "$lz4_file" ]] || continue

        found=true

        local output="${lz4_file%.lz4}"

        echo "  - Decompressing: $lz4_file -> $output"

        if ! have lz4; then
            die "lz4 is required to decompress $lz4_file"
        fi

        lz4 \
            -d \
            -q \
            -f \
            "$lz4_file" \
            "$output"

        rm -f -- "$lz4_file"
    done

    if [[ "$found" == false ]]; then
        echo "  - No compressed images found."
    fi
}

EXTRACT_FILESYSTEM()
{
    local img="$1"
    local output="$2"
    local fstype="$3"

    mkdir -p "$output"

    case "$fstype" in

        erofs)
            if have extract.erofs; then
                echo "    - Using extract.erofs"

                $(command -v extract.erofs) \
                    -i "$img" \
                    -x \
                    -o "$output"

            elif have fsck.erofs; then
                echo "    - Using fsck.erofs"

                $(command -v fsck.erofs) \
                    --extract="$output" \
                    "$img"

            elif have 7z; then
                echo "    - WARNING: Using 7z fallback for EROFS"

                $(command -v 7z) \
                    x \
                    -bd \
                    "$img" \
                    "-o$output"

            else
                die "No EROFS extractor found. Install erofs-utils."
            fi
            ;;

        ext4)
            if have 7z; then
                echo "    - Using 7z"

                $(command -v 7z) \
                    x \
                    -bd \
                    "$img" \
                    "-o$output"

            else
                die "7z is required for ext4 extraction."
            fi
            ;;

        f2fs)
            if have 7z; then
                echo "    - Using 7z"

                $(command -v 7z) \
                    x \
                    -bd \
                    "$img" \
                    "-o$output"

            else
                die "7z is required for f2fs extraction."
            fi
            ;;

        *)
            echo "    - WARNING: Unknown filesystem type."
            return 1
            ;;
    esac

    return 0
}

GENERATE_FILE_CONTEXT()
{
    local root="$1"
    local partition="$2"
    local output="file_context-$partition"

    : > "$output"

    echo "    - Generating $output"

    (
        cd "$root"

        find \
            . \
            -mindepth 1 \
            -print0 \
            2>/dev/null |
        while IFS= read -r -d '' path; do

            path="${path#./}"

            local android_path

            if [[ "$partition" == "system" ]]; then
                android_path="/$path"
            else
                android_path="/$partition/$path"
            fi

            local context=""

            if getfattr \
                -n security.selinux \
                --only-values \
                -h \
                "$path" \
                >/tmp/selinux_context.$$ \
                2>/dev/null; then

                context="$(cat /tmp/selinux_context.$$)"
                rm -f /tmp/selinux_context.$$

            else
                rm -f /tmp/selinux_context.$$
            fi

            if [[ -n "$context" ]]; then
                printf '%s %s\n' \
                    "$android_path" \
                    "$context" \
                    >> "../$output"
            fi

        done
    )

    sed -i 's/\r$//' "$output"

    if grep -nE '^[^ ]+[[:space:]]*$' "$output" >/dev/null 2>&1; then
        echo "    - WARNING: Empty SELinux context detected in $output"
    fi
}

GENERATE_FS_CONFIG()
{
    local root="$1"
    local partition="$2"
    local output="fs_config-$partition"

    : > "$output"

    echo "    - Generating $output"

    (
        cd "$root"

        find \
            . \
            -mindepth 1 \
            -print0 \
            2>/dev/null |
        while IFS= read -r -d '' path; do

            path="${path#./}"

            local android_path

            if [[ "$partition" == "system" ]]; then
                android_path="/$path"
            else
                android_path="/$partition/$path"
            fi

            local uid gid mode

            uid="$(stat -c '%u' "$path")"
            gid="$(stat -c '%g' "$path")"
            mode="$(stat -c '%a' "$path")"

            local capabilities="0x0"

            case "/$path" in
                */system/bin/run-as)
                    capabilities="0xc0"
                    ;;
                */system/bin/simpleperf_app_runner)
                    capabilities="0xc0"
                    ;;
            esac

            printf '%s %s %s %s capabilities=%s\n' \
                "$android_path" \
                "$uid" \
                "$gid" \
                "$mode" \
                "$capabilities" \
                >> "../$output"

        done
    )

    sed -i 's/\r$//' "$output"
}

GENERATE_CONFIGS()
{
    local root="$1"
    local partition="$2"

    echo "  - Generating metadata for $partition..."

    GENERATE_FILE_CONTEXT \
        "$root" \
        "$partition"

    GENERATE_FS_CONFIG \
        "$root" \
        "$partition"

    echo "    - file_context-$partition: $(wc -l < "file_context-$partition") entries"
    echo "    - fs_config-$partition:    $(wc -l < "fs_config-$partition") entries"
}

PROCESS_IMAGE()
{
    local img="$1"
    local partition="$2"
    local clean_partition="${partition%_[ab]}"

    rm -rf \
        -- \
        tmp_out \
        "$partition"

    rm -f \
        -- \
        "file_context-$clean_partition" \
        "fs_config-$clean_partition"

    mkdir -p tmp_out

    local fstype
    fstype="$(detect_fstype "$img")"

    echo "  - Processing $img"
    echo "    - Partition: $partition"
    echo "    - Filesystem: $fstype"

    if [[ "$fstype" == "unknown" ]]; then
        echo "    - WARNING: Could not determine filesystem type."
        cleanup_tmp
        return 0
    fi

    if ! EXTRACT_FILESYSTEM \
        "$img" \
        tmp_out \
        "$fstype"; then

        echo "    - WARNING: Failed to extract $partition."
        cleanup_tmp
        return 0
    fi

    if [[ -z "$(find tmp_out -mindepth 1 -print -quit 2>/dev/null)" ]]; then
        echo "    - WARNING: Extracted directory is empty."
        cleanup_tmp
        return 0
    fi

    GENERATE_CONFIGS \
        "tmp_out" \
        "$clean_partition"

    mv \
        tmp_out \
        "$partition"
}

EXTRACT_OS_PARTITIONS()
{
    echo "- Processing OS partitions..."

    if [[ -f "super.img" ]]; then

        if have file && have simg2img; then
            if file -b "super.img" 2>/dev/null | grep -qi "Android sparse"; then
                echo "  - Converting sparse super.img to raw..."

                $(command -v simg2img) \
                    "super.img" \
                    "super.raw.img"

                mv \
                    -f \
                    "super.raw.img" \
                    "super.img"
            fi
        fi

        if have lpunpack; then
            echo "  - Extracting dynamic partitions from super.img..."

            $(command -v lpunpack) \
                "super.img" \
                . || {
                    echo "  - WARNING: lpunpack failed."
                }

        else
            echo "  - WARNING: lpunpack not found."
        fi
    fi

    shopt -s nullglob

    local images=(
        *.img
    )

    shopt -u nullglob

    for img in "${images[@]}"; do

        [[ -f "$img" ]] || continue
        [[ "$img" == "super.img" ]] && continue

        local partition="${img%.img}"

        PROCESS_IMAGE \
            "$img" \
            "$partition"
    done
}

EXTRACT_CSC_PARTITIONS()
{
    echo "- Extracting CSC partitions (prism / optics)..."

    local csc_tar=""

    shopt -s nullglob

    local csc_files=(
        CSC_*.tar.md5
        CSC_*.tar
    )

    shopt -u nullglob

    if (( ${#csc_files[@]} > 0 )); then
        csc_tar="${csc_files[0]}"
    fi

    if [[ -z "$csc_tar" ]]; then
        echo "  - No CSC archive found."
        return 0
    fi

    if ! have tar; then
        die "tar is required."
    fi

    if ! have lz4; then
        die "lz4 is required for CSC extraction."
    fi

    for part in prism optics; do

        local member="${part}.img.lz4"

        if ! tar -tf "$csc_tar" "$member" >/dev/null 2>&1; then
            echo "  - $member not present in $csc_tar."
            continue
        fi

        echo "  - Extracting $member from $csc_tar..."

        rm -f \
            -- \
            "$member" \
            "${part}.img"

        rm -rf \
            -- \
            tmp_out \
            "$part"

        local clean_part="${part%_[ab]}"

        rm -f \
            -- \
            "file_context-$clean_part" \
            "fs_config-$clean_part"

        tar \
            -xf \
            "$csc_tar" \
            "$member"

        lz4 \
            -d \
            -q \
            -f \
            "$member" \
            "${part}.img"

        rm -f \
            -- \
            "$member"

        local fstype
        fstype="$(detect_fstype "${part}.img")"

        echo "    - Filesystem: $fstype"

        mkdir -p tmp_out

        if ! EXTRACT_FILESYSTEM \
            "${part}.img" \
            tmp_out \
            "$fstype"; then

            echo "    - WARNING: Failed to extract $part."
            cleanup_tmp
            continue
        fi

        if [[ -z "$(find tmp_out -mindepth 1 -print -quit 2>/dev/null)" ]]; then
            echo "    - WARNING: $part is empty after extraction."
            cleanup_tmp
            continue
        fi

        GENERATE_CONFIGS \
            "tmp_out" \
            "$clean_part"

        mv \
            tmp_out \
            "$part"
    done
}

EXTRACT_AVB()
{
    echo "- Checking AVB metadata..."

    for img in \
        boot.img \
        init_boot.img \
        vendor_boot.img \
        dtbo.img \
        vbmeta.img; do

        if [[ -f "$img" ]]; then
            echo "  - Found $img"
        fi
    done
}

MOVE_CONFIGS()
{
    [[ -n "$CONFIGS_DIR" ]] || return 0

    mkdir -p "$CONFIGS_DIR"

    echo "- Moving generated configs to: $CONFIGS_DIR"

    shopt -s nullglob
    local configs=(
        file_context-*
        fs_config-*
    )
    shopt -u nullglob

    for cfg in "${configs[@]}"; do
        [[ -f "$cfg" ]] || continue
        [[ -L "$cfg" ]] && continue

        mv -f "$cfg" "$CONFIGS_DIR/"
    done
}

EXTRACT_ALL()
{
    echo
    echo "============================================================"
    echo "Extracting $MODEL firmware with $REGION CSC"
    echo "============================================================"

    local PDR
    PDR="$(pwd)"

    local firmware_dir="$FW_DIR/${MODEL}_${REGION}"

    mkdir -p "$firmware_dir"
    cd "$firmware_dir"

    if [[ "$MODEL" == *"A366B"* || "$MODEL" == *"a366b"* ]]; then

        local external_system="$ODIN_DIR/${MODEL}_${REGION}/a366bsystem.img"

        if [[ -f "$external_system" ]]; then
            echo "  - Found external A366B system image."

            cp \
                --preserve=all \
                "$external_system" \
                "system.img"
        fi
    fi

    local ap_tar=""

    shopt -s nullglob

    local ap_files=(
        "$ODIN_DIR/${MODEL}_${REGION}"/AP_*.tar.md5
        "$ODIN_DIR/${MODEL}_${REGION}"/AP_*.tar
    )

    shopt -u nullglob

    if (( ${#ap_files[@]} > 0 )); then
        ap_tar="${ap_files[0]}"
    fi

    if [[ -n "$ap_tar" ]]; then
        echo "  - Extracting AP archive:"
        echo "    $ap_tar"

        tar \
            -xf \
            "$ap_tar" \
            -C \
            .
    else
        echo "  - WARNING: No AP archive found."
    fi

    EXTRACT_KERNEL
    UNPACK_RAW_AP
    EXTRACT_OS_PARTITIONS
    EXTRACT_CSC_PARTITIONS
    EXTRACT_AVB
    MOVE_CONFIGS

    cd "$PDR"

    echo
    echo "Finished: ${MODEL}_${REGION}"
    echo
}

: "${FW_DIR:?ERROR: FW_DIR is not set}"
: "${ODIN_DIR:?ERROR: ODIN_DIR is not set}"

FIRMWARE_LIST=()

if [[ -n "${SOURCE_FIRMWARE:-}" ]]; then
    FIRMWARE_LIST+=("$SOURCE_FIRMWARE")
fi

if [[ -n "${SOURCE_EXTRA_FIRMWARES:-}" ]]; then
    while IFS= read -r firmware; do
        [[ -n "$firmware" ]] && FIRMWARE_LIST+=("$firmware")
    done < <(
        printf '%s\n' \
            "$SOURCE_EXTRA_FIRMWARES" |
        tr ',' '\n'
    )
fi

if declare -p FIRMWARES >/dev/null 2>&1; then
    if (( ${#FIRMWARES[@]} > 0 )); then
        FIRMWARE_LIST=()

        for firmware in "${FIRMWARES[@]}"; do
            FIRMWARE_LIST+=("$firmware")
        done
    fi
fi

if (( ${#FIRMWARE_LIST[@]} == 0 )); then
    echo "ERROR: No firmware entries were provided."
    echo "Expected SOURCE_FIRMWARE, SOURCE_EXTRA_FIRMWARES or FIRMWARES."
    exit 1
fi

for i in "${FIRMWARE_LIST[@]}"; do

    MODEL="${i%%/*}"
    REST="${i#*/}"

    REGION="${REST%%/*}"

    if [[ -z "$MODEL" || -z "$REGION" || "$MODEL" == "$REGION" ]]; then
        echo "WARNING: Invalid firmware entry: $i"
        continue
    fi

    EXTRACT_ALL
done

echo "All firmware extraction tasks completed."
exit 0
