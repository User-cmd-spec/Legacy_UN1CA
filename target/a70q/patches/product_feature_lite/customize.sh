#!/usr/bin/env bash

DECODE_APK "system/framework/esecomm.jar"
DECODE_APK "system/framework/services.jar"
DECODE_APK "system/framework/framework.jar"
DECODE_APK "system/priv-app/SecSettings/SecSettings.apk"
DECODE_APK "system/framework/gamemanager.jar"
DECODE_APK "system/framework/secinputdev-service.jar"
DECODE_APK "system/priv-app/SettingsProvider/SettingsProvider.apk"
DECODE_APK "system_ext/priv-app/SystemUI/SystemUI.apk"

patch_file() {
    local target_pkg="$1"
    local relative_path="$2"
    local search_pattern="$3"
    local replace_pattern="$4"

    local file_path
    file_path=$(find "$APKTOOL_DIR/$target_pkg" -type f -path "*/$relative_path" 2>/dev/null | head -n 1)

    if [ -n "$file_path" ] && [ -f "$file_path" ]; then
        echo "  -> Dynamic Patching: $file_path"
        sed -i "s/$search_pattern/$replace_pattern/g" "$file_path"
        return 0
    else
        echo "  !! Warning: $relative_path not found in $target_pkg"
        return 1
    fi
}

extract_spf_val() {
    local base_dir="$1"
    local feature_key="$2"
    grep -rn "$feature_key" "$base_dir" 2>/dev/null | grep -oE '"[^"]+"|[0-9]+' | head -n 1 | tr -d '"' || true
}

compare_and_patch_feature() {
    local target_pkg="$1"
    local relative_smali_path="$2"
    local feature_key="$3"
    local fallback_src_val="$4"
    local fallback_tgt_val="$5"

    echo "Checking SEC Product Feature: $feature_key"

    local src_val=""
    local tgt_val=""

    if [ -n "$SRC_FW_DIR" ] && [ -d "$SRC_FW_DIR" ]; then
        src_val=$(extract_spf_val "$SRC_FW_DIR" "$feature_key")
    fi

    if [ -n "$TGT_FW_DIR" ] && [ -d "$TGT_FW_DIR" ]; then
        tgt_val=$(extract_spf_val "$TGT_FW_DIR" "$feature_key")
    fi

    [ -z "$src_val" ] && src_val="$fallback_src_val"
    [ -z "$tgt_val" ] && tgt_val="$fallback_tgt_val"

    if [ "$src_val" != "$tgt_val" ] && [ -n "$src_val" ] && [ -n "$tgt_val" ]; then
        echo "  -> Discrepancy found for $feature_key (Source: $src_val | Target: $tgt_val)"
        patch_file "$target_pkg" "$relative_smali_path" "\"$tgt_val\"" "\"$src_val\""
    else
        echo "  -> Feature $feature_key matches or skip needed (Source: $src_val | Target: $tgt_val)"
    fi
}

echo "=== Processing SEC Product Feature patches ==="

compare_and_patch_feature \
    "system/framework/services.jar" \
    "com/android/server/power/PowerManagerUtil.smali" \
    "SEC_FLOATING_FEATURE_SETTINGS_MAINLINE_API_LEVEL" \
    "30" \
    "35"

compare_and_patch_feature \
    "system/framework/services.jar" \
    "com/samsung/android/hardware/display/SemMdnieManagerService.smali" \
    "SEC_FLOATING_FEATURE_LCD_SUPPORT_MDNIE_HW" \
    "46097" \
    "37905"

compare_and_patch_feature \
    "system/framework/framework.jar" \
    "com/samsung/android/hardware/display/RefreshRateConfig.smali" \
    "SEC_FLOATING_FEATURE_LCD_CONFIG_HFR_MODE" \
    "0" \
    "2"

compare_and_patch_feature \
    "system/priv-app/SecSettings/SecSettings.apk" \
    "com/samsung/android/settings/display/SecDisplayUtils.smali" \
    "SEC_FLOATING_FEATURE_LCD_CONFIG_HFR_REFRESH_RATE" \
    "${TARGET_HFR_SUPPORTED_REFRESH_RATE:-60}" \
    "60,120"

compare_and_patch_feature \
    "system/framework/framework.jar" \
    "com/samsung/android/camera/mic/SemMultiMicManager.smali" \
    "SEC_FLOATING_FEATURE_AUDIO_CONFIG_MULTIMIC" \
    "07002" \
    "08020"

echo "=== SEC Product Feature patching completed ==="
