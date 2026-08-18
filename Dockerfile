# RunPod Serverless: ComfyUI 0.30.0 + LeonQ8 ALLinONE MiniMax H3
# Storage strategy: NETWORK VOLUME (/runpod-volume) — models are NOT baked in.
# Build stays ~5 min (no 20GB download), models persist on the volume,
# zero re-download on worker wake.
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
# ------------------------------------------------------------------
COPY handler.py network_volume.py ./

# ------------------------------------------------------------------
# 3. Network volume model-path mapping.
#    Overrides the stock extra_model_paths.yaml which lacks
#    diffusion_models/ and text_encoders/ (both required by H3).
#    ComfyUI then finds models under /runpod-volume/models/...
# ------------------------------------------------------------------
COPY extra_model_paths.yaml /comfyui/extra_model_paths.yaml

# ------------------------------------------------------------------
# 4. Character reference images baked in (small, static)
#    Referenced by workflows as holmes.png / watson.png
# ------------------------------------------------------------------
COPY input/ /comfyui/input/

# ------------------------------------------------------------------
# 5. Verify worker entrypoint present
# ------------------------------------------------------------------
RUN python -c "import ast; ast.parse(open('/handler.py').read()); print('handler.py OK')"
