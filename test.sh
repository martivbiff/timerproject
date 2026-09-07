#!/bin/bash
# Timing, clamping and bell-envelope checks. Runs headless; plays no audio.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build
swiftc -O -o build/checks Sources/Model.swift Tools/Checks/main.swift
build/checks
