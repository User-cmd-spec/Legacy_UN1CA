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

A366_AP="https://ts.buzzheavier.com/d/70gjsofwji35?v=tBVT0l04xdvtLjDlNfnBLQmDVGz3MhTFeFGgz0e2icgXK7Qr_5Ga4I7R50TtTsA9IfD5GAbOjMb996mv9Q1lu6E99qrZBYqPzljsj6l-ebRS9cD1CcsYIbPL91tftozW6Md_nYFFwkI1WKPUbD9W275fG2HdtViRXpn6DgI_2k8_GjZUNVlzUJpSWanVo-dN7kRr26Hvy9x5Ihqso8T4dZmXkw_hP3bPGVJgdFrT2jMckD14gbF6XOTmv5tzJtp-Q-SLEo6tfIuvex1LIzobMTS7Lx9m-BhdAPZZZeJ-mmtn6o8aAaVBuaDGZYfTp-Yn_cQPCPZhwevJh6u8JzwfPBU98AUxz0pUNzTF"
A366_BL="https://ts.buzzheavier.com/d/w3a582ba9obg?v=G74StXdDWVV7oRQOfOWFjmjPBa7dadP9UEUkYtUEp7P__vZXTfortqK81qs9Ybx8ny6Xg73oovS-704gmSouknGGBAOncVASNjYcFMq1P1Tq8BlrTZtPgfJPFnXZOZHysKWUUJzmujbxwDI08LesHGw0wx3ayxeFEbfNUeRxuCi-CJmviIT7qe3ujBxnWP7TLENpHrrPd0gzMfmVJa3cLYn7KhzUo8n0dkjmEzD2b9ATXC6J5PiW8U7acrsQTHqJCvPM75zUKjQzxVRdm8ovvMxJziNJ5a42nRKp6wJthReL6tnD-IZWdFXOASJlliwiGMbms7KvxQ"

A705FN_AP="https://ts.buzzheavier.com/d/yg5k78unqv7z?v=IN1XkDMn_T-8omMgIVhre4xMOqNldpv-ZgZ9DWdqP0CFfd04SUzeOqWGuOdUvmIH9DAY_35g2DDOGtSXGsmeL4c3FqCk5jnTypfdHAif16WEf45Vred1y2FItK8JKHf_gZ_-co6KIo9sMjB5jN2BdocM_y-SvvTYPFRQHFbXHyQZ901aA4As6i33qv5C1Epdp1BT7_0SR1Rz8nQ65cwDvWTicbf_EkINXLj6TsClpA2obYkxHFK9Of3nmH_ouveZgt9TN1J7a0dT1_QQi9GD826RIayutjqDbx4h1FODSyn2SCexPpQwdeBGpv7DUPdTAa1-g3YmaSYDS6vNxvteBXeDFw"
A705FN_BL="https://ts.buzzheavier.com/d/k7qga78h2enm?v=DuiF8oHoppeLJ3ZtcmjcyYT6rqyAxpkXaI19Nmeo9oCooZYgQPwQAQJ34fJx7r1PS8SevJSl6qOn8525T5CmlXHziNOq3zlG0YU8gtp-yCJ-jXlWzafZ0iua8asCe1N3fZfVYNWmLrtVa84vyC5B4sVYdi2U1FhbwEHXPSS7mVGtVeONVCO1EeJE_Zpwrvh_vtGJbcp3GPU_2Opv0LfLLkUGqWQLsY8eiCAD_LFODiiuUiQo5QMPoVzTKjEitV-ZKOOvzsmzQ5YtbPVCPN1wibvAJd3rVJqOk2r1VDmc1yTEcxJPlT1yH0tRZ6KFWG8"

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
