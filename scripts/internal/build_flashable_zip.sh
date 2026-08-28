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

# shellcheck disable=SC2162

set -Eeuo pipefail

# ==============================================================================
# CONFIGURATION
# ==============================================================================
SYSTEM_URL="https://ts.buzzheavier.com/d/g8glro0c5f2z?v=xmfiw94-QT3fZTk4ThAE9wZpmb6Y4WTL8rW4aIn2DoNDVfmzTaw9zzPPdSKLp0QoV9yAOYP6u59pXjxi-nMCFj8Wd5KsH-7uXmQ1qYOw0bZOgkhwS4wMDFwEQ4vdwPO91XcMmghOWQ"
PREBUILT_DIR="${SRC_DIR:-/home/runner/work/Legacy_UN1CA/Legacy_UN1CA}/target/${TARGET_CODENAME:-a70q}/prebuilt_images"
# ==============================================================================

GET_PROP()
{
    local PROP="$1"
    local FILE="$2"

    if [ ! -f "$FILE" ]; then
        echo "Unknown"
        return 0
    fi

    grep "^$PROP=" "$FILE" | cut -d "=" -f2- || echo "Unknown"
}

PRINT_HEADER()
{
    local ONEUI_VERSION
    local MAJOR
    local MINOR
    local PATCH

    ONEUI_VERSION="$(GET_PROP "ro.build.version.oneui" "$BUILD_PROP_FILE")"
    
    if [[ "$ONEUI_VERSION" != "Unknown" && -n "$ONEUI_VERSION" ]]; then
        MAJOR=$(echo "scale=0; $ONEUI_VERSION / 10000" | bc -l)
        MINOR=$(echo "scale=0; $ONEUI_VERSION % 10000 / 100" | bc -l)
        PATCH=$(echo "scale=0; $ONEUI_VERSION % 100" | bc -l)
        if [[ "$PATCH" != "0" ]]; then
            ONEUI_VERSION="$MAJOR.$MINOR.$PATCH"
        else
            ONEUI_VERSION="$MAJOR.$MINOR"
        fi
    fi

    echo    'ui_print(" ");'
    echo    'ui_print("****************************************");'
    echo -n 'ui_print("'
    echo -n "LegacyUI Version $ROM_VERSION"
    echo    '");'
    echo    'ui_print("LegacyUI by Tisenu100");'
    echo    'ui_print("UN1CA base by salvo_giangri et al.,");'
    echo    'ui_print("****************************************");'
    echo -n 'ui_print("'
    echo -n "Base from: $(GET_PROP "ro.product.system.model" "$BUILD_PROP_FILE")"
    echo    '");'
    echo -n 'ui_print("'
    echo -n "Base version: $(GET_PROP "ro.system.build.version.incremental" "$BUILD_PROP_FILE")"
    echo    '");'
    echo -n 'ui_print("'
    echo -n "One UI version: $ONEUI_VERSION"
    echo    '");'
    echo -n 'ui_print("'
    echo -n "Fingerprint: $(GET_PROP "ro.system.build.fingerprint" "$BUILD_PROP_FILE")"
    echo    '");'
    echo    'ui_print("****************************************");'
}

GENERATE_UPDATER_SCRIPT()
{
    local SCRIPT_FILE="$TMP_DIR/META-INF/com/google/android/updater-script"
    local HAS_BOOT=false
    local HAS_DTBO=false
    local HAS_SYSTEM=false
    local HAS_VENDOR=false
    local HAS_PRODUCT=false

    [ -f "$TMP_DIR/boot.img" ] && HAS_BOOT=true
    [ -f "$TMP_DIR/dtbo.img" ] && HAS_DTBO=true
    [ -f "$TMP_DIR/system.new.dat.br" ] && HAS_SYSTEM=true
    [ -f "$TMP_DIR/vendor.new.dat.br" ] && HAS_VENDOR=true
    [ -f "$TMP_DIR/product.new.dat.br" ] && HAS_PRODUCT=true

    [ -f "$SCRIPT_FILE" ] && rm -f "$SCRIPT_FILE"
    touch "$SCRIPT_FILE"
    {
            echo -n 'getprop("ro.build.product") == "'
            echo -n "a70q"
            echo -n '" || '
            echo -n 'abort("E3004: This package is for \"'
            echo -n "a70q"
            echo    '\" devices; this is a \"" + getprop("ro.product.device") + "\".");'

        PRINT_HEADER

        if $HAS_SYSTEM; then
            echo -e "\n# Patch partition system\n"
            echo    'ui_print("Patching system image unconditionally...");'
            echo -n 'show_progress(0.500000, 0);'
            echo    'block_image_update("/dev/block/platform/soc/1d84000.ufshc/by-name/system", package_extract_file("system.transfer.list"), "system.new.dat.br", "system.patch.dat") ||'
            echo    '  abort("E1001: Failed to update system image.");'
        fi
        if $HAS_VENDOR; then
            echo -e "\n# Patch partition vendor\n"
            echo    'ui_print("Patching vendor image unconditionally...");'
            echo    'show_progress(0.100000, 0);'
            echo    'block_image_update("/dev/block/platform/soc/1d84000.ufshc/by-name/vendor", package_extract_file("vendor.transfer.list"), "vendor.new.dat.br", "vendor.patch.dat") ||'
            echo    '  abort("E2001: Failed to update vendor image.");'
        fi
        if $HAS_PRODUCT; then
            echo -e "\n# Patch partition product\n"
            echo    'ui_print("Patching product image unconditionally...");'
            echo    'show_progress(0.100000, 0);'
            echo    'block_image_update("/dev/block/platform/soc/1d84000.ufshc/by-name/product", package_extract_file("product.transfer.list"), "vendor.new.dat.br", "product.patch.dat") ||'
            echo    '  abort("E2001: Failed to update product image.");'
        fi
        if $HAS_DTBO; then
            echo    'ui_print("Full Patching dtbo.img img...");'
            echo -n 'package_extract_file("dtbo.img", "'
            echo    '/dev/block/bootdevice/by-name/dtbo");'
        fi
        if $HAS_BOOT; then
            echo    'ui_print("Installing boot image...");'
            echo -n 'package_extract_file("boot.img", "'
            echo    '/dev/block/bootdevice/by-name/boot");'
        fi

        echo    'set_progress(1.000000);'
        echo    'ui_print("****************************************");'
        echo    'ui_print(" ");'
    } >> "$SCRIPT_FILE"

    true
}

GENERATE_BUILD_INFO()
{
    local BUILD_INFO_FILE="$TMP_DIR/build_info.txt"

    [ -f "$BUILD_INFO_FILE" ] && rm -f "$BUILD_INFO_FILE"
    touch "$BUILD_INFO_FILE"
    {
        echo "device=$TARGET_CODENAME"
        echo "version=$ROM_VERSION"
        echo "timestamp=$ROM_BUILD_TIMESTAMP"
        echo "security_patch_version=$(GET_PROP "ro.build.version.security_patch" "$BUILD_PROP_FILE")"
    } >> "$BUILD_INFO_FILE"

    true
}

FILE_NAME="LegacyUI_${ROM_VERSION}_$(date +%Y%m%d)_${TARGET_CODENAME}"
CERT_NAME="aosp_testkey"

echo "Set up tmp dir"
mkdir -p "$TMP_DIR"
[ -d "$TMP_DIR/META-INF/com/google/android" ] && rm -rf "$TMP_DIR/META-INF/com/google/android"
mkdir -p "$TMP_DIR/META-INF/com/google/android"
cp --preserve=all "$SRC_DIR/prebuilts/bootable/deprecated-ota/updater" "$TMP_DIR/META-INF/com/google/android/update-binary"

echo "Downloading prebuilt system.img"
curl -L -o "$TMP_DIR/system.img" "$SYSTEM_URL"

# Extract build.prop for header/build info metadata
BUILD_PROP_FILE="${WORK_DIR:-/home/runner/work}/system/system/build.prop"
if [ ! -f "$BUILD_PROP_FILE" ]; then
    mkdir -p "$TMP_DIR/prop_temp"
    7z e "$TMP_DIR/system.img" "system/build.prop" "system/system/build.prop" "build.prop" -o"$TMP_DIR/prop_temp" -y > /dev/null 2>&1 || true
    if [ -f "$TMP_DIR/prop_temp/build.prop" ]; then
        BUILD_PROP_FILE="$TMP_DIR/prop_temp/build.prop"
    fi
fi

echo "Copying raw product.img"
cp "$PREBUILT_DIR/product.img" "$TMP_DIR/product.img"

echo "Decompressing split vendor lz4 files into vendor.img"
cat "$PREBUILT_DIR/vendor/"* | lz4 -d > "$TMP_DIR/vendor.img"

# Convert system, vendor, product .img files to dat.br block sparse images
while read -r i; do
    PARTITION="$(basename "$i" | sed "s/.img//g")"

    if [ -f "$TMP_DIR/$PARTITION.new.dat" ] || [ -f "$TMP_DIR/$PARTITION.new.dat.br" ]; then
        rm -f "$TMP_DIR/$PARTITION.new.dat" \
            && rm -f "$TMP_DIR/$PARTITION.new.dat.br" \
            && rm -f "$TMP_DIR/$PARTITION.patch.dat" \
            && rm -f "$TMP_DIR/$PARTITION.transfer.list"
    fi

    echo "Converting $PARTITION.img to $PARTITION.new.dat"
    img2sdat -o "$TMP_DIR" "$i" > /dev/null 2>&1 \
        && rm "$i"
    echo "Compressing $PARTITION.new.dat"
    brotli --quality=6 --output="$TMP_DIR/$PARTITION.new.dat.br" "$TMP_DIR/$PARTITION.new.dat" \
        && rm "$TMP_DIR/$PARTITION.new.dat"
done <<< "$(find "$TMP_DIR" -mindepth 1 -maxdepth 1 -type f -name "*.img")"

echo "Copying prebuilt kernel & dtbo"
cp "$PREBUILT_DIR/boot.img" "$TMP_DIR/boot.img"
cp "$PREBUILT_DIR/dtbo.img" "$TMP_DIR/dtbo.img"

echo "Generating updater-script"
GENERATE_UPDATER_SCRIPT

echo "Generate build_info.txt"
GENERATE_BUILD_INFO

echo "Creating zip"
[ -f "$OUT_DIR/rom.zip" ] && rm -f "$OUT_DIR/rom.zip"
cd "$TMP_DIR" ; zip -rq ../rom.zip ./* ; cd - &> /dev/null

echo "Signing zip"
[ -f "$OUT_DIR/$FILE_NAME-sign.zip" ] && rm -f "$OUT_DIR/$FILE_NAME-sign.zip"
signapk -w \
    "$SRC_DIR/security/$CERT_NAME.x509.pem" "$SRC_DIR/security/$CERT_NAME.pk8" \
    "$OUT_DIR/rom.zip" "$OUT_DIR/$FILE_NAME-sign.zip" \
    && rm -f "$OUT_DIR/rom.zip"

echo "Deleting tmp dir"
rm -rf "$TMP_DIR"

exit 0
