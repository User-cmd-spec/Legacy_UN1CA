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

A366_AP="https://ts.buzzheavier.com/d/70gjsofwji35?v=aSfukQP05oLCT40rpreLVpsLQRF53AMO670bdS3xJgZRBaboaN7_YuDMhpadyArC1DRfTdh-aJifdFw3rB9dYmPhLySUMLPxO398pbOptSmMR_LB0V8h916XKPUA2CV_lffa7GKRBphPRuzFubF2iEtFAyyZy2pyZotRXeTAcGo0iLPATTxuRVl64wA8rPLAr8jcXPxndyFGm9HrLqXaxbLjcG-4IcTO8b_h1iOthSKVDnko74uquN2mVPJ2_FxDjUWj92laYGspB8tttuKFpHOw03WNzIVsshQwWtCDmQc1FEHow3TxAmXMq1ocZYfVcia4GpH-OTipnVI-DqqGGyX4aQt3mdKQePXe"
A366_BL="https://ts.buzzheavier.com/d/w3a582ba9obg?v=tufRKytn5GCuOH91A7V_AzIQ2TnVUkhcBDKB5gFP4yy9YizjZekRP4xq7AltczmhKIQhcUZOXooyEIvJZ5qJXqZbE9tAYfdRcPljD5BWN-jRg1P7_LF0xZMCiNOy77Rx3koeMwfz60Y6UcLe47ZcHbGrwKjH2tzrlJOp_7R99tTwbnkx5UygHKEWXjsOvww7qt8pP-jKb1bcKxtwnN7PF5vFqkJBsHAFntOzMPtV57lE56g1EwqY97t0oKj8GwbI3jb6CG2AILvNnhx8P8lzyQj8Q23awMBJaWtrsdNiTocobfFAkvY2z89n_AlB5h7-3C8oTpPriQ"

A705FN_AP="https://ts.buzzheavier.com/d/yg5k78unqv7z?v=7jnNc2vx3_cPNZUot0z-JnzTOsW1NMDkuVr-wwZhtEUcodofZ8YdIgKJchg9zD28c5_gKJ8ZvrwL9WuLHnAQX0hdz-qkckO5-ug2OHRcW5qObaEskECz8Ix4yd84naVFtUa-bSv7f6uDUmGXrmXHDTQJ2HLCHT5PCkaB864uoSpD7MOahCZbW4PKDkQOylS9gHGpLulOgoJc__rhY3S9uOGSZSto1rmruurk0OIJ-2BkYEf_IDl6PJT9ydI48QvIs_5TOcebEpPRgYh8GG32MaNPe6dosQ-znbrVRGN-M02woajSMSftNoQxOcXfUZnz9vGno_axWiXi07yK-WPvEE66CA"
A705FN_BL="https://ts.buzzheavier.com/d/k7qga78h2enm?v=mEDBjcacEqg1jPoBGmljb0Gwa7i7tizjw0jNSlBGPlgPB-U19-w-t6j1rvxIpBJpLI_tXYRRfPowE-lBMJUO8NxfIETSk0mhCO19e0R8W6flitYUfih1adb2Yr6Wy3ARyJrchrzaDGi8nblUAohBdfNOyBO7ctFMdUbaAduQnm_OC5R6qpABpmWhWIodQfccDLZoK-VJImVWrBJZBDV-tWPf33WUIyXCW2e1lLNB3U9pM9YsWokPIH0EAW6ByHh5qlBrEWfrixzuA8LJxbkHTvcYqb1-rZSpTCUuO8Pcy4kjcrIEEQ2LUhNi2hLRAGQ"

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
