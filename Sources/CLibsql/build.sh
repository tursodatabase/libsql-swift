#!/usr/bin/env sh

set -xe +f

export MACOSX_DEPLOYMENT_TARGET=10.13

cargo build --target aarch64-apple-ios --release

cargo build --target x86_64-apple-ios --release
cargo build --target aarch64-apple-ios-sim --release

mkdir -p ./target/universal-ios-sim/release

lipo \
    ./target/x86_64-apple-ios/release/liblibsql.a \
    ./target/aarch64-apple-ios-sim/release/liblibsql.a \
    -create -output ./target/universal-ios-sim/release/liblibsql.a

cargo build --target aarch64-apple-darwin --release
cargo build --target x86_64-apple-darwin --release

mkdir -p ./target/universal-macos/release

lipo \
    ./target/x86_64-apple-darwin/release/liblibsql.a \
    ./target/aarch64-apple-darwin/release/liblibsql.a \
    -create -output ./target/universal-macos/release/liblibsql.a

rm -rf CLibsql.xcframework

xcodebuild -create-xcframework \
    -library ./target/universal-ios-sim/release/liblibsql.a -headers ./include \
    -library ./target/aarch64-apple-ios/release/liblibsql.a -headers ./include \
    -library ./target/universal-macos/release/liblibsql.a -headers ./include \
    -output CLibsql.xcframework
