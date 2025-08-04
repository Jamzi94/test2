#!/bin/bash
# Script de correction automatique des custom nodes ComfyUI

echo "🔧 Application des corrections custom nodes..."

# Correction MultiTalk - import wan
if [ -f /app/custom_nodes/MultiTalk/generate_multitalk.py ]; then
    echo "Correction des imports MultiTalk..."
    sed -i 's/^import wan$/from . import wan/' /app/custom_nodes/MultiTalk/generate_multitalk.py
    sed -i 's/^from wan\.configs/from .wan.configs/' /app/custom_nodes/MultiTalk/generate_multitalk.py
fi

# Suppression des doublons WAS Node Suite
if [ -d /app/custom_nodes/was-node-suite-comfyui ]; then
    echo "Suppression doublon was-node-suite-comfyui..."
    rm -rf /app/custom_nodes/was-node-suite-comfyui
fi

# Création répertoires manquants
mkdir -p /app/models/animatediff_models
mkdir -p /app/custom_nodes/animatediff-evolved/models
mkdir -p /app/custom_nodes/ComfyUI-AnimateDiff-Evolved/models

echo "✅ Corrections custom nodes appliquées"