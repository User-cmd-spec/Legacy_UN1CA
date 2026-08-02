SOURCE_EXTRA_FIRMWARES="SM-A366B/EUX/351384481564824"
mkdir -p "$WORK_DIR/system/system/system_ext/apex"
mkdir -p "out/fw/SM-A366B_EUX/system/system/bin/"
touch "out/fw/SM-A366B_EUX/system/system/bin/linker_asan"

echo "Applying Legacy stack"
ADD_TO_WORK_DIR "$SOURCE_EXTRA_FIRMWARES" "system" "system/apex/com.android.runtime.apex" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "$SOURCE_EXTRA_FIRMWARES" "system" "system/apex/com.android.i18n.apex" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "$SOURCE_EXTRA_FIRMWARES" "system" "system/bin/bootstrap" 0 2000 751 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "$SOURCE_EXTRA_FIRMWARES" "system" "system/bin/linker64" 0 2000 755 "u:object_r:system_linker_exec:s0"
ADD_TO_WORK_DIR "$SOURCE_EXTRA_FIRMWARES" "system" "system/bin/linker_asan" 0 2000 755 "u:object_r:system_file:s0"

echo "Dirty adding libraries"

MODEL=$(echo -n "$SOURCE_EXTRA_FIRMWARES" | cut -d "/" -f 1)
REGION=$(echo -n "$SOURCE_EXTRA_FIRMWARES" | cut -d "/" -f 2)

# Standard libraries
if [ -d "$FW_DIR/${MODEL}_${REGION}/system/system/lib" ]; then
    cp -a --preserve=all "$FW_DIR/${MODEL}_${REGION}/system/system/lib" "$WORK_DIR/system/system"
    grep -F "system/lib/" "$FW_DIR/${MODEL}_${REGION}/fs_config-system" >> "$WORK_DIR/configs/fs_config-system" || true
    grep -F "system/lib/" "$FW_DIR/${MODEL}_${REGION}/file_context-system" >> "$WORK_DIR/configs/file_context-system" || true
fi

# System_ext libraries
if [ -d "$FW_DIR/${MODEL}_${REGION}/system_ext/lib" ]; then
    cp -a --preserve=all "$FW_DIR/${MODEL}_${REGION}/system_ext/lib" "$WORK_DIR/system/system/system_ext"
    cp "$FW_DIR/${MODEL}_${REGION}/fs_config-system_ext" "$FW_DIR/${MODEL}_${REGION}/fs_config-system_ext_tmp"
    cp "$FW_DIR/${MODEL}_${REGION}/file_context-system_ext" "$FW_DIR/${MODEL}_${REGION}/file_context-system_ext_tmp"

    sed -i -e 's/system_ext/system\/system_ext/g' "$FW_DIR/${MODEL}_${REGION}/fs_config-system_ext_tmp"
    sed -i -e 's/system_ext/system\/system_ext/g' "$FW_DIR/${MODEL}_${REGION}/file_context-system_ext_tmp"

    grep -F "system/system_ext/lib/" "$FW_DIR/${MODEL}_${REGION}/fs_config-system_ext_tmp" >> "$WORK_DIR/configs/fs_config-system" || true
    grep -F "system/system_ext/lib/" "$FW_DIR/${MODEL}_${REGION}/file_context-system_ext_tmp" >> "$WORK_DIR/configs/file_context-system" || true
    echo "system/system_ext/lib 0 0 755 capabilities=0x0" >> "$WORK_DIR/configs/fs_config-system"
    echo "/system/system_ext/lib u:object_r:system_lib_file:s0" >> "$WORK_DIR/configs/file_context-system"
fi

echo "Adding Legacy WFD"
echo "Adding Legacy VNDK"
ADD_TO_WORK_DIR "r9qxxx" "system" "bin" 0 2000 751 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "r9qxxx" "system" "lib" 0 0 755 "u:object_r:system_lib_file:s0"
ADD_TO_WORK_DIR "r9qxxx" "system" "system_ext/apex/com.android.vndk.v30.apex" 0 0 755 "u:object_r:system_file:s0"

echo "Legacy stack was applied successfully!"
