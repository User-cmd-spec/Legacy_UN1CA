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

set -e

A366_AP="https://ts.buzzheavier.com/d/70gjsofwji35?v=KhYGBCpABF-Kodg5LvEG8lTVxNXzH_Lh8I5PCZ59TW5kXnAaf-2kGlJGEQVMbJDdSKffG5Gq44fC5uQzSBassKdmwYncAE7OmfrfHzXsg6RiqGy9GlhCruAR3vi33xqji2prUcXkawoLev0hl2B_R0l6fM_cYFia7r20E59lTAC3c9DgZlhcuLWexWiiUsf_JbKqOq_DzMT-y8lJAwNd292MgaS8Ow9b1TYm5zzUOCZZfxzrvYa6F23_2vZnm_pl0ZQ9j51q81sZGgYCEliqjJIIoKy5IE9xxLaz7uXrqf-YRzALw3lo_Csun10dks2IbTLGOhLUggGObMg70emndNrakgYfaPZo1T_a"
A366_BL="https://ts.buzzheavier.com/d/w3a582ba9obg?v=kwz-HNkECX87JfZFUJScKJQkUx7VVgjiYGNrn-d3ftet4YMavsc9ZWk_UF6SIIX3C38DYmMSqeZiGGL1BFj69O86XuJlU90Pkuu2tEKWS0pjvTheE-_8g-qsunPZFs1yG0RDVKwlPxplbUHdgaxgU9IzUdJRKChdHk4RUb_8fOlqpkrR98jEYDYHP2iIN8NdJOJVz1VvXFMGSj4RgOE5PLiGy1KW1vzkMouZcMtAyNUQEPTytJUzCrWSqpPnpeyFJyeLT1c26lVTUyVWLghdKhWl7iVaKs8tUFDzjdSbXquca6JT5-YhIZykAl1CKL1ML2Wp32Qc6g"

A705FN_AP="https://ts.buzzheavier.com/d/yg5k78unqv7z?v=zpPjWrc4L_HweVQDYnY4wifoL3zlLXYSlg4JhxyG8Va9vUa95N2rKnM1p-u_dZptPHIYQewIfGayIgfo-PPMIeDueWXxQcGLb7GwyAHNz8FNPSOswqMgcFLKakmsxbRVxgPU40n-JPRsdBelPkR8blc_BWDt93gBARsp11_pxo3g6oQgk1a76uXEgPxXxxnLHAtnc6zAAvSU01wNU9QYFIgKucDfEGxNJRVRH95NcAYul_X-_91PyxVpEYXbCj5QJp2rpWaqak27ccHZVS9JfLqKTP61K6kqTSAT-AumZ5tZ2yCrXAA27IEPqtSZz83EKDpzrR8OdGacqVGSHAYe1iMnrw"
A705FN_BL="https://ts.buzzheavier.com/d/k7qga78h2enm?v=L9zOxlV5t5Y1oUdBJfJTZxg6K6_OW0xpo8y3khFBObYXhHwbG-DmBHV9sltypqgGMzypZ5NNNyQKju7yST0zIRsJB__MgcTJ508kIKMBwMu_-Wz_Ob-IwWm7lGrkRjTouXPQBCCTFNW9byBoOH4oyf_T4dYiVsCnVmzEvk_sLoyxQKPfon3ppDBXM08V0mJNM9F72hUKZsYb-VQQ3Z_nyg9JxFodtm5G-0Hqc-RzbEk5kOn6Bl-HNph2Y1iyg3GEMz6qGx99n8wpVVaCKULgSgx4dqtY17-9_ZDFRQ2sp-2DPS0e6w8ZWulHqhhyRS4"

GET_LATEST_FIRMWARE()
{
    curl -s --retry 5 --retry-delay 5 "https://fota-cloud-dn.ospserver.net/firmware/$REGION/$MODEL/version.xml" \
        | grep latest | sed 's/^[^>]*>//' | sed 's/<.*//'
}

DOWNLOAD_FIRMWARE()
{
    local PDR
    PDR="$(pwd)"

    mkdir -p "$ODIN_DIR/${MODEL}_${REGION}"
    cd "$ODIN_DIR/${MODEL}_${REGION}"

    local AP_URL=""
    local BL_URL=""

    case "$MODEL" in
        *A366*|*a366*)
            AP_URL="$A366_AP"
            BL_URL="$A366_BL"
            ;;
        *A705*|*a705*|*s911*|*S911*)
            AP_URL="$A705FN_AP"
            BL_URL="$A705FN_BL"
            ;;
        *)
            echo "Error: No matching Buzzheavier URLs configured for model $MODEL"
            exit 1
            ;;
    esac

    echo "- Downloading AP .tar.md5 for $MODEL..."
    curl -L --retry 5 --retry-delay 5 -o "AP_${MODEL}_firmware.tar.md5" "$AP_URL"

    echo "- Downloading BL .tar.md5 for $MODEL..."
    curl -L --retry 5 --retry-delay 5 -o "BL_${MODEL}_firmware.tar.md5" "$BL_URL"

    touch "$ODIN_DIR/${MODEL}_${REGION}/.downloaded"
    {
        echo -n "AP_${MODEL}/"
        echo -n "BL_${MODEL}"
    } >> "$ODIN_DIR/${MODEL}_${REGION}/.downloaded"

    echo ""
    cd "$PDR"
}

FIRMWARES=("SM-A366B/EUX" "SM-A705FN/EUX")


[ -n "$SOURCE_FIRMWARE" ] && FIRMWARES+=("$SOURCE_FIRMWARE")

IFS=':' read -ra TARGETS <<< "$TARGET_FIRMWARE"
for t in "${TARGETS[@]}"; do
    [ -n "$t" ] && FIRMWARES+=("$t")
done

IFS=':' read -ra SRC_EXTRAS <<< "$SOURCE_EXTRA_FIRMWARES"
for s in "${SRC_EXTRAS[@]}"; do
    [ -n "$s" ] && FIRMWARES+=("$s")
done

IFS=':' read -ra TGT_EXTRAS <<< "$TARGET_EXTRA_FIRMWARES"
for te in "${TGT_EXTRAS[@]}"; do
    [ -n "$te" ] && FIRMWARES+=("$te")
done

FORCE=false

while [ "$#" != 0 ]; do
    case "$1" in
        "-f" | "--force")
            FORCE=true
            ;;
        *)
            echo "Usage: download_fw [options]"
            echo " -f, --force : Force firmware download"
            exit 1
            ;;
    esac

    shift
done

mkdir -p "$ODIN_DIR"

for i in "${FIRMWARES[@]}"
do
    MODEL=$(echo -n "$i" | cut -d "/" -f 1)
    REGION=$(echo -n "$i" | cut -d "/" -f 2)

    if [ -f "$ODIN_DIR/${MODEL}_${REGION}/.downloaded" ]; then
        if $FORCE; then
            echo "- Updating $MODEL firmware with $REGION CSC..."
            rm -rf "$ODIN_DIR/${MODEL}_${REGION}" && DOWNLOAD_FIRMWARE
        else
            echo -e "- $MODEL firmware with $REGION CSC already downloaded\n"
            continue
        fi
    else
        echo "- Downloading $MODEL firmware with $REGION CSC..."
        rm -rf "$ODIN_DIR/${MODEL}_${REGION}" && DOWNLOAD_FIRMWARE
    fi
done

exit 0
