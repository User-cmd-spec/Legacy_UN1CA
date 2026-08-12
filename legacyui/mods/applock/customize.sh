mkdir -p "$WORK_DIR/system/system/etc/permissions"
TARGET_XML="$WORK_DIR/system/system/etc/permissions/privapp-permissions-com.samsung.android.applock.xml"

if [ ! -f "$TARGET_XML" ]; then
    cat << 'EOF' > "$TARGET_XML"
<!--
    This XML file declares which signature|privileged permissions should be granted to privileged
    applications that come with the platform
    -->
<permissions>
    <privapp-permissions package="com.samsung.android.applock">
        <permission name="android.permission.STATUS_BAR"/>
        <permission name="android.permission.SET_PROCESS_LIMIT"/>
    </privapp-permissions>
</permissions>
EOF
fi

ADD_TO_WORK_DIR "$TARGET_XML" "system" "system/etc/permissions/privapp-permissions-com.samsung.android.applock.xml" 0 0 644 "u:object_r:system_file:s0"

if [ -f "$WORK_DIR/system/system/priv-app/AppLock/AppLock.apk" ]; then
    mv -f "$WORK_DIR/system/system/priv-app/AppLock/AppLock.apk" "$WORK_DIR/system/system/priv-app/AppLock/SAppLock.apk"
    sed -i "s/AppLock.apk/SAppLock.apk/g" "$WORK_DIR/configs/fs_config-system"
    sed -i "s/AppLock\\\.apk/SAppLock\\\.apk/g" "$WORK_DIR/configs/file_context-system"
fi

if [ -d "$WORK_DIR/system/system/priv-app/AppLock" ]; then
    mv -f "$WORK_DIR/system/system/priv-app/AppLock" "$WORK_DIR/system/system/priv-app/SAppLock"
    sed -i "s/priv-app\/AppLock/priv-app\/SAppLock/g" "$WORK_DIR/configs/fs_config-system"
    sed -i "s/priv-app\/AppLock/priv-app\/SAppLock/g" "$WORK_DIR/configs/file_context-system"
fi
