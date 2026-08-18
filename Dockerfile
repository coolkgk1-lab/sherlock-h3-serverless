# RunPod Serverless: ComfyUI 0.30.0 + LeonQ8 ALLinONE MiniMax H3
# Built from the official worker-comfyui base image (5.8.7)
FROM runpod/worker-comfyui:5.8.7-base

# ------------------------------------------------------------------
# 1. Upgrade ComfyUI to >= 0.30.0 (required for native MiniMax H3 nodes)
# ------------------------------------------------------------------
RUN comfy --workspace /comfyui update || true
RUN cd /comfyui && git fetch origin && git pull origin master && \
    /opt/venv/bin/pip install -r requirements.txt

# ------------------------------------------------------------------
# 2. Install LeonQ8 All-in-One MiniMax H3 node
# ------------------------------------------------------------------
RUN git clone https://github.com/LeonQ8/ComfyUI-ALLinONE-MinimaxH3.git \
    /comfyui/custom_nodes/ComfyUI-ALLinONE-MinimaxH3

# ------------------------------------------------------------------
# 2b. Serverless worker handler (required by RunPod GitHub integration)
#     Ensures the repo contains the runpod.serverless.start() entrypoint.
# ------------------------------------------------------------------
COPY handler.py network_volume.py ./

# ------------------------------------------------------------------
# 3. Download all 5 MiniMax H3 model files (baked into image)
#    aria2 multi-connection download = fastest build, models NEVER
#    re-download on worker wake (storage strategy: bake-in).
#    Source: https://huggingface.co/Comfy-Org/MiniMax-H3
# ------------------------------------------------------------------
RUN apt-get update && apt-get install -y aria2 && rm -rf /var/lib/apt/lists/*

# Helper: 16 parallel connections per file
RUN echo 'alias h3dl="aria2c -x 16 -s 16 --console-log-level=error"' >> /root/.bashrc

# Diffusion model (ref2va - reference-to-video weights)
RUN aria2c -x 16 -s 16 --console-log-level=error \
    -d /comfyui/models/diffusion_models \
    -o minimax_h3_ref2va_pruned_int8_convrot.safetensors \
    "https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/diffusion_models/minimax_h3_ref2va_pruned_int8_convrot.safetensors"

# Text encoder (Qwen3VL 32B)
RUN aria2c -x 16 -s 16 --console-log-level=error \
    -d /comfyui/models/text_encoders \
    -o qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors \
    "https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/text_encoders/qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors"

# Video VAE
RUN aria2c -x 16 -s 16 --console-log-level=error \
    -d /comfyui/models/vae \
    -o minimax_h3_video_vae_fp16.safetensors \
    "https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/vae/minimax_h3_video_vae_fp16.safetensors"

# Audio VAE
RUN aria2c -x 16 -s 16 --console-log-level=error \
    -d /comfyui/models/vae \
    -o minimax_h3_audio_vae_fp32.safetensors \
    "https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/vae/minimax_h3_audio_vae_fp32.safetensors"

# Turbo LoRA (4-step acceleration)
RUN aria2c -x 16 -s 16 --console-log-level=error \
    -d /comfyui/models/loras \
    -o minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors \
    "https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/loras/minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors"

# ------------------------------------------------------------------
# 4. Bake character reference images into the image
#    Referenced by workflows as holmes.png / watson.png
# ------------------------------------------------------------------
COPY input/ /comfyui/input/

# ------------------------------------------------------------------
# 5. Sanity check: verify model files exist and sizes
# ------------------------------------------------------------------
RUN ls -la /comfyui/models/diffusion_models/ /comfyui/models/text_encoders/ \
          /comfyui/models/vae/ /comfyui/models/loras/
