#!/usr/bin/env bash
#
# Copyright (C) 2023 Salvo Giangreco
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#

set -eu

# Helper function to detect filesystem type
DETECT_FSTYPE() {
    local img="$1"
    if [ ! -f "$img" ] || [ ! -s "$img" ]; then
        echo "unknown"
        return 0
    fi

    if file "$img" | grep -qi "erofs"; then
        echo "erofs"
    elif file "$img" | grep -qi "ext4"; then
        echo "ext4"
    elif file "$img" | grep -qi "f2fs"; then
        echo "f2fs"
    else
        echo "unknown"
    fi
}

EXTRACT_FILESYSTEM() {
    local img="$1"
    local out_dir="$2"
    local fstype="$3"

    case "$fstype" in
        erofs)
            if command -v extract.erofs >/dev/null 2>&1; then
                extract.erofs -i "$img" -x -o "$out_dir" >/dev/null 2>&1 || return 1
            elif command -v fsck.erofs >/dev/null 2>&1; then
                fsck.erofs --extract="$out_dir" "$img" >/dev/null 2>&1 || return 1
            else
                return 1
            fi
            ;;
        ext4)
            if command -v 7z >/dev/null 2>&1; then
                7z x "$img" -o"$out_dir" >/dev/null 2>&1 || return 1
            else
                return 1
            fi
            ;;
        *)
            return 1
            ;;
    esac
    return 0
}

GENERATE_CONFIGS() {
    local target_dir="$1"
    local part_name="$2"
    local cfg_dir="$3"

    mkdir -p "$cfg_dir"
    [ -f "$cfg_dir/file_context-$part_name" ] || touch "$cfg_dir/file_context-$part_name"
    [ -f "$cfg_dir/fs_config-$part_name" ] || touch "$cfg_dir/fs_config-$part_name"
}

PROCESS_IMAGE() {
    local img="$1"
    local out_base_dir="$2"
    local cfg_dir="$3"

    local raw_name
    raw_name="$(basename "$img" .img)"
    local clean_partition="${raw_name%_[ab]}"

    # 1. Ignoruj puste pliki (np. slot B o rozmiarze 0)
    if [ ! -s "$img" ]; then
        echo "  - Pomijanie pustego obrazu: $raw_name.img"
        return 0
    fi

    local target_out="$out_base_dir/$clean_partition"

    # 2. Jesli partycja juz została wyciągnięta (np. ze slotu A), nie nadpisuj jej slotem B
    if [ -d "$target_out" ] && [ -n "$(ls -A "$target_out" 2>/dev/null)" ] && [ "$raw_name" != "$clean_partition" ]; then
        echo "  - Pomijanie $raw_name.img (Partycja $clean_partition jest już wyciągnięta)"
        return 0
    fi

    local fstype
    fstype="$(DETECT_FSTYPE "$img")"

    if [ "$fstype" = "unknown" ]; then
        echo "  - Pomijanie $raw_name.img (Nieznany system plików)"
        return 0
    fi

    echo "  - Wypakowywanie $raw_name.img ($fstype) -> $clean_partition..."

    local tmp_out
    tmp_out="$(mktemp -d)"

    if EXTRACT_FILESYSTEM "$img" "$tmp_out" "$fstype"; then
        rm -rf "$target_out"
        mkdir -p "$target_out"
        cp -a "$tmp_out/." "$target_out/"
        GENERATE_CONFIGS "$target_out" "$clean_partition" "$cfg_dir"
        echo "    Sukces: $clean_partition"
    else
        echo "    OSTRZEŻENIE: Błąd wypakowywania $raw_name.img"
    fi

    rm -rf "$tmp_out"
}

MAIN() {
    local FW_INPUT_DIR="${1:-./firmware}"
    local FW_OUTPUT_DIR="${2:-./extracted}"

    mkdir -p "$FW_OUTPUT_DIR"
    mkdir -p "$FW_OUTPUT_DIR/configs"

    for img in "$FW_INPUT_DIR"/*.img; do
        [ -e "$img" ] || continue
        PROCESS_IMAGE "$img" "$FW_OUTPUT_DIR" "$FW_OUTPUT_DIR/configs"
    done
}

if [ "${BASH_SOURCE[0]}" -eq "$0" ]; then
    MAIN "$@"
fi
