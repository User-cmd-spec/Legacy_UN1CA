echo "Settling up configuration"
IFS=':' read -a SOURCE_EXTRA_FIRMWARES <<< "$SOURCE_FIRMWARE"
MODEL=$(echo -n "${SOURCE_FIRMWARE[0]}" | cut -d "/" -f 1)
REGION=$(echo -n "${SOURCE_FIRMWARE[0]}" | cut -d "/" -f 2)

# Define central configs path based on your environment
CONFIGS_DIR="$WORK_DIR/configs"

echo "Setting up prism"

echo "Debloating prism"
rm -rf $FW_DIR/${MODEL}_${REGION}/prism/app
rm -rf $FW_DIR/${MODEL}_${REGION}/prism/HWRDB
rm -rf $FW_DIR/${MODEL}_${REGION}/prism/lost+found
rm -rf $FW_DIR/${MODEL}_${REGION}/prism/media
rm -rf $FW_DIR/${MODEL}_${REGION}/prism/priv-app

echo "Settling up a prism symlink"
rm -rf $WORK_DIR/system/prism
ln -s /system/prism $WORK_DIR/system/prism

SET_METADATA "system" "system/prism" 0 0 755 "u:object_r:system_file:s0"

# Process prism file contexts and fs_config from CONFIGS_DIR instead of FW_DIR
{
    sed "s/^\/prism/\/system\/prism/g" "$CONFIGS_DIR/file_context-prism"
} >> "$CONFIGS_DIR/file_context-system"

{
    sed "1d" "$CONFIGS_DIR/fs_config-prism" | sed "s/^prism/system\/prism/g"
} >> "$CONFIGS_DIR/file_context-system"

# Extract matched lines into the target system config files
grep -F "system/prism" "$CONFIGS_DIR/file_context-system" >> "$CONFIGS_DIR/fs_config-system"

echo "Installing prism"
cp -a --preserve=all "$FW_DIR/${MODEL}_${REGION}/prism" "$WORK_DIR/system/system"

echo "Setting up optics"

rm -rf $FW_DIR/${MODEL}_${REGION}/optics/lost+found

echo "Settling up an optics symlink"
rm -rf $WORK_DIR/system/optics
ln -s /system/optics $WORK_DIR/system/optics

SET_METADATA "system" "system/optics" 0 0 755 "u:object_r:system_file:s0"

# Process optics file contexts and fs_config from CONFIGS_DIR
{
    sed "s/^\/optics/\/system\/optics/g" "$CONFIGS_DIR/file_context-optics"
} >> "$CONFIGS_DIR/file_context-system"

{
    sed "1d" "$CONFIGS_DIR/fs_config-optics" | sed "s/^optics/system\/optics/g"
} >> "$CONFIGS_DIR/file_context-system"

# Extract matched lines into the target system config files
grep -F "system/optics" "$CONFIGS_DIR/file_context-system" >> "$CONFIGS_DIR/fs_config-system"

echo "Installing optics"
cp -a --preserve=all "$FW_DIR/${MODEL}_${REGION}/optics" "$WORK_DIR/system/system"

echo "CSC was adapted successfully!"
