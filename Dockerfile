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
# 2. Install LeonQ8 ALL-in-One MiniMax H3 node
# ------------------------------------------------------------------
RUN git clone https://github.com/LeonQ8/ComfyUI-ALLinONE-MinimaxH3.git \
    /comfyui/custom_nodes/ComfyUI-ALLinONE-MinimaxH3

# ------------------------------------------------------------------
# 3. Download all 5 MiniMax H3 model files (baked into image)
#    Source: https://huggingface.co/Comfy-Org/MiniMax-H3
# ------------------------------------------------------------------
# Diffusion model (ref2va - reference-to-video weights)
RUN wget -q --show-progress -O /comfyui/models/diffusion_models/minimax_h3_ref2va_pruned_int8_convrot.safetensors \
    "https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/diffusion_models/minimax_h3_ref2va_pruned_int8_convrot.safetensors"

# Text encoder (Qwen3VL 32B)
RUN wget -q --show-progress -O /comfyui/models/text_encoders/qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors \
    "https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/text_encoders/qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors"

# Video VAE
RUN wget -q --show-progress -O /comfyui/models/vae/minimax_h3_video_vae_fp16.safetensors \
    "https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/vae/minimax_h3_video_vae_fp16.safetensors"

# Audio VAE
RUN wget -q --show-progress -O /comfyui/models/vae/minimax_h3_audio_vae_fp32.safetensors \
    "https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/vae/minimax_h3_audio_vae_fp32.safetensors"

# Turbo LoRA (4-step acceleration)
RUN wget -q --show-progress -O /comfyui/models/loras/minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors \
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
