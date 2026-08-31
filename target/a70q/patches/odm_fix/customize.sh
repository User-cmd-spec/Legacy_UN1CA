#!/usr/bin/env bash
#===============================================================================
# LegacyUN1CA customize.sh — vendor image prep + precompiled sepolicy sync
#
# What it does:
#   1. Reassembles the split, lz4-compressed vendor image parts from
#        $SRC_DIR/target/$DEVICE/prebuilt_images/vendor/
#      (vendor.img.1.lz4 … vendor.img.12.lz4, or a single vendor.img.lz4)
#   2. Decompresses it (lz4 or magiskboot) and extracts the image into
#        $WORK_DIR/vendor
#      (auto-detects erofs / ext4 / Android sparse)
#   3. Synchronises the SELinux precompiled-policy hash files in the
#      extracted vendor tree with the freshly built system image, so init
#      takes the "precompiled policy" fast path at boot instead of
#      recompiling the CIL policy (which is what currently panics).
#   4. Verifies the hash match and announces completion.
#
#
# Optional env:
#   DEVICE                      target device              (default: a70q)
#   REGENERATED_SEPOLICY_DIR    dir containing a freshly generated
#                               precompiled_sepolicy       (default: unset)
#
#   If REGENERATED_SEPOLICY_DIR is set and contains a real precompiled_sepolicy,
#   the script replaces the stock one with it (correct fix).
#   If it is unset, the script falls back to hash-sync mode: it copies the
#   system's *_sepolicy_and_mapping.sha256 over the odm copies so init loads
#   the STOCK precompiled binary (fast, skips the broken product CIL compile,
#   but the loaded policy is the stock one — see the warning in the output).
#===============================================================================
set -euo pipefail

# ---------------------------------------------------------------- configuration
SRC_DIR="${SRC_DIR:?SRC_DIR must be set, e.g. /home/runner/work/Legacy_UN1CA/Legacy_UN1CA}"
WORK_DIR="${WORK_DIR:?WORK_DIR must be set, e.g. /home/runner/work/Legacy_UN1CA/Legacy_UN1CA/out/work_dir}"
DEVICE="${DEVICE:-a70q}"
REGEN_DIR="${REGENERATED_SEPOLICY_DIR:-}"

VENDOR_SRC="${VENDOR_SRC:-$SRC_DIR/target/$DEVICE/prebuilt_images/vendor}"
VENDOR_OUT="${VENDOR_OUT:-$WORK_DIR/vendor}"

# Root of the extracted system image (adjust if your tree differs)
SYS_ROOT="${SYS_ROOT:-$WORK_DIR/system/system}"
PLAT_SELINUX_DIR="$SYS_ROOT/etc/selinux"
SYS_EXT_SELINUX_DIR="$SYS_ROOT/system_ext/etc/selinux"
PRODUCT_SELINUX_DIR="$SYS_ROOT/product/etc/selinux"
# ODM sepolicy lives inside the vendor image on Samsung (non-dynamic layout)
ODM_SELINUX_DIR="$VENDOR_OUT/odm/etc/selinux"

TMP_IMG="$WORK_DIR/.vendor_work/vendor.img"
LZ4_FILE="$WORK_DIR/vendor.img.lz4"

# ------------------------------------------------------------------ helpers
log()  { echo -e "[customize] $*"; }
die()  { echo -e "[customize] ERROR: $*" >&2; exit 1; }

# ----------------------------------------------------- decompress a lz4 file
decompress_lz4() { # $1 in, $2 out  -> returns 0 on success
  local in="$1" out="$2"
  if command -v lz4 >/dev/null 2>&1 && lz4 -d -f -q "$in" "$out" 2>/dev/null; then
    return 0
  fi
  if command -v magiskboot >/dev/null 2>&1 && magiskboot decompress "$in" "$out" 2>/dev/null; then
    return 0
  fi
  return 1
}

# ---------------------------------------------- reassemble + decompress image
reassemble_and_decompress() {
  mkdir -p "$WORK_DIR/.vendor_work"
  rm -f "$LZ4_FILE" "$TMP_IMG"

  local -a parts=()
  local single=""
  [[ -f "$VENDOR_SRC/vendor.img.lz4" ]] && single="$VENDOR_SRC/vendor.img.lz4"
  if [[ -z "$single" ]]; then
    mapfile -d '' parts < <(find "$VENDOR_SRC" -maxdepth 1 -type f \
        -name 'vendor.img.*.lz4' -print0 2>/dev/null | sort -z -V)
  fi

  if [[ -n "$single" ]]; then
    log "Found single image: $single"
    cp -f "$single" "$LZ4_FILE"
  elif [[ ${#parts[@]} -gt 0 ]]; then
    log "Reassembling ${#parts[@]} split parts -> $(basename "$LZ4_FILE")"
    cat "${parts[@]}" > "$LZ4_FILE"
  else
    die "No vendor image found in $VENDOR_SRC (looked for vendor.img.lz4 / vendor.img.*.lz4)"
  fi

  log "Decompressing lz4 ..."
  if ! decompress_lz4 "$LZ4_FILE" "$TMP_IMG"; then
    if [[ ${#parts[@]} -gt 0 ]]; then
      log "Single-stream decompress failed, trying per-part decompress ..."
      : > "$TMP_IMG"
      local p ok=1
      for p in "${parts[@]}"; do
        if decompress_lz4 "$p" "$TMP_IMG.part"; then
          cat "$TMP_IMG.part" >> "$TMP_IMG"
          rm -f "$TMP_IMG.part"
        else
          log "  failed part: $p"; ok=0; break
        fi
      done
      (( ok )) || die "Failed to decompress vendor image parts"
    else
      die "Failed to decompress vendor image"
    fi
  fi
  log "Vendor image ready: $TMP_IMG ($(du -h "$TMP_IMG" | cut -f1))"
}

# ------------------------------------------------------------- extract image
mount_fallback() { # try loop-mount + copy if no extraction tool worked
  local mnt="$WORK_DIR/.vendor_work/mnt"
  mkdir -p "$mnt"
  if mount -o loop "$TMP_IMG" "$mnt" 2>/dev/null; then
    log "Extracting via loop-mount ..."
    cp -a "$mnt/." "$VENDOR_OUT/"
    umount "$mnt"
    rmdir "$mnt" 2>/dev/null || true
    return 0
  fi
  return 1
}

extract_image() {
  rm -rf "$VENDOR_OUT" && mkdir -p "$VENDOR_OUT"

  local magic erofs_magic ext_magic
  magic=$(od -An -tx1 -N4 "$TMP_IMG" | tr -d ' \n')
  erofs_magic=$(od -An -tx1 -j1024 -N4 "$TMP_IMG" | tr -d ' \n')
  ext_magic=$(od -An -tx1 -j1080 -N2 "$TMP_IMG" | tr -d ' \n')

  # Android sparse image?
  if [[ "$magic" == "3aff26ed" ]]; then
    log "Sparse image detected, converting ..."
    command -v simg2img >/dev/null || die "simg2img required (android-tools-fsutils)"
    simg2img "$TMP_IMG" "$TMP_IMG.raw" && mv "$TMP_IMG.raw" "$TMP_IMG"
    erofs_magic=$(od -An -tx1 -j1024 -N4 "$TMP_IMG" | tr -d ' \n')
    ext_magic=$(od -An -tx1 -j1080 -N2 "$TMP_IMG" | tr -d ' \n')
  fi

  if [[ "$erofs_magic" == "e2e1f5e0" ]]; then
    log "Filesystem: erofs"
    if command -v extract.erofs >/dev/null 2>&1; then
      extract.erofs "$TMP_IMG" "$VENDOR_OUT" && return 0
    fi
    if command -v fsck.erofs >/dev/null 2>&1; then
      fsck.erofs --extract="$VENDOR_OUT" "$TMP_IMG" && return 0
    fi
    die "No erofs extractor found — install erofs-utils (extract.erofs / fsck.erofs)"
  elif [[ "$ext_magic" == "53ef" ]]; then
    log "Filesystem: ext4"
    command -v debugfs >/dev/null || die "debugfs required (e2fsprogs)"
    debugfs -R "rdump / \"$VENDOR_OUT\"" "$TMP_IMG" >/dev/null 2>&1 && return 0
    log "debugfs extraction failed, trying loop-mount ..."
    mount_fallback && return 0
    die "Failed to extract ext4 vendor image"
  else
    log "Unknown filesystem magic, trying loop-mount ..."
    mount_fallback && return 0
    die "Unrecognised vendor image format"
  fi
}

# ---------------------------------------------------------- sync sepolicy
sync_sepolicy() {
  [[ -d "$ODM_SELINUX_DIR" ]] || die "No $ODM_SELINUX_DIR in extracted vendor (wrong image?)"

  # Mode 1: a freshly regenerated precompiled_sepolicy was supplied
  if [[ -n "$REGEN_DIR" && -f "$REGEN_DIR/precompiled_sepolicy" ]]; then
    log "REGENERATED mode: copying precompiled_sepolicy* from $REGEN_DIR"
    cp -v "$REGEN_DIR"/precompiled_sepolicy* "$ODM_SELINUX_DIR/"
  else
    log "Hash-sync mode: keeping the stock precompiled binary and syncing hash files"
    echo "  NOTE: init will load the STOCK precompiled policy (fast path)."
    echo "  The broken product_sepolicy.cil is never compiled, so the panic stops."
    echo "  This is a workaround — for a fully correct policy, set"
    echo "  REGENERATED_SEPOLICY_DIR to a freshly built precompiled_sepolicy."
  fi

  # Mode 2 (always): sync every system *_sepolicy_and_mapping.sha256 over the
  # odm precompiled counterpart so init's hash comparison passes.
  local pair name sys_sha odm_sha
  while IFS='|' read -r name sys_sha; do
    [[ -f "$sys_sha" ]] || { log "skip $name (no system sha256)"; continue; }
    odm_sha="$ODM_SELINUX_DIR/precompiled_sepolicy.${name}_sepolicy_and_mapping.sha256"
    log "sync ${name}_sepolicy_and_mapping.sha256 -> $(basename "$odm_sha")"
    cp -f "$sys_sha" "$odm_sha"
  done <<EOF
plat|$PLAT_SELINUX_DIR/plat_sepolicy_and_mapping.sha256
system_ext|$SYS_EXT_SELINUX_DIR/system_ext_sepolicy_and_mapping.sha256
product|$PRODUCT_SELINUX_DIR/product_sepolicy_and_mapping.sha256
EOF

  # policy version file, for completeness
  if [[ -f "$PLAT_SELINUX_DIR/plat_sepolicy_vers.txt" ]]; then
    cp -f "$PLAT_SELINUX_DIR/plat_sepolicy_vers.txt" \
          "$ODM_SELINUX_DIR/precompiled_sepolicy.plat_sepolicy_vers.txt"
  fi
}

# ------------------------------------------------------------------ verify
verify_sync() {
  local plat_sys="$PLAT_SELINUX_DIR/plat_sepolicy_and_mapping.sha256"
  local plat_odm="$ODM_SELINUX_DIR/precompiled_sepolicy.plat_sepolicy_and_mapping.sha256"
  if [[ -f "$plat_sys" && -f "$plat_odm" ]] && cmp -s "$plat_sys" "$plat_odm"; then
    echo "  ✔ plat_sepolicy_and_mapping.sha256 MATCHES — init will take the fast path."
    HASH_STATUS="MATCH"
  else
    echo "  ✖ hashes still differ — init will fall back to CIL compile at boot."
    HASH_STATUS="MISMATCH"
  fi
}

# ------------------------------------------------------------------- main
main() {
  log "== vendor prep for device '$DEVICE' =="
  log "source      : $VENDOR_SRC"
  log "destination : $VENDOR_OUT"

  reassemble_and_decompress
  extract_image
  sync_sepolicy
  verify_sync

  echo
  echo "==============================================================================="
  echo "  ✔ DONE"
  echo "    Vendor tree  : $VENDOR_OUT"
  echo "    Sepolicy set : $ODM_SELINUX_DIR"
  echo "    Hash match   : $HASH_STATUS"
  echo "==============================================================================="
}

main "$@"
