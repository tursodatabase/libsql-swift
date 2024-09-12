#!/usr/bin/env sh

set -xe +f

cd libsql-c

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

rm -rf ../CLibsql.xcframework

include_dir=`mktemp -d`

cp ./libsql.h $include_dir/
cp ../module.modulemap $include_dir/

xcodebuild -create-xcframework \
    -library ./target/universal-ios-sim/release/liblibsql.a -headers $include_dir \
    -library ./target/aarch64-apple-ios/release/liblibsql.a -headers $include_dir \
    -library ./target/universal-macos/release/liblibsql.a -headers $include_dir \
    -output ../CLibsql.xcframework

rm -rf $include_dir
