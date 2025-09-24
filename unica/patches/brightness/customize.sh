echo "Applying Adapative Brightness fix"
HEX_PATCH "$WORK_DIR/system/system/lib64/libsensorservice.so" \
    "f25a009420008052" "f25a009400008052"
echo "Adapative Brightness fix was applied successfully!"