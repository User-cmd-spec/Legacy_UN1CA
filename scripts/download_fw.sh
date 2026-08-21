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

A366_AP="https://ts.buzzheavier.com/d/b6h4mvgi4nwk?v=x0v0p3-GZWA1Q186lmL32nafs_RYl-K867qz3aA2YKcQbeLGF0By-GLomV4ObBBEa9HJzwUefsXCaEM6fU3XO_V7SqT9Z9h9YK8D_ovC8xIhKvJTGINDs4dg9B2kvxJR6lmvkYMN3UiCYU0D7j5mwvP7BnDsXWUotnJMzZgc2HLCe83Tg_bJx3tGV_5ODv4RCMCKU2i76w4DjLji8NvIH1bSal8AMaCgUx8EOCzN8ix6GSI7h9A2_teNaARi4O7RrcOq_P-V6ONzUPNgoJ1r4p2QlyHKWwcR2miWNDHAR3kzsiJfsCfixw825-iBPFGDj1SEXXFfBlzMGbxFli29OW26BPOxo65847-9"
A366_BL="https://ts.buzzheavier.com/d/w3a582ba9obg?v=tufRKytn5GCuOH91A7V_AzIQ2TnVUkhcBDKB5gFP4yy9YizjZekRP4xq7AltczmhKIQhcUZOXooyEIvJZ5qJXqZbE9tAYfdRcPljD5BWN-jRg1P7_LF0xZMCiNOy77Rx3koeMwfz60Y6UcLe47ZcHbGrwKjH2tzrlJOp_7R99tTwbnkx5UygHKEWXjsOvww7qt8pP-jKb1bcKxtwnN7PF5vFqkJBsHAFntOzMPtV57lE56g1EwqY97t0oKj8GwbI3jb6CG2AILvNnhx8P8lzyQj8Q23awMBJaWtrsdNiTocobfFAkvY2z89n_AlB5h7-3C8oTpPriQ"

A705FN_AP="https://ts.buzzheavier.com/d/5gjjethkgp83?v=ArmpbGqFZ37p6ztMZnqk9WJL1WvPYjGI-18NOYHu8XZoBT4htcTREJK6sGgj0qa1D_GmpXiR0kyDZfFRQLDpNscX0JXfrDX3xnJCDLBD3x0vwLsyOOmwALZtxqd2pacAAQl4u-hIAJ-cPd-pJt78crusj8HoChkXq0MHTw96RfRUJsoFpwieIsfLwq-2TRTyq2F093pGAFTirnSkQ5jZHi3amYMAQ2zZZrU2lX-YOdxaHxQZ81eWS4yoBYe7DhgpjjywHZ6ngxWW7cSpJjr-9czCtoP3JjFAf_yfgd1DTG0iGWe4j8eykAYbSwvXjBZT_c5nrLE7pP6nNowFpfoPjvhQeA"
A705FN_BL="https://ts.buzzheavier.com/d/pyjkcjbou6go?v=KbmsR13DpaOGRTLeUvd36ClDHprARI3ol22T8k2qQY9DOYn_xJcTWdAzxgO7B7YX1GvShc3UvdRd6O8puqVbRJDjWgwada2zMwfXbpPnKNyks-1nQFpRZmC1x84D-xGDsqp6nwdyRS5wH7OxuAWbOnjUAytE4BthE0i7m_WjGGsjD3aXJ5hiWW_Lnr0X5Nz4a_8bQ5M2OqpxRK3nadDJ55N_FGrbmIvkFPW_LZ7sldi4UvKr9sqXBc4z7BNSOfW3-uuCtTP7Q-RMLPDqFvx6IA8afaWvPpTtYKopKzQDtw16CMIgzYHulgMByuqoJJk"

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
