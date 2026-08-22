DECODE_APK "system" "system/priv-app/SecSetupWizard_Global/SecSetupWizard_Global.apk"

TARGET_APK_DIR=$(find "$APKTOOL_DIR" -type d -name "SecSetupWizard_Global*" | head -n 1)

if [ -z "$TARGET_APK_DIR" ] || [ ! -d "$TARGET_APK_DIR" ]; then
    LOG "[ERROR] DECODE_APK failed. Extracted directory not found under $APKTOOL_DIR"
    exit 1
fi

S2_F_FULL=$(find "$TARGET_APK_DIR" -type f -path "*/S2/f.smali" | head -n 1)
SETUP_ACT_FULL=$(find "$TARGET_APK_DIR" -type f -path "*/com/sec/android/app/SecSetupWizard/SecSetupWizardActivity.smali" | head -n 1)

if [ -n "$S2_F_FULL" ] && [ -n "$SETUP_ACT_FULL" ]; then
    S2_F_REL=$(echo "$S2_F_FULL" | sed -n "s|.*${TARGET_APK_DIR}/||p")
    SETUP_ACT_REL=$(echo "$SETUP_ACT_FULL" | sed -n "s|.*${TARGET_APK_DIR}/||p")

    LOG "- Enabling navigation bar type settings step ($S2_F_REL)"
    SMALI_PATCH "system" "system/priv-app/SecSetupWizard_Global/SecSetupWizard_Global.apk" \
        "$S2_F_REL" "replace" \
        "d(Landroid/content/Context;Z)Ljava/util/ArrayList;" \
        "navigationbar_setting" \
        "this_string_does_not_exist" \
        > /dev/null

    SMALI_PATCH "system" "system/priv-app/SecSetupWizard_Global/SecSetupWizard_Global.apk" \
        "$SETUP_ACT_REL" "replace" \
        "f(Ljava/lang/String;)Z" \
        "navigationbar_setting" \
        "this_string_does_not_exist" \
        > /dev/null
else
    LOG "[ERROR] Could not locate required smali files inside decompiled APK."
    exit 1
fi

LOG "- Disabling Recommended apps step"
EVAL "sed -i \"/omcagent/d\" \"$TARGET_APK_DIR/res/values/arrays.xml\""

if [ -d "$MODPATH/SecSetupWizard_Global.apk" ]; then
    while IFS= read -r f; do
        f="${f//$MODPATH\/SecSetupWizard_Global.apk\//}"

        if [ ! -f "$TARGET_APK_DIR/$f" ] || [[ "$f" != *".xml" ]]; then
            LOG "- Adding \"$f\" to /system/system/priv-app/SecSetupWizard_Global.apk"
            EVAL "mkdir -p \"$(dirname "$TARGET_APK_DIR/$f")\""
            EVAL "cp -a \"$MODPATH/SecSetupWizard_Global.apk/${f//\$/\\$}\" \"$TARGET_APK_DIR/${f//\$/\\$}\""
        else
            LOG "- Patching \"$f\" in /system/system/priv-app/SecSetupWizard_Global.apk"
            if [[ "$f" == *"res/values"* ]]; then
                PATCH_INST="/<\/resources>/i"
                CONTENT="$(sed -e "/?xml/d" -e "/resources>/d" "$MODPATH/SecSetupWizard_Global.apk/$f")"
            else
                PATCH_INST="$(head -n 1 "$MODPATH/SecSetupWizard_Global.apk/$f")"
                CONTENT="$(tail -n +2 "$MODPATH/SecSetupWizard_Global.apk/$f")"
            fi
            CONTENT="$(sed -e "s/\"/\\\\\"/g" -e "s/\\\\\\\\\"/\\\\\\\\\\\\\\\\\\\\\"/g" -e "s/\\$/\\\\$/g" -e "s/ /\\\ /g" -e "s/\\\\n/\\\\\\\\\n/g" <<< "$CONTENT")"
            CONTENT="$(sed -E ':a;N;$!ba;s/\r{0,1}\n/\\n/g' <<< "$CONTENT")"
            EVAL "sed -i \"$PATCH_INST $CONTENT\" \"$TARGET_APK_DIR/$f\""
        fi
    done < <(find "$MODPATH/SecSetupWizard_Global.apk" -type f)
else
    LOG "- Directory $MODPATH/SecSetupWizard_Global.apk not found, skipping dynamic file patches."
fi

unset PATCH_INST CONTENT TARGET_APK_DIR S2_F_FULL SETUP_ACT_FULL S2_F_REL SETUP_ACT_REL
