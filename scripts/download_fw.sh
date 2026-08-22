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

A366_AP="https://ts.buzzheavier.com/d/b6h4mvgi4nwk?v=-2ISDgiIYAxKXFF0is7pTYhY8FfQjZgrxSJLjC7ultE57vY6yLHnwAo9tMFmnsZXH7GESQG75OESAeCEV0hJlUmCcSVYFpwMw5uKrUeCRhsiA6h-rQD1--_68blnt1SkORXo9UREM_przp8VdPSKz--yh6nghWjfO9pOZR5Ja5klhs75Od7G7rh8sWmt4FejspUUHT4DxUpHWaYLyn8hpc_4m0J3D27urk2bcmIJU1HR0X3vxwgQGdas1H44M1lZF54yk_0k39IJZ3rRdSldTFYOdMd0syVYrnYjjQvORHZs0Kjm7t15pPICk-Kcb2wyO7oUhKXmuY4Iw1Lcplzr1EHCdh-LH0TXMGtk"
A366_BL="https://ts.buzzheavier.com/d/w3a582ba9obg?v=YAkAzAO76478sXsagjH6w5YBgy1oxpUpc9HJRFQFS8Dm6R78wKXOZU-LZWbuv7IXtUxlChmPPKbW1qqfCkbbJlfynZygSRm27M5i6VJmxXmftPtEsQ55SlP9JEYi7zqr-aqt8mugTmTZUArieAAnlckWue_WgMG-h1cAmeHiPAWlhTZPH-O9mYJ0fDpx5e6lXKrlE7OAvbOc0JdwvXjmepkgi1XiRy2K1_-LgOkf0clC_ES0Mps7MD5obOijY1lcJhSqV5oPp09OMhRdTot_QVIIAVbX2bJd06UCmFQPzekCXYb9a6LPxC-0oCgacFMCkpbvSa6vgA"
A366_CSC="https://ts.buzzheavier.com/d/z9vn6crydz4t?v=rxFy469xAwlngaU9qRfY4n29Z9Zlcf-SHxNLBduy10yg2EGStG_vx8ePazro_-2oGConGmjOKEzrr9EjwW05ukZ2Vc3jBvBb9RKXVmItAAMCwSGWB3LoeQDvGar3yVaiPtct1LL65bwPZ1GpWFoDDkEKXUXryRPcHZuboGIRjSCLi9iA-uvTyNBKX8zSFlSu_9Puqazk0y_68MBMwrfK-UxM9ThLWM57yXMxzNpE_t6XIkc6q5NLxH-Ez-2PozJoB3iK0xs0TE-4zCPsvUcHYPy8d10GOE05fTVewbea4X90IZk8Yg"

A705FN_AP="https://ts.buzzheavier.com/d/5gjjethkgp83?v=_qPDxWUPnUjRqXI6jWk381X4-6DKYBbddp5j89Y5G0eMolDvKPW3S0oMjpFpMi6_2D1TBQFR9yzCwECcs3ZH7R79Y0oi1SfAaXtO8LKMeKW8cFAJM-PIttbWxe-lI_xCDCueJ5VP3xfvQfJmideLQmtmdvwimU2xwo0geVQYs0GvkeN52qLYiyB13oB877GVh7q7tnb1NwoRGvpPqMm9nk7Gg-pcIlpbQI8ycc1_C3SXls2A0ybtPteyjFmIZSXhdPJ49dAj37-Eth3rHiqHOrTnkGXr-sUjz2-5Cxg4l5BJZe_Lvlc-T5v6stpGUAOlRbwJ27n2r3smgfraY8rqy9Avfg"
A705FN_BL="https://ts.buzzheavier.com/d/5gjjethkgp83?v=_qPDxWUPnUjRqXI6jWk381X4-6DKYBbddp5j89Y5G0eMolDvKPW3S0oMjpFpMi6_2D1TBQFR9yzCwECcs3ZH7R79Y0oi1SfAaXtO8LKMeKW8cFAJM-PIttbWxe-lI_xCDCueJ5VP3xfvQfJmideLQmtmdvwimU2xwo0geVQYs0GvkeN52qLYiyB13oB877GVh7q7tnb1NwoRGvpPqMm9nk7Gg-pcIlpbQI8ycc1_C3SXls2A0ybtPteyjFmIZSXhdPJ49dAj37-Eth3rHiqHOrTnkGXr-sUjz2-5Cxg4l5BJZe_Lvlc-T5v6stpGUAOlRbwJ27n2r3smgfraY8rqy9Avfg"

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