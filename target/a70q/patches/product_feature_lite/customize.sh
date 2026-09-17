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
        echo "  -> Patching: $file_path"
        sed -i "s/$search_pattern/$replace_pattern/g" "$file_path"
    else
        echo "  !! Warning: $relative_path not found in $target_pkg, skipping..."
    fi
}

echo "Applying MAINLINE_API_LEVEL patches"
patch_file "system/framework/esecomm.jar" "com/sec/esecomm/EsecommAdapter.smali" "\"MAINLINE_API_LEVEL: 35\"" "\"MAINLINE_API_LEVEL: 30\""
patch_file "system/framework/esecomm.jar" "com/sec/esecomm/EsecommAdapter.smali" "\"35\"" "\"30\""

patch_file "system/framework/services.jar" "com/android/server/SystemServer.smali" "\"MAINLINE_API_LEVEL: 35\"" "\"MAINLINE_API_LEVEL: 30\""
patch_file "system/framework/services.jar" "com/android/server/SystemServer.smali" "\"35\"" "\"30\""

patch_file "system/framework/services.jar" "com/android/server/power/PowerManagerUtil.smali" "\"MAINLINE_API_LEVEL: 35\"" "\"MAINLINE_API_LEVEL: 30\""
patch_file "system/framework/services.jar" "com/android/server/power/PowerManagerUtil.smali" "\"35\"" "\"30\""

patch_file "system/framework/services.jar" "com/android/server/sepunion/EngmodeService\$EngmodeTimeThread.smali" "\"MAINLINE_API_LEVEL: 35\"" "\"MAINLINE_API_LEVEL: 30\""
patch_file "system/framework/services.jar" "com/android/server/sepunion/EngmodeService\$EngmodeTimeThread.smali" "\"35\"" "\"30\""

echo "Applying mDNIe features patches"
patch_file "system/framework/services.jar" "com/samsung/android/hardware/display/SemMdnieManagerService.smali" "\"37905\"" "\"46097\""
patch_file "system/framework/services.jar" "com/samsung/android/hardware/display/SemMdnieManagerService.smali" "\"3\"" "\"0\""

echo "Applying HFR_MODE patches"
patch_file "system/framework/framework.jar" "com/samsung/android/rune/CoreRune.smali" "\"2\"" "\"0\""
patch_file "system/framework/framework.jar" "com/samsung/android/hardware/display/RefreshRateConfig.smali" "\"2\"" "\"0\""
patch_file "system/framework/gamemanager.jar" "com/samsung/android/game/GameManagerService.smali" "\"2\"" "\"0\""
patch_file "system/framework/secinputdev-service.jar" "com/samsung/android/hardware/secinputdev/SemInputDeviceManagerService.smali" "\"2\"" "\"0\""
patch_file "system/framework/secinputdev-service.jar" "com/samsung/android/hardware/secinputdev/utils/SemInputFeatures.smali" "\"2\"" "\"0\""
patch_file "system/framework/secinputdev-service.jar" "com/samsung/android/hardware/secinputdev/utils/SemInputFeaturesExtra.smali" "\"2\"" "\"0\""
patch_file "system/priv-app/SecSettings/SecSettings.apk" "com/samsung/android/settings/display/SecDisplayUtils.smali" "\"2\"" "\"0\""
patch_file "system/priv-app/SettingsProvider/SettingsProvider.apk" "com/android/providers/settings/DatabaseHelper.smali" "\"2\"" "\"0\""
patch_file "system_ext/priv-app/SystemUI/SystemUI.apk" "com/android/systemui/LsRune.smali" "\"2\"" "\"0\""

echo "Applying HFR_SUPPORTED_REFRESH_RATE patches"
HFR_REPLACE="\"\""
if [[ "$TARGET_HFR_SUPPORTED_REFRESH_RATE" != "none" ]]; then
    HFR_REPLACE="\"60\""
fi

patch_file "system/framework/framework.jar" "com/samsung/android/hardware/display/RefreshRateConfig.smali" "\"60,120\"" "$HFR_REPLACE"
patch_file "system/priv-app/SecSettings/SecSettings.apk" "com/samsung/android/settings/display/SecDisplayUtils.smali" "\"60,120\"" "$HFR_REPLACE"

echo "Applying SemMultiMicManager patches"
patch_file "system/framework/framework.jar" "com/samsung/android/camera/mic/SemMultiMicManager.smali" "08020" "07002"

echo "Applying model detection patches"
patch_file "system/framework/framework.jar" "com/samsung/android/rune/CoreRune.smali" "ro\.product\.model" "ro\.product\.vendor\.model"
patch_file "system/framework/services.jar" "com/android/server/am/FreecessController.smali" "ro\.product\.model" "ro\.product\.vendor\.model"
