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

A366_AP="https://ts.buzzheavier.com/d/dmxgprk0tnzv?v=6jL3nF9j8cz-EMjl8MXXJTN-zNv3zCbz21NexnTyRPOgm_4iofBRaLh_lVrFe2arLvDppazU1H9NufQELvx9wpU6eB3J7yxP7MzhBvpm3tZhcA7251WMmnFb2vXfoxRlN7JfrWL8n1bcZ5-TbTD69vmaaEz4e1jGUAL4lb7BPNmTJKHTwaux6UnujC0_JeEuSXr3oekskvBpuffKEbyTuWeoS0jgIE2OkwZjqM-vj0VbuoFBmJW5iIAVKGM_W1pMmSUUrLLNxho1Kczj52JCIWRAPe4ahMZxJS30eJHwzOnDcvBQvU6GiFDE87f8w6_rzF7GXfojWvLPCr1qyub68fCrN9GFGuahZYg-"
A366_BL="https://ts.buzzheavier.com/d/w3a582ba9obg?v=UF1IU5QSqyJefyrw3T-3rkUN21laJM5rQPJC6qhzxQbSnM4g1g_AVu7aSG3sHsuFx2OkneaKQAJiQDUQDKJzJLvf_ySyfTiU3YvKAOiJX3Mh5TUslscHx0fHMKgGfTGO0bpc5D_qdwtJHSHCf27uKXuGAhlXTlAyqoTZvFnnqNSCOijO7OIjEJDtbWtJiQM6inQze9jXnaibK4pBIL-NCZYcAX1Tc7sLiV2nhqdgj-owtjvYKq8zo26g-qIYs9LUWCmwMowOhwrI81jzCOV0UuKu7is7GCXNdASjQwIaT6-o2D1vXsTWar_aBuN8B1lgy6vQGp7EhQ"

A705FN_AP="https://ts.buzzheavier.com/d/iivnn2ka3pnp?v=DJ9IQ6DTgfA5mshJLUAeTAYa3Oq_F2HMNVDsDOd6nCy75_Nk9VDD0eSeLjzwNWZyMZh4U3cljenea7f7b9s7Y5wB9HEWaGKX1dlM1HSVEWXvcRmvYGVFeqYEo3rzRvq6GGlPWbK5WGOIOoHyL-RLePGHhY4LNc7wI1aH0gtW33mfzuNQKe69WVS-8vw1R8xprWdh_O6XWk_y2cJahoAe8VWxfMyFTOy0IfxcGybbm4lO4RpVRGIy7SoHY7pYcqiboy_McDy5f4og7jmNMiZ43NVzP0DW_VXAdVpy0nZHEVa8yV1pox70GANXIsWVLKGjUUjAEvhygC3ONOD19WQygQpZzA"
A705FN_BL="https://ts.buzzheavier.com/d/ptawjbdqas7q?v=39BWppH2kBo69S8rrk_eOVVVDYI7O64xkpv7CR8HB6J09HzeA7FshvZZOvrS3Xzk7gSQec1i2IOjCO6_6QAqwnanTMzzZYyBfFBwECFZyTlHX6rzIXlc-L4Anmm9SygltKbVjp8YTMLIx6H8eREMJzgLhpAitlT1XFoXXNxAo_HXPz1lUzBED_9Sju7e0qaNqyMvnYKj_qjBK3zAU5PD96VplztCNtW9ryzSM8FGbL4UGPyRmooDv1wdD6jWyGF9dLHkfXPPu4ZX8BcUl1acRr1PIHTh-c2Njk9UIF3Qh3TXhYhPD0snNKDUOxng-ho"

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
