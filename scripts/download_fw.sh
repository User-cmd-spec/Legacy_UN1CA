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

A366_AP="https://ts.buzzheavier.com/d/230tjlydladq?v=gWgy6gUuf02wP8fo_NDj7eqEOaoGjdEBn-5yYYpYx7BpYd7Z_gZy9MEVzIR_vv5NyRmNw59B4KpNp1LzlHyc6ispErNKBOVcsKHBQ6zYNMfQ1Yx4oaYMKNkvR2SmFM4O9nhy5Xi-aK1H0vzW1fgNpv6xBoHEBsVh-D4U7vAS0ptLIY7SAHN6Q7pxjJRRWyjocIfFM98L4by-5fDZprpf7aFkba3yM_Og6MqCztFmp5j64RsoembeUr-qAYVgvuhwzKEX6DbBoKE7vXKi0_LgJl1ISFFdw0vx6qFawTGCS9K_RkZ2cZOqPxOVYMiSg-4r2RyYjdHV-jTLOhDDO9D98Agtut-rEm6m_Lxl"
A366_BL="https://ts.buzzheavier.com/d/w3a582ba9obg?v=kT022-GKTYnusbltOKawkyWHzweFx00MUIUdjq0_UV8WRJtTMswuuWneFBkYnomIJIZzm-rMVJ6yVs_nsTrKjWC5dsw0PeqyBefDc6ajjepgrnZySZG8VpcybufIK4dnvgbH22r4IzIZ8vf7MZrAlDgjFe7dRPnkd4diTqWWa0DeGAZgnQy_PUEmnCK2-IPqA2G7Sd1vPlE3QXHuyJiG71pUanez4KFGnLFh91Ng9cLn2tfNacMXbuCZ5IwRB4bxrYtPH-n9KHNWIlj3VJ1bK_A39-jmarXKeXU9kelytNDQEBGOPVCOv-3SyU_lg849ujev47gzAA"
A366_CSC="https://ts.buzzheavier.com/d/qapiljiphqyt?v=ZoOO7fRXmjXLYCAAfwtmy_3S_tvm8JC7NW5eKn9yPJKSf4NOgbirUk4Ibk0DMb66MMtl0g_hPa7R6wtaP1cMwAUJwRCSsGA5bjNX-C3qJL7vz_EUA5bzoClCtRBdKV4SGXS8ZM5I8upiuTeR3K_M9xC7Lmu0lSD9p6W4l_cbVx24KlWEcYqfFpVhRIOEZBq3jFkR6E99FemQSKQFPafVu26pEEi_VZJtQHN0WWM6O1GpCM2td0ZuIGvFC2Qg-ir-J_lzviVvEVSjTPdP3l72K2lHpjkgi6LV9xKair4r3fCbjt-AdA"
A366_SYSTEM="https://ts.buzzheavier.com/d/cnjk2mhjluyc?v=ULpqCAcJqy6Q6pRvPNnisycdpze2LMqm-MgR4rmYniBTjb_aiOpxgP1Rp4-_6qx0PrRKlZW0m6z7B0dzb-LC_6b5EvNhFiVOCqxKQ8U3iJCAjnn5xNk4Q8BNZ6zd29Uv2W5vaX7k_iPuV784wiBUxvo"

A705FN_AP="https://ts.buzzheavier.com/d/tqiih3ig4idz?v=CW1J5ao37_BVLunr4RfxG8dZFwyRxvGyIsJK6EiVuF8Qb2a9TkxVDjQukOM2wDY7iq5mqcs_raAMDmh4UfVI61fkqV5ijhyc-ruKE6g5CfEipNBjNN13PWGM4FRJk5cBWYPbWc4YQNobjCSx_SmcuwiR18bWN7zVPv9j3UnFdzV-4HHjRdSUHBepD9eu23BlfzZYiA7HlKphMCvZz4WOTy5p6nXU-i--xGqbBCF-fG3HA_FOggIk0kRMJmNpezRuPivmBFkYaGIFI6Ecee8ezprY4IzaxuDyP-ayOvFZHaBZ6Rwls8Z_0hYq9cHYdaHuYEZXGkppUxK_J-UJU4iHVUUdPA"
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
