FROM pytorch/pytorch:2.5.1-cuda12.4-cudnn9-runtime

USER root

# Install system dependencies including git
RUN apt-get update -qq && \
    apt-get install -y -qq --no-install-recommends \
        libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 \
        git build-essential libportaudio2 ffmpeg && \
    rm -rf /var/lib/apt/lists/*

# Create user and clone ComfyUI
RUN groupadd -r comfygroup && useradd -r -g comfygroup -m comfyuser
RUN git clone https://github.com/comfyanonymous/ComfyUI /app
WORKDIR /app
RUN chown -R comfyuser:comfygroup /app

# Patch ComfyUI
RUN sed -i 's/weights_only=True/weights_only=False/g' /app/comfy/utils.py

# Install PyTorch and dependencies first
RUN pip install --upgrade pip wheel setuptools

# Install requirements.txt first (with generic versions)
RUN pip install -r requirements.txt

# FORCE install our specific versions (override requirements.txt)
RUN pip install --force-reinstall torch==2.5.1+cu124 torchvision==0.20.1+cu124 torchaudio==2.5.1+cu124 --extra-index-url https://download.pytorch.org/whl/cu124
RUN pip install --force-reinstall numpy==1.26.4
RUN pip install xformers==0.0.28.post3 pytorch-lightning==2.5.2 torchmetrics==1.7.4 torchsde==0.2.6 triton==3.1.0 torchelastic==0.2.2

# Install ComfyUI packages
RUN pip install comfyui_frontend_package==1.23.4

# Install additional dependencies
RUN pip install dlib-bin opencv-python-headless librosa scikit-image basicsr facexlib gfpgan imageio-ffmpeg dill onnxruntime pykalman GitPython omegaconf ultralytics insightface einx toml rich sounddevice

# Create directories and set proper permissions (including CUDA cache)
RUN mkdir -p /app/user /app/temp /app/output /app/input /app/models /app/custom_nodes /tmp/cuda-cache && \
    chmod 777 /tmp/cuda-cache && \
    chown -R comfyuser:comfygroup /app

USER comfyuser
WORKDIR /app

# Configuration GPU/CPU adaptative et git environment
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility
ENV CUDA_CACHE_PATH=/tmp/cuda-cache
ENV GIT_PYTHON_REFRESH=quiet
ENV PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:128

CMD ["python","main.py","--listen","0.0.0.0","--port","8188"]