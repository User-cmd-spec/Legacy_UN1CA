#!/usr/bin/env bash
#
# Copyright (C) 2023 Salvo Giangreco
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

set -eu

# Helper function to safely copy files without crashing
SAFE_CP() {
    local SRC="$1"
    local DEST="$2"

    if [ -f "$SRC" ]; then
        local DEST_DIR
        DEST_DIR="$(dirname "$DEST")"
        mkdir -p "$DEST_DIR"

        if [ -f "$DEST" ]; then
            local REAL_SRC REAL_DEST
            REAL_SRC="$(realpath "$SRC" 2>/dev/null || true)"
            REAL_DEST="$(realpath "$DEST" 2>/dev/null || true)"
            if [ -n "$REAL_SRC" ] && [ "$REAL_SRC" = "$REAL_DEST" ]; then
                return 0
            fi
        fi
        cp --preserve=all "$SRC" "$DEST"
    fi
}

# Helper function to safely copy directory contents without path errors
SAFE_CP_DIR() {
    local SRC="$1"
    local DEST="$2"

    if [ -d "$SRC" ]; then
        local REAL_SRC REAL_DEST
        REAL_SRC="$(realpath "$SRC" 2>/dev/null || true)"
        REAL_DEST="$(realpath "$DEST" 2>/dev/null || true)"

        if [ -n "$REAL_SRC" ] && [ "$REAL_SRC" = "$REAL_DEST" ]; then
            return 0
        fi

        mkdir -p "$DEST"
        cp -a --preserve=all "$SRC/." "$DEST/"
    fi
}

# Helper function to execute sed safely if file exists
SAFE_SED() {
    local EXPR="$1"
    local FILE="$2"

    if [ -f "$FILE" ]; then
        sed -i "$EXPR" "$FILE"
    fi
}

COPY_SOURCE_FIRMWARE()
{
    local MODEL
    local REGION
    MODEL=$(echo -n "$SOURCE_FIRMWARE" | cut -d "/" -f 1)
    REGION=$(echo -n "$SOURCE_FIRMWARE" | cut -d "/" -f 2)

    local SRC_DIR_FW="$FW_DIR/${MODEL}_${REGION}"

    # Setup the system partition
    if [ ! -d "$WORK_DIR/system" ]; then
        SAFE_CP_DIR "$SRC_DIR_FW/system" "$WORK_DIR/system"
        SAFE_CP "$SRC_DIR_FW/configs/file_context-system" "$WORK_DIR/configs/file_context-system"
        SAFE_CP "$SRC_DIR_FW/configs/fs_config-system" "$WORK_DIR/configs/fs_config-system"
    fi

    # Differentiate system_ext & product status
    if $SOURCE_HAS_SYSTEM_EXT; then
        if ! $TARGET_HAS_SYSTEM_EXT; then
            if [ ! -d "$WORK_DIR/system/system/system_ext" ]; then
                rm -rf "$WORK_DIR/system/system_ext"
                rm -f "$WORK_DIR/system/system/system_ext"
                SAFE_SED "/system_ext/d" "$WORK_DIR/configs/file_context-system"
                SAFE_SED "/system_ext/d" "$WORK_DIR/configs/fs_config-system"
                
                SAFE_CP_DIR "$SRC_DIR_FW/system_ext" "$WORK_DIR/system/system/system_ext"
                ln -sf "/system/system_ext" "$WORK_DIR/system/system_ext"
                
                echo "/system_ext u:object_r:system_file:s0" >> "$WORK_DIR/configs/file_context-system"
                echo "system_ext 0 0 644 capabilities=0x0" >> "$WORK_DIR/configs/fs_config-system"
                
                if [ -f "$SRC_DIR_FW/configs/file_context-system_ext" ]; then
                    sed "s/^\/system_ext/\/system\/system_ext/g" "$SRC_DIR_FW/configs/file_context-system_ext" >> "$WORK_DIR/configs/file_context-system"
                fi
                
                echo "system/system_ext 0 0 755 capabilities=0x0" >> "$WORK_DIR/configs/fs_config-system"
                
                if [ -f "$SRC_DIR_FW/configs/fs_config-system_ext" ]; then
                    sed "1d" "$SRC_DIR_FW/configs/fs_config-system_ext" | sed "s/^system_ext/system\/system_ext/g" >> "$WORK_DIR/configs/fs_config-system"
                fi
                
                rm -f "$WORK_DIR/system/system/system_ext/etc/NOTICE.xml.gz"
                SAFE_SED '/system\/system_ext\/etc\/NOTICE\.xml\.gz/d' "$WORK_DIR/configs/file_context-system"
                SAFE_SED "/system\/system_ext\/etc\/NOTICE.xml.gz/d" "$WORK_DIR/configs/fs_config-system"
                rm -f "$WORK_DIR/system/system/system_ext/etc/fs_config_dirs"
                SAFE_SED "/system\/system_ext\/etc\/fs_config_dirs/d" "$WORK_DIR/configs/file_context-system"
                SAFE_SED "/system\/system_ext\/etc\/fs_config_dirs/d" "$WORK_DIR/configs/fs_config-system"
                rm -f "$WORK_DIR/system/system/system_ext/etc/fs_config_files"
                SAFE_SED "/system\/system_ext\/etc\/fs_config_files/d" "$WORK_DIR/configs/file_context-system"
                SAFE_SED "/system\/system_ext\/etc\/fs_config_files/d" "$WORK_DIR/configs/fs_config-system"
            fi
        elif [ ! -d "$WORK_DIR/system_ext" ]; then
            SAFE_CP_DIR "$SRC_DIR_FW/system_ext" "$WORK_DIR/system_ext"
            SAFE_CP "$SRC_DIR_FW/configs/file_context-system_ext" "$WORK_DIR/configs/file_context-system_ext"
            SAFE_CP "$SRC_DIR_FW/configs/fs_config-system_ext" "$WORK_DIR/configs/fs_config-system_ext"
        fi
    else
        if $TARGET_HAS_SYSTEM_EXT; then
            SAFE_CP_DIR "$SRC_DIR_FW/system/system/system_ext" "$WORK_DIR/system_ext"
            rm -rf "$WORK_DIR/system/system/system_ext"
            rm -f "$WORK_DIR/system/system_ext"
            mkdir -p "$WORK_DIR/system/system_ext"
            ln -s "/system_ext" "$WORK_DIR/system/system/system_ext"
            
            if [ -f "$SRC_DIR_FW/configs/fs_config-system" ]; then
                grep 'system_ext' "$SRC_DIR_FW/configs/fs_config-system" | sed 's/^system\///' | sed '/system_ext 0 0 644 capabilities/d' | sed '/system_ext 0 0 755 capabilities/d' >> "$WORK_DIR/configs/fs_config-system_ext" || true
            fi
            if [ -f "$SRC_DIR_FW/configs/file_context-system" ]; then
                grep 'system_ext' "$SRC_DIR_FW/configs/file_context-system" | sed '/system_ext u:object_r:system_file:s0/d' | sed 's/^\/system//' >> "$WORK_DIR/configs/file_context-system_ext" || true
            fi
            
            SAFE_SED '/system_ext/d' "$WORK_DIR/configs/fs_config-system"
            SAFE_SED '/system_ext/d' "$WORK_DIR/configs/file_context-system"
            
            echo "/system/system_ext u:object_r:system_file:s0" >> "$WORK_DIR/configs/file_context-system"
            echo "/system_ext u:object_r:system_file:s0" >> "$WORK_DIR/configs/file_context-system"
            echo "system/system_ext 0 0 644 capabilities=0x0" >> "$WORK_DIR/configs/fs_config-system"
            echo "system_ext 0 0 755 capabilities=0x0" >> "$WORK_DIR/configs/fs_config-system"
            
            echo " 0 0 755 capabilities=0x0" >> "$WORK_DIR/configs/fs_config-system_ext"
            echo "/system_ext u:object_r:system_file:s0" >> "$WORK_DIR/configs/file_context-system_ext"
        fi
    fi

    if $SOURCE_HAS_PRODUCT; then
        if ! $TARGET_HAS_PRODUCT; then
            if [ ! -d "$WORK_DIR/system/system/product" ]; then
                rm -rf "$WORK_DIR/system/product"
                rm -f "$WORK_DIR/system/system/product"
                SAFE_SED "/product/d" "$WORK_DIR/configs/file_context-system"
                SAFE_SED "/product/d" "$WORK_DIR/configs/fs_config-system"
                
                SAFE_CP_DIR "$SRC_DIR_FW/product" "$WORK_DIR/system/system/product"
                ln -sf "/system/product" "$WORK_DIR/system/product"
                
                echo "/product u:object_r:system_file:s0" >> "$WORK_DIR/configs/file_context-system"
                echo "product 0 0 644 capabilities=0x0" >> "$WORK_DIR/configs/fs_config-system"
                
                if [ -f "$SRC_DIR_FW/configs/file_context-product" ]; then
                    sed "s/^\/product/\/system\/product/g" "$SRC_DIR_FW/configs/file_context-product" >> "$WORK_DIR/configs/file_context-system"
                fi
                
                echo "system/product 0 0 755 capabilities=0x0" >> "$WORK_DIR/configs/fs_config-system"
                
                if [ -f "$SRC_DIR_FW/configs/fs_config-product" ]; then
                    sed "1d" "$SRC_DIR_FW/configs/fs_config-product" | sed "s/^product/system\/product/g" >> "$WORK_DIR/configs/fs_config-system"
                fi
                
                rm -f "$WORK_DIR/system/system/product/etc/NOTICE.xml.gz"
                SAFE_SED '/system\/product\/etc\/NOTICE\\.xml\\.gz/d' "$WORK_DIR/configs/file_context-system"
                SAFE_SED "/system\/product\/etc\/NOTICE.xml.gz/d" "$WORK_DIR/configs/fs_config-system"
                rm -f "$WORK_DIR/system/system/product/etc/fs_config_dirs"
                SAFE_SED "/system\/product\/etc\/fs_config_dirs/d" "$WORK_DIR/configs/file_context-system"
                SAFE_SED "/system\/product\/etc\/fs_config_dirs/d" "$WORK_DIR/configs/fs_config-system"
                rm -f "$WORK_DIR/system/system/product/etc/fs_config_files"
                SAFE_SED "/system\/product\/etc\/fs_config_files/d" "$WORK_DIR/configs/file_context-system"
                SAFE_SED "/system\/product\/etc\/fs_config_files/d" "$WORK_DIR/configs/fs_config-system"
            fi
        elif [ ! -d "$WORK_DIR/product" ]; then
            SAFE_CP_DIR "$SRC_DIR_FW/product" "$WORK_DIR/product"
            SAFE_CP "$SRC_DIR_FW/configs/file_context-product" "$WORK_DIR/configs/file_context-product"
            SAFE_CP "$SRC_DIR_FW/configs/fs_config-product" "$WORK_DIR/configs/fs_config-product"
        fi
    else
        if $TARGET_HAS_PRODUCT; then
            SAFE_CP_DIR "$SRC_DIR_FW/system/system/product" "$WORK_DIR/product"
            rm -rf "$WORK_DIR/system/system/product"
            rm -f "$WORK_DIR/system/product"
            mkdir -p "$WORK_DIR/system/product"
            ln -s "/product" "$WORK_DIR/system/system/product"
            
            if [ -f "$SRC_DIR_FW/configs/fs_config-system" ]; me]; then
                grep 'product' "$SRC_DIR_FW/configs/fs_config-system" | sed 's/^system\///' | sed '/product 0 0 644 capabilities/d' | sed '/product 0 0 755 capabilities/d' >> "$WORK_DIR/configs/fs_config-product" || true
            fi
            if [ -f "$SRC_DIR_FW/configs/file_context-system" ]; then
                grep 'product' "$SRC_DIR_FW/configs/file_context-system" | sed '/product u:object_r:system_file:s0/d' | sed 's/^\/system//' >> "$WORK_DIR/configs/file_context-product" || true
            fi
            
            SAFE_SED '/product/d' "$WORK_DIR/configs/fs_config-system"
            SAFE_SED '/product/d' "$WORK_DIR/configs/file_context-system"
            
            echo "/system/product u:object_r:system_file:s0" >> "$WORK_DIR/configs/file_context-system"
            echo "/product u:object_r:system_file:s0" >> "$WORK_DIR/configs/file_context-system"
            echo "system/product 0 0 644 capabilities=0x0" >> "$WORK_DIR/configs/fs_config-system"
            echo "product 0 0 755 capabilities=0x0" >> "$WORK_DIR/configs/fs_config-system"
            
            echo " 0 0 755 capabilities=0x0" >> "$WORK_DIR/configs/fs_config-product"
            echo "/product u:object_r:system_file:s0" >> "$WORK_DIR/configs/file_context-product"
        fi
    fi
}

mkdir -p "$WORK_DIR"
mkdir -p "$WORK_DIR/configs"
COPY_SOURCE_FIRMWARE

exit 0
