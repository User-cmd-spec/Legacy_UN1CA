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

set -Eeuo pipefail

START=$SECONDS

pwd
ls -l "$GITHUB_WORKSPACE"
ls -l "$OUT_DIR"
ls -l "$OUT_DIR/fw"
ls -l "$OUT_DIR/fw/SM-A366B_EUX" 2>/dev/null || true
ls -l "$OUT_DIR/fw/SM-A705FN_EUX" 2>/dev/null || true
ls -l "$OUT_DIR/odin"
ls -l "$OUT_DIR/fw/SM-A366B_EUX/system" 2>/dev/null || true
ls -l "$OUT_DIR/fw/SM-A366B_EUX/system/system" 2>/dev/null || true

echo "WORK_DIR = $WORK_DIR"
echo "===== Start making ROM ====="

# [
COMMIT_HASH="$(git rev-parse HEAD)"
CONFIG_HASH="$(sed '/ROM_BUILD_TIMESTAMP/d' "$OUT_DIR/config.sh" | sha1sum | cut -d ' ' -f 1)"
WORK_DIR_HASH="$(printf '%s' "$COMMIT_HASH$CONFIG_HASH" | sha1sum | cut -d ' ' -f 1)"
# ]

FORCE=false
BUILD_ROM=true
BUILD_ZIP=true

while (($#)); do
    case "$1" in
        -f|--force)
            FORCE=true
            ;;
        --no-rom-zip)
            BUILD_ZIP=false
            ;;
        *)
            echo "Usage: make_rom [options]"
            echo "  -f, --force       Force rebuild of the ROM"
            echo "  --no-rom-zip      Do not build ROM zip"
            exit 1
            ;;
    esac
    shift
done

# If the work dir is already completed with the same source/config hash,
# there is nothing to rebuild. --force overrides this.
if [[ -f "$WORK_DIR/.completed" && "$FORCE" != true ]]; then
    if [[ "$(cat "$WORK_DIR/.completed")" == "$WORK_DIR_HASH" ]]; then
        BUILD_ROM=false
    else
        echo "Changes in config.sh/the repo have been detected."
        echo 'Please clean your work dir or run the command with "--force".'
        exit 1
    fi
fi

if [[ "$BUILD_ROM" == true ]]; then
    echo "- Preparing firmware..."

    # IMPORTANT:
    # extract_fw.sh is allowed to determine whether the already-downloaded
    # firmware is usable. Its failure must NOT trigger an automatic download.
    #
    # A download is a separate operation and should only happen when the
    # firmware archive is actually missing. This prevents a permissions or
    # extraction failure from causing a second download/extraction cycle.
    #
    # The extraction script itself is responsible for reporting a real
    # extraction error and the build stops instead of silently retrying.
    FW_MISSING=false

    for fw_dir in \
        "$OUT_DIR/odin/SM-A366B_EUX" \
        "$OUT_DIR/odin/SM-A705FN_EUX"
    do
        if [[ ! -d "$fw_dir" ]]; then
            FW_MISSING=true
            break
        fi
    done

    if [[ "$FW_MISSING" == true ]]; then
        echo "- Firmware directory is missing. Downloading firmware..."
        bash "$SRC_DIR/scripts/download_fw.sh"
    fi

    echo "- Extracting/validating firmware..."
    if ! bash "$SRC_DIR/scripts/extract_fw.sh"; then
        echo
        echo "ERROR: extract_fw.sh failed."
        echo "The firmware was NOT downloaded again."
        echo "Fix the extraction error above and rerun make_rom.sh."
        exit 1
    fi

    echo -e "\n- Creating work dir..."
    bash "$SRC_DIR/scripts/internal/create_work_dir.sh"

    echo "- Work dir contents:"
    ls -l "$WORK_DIR"
    ls -l "$WORK_DIR/configs"
    ls -l "$WORK_DIR/system"

    mkdir -p "$GITHUB_WORKSPACE/debug-artifacts"
    cp "$WORK_DIR/configs/file_context-system" \
        "$GITHUB_WORKSPACE/debug-artifacts/file_context-system"
    cp "$WORK_DIR/configs/fs_config-system" \
        "$GITHUB_WORKSPACE/debug-artifacts/fs_config-system"

    awk '$2 == "0" {print "FOUND BAD LINE: " $0}' \
        "$WORK_DIR/configs/file_context-system" || true

    echo -e "\n- Applying ROM patches..."
    bash "$SRC_DIR/scripts/internal/apply_modules.sh" "$SRC_DIR/legacyui/patches"

    if [[ -d "$SRC_DIR/target/$TARGET_CODENAME/patches" ]]; then
        bash "$SRC_DIR/scripts/internal/apply_modules.sh" \
            "$SRC_DIR/target/$TARGET_CODENAME/patches"
    fi

    ls -l "$APKTOOL_DIR/" 2>/dev/null || true
    ls -l "$OUT_DIR/apktool" 2>/dev/null || true

    echo -e "\n- Applying ROM mods..."
    bash "$SRC_DIR/scripts/internal/apply_modules.sh" "$SRC_DIR/legacyui/mods"

    echo -e "\n- Recompiling APKs/JARs..."
    while IFS= read -r i; do
        bash "$SRC_DIR/scripts/apktool.sh" b "$i"
    done < <(
        find "$OUT_DIR/apktool" -type d \
            \( -name '*.apk' -o -name '*.jar' \) \
            -printf '%p\n' |
        sed "s|$OUT_DIR/apktool||"
    )

    echo
    printf '%s' "$WORK_DIR_HASH" > "$WORK_DIR/.completed"
else
    echo -e "- Work dir is already up to date. Nothing to rebuild.\n"
fi

# Remove unsupported capabilities entries before image creation.
# This is deliberately done after create_work_dir.sh so the generated config
# is the one being sanitized.
if [[ -f "$WORK_DIR/configs/file_context-system" ]]; then
    sed -E \
        '/^[^[:space:]]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+capabilities=/d' \
        "$WORK_DIR/configs/file_context-system" \
        > "$WORK_DIR/configs/file_context-system.tmp"

    mv "$WORK_DIR/configs/file_context-system.tmp" \
        "$WORK_DIR/configs/file_context-system"

    grep -nE \
        '^[^[:space:]]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+capabilities=' \
        "$WORK_DIR/configs/file_context-system" || true
fi

if [[ "$BUILD_ZIP" == true ]]; then
    echo "- Building ROM zip..."
    bash "$SRC_DIR/scripts/internal/build_flashable_zip.sh"
    echo
fi

ESTIMATED=$((SECONDS - START))
echo "Build completed in $((ESTIMATED / 3600))hrs $(((ESTIMATED / 60) % 60))min $((ESTIMATED % 60))sec."

exit 0
