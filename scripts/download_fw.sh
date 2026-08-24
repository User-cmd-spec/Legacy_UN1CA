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

A366_AP="https://ts.buzzheavier.com/d/b6h4mvgi4nwk?v=f1gLFg2S0fN7TjaZHu-WUSoGs-DRpxm8dAh_WwY33tmqmS3Ok8i-JqeQTDOt9DDapiBH1Bc-1yEa8njIuS8xIpoioOrGfq_BHsRu5n09-L9tx2tZ6X4VKTM-ehVRpjQYBGG02T_n2CrNpKRie5444QGyb046fcaZFGzJBTU6mhntWL2FuE73W0TzZEB6QTHtPTMtToqpLnSCKa5PFW2EhdV7-alQFLjvdq-FGbZnhahEKp_6G2ZWOydvfkK-nS5i4cPKGy_dM5K-C5yXcgocgZOCcl3d8NB-Bqyrqu8xtdFJfLYpnCGKFDZYzP-c0ybNGnCxp5g_OPfTLxDVlUVVYk0m7IpkkQQqUH8c"
A366_BL="https://ts.buzzheavier.com/d/w3a582ba9obg?v=mujleajx0rXxrg4hq1FYr10CDHKQQKfMq0IhV201oyGfawNnimzalDAHwyR9OhdGvxO3RIoqxfmz6dvpWQxng5FnxV6oDOjdjhpj-9z7LfjstGcasT8VsH1S8STi6xBD620dfhnbXPQnqK3F9AqSXolWIXEc9ALWL2_blF4FnOmJ1iY5EygHObZYNpAYqHigBh6yK6KKJKVwT51uY2MTo14PNQp-ZP9QqY5s8lY85ZMJR7Lofdknk1MPzVq8bFGdmKDv23rhdc2dcPHjtcok9J_DIN7vvyfW1fMkA88gSDBoHlqpXygOR2Doss8VDxqyWqerAeJjTg"
A366_CSC="https://ts.buzzheavier.com/d/z9vn6crydz4t?v=rxFy469xAwlngaU9qRfY4n29Z9Zlcf-SHxNLBduy10yg2EGStG_vx8ePazro_-2oGConGmjOKEzrr9EjwW05ukZ2Vc3jBvBb9RKXVmItAAMCwSGWB3LoeQDvGar3yVaiPtct1LL65bwPZ1GpWFoDDkEKXUXryRPcHZuboGIRjSCLi9iA-uvTyNBKX8zSFlSu_9Puqazk0y_68MBMwrfK-UxM9ThLWM57yXMxzNpE_t6XIkc6q5NLxH-Ez-2PozJoB3iK0xs0TE-4zCPsvUcHYPy8d10GOE05fTVewbea4X90IZk8Yg"

A705FN_AP="https://ts.buzzheavier.com/d/5gjjethkgp83?v=kQOfIgx60qgrhZWz_0EYNXPUn9z630GFqFz6vx7NF0gdrJpGSFj4DSNfeGzHUBq4Nu-0EwFspdmtU1VYEs0i0DUavs3J3rzCS0mtmPgqrHTO1f79-1YeVnJDTaCOn9NjnKaYHB1N_8FW2lZwJbMO8ABkAqDKwRWvbs_2BfeC5WmHloBdpkgoOysBFGx-hInh3U_wUygbPqftClosVZSMRyft2jSdq_Z4aqf1BSOiZ4HEW-wK9AW7-cRC2fKiuiRFmnEJb28R3m2rSCFS-fEvZ87QriNn1zfju_Wk79lsmkhOM6Chtkgb33bVcY8LgZDbAGZC7hzFlXZHeFYqQoVG8bkjDA"
A705FN_BL="https://ts.buzzheavier.com/d/pyjkcjbou6go?v=ptanDYbC-_rE6M-ub1cyQXyg5uFRD-QIm_QISWN531iql09f3xcBuCru_7OlwO5MdI0YHV5bz9ePKo12oEo2rT_zWpu5qj_fjCb9685jTrpOGtA7Dv7s_iFylP9a5WvlAxiUHXglrmaNw_lxOjz2UyHRP_Z9RjMhqT2GKiq4G9IOo8RP3nPyVVbVRW-O2MBHk-4XRzGr-fOtV3KdWxv2oi1id2woZPFT_cmSaAy23o7Jfay5z21yp2igL6vTjFXXQi1EfPkb_iC-4C7rcPNKlw4Kh76hIOhUtnatLVpU83GiLL-zLETFJOH1zhUPCcQ"

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
