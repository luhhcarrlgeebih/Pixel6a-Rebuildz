#!/usr/bin/env bash
set -Eeuo pipefail

DEVICE_NAME="${1:-bluejay}"
IMAGE_DIR="${2:-$(pwd)/out/target/product/$DEVICE_NAME}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

OUT="$ROOT/SHRP-$DEVICE_NAME-installer.zip"
WORK="$ROOT/.zip-work"

IMAGE=""

for candidate in recovery.img boot.img; do
    if [ -f "$IMAGE_DIR/$candidate" ]; then
        IMAGE="$candidate"
        break
    fi
done

if [ -z "$IMAGE" ]; then
    echo "No recovery.img or boot.img found in $IMAGE_DIR" >&2
    exit 1
fi

rm -rf "$WORK"
mkdir -p "$WORK/META-INF/com/google/android"

cp "$IMAGE_DIR/$IMAGE" "$WORK/$IMAGE"

cat > "$WORK/META-INF/com/google/android/updater-script" <<EOF
ui_print("SHRP $DEVICE_NAME installer");
ui_print("DEVICE: $DEVICE_NAME");
ui_print("IMAGE: $IMAGE");
ui_print("This ZIP is an experimental recovery installer.");
ui_print("Back up boot, vbmeta, persist, and other required partitions.");

assert(getprop("ro.product.device") == "$DEVICE_NAME");
assert(getprop("ro.boot.slot_suffix") == "a" ||
       getprop("ro.boot.slot_suffix") == "b");

package_extract_file("$IMAGE", "/tmp/$IMAGE");

run_program(
    "/system/bin/dd",
    "if=/tmp/$IMAGE",
    "of=/dev/block/by-name/boot" + getprop("ro.boot.slot_suffix"),
    "bs=4096"
);

ui_print("Recovery image written to boot slot");
ui_print("Reboot to recovery and verify it before using.");
EOF

cat > "$WORK/META-INF/com/google/android/update-binary" <<'EOF'
#!/sbin/sh

UPDATER_SCRIPT="/tmp/update-binary/updater-script"
ZIPFILE="$3"

mkdir -p /tmp/update-binary
cd /tmp/update-binary

unzip -o "$ZIPFILE" META-INF/com/google/android/updater-script
exit 0
EOF

chmod 755 "$WORK/META-INF/com/google/android/update-binary"

cd "$WORK"
rm -f "$OUT"
zip -r -9 "$OUT" META-INF "$IMAGE"

rm -rf "$WORK"

echo "Created $OUT using $IMAGE"
unzip -l "$OUT"
