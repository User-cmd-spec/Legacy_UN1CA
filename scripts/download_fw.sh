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

A366_AP="https://ts.buzzheavier.com/d/230tjlydladq?v=uZcFsqh4rh6B_xDYukjduaJjmVNjtpPnzUc1d9cNic6XNj43Z2mWjbkwVOETzDjRcJsVHUIiwmHcleUVAGmAGuUl2Uf79_-3TZJ23gNWHlI-H9Y5EQxznoMAunGqEJPANVCfb0bT341OaxVPwzY6BYQRJZ6f3LPpIle3ZhbzAobYYMFZCAcfBtw9-0J636gsu9AijeP8xNBA1VOLrLbtUbZfzss8I90rdgwQ-D7FfiaSkxZOJ1a1_xhwJIksOQmMf9keq96itMWp1iH3zSL-XKNfUPmvnjYWy3UK4H6_Ip4HIcdVbsbW4cN2ZrpJXwxNvsCj3xu1bJPXF-QoFU13dQHHJm3WEt1sAwpN"
A366_BL="https://ts.buzzheavier.com/d/w3a582ba9obg?v=kT022-GKTYnusbltOKawkyWHzweFx00MUIUdjq0_UV8WRJtTMswuuWneFBkYnomIJIZzm-rMVJ6yVs_nsTrKjWC5dsw0PeqyBefDc6ajjepgrnZySZG8VpcybufIK4dnvgbH22r4IzIZ8vf7MZrAlDgjFe7dRPnkd4diTqWWa0DeGAZgnQy_PUEmnCK2-IPqA2G7Sd1vPlE3QXHuyJiG71pUanez4KFGnLFh91Ng9cLn2tfNacMXbuCZ5IwRB4bxrYtPH-n9KHNWIlj3VJ1bK_A39-jmarXKeXU9kelytNDQEBGOPVCOv-3SyU_lg849ujev47gzAA"
A366_CSC="https://ts.buzzheavier.com/d/qapiljiphqyt?v=Mly_5mTmgPX1qvvH27BNZiYY75f-qijmiVSHBHBsU3tSQHsbYq49gKPL4X5bMl7kFLAsEctcXQBJ1toZJ-Orioxs7rce_Z1K7yyQA76eVgQlNaLxEzXMmo5n0psPNBuzIGTSQZKpLgXwfxC7pfOvlJ8_k6c4LprBS1-iJ5SZqyLPxQzhcrPTbp-_R1Jm2lYE1DEMhJZBoNMlFD5_i4S70EOLLtWZX64XZWFSPn14KgBQEWUrQWKNc-dBoMRsbZy-YlTwanobnLByF0FysEKirFIinuto-NaxaY0nw15dEa9riVaaMw"
A366_SYSTEM="https://ts.buzzheavier.com/d/wyu1878e65nz?v=zCg05waCaL2x_Qh21AVQGYgnz2k7e8PkWB71ZbQSrVQyhAshw1PMA5Yua0HEPjSVFIhoZ_HVAmtfdeV3pyMWaITefRMICLq-QmXjzawj9mYPQUkLoHJZi2RkQisBiJTd4_-jyJ5t2Gj734ZcjN4u_EI"

A705FN_AP="https://ts.buzzheavier.com/d/tqiih3ig4idz?v=IeTBPrnljDtLWqTEFkBcz_roNsI1LzWkWrDUM57e4XVj5l0caaGppQf62ccMBD8WSgCJbx9f2nSB9btYfgqqxb9UTLsVa1KVzJ_mRsDtah2FRt2IftKIoXlUlgal9X0bsBMOn4EHK4MpIyGEL5WP4dJf8yg5YhaQ0KlI-LXFlPeWENGtOE42FS39uVBQ6iWr6WNmoOEyhV2UnCwwFByqAyexbfFHA3DL5my8JJb6QDBDr-aAbJYcDGx-Ock_U8jmljBO9X1OenIYhcbuA_nnJk3SHEF6hjhXudedL65l2-C9j5jNtba1pEzmb1LoTYfHRC_L9m8dVlYcLY1l1gkxgPwn5g"
A705FN_BL="https://ts.buzzheavier.com/d/c2mf7920pmjs?v=wjPMYAhd8Z20bhyUoO0fnWdN7kq_Wp44Y7ZZli8rhbaVuCJNaqPzI_KEH41fC8cgXYOQGOoT_b9cPcGvNXNipH3jiY3g6i8RiHNxR26eM9GrY_h5dO5EALLFVPFnwMyNlYsRPW-dm0ISsRDnbAjFhSzzd_XG6C4jHejPdL3DNRDKlAUBCMjEcT6KPp2n2HYQz6xiWn5SCj9p_HhwpL195npfAeKpTezUHHMi-EaWL8ABt9qmRhuAtGolf-pHXO-096X6ojH5JPHxF7tL8Q0f-ptk2VOby7TBbQWqY0SPvDqWEfbwGvCiBLkfznbwF6I"

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
    local CSC_URL=""
    local SYSTEM_URL=""

    case "$MODEL" in
        *A366*|*a366*)
            AP_URL="$A366_AP"
            BL_URL="$A366_BL"
            CSC_URL="$A366_CSC"
            SYSTEM_URL="$A366_SYSTEM"
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

    if [ -n "$CSC_URL" ] && { [ "$IS_SOURCE_FW" = true ] || [[ "$MODEL" =~ (A366|a366) ]]; }; then
        echo "- Downloading CSC .tar.md5 for $MODEL..."
        curl -L --retry 5 --retry-delay 5 -o "CSC_${MODEL}_firmware.tar.md5" "$CSC_URL"
    fi

    if [ -n "$SYSTEM_URL" ]; then
        echo "- Downloading system image for $MODEL..."
        curl -L --retry 5 --retry-delay 5 -o "a366bsystem.img" "$SYSTEM_URL"
    fi

    touch "$ODIN_DIR/${MODEL}_${REGION}/.downloaded"
    {
        echo -n "AP_${MODEL}/"
        echo -n "BL_${MODEL}"
        if [ -f "CSC_${MODEL}_firmware.tar.md5" ]; then
            echo -n "/CSC_${MODEL}"
        fi
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

SOURCE_MODEL=""
SOURCE_REGION=""
if [ -n "$SOURCE_FIRMWARE" ]; then
    SOURCE_MODEL=$(echo -n "$SOURCE_FIRMWARE" | cut -d "/" -f 1)
    SOURCE_REGION=$(echo -n "$SOURCE_FIRMWARE" | cut -d "/" -f 2)
fi

for i in "${FIRMWARES[@]}"
do
    MODEL=$(echo -n "$i" | cut -d "/" -f 1)
    REGION=$(echo -n "$i" | cut -d "/" -f 2)

    IS_SOURCE_FW=false
    if [ -n "$SOURCE_MODEL" ] && [ "$MODEL" = "$SOURCE_MODEL" ] && [ "$REGION" = "$SOURCE_REGION" ]; then
        IS_SOURCE_FW=true
    fi

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
