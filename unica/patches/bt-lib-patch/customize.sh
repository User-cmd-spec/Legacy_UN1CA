if [ ! -f "$WORK_DIR/system/system/lib64/libbluetooth_jni.so" ]; then
    [ -d "$TMP_DIR" ] && rm -rf "$TMP_DIR"
    mkdir -p "$TMP_DIR"

    unzip -q -j "$WORK_DIR/system/system/apex/com.android.btservices.apex" \
        "apex_payload.img" -d "$TMP_DIR"

    mkdir -p "$TMP_DIR/tmp_out"
    sudo mount -o ro "$TMP_DIR/apex_payload.img" "$TMP_DIR/tmp_out"
    sudo cat "$TMP_DIR/tmp_out/lib64/libbluetooth_jni.so" > "$WORK_DIR/system/system/lib64/libbluetooth_jni.so"

    sudo umount "$TMP_DIR/tmp_out"
    rm -rf "$TMP_DIR"

    SET_METADATA "system" "system/lib64/libbluetooth_jni.so" 0 0 644 "u:object_r:system_lib_file:s0"
fi

# https://github.com/duhansysl/Bluetooth-Library-Patcher/blob/main/hexpatcher.sh#L53
HEX_PATCH "$WORK_DIR/system/system/lib64/libbluetooth_jni.so" \
    "97753948050037360080" "9775392a000014360080"
HEX_PATCH "$WORK_DIR/system/system/lib64/libbluetooth_jni.so" \
    "97773948050037360080" "9777392a000014360080"
