#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RUST_DIR="$PROJECT_DIR/rust"
NATIVE_DIR="$PROJECT_DIR/native"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Building sr25519 Rust library${NC}"

# Detect platform
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    PLATFORM="linux"
    EXT="so"
    LIBNAME="libsr25519.so"
    TARGET="x86_64-unknown-linux-gnu"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    PLATFORM="macos"
    LIBNAME="libsr25519.dylib"
    # Build universal binary for macOS (Intel + Apple Silicon)
    echo -e "${YELLOW}Building for macOS (universal binary)${NC}"
    cd "$RUST_DIR"

    cargo build --release --target x86_64-apple-darwin
    cargo build --release --target aarch64-apple-darwin

    mkdir -p "$NATIVE_DIR/$PLATFORM"
    lipo -create \
        "target/x86_64-apple-darwin/release/$LIBNAME" \
        "target/aarch64-apple-darwin/release/$LIBNAME" \
        -output "$NATIVE_DIR/$PLATFORM/$LIBNAME"

    echo -e "${GREEN}Build complete: $NATIVE_DIR/$PLATFORM/$LIBNAME${NC}"
    exit 0
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    PLATFORM="windows"
    EXT="dll"
    LIBNAME="sr25519.dll"
    TARGET="x86_64-pc-windows-msvc"
else
    echo -e "${RED}Unsupported platform: $OSTYPE${NC}"
    exit 1
fi

# Build for target platform
echo -e "${YELLOW}Building for $PLATFORM (target: $TARGET)${NC}"
cd "$RUST_DIR"

# Install target if not already installed
rustup target add "$TARGET" 2>/dev/null || true

# Build
cargo build --release --target "$TARGET"

# Copy built library
mkdir -p "$NATIVE_DIR/$PLATFORM"
cp "target/$TARGET/release/$LIBNAME" "$NATIVE_DIR/$PLATFORM/"

echo -e "${GREEN}Build complete: $NATIVE_DIR/$PLATFORM/$LIBNAME${NC}"
