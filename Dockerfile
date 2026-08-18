# RunPod Serverless: ComfyUI 0.30+ + LeonQ8 ALLinONE MiniMax H3
# Storage strategy: FULL BAKE-IN — all models in the image (fastest cold start, no volume read).
# LOCKED recipe: official v4 LoRA, 6 steps, 1152x640 (+ optional SeedVR2 2x upscale).
# Build ~10-13 min (well under 30-min limit). HF download is fast on RunPod EU network (~3-5 min for 47GB).
FROM runpod/worker-comfyui:5.8.6-base

# ------------------------------------------------------------------
# 1. Upgrade ComfyUI (native MiniMax H3 + R2V core bug fix)
# ------------------------------------------------------------------
RUN comfy --workspace /comfyui update || true
RUN cd /comfyui && (git fetch origin && git pull origin master || git pull origin main || true) && \
    /opt/venv/bin/pip install -r requirements.txt || true

# ------------------------------------------------------------------
# 2. Install aria2 for fast parallel model download
# ------------------------------------------------------------------
RUN apt-get update -y && apt-get install -y --no-install-recommends aria2 && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------------
# 3. Bake the MiniMax H3 models into the image (Comfy-Org/MiniMax-H3)
#    All 5 official files + official Turbo LoRA. aria2 -x16 -s16 parallel.
# ------------------------------------------------------------------
RUN aria2c -x16 -s16 \
  "https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/diffusion_models/minimax_h3_ref2va_pruned_int8_convrot.safetensors" \
  "https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/diffusion_models/minimax_h3_fl2va_pruned_int8_convrot.safetensors" \
  "https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/text_encoders/qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors" \
  "https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/vae/minimax_h3_video_vae_fp16.safetensors" \
  "https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/vae/minimax_h3_audio_vae_fp32.safetensors" \
  "https://huggingface.co/larryvrh/MiniMax-H3-Turbo-Lora/resolve/main/minimax_h3_turbo_v4_step600_ema.safetensors" \
  --dir=/comfyui/models --continue=true \
  && echo "MODELS_DOWNLOADED"

# ------------------------------------------------------------------
# 4. Bake the SeedVR2 upscale models (DiT + VAE) into the image
#    Source: numz/SeedVR2_comfyUI (the pack's own auto-download repo) - files at repo root
# ------------------------------------------------------------------
RUN mkdir -p /comfyui/models/SEEDVR2 && aria2c -x16 -s16 \
  "https://huggingface.co/numz/SeedVR2_comfyUI/resolve/main/seedvr2_ema_3b_fp8_e4m3fn.safetensors" \
  "https://huggingface.co/Comfy-Org/SeedVR2/resolve/main/vae/ema_vae_fp16.safetensors" \
  --dir=/comfyui/models/SEEDVR2 --continue=true \
  && echo "SEEDVR2_DOWNLOADED"

# ------------------------------------------------------------------
# 5. Install custom node packs (ALLinONE, SeedVR2, vrgamedevgirl)
# ------------------------------------------------------------------
RUN git clone --depth 1 https://github.com/LeonQ8/ComfyUI-ALLinONE-MinimaxH3.git \
    /comfyui/custom_nodes/ComfyUI-ALLinONE-MinimaxH3
RUN git clone --depth 1 https://github.com/Larryvrh/ComfyUI-MiniMax-H3-Turbo.git \
    /comfyui/custom_nodes/ComfyUI-MiniMax-H3-Turbo
RUN git clone --depth 1 https://github.com/numz/ComfyUI-SeedVR2_VideoUpscaler.git \
    /comfyui/custom_nodes/ComfyUI-SeedVR2_VideoUpscaler
RUN git clone --depth 1 https://github.com/vrgamegirl19/comfyui-vrgamedevgirl.git \
    /comfyui/custom_nodes/comfyui-vrgamedevgirl
# Install any node-pack python deps
RUN pip install -r /comfyui/custom_nodes/ComfyUI-SeedVR2_VideoUpscaler/requirements.txt || true
RUN pip install -r /comfyui/custom_nodes/comfyui-vrgamedevgirl/requirements.txt || true

# ------------------------------------------------------------------
# 6. Serverless worker handler (thin entrypoint, logic in handler_impl.py)
# ------------------------------------------------------------------
COPY handler.py handler_impl.py network_volume.py ./

# ------------------------------------------------------------------
# 7. extra_model_paths.yaml — keeps volume models working as fallback;
#    image-baked models are found via default ComfyUI paths.
# ------------------------------------------------------------------
COPY extra_model_paths.yaml /comfyui/extra_model_paths.yaml

# ------------------------------------------------------------------
# 8. Character reference images baked in (small, static)
# ------------------------------------------------------------------
COPY input/ /comfyui/input/

# ------------------------------------------------------------------
# 9. Verify handler + model presence
# ------------------------------------------------------------------
RUN python -c "import ast; ast.parse(open('/handler.py').read()); print('handler.py OK')" \
 && ls -la /comfyui/models/diffusion_models/ /comfyui/models/loras/ | head -20
