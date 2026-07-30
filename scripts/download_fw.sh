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

A366_AP="https://ts.buzzheavier.com/d/dmxgprk0tnzv?v=xC1mqJ02ke065_p_FmYi6ItDetZR5OWp06ATnLSzvunSZh0gDjnJ1YDyWOXJ2qJhopZsL5XtNuN2ptFHsEnBvWi-Zu6i9QWRLK73kK296nj9ZxUdqNP8oLyrIwVp42MmX-OmjOrdZqFR8_BA3EffZBilSsBJ95-Lt8OLP_DeFJaugjWxVhFhz7mlcpKzYLYGWYNSCxrBTMcgZx2Qv8XNHiMU__skVYLqYiEON_rk-bb4ptdWvaaJFBtCA8SLdAxyE2WKm1R34sZB2jBfnI6TX_qDIKMVdlUTLXzAX1k9aL583yuu4qUDfZ4OlZ2S0dWW7TWUXwQfmo4dyXySBT3iA0lTOQEvV7yb8zpH"
A366_BL="https://ts.buzzheavier.com/d/w3a582ba9obg?v=jSqnPNQF48T5uFiIgN2Gj2qEFOB7XoYt_9u_2PuG4zO4249y38OLSoq4wAyexgbM_MB9c5OyawCNu5zIBWzWUPn9rS1gsC8Ztsv4kC3mCA2uWucIdW3V-N0OQOuoUiBksTZiyv4Lmfy17Z_yhLyoSZ9VpcOkMQ4H-rykIfZRoiE4MPF8NbJZfQ5HuZdVeIWQWqFjGuxh0LyB1fwRxK_-FnEwNsKDfTOwjKq6MDGoYK0IiD5USuZHCbsx-ih9bBjucCeWNnQnS5RRthJ8rLb4dJFm6kVSzqkg9imEK32vVOQtIAgQ3Tuuil3aZP6lSAwR_s9PBLvYtw"

A705FN_AP="https://ts.buzzheavier.com/d/iivnn2ka3pnp?v=mZPvNQdwOM15bsc2Z5qKEo6vSvzc2y2Sy4S_k0ugGgTvidd5azM_Rm4j157r6EffMtBY5FyOc32BA1oko2ZydoNLgdpfzfuREm2O24KmCARLwMLvwuPYycAb25JFjn3Oe4bzL9vgEUZSLHbhunwbgrLuIFNUQmz0v4w5x1WkT53q7HU71BPl4g_jaXCSak5LobEZhEy_4F2DBlCu3N2F94Hv3Txhl9MfE6AalGvXubqHHPMke_TnoBS6zrj4humsghsDHt0CPJ3vs52CtFVix4vyfNYdtuvyxjk5TsQ2dE6T3_dDVcPLbAsSrcXNvkLY_9q5e6Mkg1bnejsSUnzvVoy1Mw"
A705FN_BL="https://ts.buzzheavier.com/d/ptawjbdqas7q?v=IBoThUgqrNuQWgqMF-DpVDVwiEAQBrCpFs2V1mFGekL9jNvErKV2xQmr51tPqXPywWdUlAP8V-s8NkC1sucOgHzqbK4Z9jXFcyTSGI3ulV8qFbVn4DG76Zasgvb0D4_kfsJx_4G_JTxWnC8kZOy55dBjCXUTD6Y8Jh8ZMzrVKh-OnACMUXleLEPyaRjG5XGPbnFCQvTnVytLUp291Iq9iH04EnNhjbgD8UHadIcb6hww969iWQ_Zq8eTNraScgjuHh63beEjvfNC2jgrhyXyGYePsKOiQ5xgopwX5amXO70IOPM9SjoRQPPAXuZ3Ems"

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
