#!/bin/bash

if [ -n "$WORK_DIR" ]; then
    TARGET_FILE="$WORK_DIR/system/system/etc/permissions/privapp-permissions-com.samsung.android.applock.xml"
else
    TARGET_FILE="out/fw/SM-A366B_EUX/system/system/etc/permissions/privapp-permissions-com.samsung.android.applock.xml"
fi

mkdir -p "$(dirname "$TARGET_FILE")"

cat << 'EOF' > "$TARGET_FILE"
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

chmod 644 "$TARGET_FILE"
