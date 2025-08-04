#!/bin/bash
detect_gpu_info() {
    if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
        export DETECTED_VRAM_GB=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1 | awk '{print int($1/1024)}')
        export DETECTED_GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)
    else
        export DETECTED_VRAM_GB=0
        export DETECTED_GPU_NAME="Inconnue"
    fi
}
