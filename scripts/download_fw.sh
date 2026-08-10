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

A366_AP="https://ts.buzzheavier.com/d/dmxgprk0tnzv?v=eKvmYqqCKG-TqZ_o8I4txApjCvgc9hawXWIF0vo5sZ7iUsnTqchhPSx1P8GLAJId_KK3od_upIEISX-TozoP3kTphHhFKc0wyA6-Bd8eKp6RwhfkJIdDcKqVnWEmAyRx0CerY8xMMo7-91tEnDgWKPhxCdrBMyTgTKEpk0BovuJ2UkgPzxLncR0SR4LqtA3IvaUMhdH3vj4QdxSEG-1QTJIahGB2XgajuusK2de9P-AIk7oa8uyFSJlnGsnGLNLcQ0GTeUGfuZXg7kqXCRrXIrQ2tGmOSof9LVW-QfTVT8eY2WDtzTmtzRFXtI_swYtrna1bn16kAbric9_IE3QIUj37eCJAy8ZOywxw"
A366_BL="https://ts.buzzheavier.com/d/w3a582ba9obg?v=U2E5a-o9L1pwLYYESK7sf8WSx7LS_h9TEpbRarmZQYmnbTCwGQmurvL_etsI_Tqb0I0FECOAngWvUkTexanYxMLOo1biAUwO1Ha2B5Zjwu_AQ2LRNxyEIipoq-lR18F4KDsP1NBeeE0NxP36p5ddszBpuqlft2qDRtTvgpcnk_Erx9Iw9uQrDqQJpq66oiSYHnk5RCt693tYT628MXKA7zwEnUa8iwyZWgztc4Hb4qLPuZsFQrxB5sQJc_R1p4T-BuKH5JwluAN7H_vO8dYmNpOoTieOTNouLnksywhSxmf49Ma6fAEMQd6c0dWNBbGsY-yw8JoaKg"

A705FN_AP="https://ts.buzzheavier.com/d/iivnn2ka3pnp?v=dY3Iuw8R-VXVS-6fr9vLjHzXZ-wKtUzmvoOmjB-Vc5lqph1wDvMXp11z9Sk8Hsgi6v6JNdTYI7WzvxTdmivhs-NW3d9n034yEuh5mPV1prVSyuCjFQWb1CUgDFqVtoZtPulHb6LS3a0clN2S4pf7L8-3i65B_VIJ-62XJFSuZqU5_UIauAJUE3YOUxRvN9fbs5Jo1pbjfCHp__GKwwj8rrShN0LorDlvJG8MeMsmHdSNR1tlnQs7AvdYu2c_4ihI3rpKury8NdwQaTqFV8Io-ZeQZeaq2NUY1XHm77nUrgwg9CgsLZNQe4m4OqZZh5cm1fDP64xXWYgZCOdpkbfKEz0eZQ"
A705FN_BL="https://ts.buzzheavier.com/d/ptawjbdqas7q?v=YBgp5j6zS2FdmBVJOMkVDYwqTyVW6JQdkNxuibtqpHXxSvQxQOixA8VNanfmqE6eLkbxa-rLq3RfN5_-G3yJY8wLUEpzjZouiHMOhXhw5YmIf6pwyUIEoXE_CVfeAxImqc1nTnz4GvuXW1MqoAneZxzGEn-cq-5z-KGWbjGK29DUrbFptQnZkuNQm040siTjxOZ4yCdSZXFnQ6TCc2rrKBQj_rIU29eRXyjase1SWQ32Kq_W4-JiPWoK4N1oeVSo-YR-rlThuQ6XZhj_urXnPS6eEzyyYnA8oes-Exb-9kDaS5DWX8s2TO7h7KCfmbM"

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
