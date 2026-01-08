#!/bin/bash

set -euo pipefail

TOP_MODULE="${1:-}"

if [ -z "$TOP_MODULE" ]; then
    echo "Error: Debes especificar el nombre del módulo top como argumento."
    exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Simulando módulo top: $TOP_MODULE"

rm -rf "$ROOT_DIR/questasim"
mkdir -p "$ROOT_DIR/questasim"

vsim -do "set top_simu $TOP_MODULE; source $ROOT_DIR/tools/run_sim.tcl"