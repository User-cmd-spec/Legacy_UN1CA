#
# Copyright (C) 2025 Salvo Giangreco
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

# [
# APPLY_PATCH <partition> <apk/jar> <patch>
# Applies a unified diff patch to the provided APK/JAR decoded directory.
APPLY_PATCH()
{
    _CHECK_NON_EMPTY_PARAM "PARTITION" "$1" || return 1
    _CHECK_NON_EMPTY_PARAM "FILE" "$2" || return 1
    _CHECK_NON_EMPTY_PARAM "PATCH" "$3" || return 1

    local PARTITION="$1"
    local FILE="$2"
    local PATCH="$3"

    if ! _IS_VALID_PARTITION_NAME "$PARTITION"; then
        LOGE "\"$PARTITION\" is not a valid partition name"
        return 1
    fi

    if [ ! -f "$PATCH" ]; then
        LOGE "File not found: ${PATCH//$SRC_DIR\//}"
        return 1
    fi

    while [[ "${FILE:0:1}" == "/" ]]; do
        FILE="${FILE:1}"
    done

    DECODE_APK "$PARTITION" "$FILE" || return 1

    LOG "- Applying \"$(grep "^Subject:" "$PATCH" | sed "s/.*PATCH] //")\" to /$PARTITION/$FILE"
    EVAL "LC_ALL=C git apply --directory=\"$APKTOOL_DIR/$PARTITION/${FILE//system\//}\" --verbose --unsafe-paths \"$PATCH\"" || return 1
}
SMALI_PATCH()
{
    _CHECK_NON_EMPTY_PARAM "PARTITION" "$1" || return 1
    _CHECK_NON_EMPTY_PARAM "FILE" "$2" || return 1
    _CHECK_NON_EMPTY_PARAM "SMALI" "$3" || return 1
    _CHECK_NON_EMPTY_PARAM "OPERATION" "$4" || return 1

    local PARTITION="$1"
    local FILE="$2"
    local SMALI="$3"
    local OPERATION="$4"

    if ! IS_VALID_PARTITION_NAME "$PARTITION"; then
        LOGE "\"$PARTITION\" is not a valid partition name"
        return 1
    fi

    while [[ "${FILE:0:1}" == "/" ]]; do
        FILE="${FILE:1}"
    done

    DECODE_APK "$PARTITION" "$FILE" || return 1

    if [[ "$OPERATION" != "null" ]] && [[ "$OPERATION" != "remove" ]] && \
        [[ "$OPERATION" != "replace" ]] && [[ "$OPERATION" != "replaceall" ]] && \
            [[ "$OPERATION" != "return" ]] && [[ "$OPERATION" != "strip" ]]; then
        LOGE "Operation not valid: \"$OPERATION\""
        return 1
    fi

    if [[ "$OPERATION" == "replaceall" ]]; then
        _CHECK_NON_EMPTY_PARAM "VALUE" "$5" || return 1
        local VALUE="$5"
        local REPLACEMENT="$6"
    elif [[ "$OPERATION" != "remove" ]]; then
        _CHECK_NON_EMPTY_PARAM "METHOD" "$5" || return 1
        local METHOD="$5"

        if ! [[ "$METHOD" =~ ^[A-Za-z0-9\$\<\-].*\(.*\).* ]]; then
            LOGE "Method name not valid: \"$METHOD\""
            return 1
        fi
    fi

    if [[ "$OPERATION" == "return" ]]; then
        _CHECK_NON_EMPTY_PARAM "VALUE" "$6" || return 1
        local VALUE="$6"
    fi

    if [[ "$OPERATION" == "replace" ]]; then
        _CHECK_NON_EMPTY_PARAM "VALUE" "$6" || return 1
        local VALUE="$6"
        local REPLACEMENT="$7"
    fi

    local FILE_PATH="$APKTOOL_DIR/$PARTITION/${FILE//system\//}"

    # Check if provided smali exists
    if [ ! -f "$FILE_PATH/$SMALI" ]; then
        LOGE "Smali not found: \"/$PARTITION/$FILE/$SMALI\""

        local MATCHES
        MATCHES="$(find "$FILE_PATH" -type f -name "*${SMALI##*/}")"

        if [ "$MATCHES" ]; then
            echo -e "\n\033[0;31mPossible matches?" >&2
            echo -e -n "$(head -n 10 <<< "${MATCHES//$FILE_PATH\//    }")" >&2
            [ "$(wc -l <<< "$MATCHES")" -gt 10 ] && \
                echo -e -n "\n    ...and other $(($(wc -l <<< "$MATCHES") - 10)) matches"  >&2
            echo -e "\033[0m" >&2
        fi

        return 1
    elif [[ "$OPERATION" == "remove" ]]; then
        local USED
        USED="$(find "$FILE_PATH" ! -path "*$SMALI" -type f -exec grep -r -n -- "$(cut -d "." -f "1" <<< "${SMALI#*/}");" {} \+ || true)"
        USED="$(cut -d ":" -f 1-2 <<< "$USED")"

        if [ "$USED" ]; then
            LOGE "Cannot remove \"$SMALI\" from /$PARTITION/$FILE as it is used elsewhere"
            echo -e "\n\033[0;31mMatches:" >&2
            echo -e -n "$(head -n 10 <<< "${USED//$FILE_PATH\//    - }")" >&2
            [ "$(wc -l <<< "$USED")" -gt 10 ] && \
                echo -e -n "\n    ...and other $(($(wc -l <<< "$USED") - 10)) matches" >&2
            echo -e "\033[0m" >&2
            return 1
        fi

        LOG "- Removing \"$SMALI\" from /$PARTITION/$FILE"
        EVAL "LC_ALL=C rm \"$FILE_PATH/${SMALI//$/\\$}\"" || return 1
        return 0
    fi

    # Check if provided method is method and exists inside smali
    if ! grep "^\.method.*" "$FILE_PATH/$SMALI" | grep -q -F -- "$METHOD" "$FILE_PATH/$SMALI"; then
        LOGE "Method \"$METHOD\" not found in /$PARTITION/$FILE/$SMALI"

        local MATCHES
        MATCHES="$(grep -r "^\.method.*$METHOD" "$FILE_PATH")"

        if [ "$MATCHES" ]; then
            echo -e "\n\033[0;31mPossible matches?" >&2
            echo -e "$(head -n 10 <<< "${MATCHES//$FILE_PATH\//    - }")" >&2
            [ "$(wc -l <<< "$MATCHES")" -gt 10 ] && \
                echo -n "    ...and other $(($(wc -l <<< "$MATCHES") - 10)) matches" >&2
            echo -e "\033[0m" >&2
        fi

        return 1
    fi

    local BEFORE
    local AFTER

    BEFORE="$(sha1sum "$FILE_PATH/$SMALI")"

    # Remove the method completely
    if [[ "$OPERATION" == "strip" ]]; then
        local USED
        USED="$(grep -r -n -- "invoke.*$(basename "$SMALI" | cut -d "." -f "1");" "$FILE_PATH")"
        USED="$(grep -F "$METHOD" <<< "$USED" | cut -d ":" -f 1-2)"

        if [ "$USED" ]; then
            LOGE "Cannot strip method \"$METHOD\" in /$PARTITION/$FILE/$SMALI as it is used elsewhere"
            echo -e "\n\033[0;31mMatches:" >&2
            echo -e -n "$(head -n 10 <<< "${USED//$FILE_PATH\//    - }")" >&2
            [ "$(wc -l <<< "$USED")" -gt 10 ] && \
                echo -e -n "\n    ...and other $(($(wc -l <<< "$USED") - 10)) matches" >&2
            echo -e "\033[0m" >&2
            return 1
        fi

        LOG "- Stripping method \"$METHOD\" in /$PARTITION/$FILE/$SMALI"

        awk -v FN="$METHOD" '
            BEGIN { inside = 0; skip = 0 }
            /^\.method/ && index($0, FN) {
                inside = 1
                next
            }
            inside && /^\.end method/ {
                inside = 0
                skip = 1
                next
            }
            inside { next }
            {
                if (skip) {
                    skip = 0
                    next
                }
                print
            }
        ' "$FILE_PATH/$SMALI" > "$FILE_PATH/$SMALI.tmp" && \
            mv "$FILE_PATH/$SMALI.tmp" "$FILE_PATH/$SMALI"

        AFTER="$(sha1sum "$FILE_PATH/$SMALI")"
        if [[ "$BEFORE" == "$AFTER" ]]; then
            LOGE "Failed to strip method \"$METHOD\" in /$PARTITION/$FILE/$SMALI"
            return 1
        fi
    # Remove the contents of method, leave declaration
    elif [[ "$OPERATION" == "null" ]]; then
        local RET
        local LOC=".locals 0"

        RET="${METHOD#*)}"
        if [[ "$RET" != "V" ]]; then
            LOGE "Cannot nullify non-void method \"$METHOD\" in /$PARTITION/$FILE/$SMALI"
            return 1
        else
            RET="return-void"
        fi

        LOG "- Nullifying method \"$METHOD\" in /$PARTITION/$FILE/$SMALI"

        awk -v FN="$METHOD" -v LOC="$LOC" -v RET="$RET" '
            BEGIN { inside = 0 }
            /^\.method/ && index($0, FN) {
                print
                print "    " LOC
                print "    "
                print "    " RET
                inside = 1
                next
            }
            inside && /^\.end method/ {
                print
                inside = 0
                next
            }
            inside { next }
            { print }
        ' "$FILE_PATH/$SMALI" > "$FILE_PATH/$SMALI.tmp" && \
            mv "$FILE_PATH/$SMALI.tmp" "$FILE_PATH/$SMALI"

        AFTER="$(sha1sum "$FILE_PATH/$SMALI")"
        if [[ "$BEFORE" == "$AFTER" ]]; then
            LOGE "Failed to nullify method \"$METHOD\" in /$PARTITION/$FILE/$SMALI"
            return 1
        fi
    # Replace the method contents with a single return
    elif [[ "$OPERATION" == "return" ]]; then
        local RET
        local REG
        local LOC

        # Decide on register
        REG="p0"
        LOC=".locals 0"
        if [[ "$(grep "^\.method.*" "$FILE_PATH/$SMALI" | \
                    grep -F -- "$METHOD" "$FILE_PATH/$SMALI")" == *" static "* ]] && \
                [[ "$METHOD" == *"()"* ]]; then
            REG="v0"
            LOC=".locals 1"
        fi

        # Decide return type
        RET="${METHOD#*)}"
        if [[ "$RET" == "V" ]]; then
            LOGE "Cannot change return value of void method \"$METHOD\" in /$PARTITION/$FILE/$SMALI"
            return 1
        elif [[ "$RET" == "Ljava/lang/String;" ]]; then
            VALUE="\"$VALUE\""
            RET="return-object $REG"
        elif [[ "$RET" =~ ^\[*[ZBCSIJFD]$ ]]; then
            # Boolean type
            if [[ "$RET" == "Z" ]]; then
                if [[ "$VALUE" == "true" ]]; then
                    VALUE="0x1"
                elif [[ "$VALUE" == "false" ]]; then
                    VALUE="0x0"
                fi

                if [[ "$VALUE" != "0x0" ]] && [[ "$VALUE" != "0x1" ]]; then
                    LOGE "Cannot use a constant value for method \"$METHOD\" in /$PARTITION/$FILE/$SMALI"
                    return 1
                fi
            fi

            # Convert decimal value to hex
            if [[ "$VALUE" =~ ^-?[0-9]+$ ]]; then
                VALUE="0x$(printf "%x" "$VALUE")"
            fi

            if [[ "$VALUE" =~ ^\".*\"$ ]]; then
                LOGE "Cannot use a string value for method \"$METHOD\" in /$PARTITION/$FILE/$SMALI"
                return 1
            fi

            # Long type
            if [[ "$RET" == "J" ]]; then
                RET="return-wide $REG"
            else
                RET="return $REG"
            fi
        else
            if [[ "$VALUE" == "null" ]]; then
                VALUE="0x0"
            fi

            if [[ "$VALUE" != "0x0" ]]; then
                LOGE "Cannot use a constant value for method \"$METHOD\" in /$PARTITION/$FILE/$SMALI"
                return 1
            fi

            RET="return-object $REG"
        fi

        # Decide what to return
        local hex
        local num
        if [[ "$VALUE" =~ ^-?0x[0-9a-fA-F]+$ ]]; then
            # Hexadecimal value
            if [[ "$VALUE" == "-"* ]]; then
                hex="${VALUE#-0x}"
                num="$((-16#$hex))"
            else
                hex="${VALUE#0x}"
                num="$((16#$hex))"
            fi
            if [[ "$RET" == "return-wide"* ]]; then
                VALUE="const-wide/16 $REG, $VALUE"
            elif [ "$num" -gt "-8" ] && [ "$num" -lt "8" ]; then
                VALUE="const/4 $REG, $VALUE"
            else
                VALUE="const/16 $REG, $VALUE"
            fi
        elif [[ "$VALUE" =~ ^\".*\"$ ]]; then
            # String value
            VALUE="const-string $REG, $VALUE"
        else
            LOGE "Return value for method \"$METHOD\" in /$PARTITION/$FILE/$SMALI not valid: \"$VALUE\""
            return 1
        fi

        LOG "- Replacing return value of method \"$METHOD\" in /$PARTITION/$FILE/$SMALI to \"$VALUE\""

        awk -v FN="$METHOD" -v LOC="$LOC" -v VAL="$VALUE" -v RET="$RET" '
            BEGIN { inside = 0 }
            /^\.method/ && index($0, FN) {
                print
                print "    " LOC
                print ""
                print "    " VAL
                print ""
                print "    " RET
                inside = 1
                next
            }
            inside && /^\.end method/ {
                print
                inside = 0
                next
            }
            inside { next }
            { print }
        ' "$FILE_PATH/$SMALI" > "$FILE_PATH/$SMALI.tmp" && \
            mv "$FILE_PATH/$SMALI.tmp" "$FILE_PATH/$SMALI"

        AFTER="$(sha1sum "$FILE_PATH/$SMALI")"
        if [[ "$BEFORE" == "$AFTER" ]]; then
            LOGE "Failed to replace return value of method \"$METHOD\" in /$PARTITION/$FILE/$SMALI to \"$VALUE\""
            return 1
        fi
    # Replace a string with another string inside the method
    # or Replace a line with another line inside the method
    elif [[ "$OPERATION" == "replace" ]]; then
        LOG "- Replacing value \"$VALUE\" of method \"$METHOD\" in /$PARTITION/$FILE/$SMALI with \"$REPLACEMENT\""

        awk -v FN="$METHOD" -v STR="$VALUE" -v REP="$REPLACEMENT" '
            BEGIN { inside = 0; isline = (index(REP, "\n") > 0) }
            /^\.method/ && index($0, FN) { inside = 1 }
            inside {
                if (isline) {
                    if (index($0, STR)) {
                        gsub(/\\n/, "\n", REP)
                        print REP
                        next
                    }
                } else if ($0 ~ /^[[:space:]]*const-string(\/jumbo)?/) {
                    sub("\"" STR "\"", "\"" REP "\"")
                } else {
                    line = $0
                    gsub(/^[ \t]+|[ \t]+$/, "", line)

                    if (line == STR) {
                        match($0, /^[ \t]+/)
                        indent = substr($0, RSTART, RLENGTH)
                        $0 = indent REP
                    }
                }
            }
            inside && /^\.end method/ { inside = 0 }
            { print }
        ' "$FILE_PATH/$SMALI" > "$FILE_PATH/$SMALI.tmp" && \
            mv "$FILE_PATH/$SMALI.tmp" "$FILE_PATH/$SMALI"

        AFTER="$(sha1sum "$FILE_PATH/$SMALI")"
        if [[ "$BEFORE" == "$AFTER" ]]; then
            LOGE "Failed to replace value \"$VALUE\" of method \"$METHOD\" in /$PARTITION/$FILE/$SMALI with \"$REPLACEMENT\""
            return 1
        fi
    # Replace all occurrences of value with another
    #TODO: Improve, add more failchecks, currently it is unsafe
    elif [[ "$OPERATION" == "replaceall" ]]; then
        LOG "- Replacing all occurrences of \"$VALUE\" with \"$REPLACEMENT\" in /$PARTITION/$FILE/$SMALI"

        EVAL "sed -i \"s|$VALUE|$REPLACEMENT|g\" \"$FILE_PATH/${SMALI//$/\\$}\"" || return 1

        AFTER="$(sha1sum "$FILE_PATH/$SMALI")"
        if [[ "$BEFORE" == "$AFTER" ]]; then
            LOGE "Failed to replace all occurrences of \"$VALUE\" with \"$REPLACEMENT\" in /$PARTITION/$FILE/$SMALI"
            return 1
        fi
    fi

    return 0
}

_CHECK_NON_EMPTY_PARAM()
{
    if [ ! "$2" ]; then
        echo -n -e '\033[0;31m' >&2

        local STACK_SIZE="${#FUNCNAME[@]}"
        if [[ "$STACK_SIZE" -gt "1" ]]; then
            echo -n "(" >&2
            if [[ "$STACK_SIZE" -gt "2" ]]; then
                echo -n "${BASH_SOURCE[2]//$SRC_DIR\//}:${BASH_LINENO[1]}:" >&2
            fi
            echo -n "${FUNCNAME[1]}) " >&2
        fi

        echo -n "$1 is not set!" >&2
        echo -e '\033[0m' >&2

        return 1
    fi

    return 0
}

LOG_STEP_OUT()
{
    local INDENT="${INDENT_LEVEL:=0}"
    if [ "$INDENT_LEVEL" -gt 0 ]; then
        export INDENT_LEVEL=$((INDENT - 2))
    fi
}

LOG_STEP_IN()
{
    local BOLD
    local RESET="\033[0m"

    if [[ "$1" == "true" ]]; then
        BOLD="\033[1;37m"
        shift
    fi

    if [ "$1" ]; then
        LOG "${BOLD}${1}${RESET}"
    fi

    local INDENT="${INDENT_LEVEL:=0}"
    export INDENT_LEVEL="$((INDENT + 2))"
}

LOG()
{
    local INDENT="${INDENT_LEVEL:=0}"

    echo -e "$(printf "%*s%s" "$INDENT" "" "$1")"
}

LOGW()
{
    local YELLOW="\033[0;33m"
    local RESET="\033[0m"

    echo -e "${YELLOW}$(_GET_CALLER_INFO)${1}${RESET}" >&2
}

_ECHO_STDERR()
{
    local TYPE="${1:?}"
    local MESSAGE="${2:?}"

    if [[ "$TYPE" == "W"* ]]; then
        echo -n -e '\033[0;33m' >&2
    elif [[ "$TYPE" == "E"* ]]; then
        echo -n -e '\033[0;31m' >&2
    fi

    local STACK_SIZE="${#FUNCNAME[@]}"
    if [[ "$STACK_SIZE" -gt "1" ]]; then
        echo -n "(" >&2
        if [[ "$STACK_SIZE" -gt "2" ]]; then
            echo -n "${BASH_SOURCE[2]//$SRC_DIR\//}:${BASH_LINENO[1]}:" >&2
        fi
        echo -n "${FUNCNAME[1]}) " >&2
    fi

    echo -n "$MESSAGE" >&2
    echo -e '\033[0m' >&2
}

_GET_PROP_FILES_PATH()
{
    local PARTITION="$1"
    local FILES

    if _IS_VALID_PARTITION_NAME "$PARTITION"; then
        case "$PARTITION" in
            "system")
                FILES="$WORK_DIR/system/system/build.prop"
                ;;
            "vendor")
                FILES="$WORK_DIR/vendor/default.prop
                    $WORK_DIR/vendor/build.prop"
                ;;
            "product")
                FILES="$WORK_DIR/product/etc/build.prop"
                ;;
            "system_ext")
                FILES="$WORK_DIR/system_ext/etc/build.prop
                    $WORK_DIR/system/system/system_ext/etc/build.prop"
                ;;
            "odm")
                FILES="$WORK_DIR/odm/etc/build.prop"
                ;;
            "vendor_dlkm")
                FILES="$WORK_DIR/vendor_dlkm/etc/build.prop
                    $WORK_DIR/vendor/vendor_dlkm/etc/build.prop"
                ;;
            "odm_dlkm")
                FILES="$WORK_DIR/vendor/odm_dlkm/etc/build.prop"
                ;;
            "system_dlkm")
                FILES="$WORK_DIR/system_dlkm/etc/build.prop
                    $WORK_DIR/system/system/system_dlkm/etc/build.prop"
                ;;
        esac
    else
        # https://android.googlesource.com/platform/system/core/+/refs/tags/android-15.0.0_r1/init/property_service.cpp#1214
        FILES="$WORK_DIR/system/system/build.prop
            $WORK_DIR/system_ext/etc/build.prop
            $WORK_DIR/system/system/system_ext/etc/build.prop
            $WORK_DIR/system_dlkm/etc/build.prop
            $WORK_DIR/system/system/system_dlkm/etc/build.prop
            $WORK_DIR/vendor/default.prop
            $WORK_DIR/vendor/build.prop
            $WORK_DIR/vendor_dlkm/etc/build.prop
            $WORK_DIR/vendor/vendor_dlkm/etc/build.prop
            $WORK_DIR/vendor/odm_dlkm/etc/build.prop
            $WORK_DIR/odm/etc/build.prop
            $WORK_DIR/product/etc/build.prop"
    fi

    echo "${FILES// }"
}

PRINT_ASSERTIONS()
{
    _CHECK_NON_EMPTY_PARAM "BUILD_INFO" "$1" || return 1

    local BUILD_INFO="$1"

    local DEVICE
    DEVICE="$(grep "^device" <<< "$BUILD_INFO" | cut -d "=" -f 2 -s)"

    if [ "$(grep "^model" <<< "$BUILD_INFO" | cut -d "=" -f 2 -s)" ]; then
        local TARGET_ASSERT_MODEL
        TARGET_ASSERT_MODEL="$(grep "^model" <<< "$BUILD_INFO" | cut -d "=" -f 2 -s)"
        IFS=';' read -r -a TARGET_ASSERT_MODEL <<< "$TARGET_ASSERT_MODEL"

        for i in "${TARGET_ASSERT_MODEL[@]}"; do
            echo -n 'getprop("ro.boot.em.model") == "'
            echo -n "$i"
            echo -n '" || '
        done
        echo -n 'abort("E3004: This package is for \"'
        echo -n "$DEVICE"
        echo    '\" devices; this is a \"" + getprop("ro.product.device") + "\".");'
    else
        echo -n 'getprop("ro.product.device") == "'
        echo -n "$DEVICE"
        echo -n '" || abort("E3004: This package is for \"'
        echo -n "$DEVICE"
        echo    '\" devices; this is a \"" + getprop("ro.product.device") + "\".");'
    fi

    if [ ! -d "$SRC_DIR/target/$DEVICE" ]; then
        LOGE "Folder not found: target/$DEVICE"
        return 1
    fi

    if [ -f "$SRC_DIR/target/$DEVICE/installer/assertions.edify" ]; then
        cat "$SRC_DIR/target/$DEVICE/installer/assertions.edify"
    fi
}

IS_SPARSE_IMAGE()
{
    _CHECK_NON_EMPTY_PARAM "FILE" "$1" || exit 1

    local FILE="$1"

    if [ ! -f "$FILE" ]; then
        LOGE "File not found: ${FILE//$SRC_DIR\//}"
        return 1
    fi

    # https://android.googlesource.com/platform/system/core/+/refs/tags/android-15.0.0_r1/libsparse/sparse_format.h#39
    [[ "$(READ_BYTES_AT "$FILE" "0" "4")" == "ed26ff3a" ]]
}

READ_BYTES_AT()
{
    _CHECK_NON_EMPTY_PARAM "FILE" "$1" || return 1
    _CHECK_NON_EMPTY_PARAM "OFFSET" "$2" || return 1
    _CHECK_NON_EMPTY_PARAM "BYTES" "$3" || return 1

    local FILE="$1"
    local OFFSET="$2"
    local BYTES="$3"

    if [ ! -f "$FILE" ]; then
        LOGE "File not found: ${FILE//$SRC_DIR\//}"
        return 1
    fi

    local FILE_SIZE
    FILE_SIZE="$(wc -c "$FILE" | cut -d " " -f 1)"
    if ! [[ "$OFFSET" =~ ^[+-]?[0-9]+$ ]] || [[ "$OFFSET" -gt "$FILE_SIZE" ]]; then
        LOGE "Offset value not valid: $OFFSET"
        return 1
    fi
    if ! [[ "$BYTES" =~ ^[+-]?[0-9]+$ ]] || [[ "$BYTES" -gt "$((FILE_SIZE - OFFSET))" ]]; then
        LOGE "Bytes value not valid: $BYTES"
        return 1
    fi

    local READ
    local LENGTH
    READ="$(xxd -p -l "$BYTES" --skip "$OFFSET" "$FILE")"
    LENGTH="${#READ}"

    while [[ "$LENGTH" -gt 0 ]]; do
        echo -n "${READ:$LENGTH-2:2}"
        LENGTH="$((LENGTH - 2))"
    done
    echo ""
}

_CHECK_NON_EMPTY_PARAM()
{
    if [ ! "$2" ]; then
        echo -n -e '\033[0;31m' >&2

        local STACK_SIZE="${#FUNCNAME[@]}"
        if [[ "$STACK_SIZE" -gt "1" ]]; then
            echo -n "(" >&2
            if [[ "$STACK_SIZE" -gt "2" ]]; then
                echo -n "${BASH_SOURCE[2]//$SRC_DIR\//}:${BASH_LINENO[1]}:" >&2
            fi
            echo -n "${FUNCNAME[1]}) " >&2
        fi

        echo -n "$1 is not set!" >&2
        echo -e '\033[0m' >&2

        return 1
    fi

_GET_CALLER_INFO()
{
    if [[ "${FUNCNAME[2]}" != "main" ]]; then
        echo -n "("
        if [ "${BASH_SOURCE[3]}" ]; then
            echo -n "${BASH_SOURCE[3]//$SRC_DIR\//}:"
        fi
        if [ "${BASH_LINENO[2]}" ]; then
            echo -n "${BASH_LINENO[2]}:"
        fi
        echo -n "${FUNCNAME[2]}) "
    else
        echo -n "("
        if [ "${BASH_SOURCE[2]}" ]; then
            echo -n "${BASH_SOURCE[2]//$SRC_DIR\//}:"
        fi
        if [ "${BASH_LINENO[1]}" ]; then
            echo -n "${BASH_LINENO[1]}"
        fi
        echo -n ") "
    fi
}

EVAL()
{
    _CHECK_NON_EMPTY_PARAM "CMD" "$1" || return 1

    local CMD="$1"

    local OUT
    OUT="$(eval "$CMD" 2>&1)"
    # shellcheck disable=SC2181,SC2291
    if [ $? -ne 0 ]; then
        LOGE "Command returned a non-zero exit code\n"
        echo -e    '\033[0;31m'"$CMD"'\033[0m\n' >&2
        echo -n -e '\033[0;33m' >&2
        echo -n    "$OUT" >&2
        echo -e    '\033[0m' >&2
        return 1
    fi

    return 0
}

GET_IMAGE_SIZE()
{
    _CHECK_NON_EMPTY_PARAM "FILE" "$1" || return 1

    local FILE="$1"

    if [ ! -f "$FILE" ]; then
        LOGE "File not found: ${FILE//$SRC_DIR\//}"
        return 1
    fi

    if IS_SPARSE_IMAGE "$FILE"; then
        local BLOCK_SIZE
        local BLOCKS
        BLOCK_SIZE="$(printf "%d" "0x$(READ_BYTES_AT "$FILE" "12" "4")")"
        BLOCKS="$(printf "%d" "0x$(READ_BYTES_AT "$FILE" "16" "4")")"

        bc -l <<< "$BLOCKS * $BLOCK_SIZE"
    else
        GET_DISK_USAGE "$FILE"
    fi
}

GET_DISK_USAGE()
{
    _CHECK_NON_EMPTY_PARAM "FILE" "$1" || return 1

    local FILE="$1"

    if [ ! -e "$FILE" ]; then
        LOGE "File not found: ${FILE//$SRC_DIR\//}"
        return 1
    fi

    local SIZE
    # https://android.googlesource.com/platform/build/+/refs/tags/android-15.0.0_r1/tools/releasetools/build_image.py#63
    SIZE="$(du -b -k -s "$FILE" | cut -f 1)"

    bc -l <<< "$SIZE * 1024"
}

PRINT_BUILD_INFO()
{
    local SOURCE_BUILD_INFO
    local TARGET_BUILD_INFO

    if [[ "$#" == "1" ]]; then
        TARGET_BUILD_INFO="$1"
    elif [[ "$#" == "2" ]]; then
        SOURCE_BUILD_INFO="$1"
        TARGET_BUILD_INFO="$2"
    else
        _CHECK_NON_EMPTY_PARAM "BUILD_INFO" "$1"
        return 1
    fi

    echo -n "device="
    grep "^device" <<< "$TARGET_BUILD_INFO" | cut -d "=" -f 2 -s
    echo -n "version="
    grep "^version" <<< "$TARGET_BUILD_INFO" | cut -d "=" -f 2 -s
    echo -n "timestamp="
    grep "^timestamp" <<< "$TARGET_BUILD_INFO" | cut -d "=" -f 2 -s
    echo -n "security_patch_version="
    grep "^security_patch" <<< "$TARGET_BUILD_INFO" | cut -d "=" -f 2 -s
    echo -n "incremental="
    if [ "$SOURCE_BUILD_INFO" ]; then
        grep "^timestamp" <<< "$SOURCE_BUILD_INFO" | cut -d "=" -f 2 -s
    else
        echo "0"
    fi
}

FILE_EXISTS_IN_TAR()
{
    _CHECK_NON_EMPTY_PARAM "TAR" "$1" || return 1
    _CHECK_NON_EMPTY_PARAM "FILE" "$2" || return 1

    tar tf "$1" "$2" &> /dev/null
    return $?
}

COMPARE_SEC_BUILD_VERSION()
{
    local STRING1="$1"
    local STRING2="$2"

    STRING1="$(cut -d "/" -f 1 -s <<< "$STRING1")"
    STRING2="$(cut -d "/" -f 1 -s <<< "$STRING2")"

    # Samsung Android OS build version scheme works as follows (eg. A528BXXU1DWA4):
    # - A528B: Model number
    # - XX: Region (XX = EUR_OPEN)
    # - U: Firmware type (U = full update, S = security update)
    # - 1: Rollback protection bit
    # - D: Major OS version (D = 4th OS rollout)
    # - W: Year (W = 2023)
    # - A: Month (A = january)
    # - 4: Incremental version
    local STRING1_MAJOR="${STRING1:${#STRING1}-4:1}"
    local STRING1_YEAR="${STRING1:${#STRING1}-3:1}"
    local STRING1_MONTH="${STRING1:${#STRING1}-2:1}"
    local STRING1_INCREMENTAL="${STRING1:${#STRING1}-1:1}"

    local STRING2_MAJOR="${STRING2:${#STRING2}-4:1}"
    local STRING2_YEAR="${STRING2:${#STRING2}-3:1}"
    local STRING2_MONTH="${STRING2:${#STRING2}-2:1}"
    local STRING2_INCREMENTAL="${STRING2:${#STRING2}-1:1}"

    [[ "$STRING1_MAJOR" > "$STRING2_MAJOR" ]] && return 0
    [[ "$STRING1_MAJOR" < "$STRING2_MAJOR" ]] && return 1
    [[ "$STRING1_YEAR" > "$STRING2_YEAR" ]] && return 0
    [[ "$STRING1_YEAR" < "$STRING2_YEAR" ]] && return 1
    [[ "$STRING1_MONTH" > "$STRING2_MONTH" ]] && return 0
    [[ "$STRING1_MONTH" < "$STRING2_MONTH" ]] && return 1
    [[ "$STRING1_INCREMENTAL" > "$STRING2_INCREMENTAL" ]] && return 0
    [[ "$STRING1_INCREMENTAL" < "$STRING2_INCREMENTAL" ]] && return 1

    return 0
}

_GET_PROP_LOCATION()
{
    local FILES
    FILES="$(_GET_PROP_FILES_PATH "${1:?}")"

    if _IS_VALID_PARTITION_NAME "${1:?}"; then
        shift
    fi

    local PROP="${1:?}"
    # shellcheck disable=SC2116
    for f in $(echo "$FILES"); do
        grep -l "^$PROP=" "$f" 2> /dev/null || true
    done
}

_GET_SELINUX_LABEL()
{
    local PARTITION="${1:?}"
    local FILE="${2:?}"
    local FC_FILE

    case "$PARTITION" in
        "product")
            if $TARGET_HAS_PRODUCT; then
                FC_FILE="$WORK_DIR/product/etc/selinux/product_file_contexts"
            else
                FC_FILE="$WORK_DIR/system/system/product/etc/selinux/product_file_contexts"
            fi
            ;;
        "vendor")
            FC_FILE="$WORK_DIR/vendor/etc/selinux/vendor_file_contexts"
            ;;
        "system_ext")
            if $TARGET_HAS_SYSTEM_EXT; then
                FC_FILE="$WORK_DIR/system_ext/etc/selinux/system_ext_file_contexts"
            else
                FC_FILE="$WORK_DIR/system/system/system_ext/etc/selinux/system_ext_file_contexts"
            fi
            ;;
        *)
            FC_FILE="$WORK_DIR/system/system/etc/selinux/plat_file_contexts"
            ;;
    esac

    if [[ "${FILE:0:1}" != "/" ]]; then
        FILE="/$FILE"
    fi

    local LABEL="u:object_r:system_file:s0"
    while IFS= read -r l; do
        l="$(tr -s "\t" " " <<< "$l")"
        if [[ "$FILE" =~ ^$(cut -d " " -f 1 <<< "$l")$ ]]; then
            LABEL="$(cut -d " " -f 2 <<< "$l")"
            break
        fi
    done <<< "$(tac "$FC_FILE" 2> /dev/null)"

    echo "$LABEL"
}

_HANDLE_SPECIAL_CHARS()
{
    local STRING="${1:?}"

    STRING="${STRING//\./\\.}"
    STRING="${STRING//\+/\\+}"
    STRING="${STRING//\[/\\[}"
    STRING="${STRING//\]/\\]}"
    STRING="${STRING//\*/\\*}"

    echo "$STRING"
}

LOGE()
{
    local RED="\033[0;31m"
    local RESET="\033[0m"

    echo -e "${RED}$(_GET_CALLER_INFO)${1}${RESET}" >&2
}

IS_VALID_PARTITION_NAME()
{
    local PARTITION="$1"
    # https://android.googlesource.com/platform/build/+/refs/tags/android-15.0.0_r1/tools/releasetools/common.py#131
    [[ "$PARTITION" == "system" ]] || [[ "$PARTITION" == "vendor" ]] || [[ "$PARTITION" == "product" ]] || \
        [[ "$PARTITION" == "system_ext" ]] || [[ "$PARTITION" == "odm" ]] || [[ "$PARTITION" == "vendor_dlkm" ]] || \
        [[ "$PARTITION" == "odm_dlkm" ]] || [[ "$PARTITION" == "system_dlkm" ]]
}

_IS_VALID_PARTITION_NAME() {
    IS_VALID_PARTITION_NAME "$@"
}
# ]

# ADD_TO_WORK_DIR <source> <partition> <file/dir> <user> <group> <mode> <label>
# Adds the supplied file/directory in work dir along with its entries in fs_config/file_context.
#
# `source` argument can be:
# - a full path
# - a string in the following format: "MODEL/CSC" (the folder MUST exist under `out/fw`)
# - a string with the product name of the desidered device's prebuilt blobs (the folder MUST exist under `prebuilts/samsung`)
#
# `user`/`group`/`mode`/`label`/ arguments can be omitted as long as the respective entry is present in `source`/fs_config and `source`/file_context.
ADD_TO_WORK_DIR()
{
    _CHECK_NON_EMPTY_PARAM "SOURCE" "$1"
    _CHECK_NON_EMPTY_PARAM "PARTITION" "$2"
    _CHECK_NON_EMPTY_PARAM "FILE" "$3"

    local SOURCE="$1"
    local PARTITION="$2"
    local FILE="$3"
    local USER="$4"
    local GROUP="$5"
    local MODE="$6"
    local LABEL="$7"

    if [ ! -d "$SOURCE" ]; then
        if [ "$(cut -d "/" -f 2 -s <<< "$SOURCE")" ]; then
            SOURCE="$FW_DIR/$(cut -d "/" -f 1 <<< "$SOURCE")_$(cut -d "/" -f 2 <<< "$SOURCE")"
        else
            SOURCE="$SRC_DIR/prebuilts/samsung/$SOURCE"
        fi
    fi

    if [ ! -d "$SOURCE" ]; then
        _ECHO_STDERR ERR "Folder not found: ${SOURCE//$SRC_DIR\//}"
        return 1
    fi

    if ! _IS_VALID_PARTITION_NAME "$PARTITION"; then
        _ECHO_STDERR ERR "\"$PARTITION\" is not a valid partition name"
        return 1
    fi

    while [[ "${FILE:0:1}" == "/" ]]; do
        FILE="${FILE:1}"
    done

    local SOURCE_FILE="$SOURCE"
    local TARGET_FILE="$WORK_DIR"
    if [[ "$PARTITION" == "system_ext" ]]; then
        if [ -d "$SOURCE/system_ext" ]; then
            SOURCE_FILE+="/system_ext/$FILE"
        elif [ -d "$SOURCE/system/system/system_ext" ]; then
            SOURCE_FILE+="/system/system/system_ext/$FILE"
        else
            SOURCE_FILE+="/system/system_ext/$FILE"
        fi

        if $TARGET_HAS_SYSTEM_EXT; then
            TARGET_FILE+="/system_ext/$FILE"
        else
            PARTITION="system"
            FILE="system/system_ext/$FILE"
            TARGET_FILE+="/system/$FILE"
        fi
    elif [[ "$PARTITION" == "product" ]]; then
        if [ -d "$SOURCE/product" ]; then
            SOURCE_FILE+="/product/$FILE"
        elif [ -d "$SOURCE/system/system/product" ]; then
            SOURCE_FILE+="/system/system/product/$FILE"
        else
            SOURCE_FILE+="/system/product/$FILE"
        fi

        if $TARGET_HAS_PRODUCT; then
            TARGET_FILE+="/product/$FILE"
        else
            PARTITION="system"
            FILE="system/product/$FILE"
            TARGET_FILE+="/system/$FILE"
        fi
    elif [[ "$PARTITION" == "system" ]]; then
        if [ -d "$SOURCE/system/system" ]; then
            SOURCE_FILE+="/system/$FILE"
            TARGET_FILE+="/system/$FILE"
        else
            SOURCE_FILE+="/system/${FILE//system\//}"
            TARGET_FILE+="/system/system/${FILE//system\//}"
        fi
    else
        SOURCE_FILE+="/$PARTITION/$FILE"
        TARGET_FILE+="/$PARTITION/$FILE"
    fi

    if [ ! -e "$SOURCE_FILE" ] && [ ! -L "$SOURCE_FILE" ]; then
        if [ -e "$SOURCE_FILE.00" ]; then
            mkdir -p "$(dirname "$TARGET_FILE")"
            cat "$SOURCE_FILE."* > "$TARGET_FILE"
        else
            _ECHO_STDERR ERR "File not found: ${SOURCE_FILE//$SRC_DIR\//}"
            return 1
        fi
    else
        # Prevent cp crash when source and target resolve to the exact same file/folder
        if [ "$(realpath -m "$SOURCE_FILE")" != "$(realpath -m "$TARGET_FILE")" ]; then
            if [ ! -d "$SOURCE_FILE" ]; then
                mkdir -p "$(dirname "$TARGET_FILE")"
            else
                mkdir -p "$TARGET_FILE"
            fi
            cp -a -T "$SOURCE_FILE" "$TARGET_FILE"
        else
            _ECHO_STDERR WARN "Source and target are identical ($SOURCE_FILE). Skipping cp."
        fi
    fi

    local ENTRY="${TARGET_FILE//$WORK_DIR\//}"
    [[ "$PARTITION" == "system" ]] && ENTRY="${ENTRY//system\/system\//system/}"
    ENTRY="${ENTRY%/.}"

    if ! grep -q -F "$ENTRY " "$WORK_DIR/configs/fs_config-$PARTITION" 2> /dev/null; then
        if [ "$USER" ] && [ "$GROUP" ] && [ "$MODE" ]; then
            echo "$ENTRY $USER $GROUP $MODE capabilities=0x0" >> "$WORK_DIR/configs/fs_config-$PARTITION"
        elif grep -q -F "$ENTRY " "$SOURCE/fs_config-$PARTITION" 2> /dev/null; then
            grep -F "$ENTRY " "$SOURCE/fs_config-$PARTITION" >> "$WORK_DIR/configs/fs_config-$PARTITION"
        else
            _ECHO_STDERR WARN "No fs_config entry found for \"$ENTRY\" in \"${SOURCE//$SRC_DIR\//}\". Using default values"

            USER=0
            GROUP=0
            MODE=644
            if [ -d "$TARGET_FILE" ]; then
                [[ "$PARTITION" == "vendor" ]] && GROUP=2000
                MODE=755
            fi

            echo "$ENTRY $USER $GROUP $MODE capabilities=0x0" >> "$WORK_DIR/configs/fs_config-$PARTITION"
        fi
    fi

    if ! grep -q -F "/$(_HANDLE_SPECIAL_CHARS "$ENTRY") " "$WORK_DIR/configs/file_context-$PARTITION" 2> /dev/null; then
        if [ "$LABEL" ]; then
            echo "/$(_HANDLE_SPECIAL_CHARS "$ENTRY") $LABEL" >> "$WORK_DIR/configs/file_context-$PARTITION"
        elif grep -q -F "/$(_HANDLE_SPECIAL_CHARS "$ENTRY") " "$SOURCE/file_context-$PARTITION" 2> /dev/null; then
            grep -F "/$(_HANDLE_SPECIAL_CHARS "$ENTRY") " "$SOURCE/file_context-$PARTITION" >> "$WORK_DIR/configs/file_context-$PARTITION"
        else
            _ECHO_STDERR WARN "No file_context entry found for \"$ENTRY\" in \"${SOURCE//$SRC_DIR\//}\". Using default value"

            LABEL="$(_GET_SELINUX_LABEL "$PARTITION" "/$ENTRY")"

            echo "/$(_HANDLE_SPECIAL_CHARS "$ENTRY") $LABEL" >> "$WORK_DIR/configs/file_context-$PARTITION"
        fi
    fi

    if [ -d "$TARGET_FILE" ]; then
        local FILES
        FILES="$(find "${SOURCE_FILE%/.}")"
        FILES="${FILES//$SOURCE\//}"
        [[ "$PARTITION" == "system" ]] && FILES="${FILES//system\/system\//system/}"
        $TARGET_HAS_SYSTEM_EXT || FILES="${FILES//system_ext\//system/system_ext/}"
        $TARGET_HAS_PRODUCT || FILES="${FILES//product\//system/product/}"

        # shellcheck disable=SC2116
        for f in $(echo "$FILES"); do
            _IS_VALID_PARTITION_NAME "$f" && continue

            if ! grep -q -F "$f " "$WORK_DIR/configs/fs_config-$PARTITION" 2> /dev/null; then
                if grep -q -F "$f " "$SOURCE/fs_config-$PARTITION" 2> /dev/null; then
                    grep -F "$f " "$SOURCE/fs_config-$PARTITION" >> "$WORK_DIR/configs/fs_config-$PARTITION"
                else
                    _ECHO_STDERR WARN "No fs_config entry found for \"$f\" in \"${SOURCE//$SRC_DIR\//}\". Using default values"

                    USER=0
                    GROUP=0
                    MODE=644
                    if [ -d "$SOURCE/$f" ] || [ -d "$SOURCE/system/$f" ] || [ -d "$SOURCE/${f//system\//}" ]; then
                        [[ "$PARTITION" == "vendor" ]] && GROUP=2000
                        MODE=755
                    fi

                    echo "$f $USER $GROUP $MODE capabilities=0x0" >> "$WORK_DIR/configs/fs_config-$PARTITION"
                fi
            fi

            if ! grep -q -F "/$(_HANDLE_SPECIAL_CHARS "$f") " "$WORK_DIR/configs/file_context-$PARTITION" 2> /dev/null; then
                if grep -q -F "/$(_HANDLE_SPECIAL_CHARS "$f") " "$SOURCE/file_context-$PARTITION" 2> /dev/null; then
                    grep -F "/$(_HANDLE_SPECIAL_CHARS "$f") " "$SOURCE/file_context-$PARTITION" >> "$WORK_DIR/configs/file_context-$PARTITION"
                else
                    _ECHO_STDERR WARN "No file_context entry found for \"$f\" in \"${SOURCE//$SRC_DIR\//}\". Using default value"

                    LABEL="$(_GET_SELINUX_LABEL "$PARTITION" "/$f")"

                    echo "/$(_HANDLE_SPECIAL_CHARS "$f") $LABEL" >> "$WORK_DIR/configs/file_context-$PARTITION"
                fi
            fi
        done
    else
        local TMP="${TARGET_FILE%/.}"
        TMP="$(dirname "${TMP//$WORK_DIR\//}")"
        [[ "$PARTITION" == "system" ]] && TMP="${TMP//system\/system\//system/}"

        while [[ "$TMP" != "." ]]; do
            _IS_VALID_PARTITION_NAME "$TMP" && break

            if ! grep -q -F "$TMP " "$WORK_DIR/configs/fs_config-$PARTITION" 2> /dev/null; then
                if grep -q -F "$TMP " "$SOURCE/fs_config-$PARTITION" 2> /dev/null; then
                    grep -F "$TMP " "$SOURCE/fs_config-$PARTITION" >> "$WORK_DIR/configs/fs_config-$PARTITION"
                else
                    _ECHO_STDERR WARN "No fs_config entry found for \"$TMP\" in \"${SOURCE//$SRC_DIR\//}\". Using default values"

                    USER=0
                    GROUP=0
                    MODE=755
                    [[ "$PARTITION" == "vendor" ]] && GROUP=2000

                    echo "$TMP $USER $GROUP $MODE capabilities=0x0" >> "$WORK_DIR/configs/fs_config-$PARTITION"
                fi
            fi

            if ! grep -q -F "/$(_HANDLE_SPECIAL_CHARS "$TMP") " "$WORK_DIR/configs/file_context-$PARTITION" 2> /dev/null; then
                if grep -q -F "/$(_HANDLE_SPECIAL_CHARS "$TMP") " "$SOURCE/file_context-$PARTITION" 2> /dev/null; then
                    grep -F "/$(_HANDLE_SPECIAL_CHARS "$TMP") " "$SOURCE/file_context-$PARTITION" >> "$WORK_DIR/configs/file_context-$PARTITION"
                else
                    _ECHO_STDERR WARN "No file_context entry found for \"$TMP\" in \"${SOURCE//$SRC_DIR\//}\". Using default value"

                    LABEL="$(_GET_SELINUX_LABEL "$PARTITION" "/$TMP")"

                    echo "/$(_HANDLE_SPECIAL_CHARS "$TMP") $LABEL" >> "$WORK_DIR/configs/file_context-$PARTITION"
                fi
            fi

            TMP="$(dirname "$TMP")"
        done
    fi

    return 0
}
# DECODE_APK <apk/jar>
# Same usage as `run_cmd apktool d <apk/jar>`.
# APK/JAR path MUST not be full and match an existing file inside work_dir.
DECODE_APK()
{
    _CHECK_NON_EMPTY_PARAM "FILE" "$1"

    if [ ! -d "$APKTOOL_DIR/$1" ]; then
        "$SRC_DIR/scripts/apktool.sh" d "$1"
        return $?
    fi

    return 0
}

# DELETE_FROM_WORK_DIR "<partition>" "<file/dir>"
# Deletes the supplied file/directory from work dir along with its entries in fs_config/file_context.
DELETE_FROM_WORK_DIR()
{
    _CHECK_NON_EMPTY_PARAM "PARTITION" "$1"
    _CHECK_NON_EMPTY_PARAM "FILE" "$2"

    local PARTITION="$1"
    local FILE="$2"

    if ! _IS_VALID_PARTITION_NAME "$PARTITION"; then
        echo "\"$PARTITION\" is not a valid partition name"
        return 1
    fi

    while [[ "${FILE:0:1}" == "/" ]]; do
        FILE="${FILE:1}"
    done

    if ! $TARGET_HAS_SYSTEM_EXT && [[ "$PARTITION" == "system_ext" ]]; then
        PARTITION="system"
        FILE="system/system_ext/$FILE"
    fi

    if ! $TARGET_HAS_PRODUCT && [[ "$PARTITION" == "product" ]]; then
        PARTITION="system"
        FILE="system/product/$FILE"
    fi

    local FILE_PATH="$WORK_DIR"
    case "$PARTITION" in
        "system_ext")
            if $TARGET_HAS_SYSTEM_EXT; then
                FILE_PATH+="/system_ext"
            else
                FILE_PATH+="/system/system/system_ext"
            fi
            ;;
        "product")
            if $TARGET_HAS_PRODUCT; then
                FILE_PATH+="/product"
            else
                FILE_PATH+="/system/system/product"
            fi
            ;;
        *)
            FILE_PATH+="/$PARTITION"
            ;;
    esac
    FILE_PATH+="/$FILE"

    if [ ! -e "$FILE_PATH" ] && [ ! -L "$FILE_PATH" ]; then
        _ECHO_STDERR WARN "File not found: ${FILE_PATH//$WORK_DIR/}"
        return 0
    fi

    local IS_DIR=false
    [ -d "$FILE_PATH" ] && IS_DIR=true

    echo "Deleting ${FILE_PATH//$WORK_DIR/}"
    rm -rf "$FILE_PATH"

    local PATTERN="${FILE//\//\\/}"
    [ "$PARTITION" != "system" ] && PATTERN="$PARTITION\/$PATTERN"
    sed -i "/^$PATTERN /d" "$WORK_DIR/configs/fs_config-$PARTITION"
    if $IS_DIR; then
        sed -i "/^$PATTERN\//d" "$WORK_DIR/configs/fs_config-$PARTITION"
    fi

    PATTERN="$(_HANDLE_SPECIAL_CHARS "$FILE")"
    PATTERN="${PATTERN//\\/\\\\}"
    PATTERN="${PATTERN//\//\\/}"
    [ "$PARTITION" != "system" ] && PATTERN="$PARTITION\/$PATTERN"
    sed -i "/^\/$PATTERN /d" "$WORK_DIR/configs/file_context-$PARTITION"
    if $IS_DIR; then
        sed -i "/^\/$PATTERN\//d" "$WORK_DIR/configs/file_context-$PARTITION"
    fi

    if [[ "$FILE" == *".so" ]]; then
        # shellcheck disable=SC2013
        for f in $(grep -l "$(basename "$FILE")" "$WORK_DIR/system/system/etc/public.libraries"*.txt); do
            sed -i "/$(basename "$FILE")/d" "$f"
        done
    fi

    return 0
}

# DOWNLOAD_FILE "<url>" "<output path>"
# Downloads the file from the provided URL and stores it in the desidered output path.
DOWNLOAD_FILE()
{
    _CHECK_NON_EMPTY_PARAM "URL" "$1"
    _CHECK_NON_EMPTY_PARAM "OUTPUT" "$2"

    local URL="$1"
    local OUTPUT="$2"

    mkdir -p "$(dirname "$OUTPUT")"
    curl -L -# -o "$OUTPUT" "$URL"
    return $?
}

# GET_GALAXY_STORE_DOWNLOAD_URL "<package name>"
# Returns a URL to download the desidered app from Samsung servers.
GET_GALAXY_STORE_DOWNLOAD_URL()
{
    _CHECK_NON_EMPTY_PARAM "PACKAGE" "$1"

    local PACKAGE="$1"
    local OUT

    OUT="$(curl -L -s "https://vas.samsungapps.com/stub/stubDownload.as?appId=$PACKAGE&deviceId=SM-A366B&mcc=505&mnc=03&csc=EUX&sdkVer=36&extuk=a59839d085b95518&pd=0")"

    if grep -q "Download URI Available" <<< "$OUT"; then
        grep "downloadURI" <<< "$OUT" | cut -d ">" -f 2 | sed -e 's/<!\[CDATA\[//g; s/\]\]//g'
        return $?
    fi

    _ECHO_STDERR ERR "No download URI found for app \"$PACKAGE\""
    return 1
}

# GET_FLOATING_FEATURE_CONFIG "<config>"
# Returns the supplied config value.
GET_FLOATING_FEATURE_CONFIG()
{
    _CHECK_NON_EMPTY_PARAM "CONFIG" "$1"

    local CONFIG="$1"
    local FILE="$WORK_DIR/system/system/etc/floating_feature.xml"

    if [ ! -f "$FILE" ]; then
        _ECHO_STDERR ERR "File not found: ${FILE//$WORK_DIR/}"
        return 1
    fi

    grep -o -P "(?<=<$CONFIG>)[^<]+" "$FILE" 2> /dev/null
}

# GET_PROP "<partition>/<file>" "<prop>"
# Returns the supplied prop value, partition/file can be omitted.
GET_PROP()
{
    local FILES
    if [[ "$1" == *".prop" ]]; then
        FILES="$1"
        shift
    else
        FILES="$(_GET_PROP_FILES_PATH "$1")"
        if _IS_VALID_PARTITION_NAME "$1"; then
            shift
        fi
    fi

    _CHECK_NON_EMPTY_PARAM "PROP" "$1"

    local PROP="$1"
    # shellcheck disable=SC2002,SC2046,SC2116
    cat $(echo "$FILES") 2> /dev/null | sed -n "s/^$PROP=//p" | head -n 1
}

# HEX_PATCH "<file>" "<old pattern>" "<new pattern>"
# Applies the supplied hex patch to the desidered file.
HEX_PATCH()
{
    _CHECK_NON_EMPTY_PARAM "FILE" "$1"
    _CHECK_NON_EMPTY_PARAM "FROM" "$2"
    _CHECK_NON_EMPTY_PARAM "TO" "$3"

    local FILE="$1"
    local FROM="$2"
    local TO="$3"

    if [ ! -f "$FILE" ]; then
        _ECHO_STDERR ERR "File not found: ${FILE//$WORK_DIR/}"
        return 1
    fi

    FROM="$(tr "[:upper:]" "[:lower:]" <<< "$FROM")"
    TO="$(tr "[:upper:]" "[:lower:]" <<< "$TO")"

    if xxd -p "$FILE" | tr -d "\n" | tr -d " " | grep -q "$TO"; then
        _ECHO_STDERR WARN "\"$TO\" already applied in ${FILE//$WORK_DIR/}"
        return 0
    fi

    if ! xxd -p "$FILE" | tr -d "\n" | tr -d " " | grep -q "$FROM"; then
        _ECHO_STDERR ERR "No \"$FROM\" match in ${FILE//$WORK_DIR/}"
        return 1
    fi

    echo "Patching \"$FROM\" to \"$TO\" in ${FILE//$WORK_DIR/}"
    xxd -p "$FILE" | tr -d "\n" | tr -d " " | sed "s/$FROM/$TO/" | xxd -r -p > "$FILE.tmp"
    mv "$FILE.tmp" "$FILE"

    return 0
}

# SET_FLOATING_FEATURE_CONFIG "<config>" "<value>"
# Sets the supplied config to the desidered value.
# "-d" or "--delete" can be passed as value to delete the config.
SET_FLOATING_FEATURE_CONFIG()
{
    _CHECK_NON_EMPTY_PARAM "CONFIG" "$1"
    _CHECK_NON_EMPTY_PARAM "VALUE" "$2"

    local CONFIG="$1"
    local VALUE="$2"
    local FILE="$WORK_DIR/system/system/etc/floating_feature.xml"

    if [ ! -f "$FILE" ]; then
        _ECHO_STDERR ERR "File not found: ${FILE//$WORK_DIR/}"
        return 1
    fi

    if grep -q "$CONFIG" "$FILE"; then
        if [[ "$VALUE" == "-d" ]] || [[ "$VALUE" == "--delete" ]]; then
            echo "Deleting \"$CONFIG\" config in /system/system/etc/floating_feature.xml"
            sed -i "/$CONFIG/d" "$FILE"
        else
            echo "Replacing \"$CONFIG\" config with \"$VALUE\" in /system/system/etc/floating_feature.xml"
            sed -i "$(sed -n "/<${CONFIG}>/=" "$FILE") c\ \ \ \ <${CONFIG}>${VALUE}</${CONFIG}>" "$FILE"
        fi
    elif [[ "$VALUE" != "-d" ]] && [[ "$VALUE" != "--delete" ]]; then
        echo "Adding \"$CONFIG\" config with \"$VALUE\" in /system/system/etc/floating_feature.xml"
        sed -i "/<\/SecFloatingFeatureSet>/d" "$FILE"
        if ! grep -q "Added by scripts" "$FILE"; then
            echo "    <!-- Added by scripts/utils/module_utils.sh -->" >> "$FILE"
        fi
        echo "    <${CONFIG}>${VALUE}</${CONFIG}>" >> "$FILE"
        echo "</SecFloatingFeatureSet>" >> "$FILE"
    fi

    return 0
}

# SET_METADATA <partition> <file/dir> <user> <group> <mode> <label>
# Adds the supplied file/directory entry attrs in fs_config/file_context.
SET_METADATA()
{
    _CHECK_NON_EMPTY_PARAM "PARTITION" "$1"
    _CHECK_NON_EMPTY_PARAM "ENTRY" "$2"
    _CHECK_NON_EMPTY_PARAM "USER" "$3"
    _CHECK_NON_EMPTY_PARAM "GROUP" "$4"
    _CHECK_NON_EMPTY_PARAM "MODE" "$5"
    _CHECK_NON_EMPTY_PARAM "LABEL" "$6"

    local PARTITION="$1"
    local ENTRY="$2"
    local USER="$3"
    local GROUP="$4"
    local MODE="$5"
    local LABEL="$6"

    if ! _IS_VALID_PARTITION_NAME "$PARTITION"; then
        _ECHO_STDERR ERR "\"$PARTITION\" is not a valid partition name"
        return 1
    fi

    while [[ "${ENTRY:0:1}" == "/" ]]; do
        ENTRY="${ENTRY:1}"
    done

    [ "$PARTITION" != "system" ] && [[ "$ENTRY" != "$PARTITION/"* ]] && ENTRY="$PARTITION/$ENTRY"

    local PATTERN
    PATTERN="${ENTRY//\//\\/}"
    sed -i "/^$PATTERN /d" "$WORK_DIR/configs/fs_config-$PARTITION"

    echo "$ENTRY $USER $GROUP $MODE capabilities=0x0" >> "$WORK_DIR/configs/fs_config-$PARTITION"

    PATTERN="$(_HANDLE_SPECIAL_CHARS "$ENTRY")"
    PATTERN="${PATTERN//\\/\\\\}"
    PATTERN="${PATTERN//\//\\/}"
    sed -i "/^\/$PATTERN /d" "$WORK_DIR/configs/file_context-$PARTITION"

    echo "/$(_HANDLE_SPECIAL_CHARS "$ENTRY") $LABEL" >> "$WORK_DIR/configs/file_context-$PARTITION"
}

# SET_PROP "<partition>" "<prop>" "<value>"
# Sets the supplied prop to the desidered value, partition name CANNOT be omitted.
# "-d" or "--delete" can be passed as value to delete the prop.
SET_PROP()
{
    _CHECK_NON_EMPTY_PARAM "PARTITION" "$1"
    _CHECK_NON_EMPTY_PARAM "PROP" "$2"

    local PARTITION="$1"
    local PROP="$2"
    local VALUE="$3"

    if ! _IS_VALID_PARTITION_NAME "$PARTITION"; then
        _ECHO_STDERR ERR "\"$PARTITION\" is not a valid partition name"
        return 1
    fi

    if [ "$(GET_PROP "$PARTITION" "$PROP")" ]; then
        local FILES
        FILES="$(_GET_PROP_LOCATION "$PARTITION" "$PROP")"
        # shellcheck disable=SC2116
        for f in $(echo "$FILES"); do
            if [[ "$VALUE" == "-d" ]] || [[ "$VALUE" == "--delete" ]]; then
                echo "Deleting \"$PROP\" prop in ${f//$WORK_DIR/}"
                sed -i "/^$PROP/d" "$f"
            else
                echo "Replacing \"$PROP\" prop with \"$VALUE\" in ${f//$WORK_DIR/}"

                local LINES
                LINES="$(sed -n "/^${PROP}\b/=" "$f")"
                for l in $LINES; do
                    sed -i "$l c${PROP}=${VALUE}" "$f"
                done
            fi
        done
    elif [[ "$VALUE" != "-d" ]] && [[ "$VALUE" != "--delete" ]]; then
        local FILE

        case "$PARTITION" in
            "system")
                FILE="$WORK_DIR/system/system/build.prop"
                ;;
            "system_ext")
                if $TARGET_HAS_SYSTEM_EXT; then
                    FILE="$WORK_DIR/system_ext/etc/build.prop"
                else
                    FILE="$WORK_DIR/system/system/system_ext/etc/build.prop"
                fi
                ;;
            "system_dlkm")
                FILE="$WORK_DIR/system_dlkm/etc/build.prop"
                ;;
            "vendor")
                FILE="$WORK_DIR/vendor/build.prop"
                ;;
            "vendor_dlkm")
                FILE="$WORK_DIR/vendor_dlkm/etc/build.prop"
                ;;
            "odm_dlkm")
                FILE="$WORK_DIR/vendor/odm_dlkm/etc/build.prop"
                ;;
            "odm")
                FILE="$WORK_DIR/odm/etc/build.prop"
                ;;
            "product")
                if $TARGET_HAS_PRODUCT; then
                    FILE="$WORK_DIR/product/etc/build.prop"
                else
                    FILE="$WORK_DIR/system/system/product/etc/build.prop"
                fi
                ;;
        esac

        if [ ! -f "$FILE" ]; then
            _ECHO_STDERR WARN "File not found: ${FILE//$WORK_DIR/}"
            return 0
        fi

        echo "Adding \"$PROP\" prop with \"$VALUE\" in ${FILE//$WORK_DIR/}"
        if ! grep -q "Added by scripts" "$FILE"; then
            echo "# Added by scripts/utils/module_utils.sh" >> "$FILE"
        fi
        echo "$PROP=$VALUE" >> "$FILE"
    fi

    return 0
}

# SET_PROP_IF_DIFF "<partition>" "<prop>" "<value>"
# Calls SET_PROP if the current prop value does not match, partition name CANNOT be omitted.
SET_PROP_IF_DIFF()
{
    _CHECK_NON_EMPTY_PARAM "PARTITION" "$1"
    _CHECK_NON_EMPTY_PARAM "PROP" "$2"
    _CHECK_NON_EMPTY_PARAM "EXPECTED" "$3"

    local PARTITION="$1"
    local PROP="$2"
    local EXPECTED="$3"

    if ! _IS_VALID_PARTITION_NAME "$PARTITION"; then
        _ECHO_STDERR ERR "\"$PARTITION\" is not a valid partition name"
        return 1
    fi

    local CURRENT
    CURRENT="$(GET_PROP "$PARTITION" "$PROP")"
    [ -z "$CURRENT" ] || [ "$CURRENT" = "$EXPECTED" ] || SET_PROP "$PARTITION" "$PROP" "$EXPECTED"
}
