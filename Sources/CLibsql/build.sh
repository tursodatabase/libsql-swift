#!/usr/bin/env sh

set -eu
set -x

cd libsql-c

export IPHONEOS_DEPLOYMENT_TARGET=15.1

macos_sdk="$(xcrun --sdk macosx --show-sdk-path)"
xcframework_root="../CLibsql.xcframework"
xcframework_output="../CLibsql.xcframework.new"

rustup target add aarch64-apple-ios-macabi x86_64-apple-ios-macabi

wrapper_dir="$(mktemp -d)"
include_dir="$(mktemp -d)"

cleanup() {
    rm -rf "$wrapper_dir" "$include_dir"
}

trap cleanup EXIT

cat > "$wrapper_dir/clang-macabi-wrapper" <<'EOF'
#!/usr/bin/env sh
set -eu
real_clang="$(xcrun --find clang)"
python3 - "$real_clang" "$@" <<'PY'
import os
import sys

real = sys.argv[1]
args = [arg.replace("macabimacabi", "macabi") for arg in sys.argv[2:]]
os.execv(real, [real, *args])
PY
EOF
chmod +x "$wrapper_dir/clang-macabi-wrapper"

build_maccatalyst() {
    env \
        -u IPHONEOS_DEPLOYMENT_TARGET \
        SDKROOT="$macos_sdk" \
        CC_aarch64_apple_ios_macabi="$wrapper_dir/clang-macabi-wrapper" \
        cargo build --target aarch64-apple-ios-macabi --release

    env \
        -u IPHONEOS_DEPLOYMENT_TARGET \
        SDKROOT="$macos_sdk" \
        CC_x86_64_apple_ios_macabi="$wrapper_dir/clang-macabi-wrapper" \
        cargo build --target x86_64-apple-ios-macabi --release

    mkdir -p ./target/universal-maccatalyst/release

    lipo \
        ./target/x86_64-apple-ios-macabi/release/liblibsql.a \
        ./target/aarch64-apple-ios-macabi/release/liblibsql.a \
        -create -output ./target/universal-maccatalyst/release/liblibsql.a
}

build_maccatalyst

test -f "$xcframework_root/ios-arm64/liblibsql.a"
test -f "$xcframework_root/ios-arm64_x86_64-simulator/liblibsql.a"
test -f "$xcframework_root/macos-arm64_x86_64/liblibsql.a"

cp ./libsql.h "$include_dir/"
cp ../module.modulemap "$include_dir/"

rm -rf "$xcframework_output"

xcodebuild -create-xcframework \
    -library "$xcframework_root/ios-arm64/liblibsql.a" -headers "$include_dir" \
    -library "$xcframework_root/ios-arm64_x86_64-simulator/liblibsql.a" -headers "$include_dir" \
    -library "$xcframework_root/macos-arm64_x86_64/liblibsql.a" -headers "$include_dir" \
    -library ./target/universal-maccatalyst/release/liblibsql.a -headers "$include_dir" \
    -output "$xcframework_output"

rm -rf "$xcframework_root"
mv "$xcframework_output" "$xcframework_root"
