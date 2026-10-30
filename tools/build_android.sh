#!/bin/bash
# Signed Android debug export. Godot runs build-tools/apksigner, a shell
# script that needs `java` on PATH; without it signing silently fails and
# the APK is left UNSIGNED. So put the JDK on PATH and always verify.
set -e
OUT=${1:?usage: build_android.sh OUT.apk}
G=${GODOT:-/workspace/tools/Godot_v4.4.1-stable_linux.x86_64}
export JAVA_HOME=${JAVA_HOME:-/workspace/tools/jdk17}
export PATH="$JAVA_HOME/bin:$PATH"
SDK=${ANDROID_SDK:-/workspace/tools/android-sdk}
cd "$(dirname "$0")/.."
rm -f "$OUT"
"$G" --headless --path . --export-debug "Android" "$OUT" 2>&1 | tee /tmp/godot_export.log | grep -iE "sign|error" || true
APKSIGNER=$(ls -d "$SDK"/build-tools/*/apksigner | tail -1)
"$APKSIGNER" verify --print-certs "$OUT"
