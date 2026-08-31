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

A366_AP="https://ts.buzzheavier.com/d/yr20r31mrxfu?v=DHr77dw2Btjvqx1AxyXdtzrFFzClFVa9h_ikV2uHlwMUJ00nr1DatX-fWk2wwONa6p_UrJpvUPmIj6XCR0HL_yGj_AT_y5QQ_eWQTXO0SxVyLdt8kWwlANqC1v35inUr_uux9CazA8ShvXbH3RnmoFK7JAwtnGU8UUQC6rElLccyv0extc28eLeM-VvVCQ-fnEbGLqHqKKHNSS-_SRzwKZGF5mdQeBR839qh4lHr4LRRDT3WF10vOCDF-R5UZZOo324lt4rv5oMtVhVhtJtCqc2NdR1bUf0Qf3hNFQ-rcFBkEzWRf6V-QeNXruLRgFRSgaNHV1l2bc00ShW6MdWzzDIPNyVgmeKzj1TB"
A366_BL="https://ts.buzzheavier.com/d/ib2jbg2zgrsj?v=yzyNogqYx6leQotBwn6W_9RkkS2Pl9FMBgUPBYDwVckoUGZHeJ46Y6y0g-1kEEWAMxBhFqYA0-QcAR2ztsBs4scUrU8kUoYmU9sHllWDvQzKv30Ep9bAqnFMiwjYBLaq199PKi5_nBQiqIMOQQGT78bkpCFvPQNUYOXoyruvwvDMT87uF1pAoKY6-Gks0-nAFNWwwqDKemA-3RVAUwTPLiO1icvrt_Ixz1N2XNi797-h06z8lXvamSG6plwaQVGexrlLDUh_f7WZ_aYUBCX97WLYNP3E1KalU1ZISYpc87m6uRIbcwEeCRyp9XqCohhlanpOUwGxhg"
A366_CSC="https://ts.buzzheavier.com/d/6mr1wp8n0q9w?v=o8Sou-0fC5iBLYiPJKa9ht45trbL1lyUh1y7Eem-P_6jrypB3XZIM-LmpO_hbobOMTL-BrqIwhz_RsvAdTeFdYvd--YQArDQiivgrFqpd__j0pIg1YKKQQ3_Q4k0xrxVZGba7hwy5OJi39DPqhTXUB8uzbHmep6e35D9dz8fc3Nu-C1-6hT4vdXDFbuF-ND3AF8KZmhlA9TeKHxbNnuR7Ifr3lV4dmpVIliOvCQvEmSuWA1IG8Z5gjKRfzoqDhpNAlcSp0idioFy29XOpkgmR-WYwW8lXUyTTJ1dfVHlqtbhUlrVvw"

A705FN_AP="https://ts.buzzheavier.com/d/aovfxqjduk30?v=4dgJV8lLxjVUMVyNKCbJVHQiZfE3w-1IhRfpisPeDkafn7i4kSOcZ6N2D2YQCmta82I8gGWNmUH-ox2MzIE-mQRMXRMWAjuqz8STGrStku5O9bGyTW61Z6RBZK0Rm-xzhm7gkXQwf5m4ZotJGLzIkZZOr84eb_HlGRdWgthVNBYmyBnRe26cHZj7JNjmYg3bWKlHNj9QwnWDBP3B-YHf5WA9dL1U2nDZFB3R3oBcLtM455vbwMf7-3ssmek--CXfNzEH42EYUE-9CsanvB-Br5xz3VsSopV1ylqGPbe0lGQ5YShZ_0KM5Wu9Us5iN4SokOOnKTDahCVMeE-Tos8fxbvB9g"
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

    case "$MODEL" in
        *A366*|*a366*)
            AP_URL="$A366_AP"
            BL_URL="$A366_BL"
            CSC_URL="$A366_CSC"
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
