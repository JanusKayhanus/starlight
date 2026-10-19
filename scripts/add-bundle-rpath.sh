#!/bin/sh
set -e
binary="$1"
if ! otool -l "$binary" | grep -q '@executable_path/../Frameworks'; then
    install_name_tool -add_rpath '@executable_path/../Frameworks' "$binary"
fi
