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

A366_AP="https://ts.buzzheavier.com/d/70gjsofwji35?v=GxWKLtlzX0DgRLiOyDBWHNFz0BQ2GAmYTJb5wt2WtKMAMck0dqKPph3UKXu0FGJcUdmLM_soBUkj_W1myh0SKPeKHrqR3eJOSE0YKnTczocr7-6jScIenhs8VAQSUqXG2Qi3fj0nWQJI5H50MYW3bokLpkDLALBvNE5g5cxm8rqBnC6md6utuoRBJoj4ZMs-HVuA6XIxGMiEyQ-Cv2mGICrMMx22V19B5SSkjKvWn8qFXcf-LFV_S3nwwuPgOJC_TmjzGTHpy0hLS-EvfRfIRhJchpTzKta8qjpQabVgmuRk8XM01e_UxqWLhuhbrbhMF7Fk7bRm3Q-GemfEX3lX2-cBhEYH--AOBS2r"
A366_BL="https://ts.buzzheavier.com/d/w3a582ba9obg?v=_Cy58gwq225dE41z-k2TqqoacP6r_KJ_mmOy-C7kU0OO4NDxNgdP3CFwtjezxK8MRpPqRdQydrtTXY9PrYzNuyBz-kCnZkccrTQK8KPzKIWYD0EKInxmfMT_XGYeF7d0OO0NX-kJRUaaJP9HF4p7HeRhNTVcBBGLLCQHyL1SdP7n8yGFh5GjkquAJXBDfbglFiidPNIciU7W8lThbKcQOwR7VOyhY0F9CMYqIv1OH4e6Nn8rfvza2-nbj5SRpCmeen2A5ZIU8DDsLZZaRdAJl2htu4T1fTsKvthBG6htRwIzEqE3cCDazR5tHgUakoKCwRWWdDWj8Q"

A705FN_AP="https://ts.buzzheavier.com/d/yg5k78unqv7z?v=Pq13tMNPW2Et7fIqrkIML4V9YNlgOFu3jDvWRG8nejISpqCNRTAicDWhq-h_62gHO7zlXvl6OynU2amh5EDXZpd6_CXdjoenfq_WiWxhqj4A3v2CYzYIKqPDMDCIJtnZc_nQAunbAeFY3RYrZ7-rI0k_pWmMF4BCZ_NFprDsBgLOhZmuoq1tN-Lk2plMsLleRI1qACRHG-DzdVLZFvIexduJrleEmvRT5be8OfqcT_rQJQD8wAyyQY8qU6nRQR9P2GbytaADhpN7A5tI3eNgSo93Pd36TIQqFVlJvBxGcejUiQ2kcBZ30T8JLkqG9h3iZdCO9sfcWgy5JwWbNYkfZrMC_Q"
A705FN_BL="https://ts.buzzheavier.com/d/k7qga78h2enm?v=KbBm1XqVATxrsnlAy6UBAI6TTqajOYDM_c6jTZPWtVXmEY5NV1fTb9zUeXW8J-FGi6sGGK6q4BmN9f_5XI_qmwiOUOexrVXnq2gNeRa8BF7zMSRHoEJ-5YxoBCdT_E2qj4VOb6cQZADzAdxCqIqZ811tmDc2Vz-5c-SxyRxH1BPcnMrmvkYXogMApCMD9UEiMQpBEzzqwvHQ3V5Df3KcPS_OaLemFO12UZ-yYm9e8tDaR8-3sN4yjPEl3XwCNDfYaLPtaOw3ugKyb8-qdntXd1l_CyjhyEu9v05P3AKBFwOARaesneKp39Kr-cYmC8c"

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
