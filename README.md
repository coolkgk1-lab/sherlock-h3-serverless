# Sherlock H3 Serverless

RunPod Serverless endpoint running **ComfyUI 0.30.0** + **LeonQ8 ALL-in-One MiniMax H3** for reference-to-video generation with native audio.

## Storage strategy: Network Volume

The 20GB of H3 models live on a **RunPod Network Volume** mounted at `/runpod-volume` — **not** baked into the image.

- Image build stays **~5 min** (no 20GB download in Docker — avoids the 30-min build limit)
- Models download **once** into the volume; **zero re-download** on worker wake
- `extra_model_paths.yaml` maps `/runpod-volume/models/...` into ComfyUI (incl. `diffusion_models/` and `text_encoders/` which H3 needs)

## Cost model

- **Active Workers: 0** — pay only while a generation is running
- **Idle Timeout: 5s** — worker shuts down 5s after each job
- Estimated film cost (300 × 15s clips): **$10-15** + volume storage (~$0.07/GB/mo)

## Deploy

### 1. Create the Network Volume (RunPod console)

1. RunPod → **Storage** → **Network Volumes** → **New Volume**
2. Name: `sherlock-h3-models`
3. **Region: EU-RO-1** (must match your endpoint's GPU region)
4. Size: **40 GB** (models ≈ 20GB, leaves headroom)
5. Create

### 2. Copy models from your existing pod to the volume

Mount the volume to your existing pod (Edit pod → Network Volume → select it), then in the pod terminal:

```bash
# Copy the 5 H3 models into the volume's model directories
mkdir -p /runpod-volume/models/{diffusion_models,text_encoders,vae,loras}
cp /workspace/runpod-slim/ComfyUI/models/diffusion_models/minimax_h3_ref2va_pruned_int8_convrot.safetensors /runpod-volume/models/diffusion_models/
cp /workspace/runpod-slim/ComfyUI/models/text_encoders/qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors /runpod-volume/models/text_encoders/
cp /workspace/runpod-slim/ComfyUI/models/vae/minimax_h3_video_vae_fp16.safetensors /runpod-volume/models/vae/
cp /workspace/runpod-slim/ComfyUI/models/vae/minimax_h3_audio_vae_fp32.safetensors /runpod-volume/models/vae/
cp /workspace/runpod-slim/ComfyUI/models/loras/minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors /runpod-volume/models/loras/

# Verify sizes (should be ~20GB total)
du -sh /runpod-volume/models/
```

### 3. Deploy the endpoint from GitHub

1. RunPod → **Serverless** → **New Endpoint** → **"Start from GitHub Repo"**
2. Repo: `coolkgk1-lab/sherlock-h3-serverless`, branch `main`, Dockerfile: `Dockerfile`
3. GPU: **RTX PRO 4500 (32GB)**, GPUs/worker: `1`
4. Active Workers: `0`, Max Workers: `3`, Idle Timeout: `5s`
5. Container Disk: **20 GB** (image is small now)
6. **Advanced → Select Network Volume: `sherlock-h3-models`**
7. Deploy. Build ~5 min. Wait for **Ready** → copy Endpoint ID

## Call the endpoint — dynamic references

```bash
curl -X POST \
  -H "Authorization: Bearer <RUNPOD_API_KEY>" \
  -H "Content-Type: application/json" \
  -d '{
    "input": {
      "workflow": <workflow-json-from-workflows/r2v_template.json with __PROMPT__ replaced>,
      "images": [
        {"name": "holmes.png", "image": "data:image/png;base64,<BASE64_1>"},
        {"name": "watson.png", "image": "data:image/png;base64,<BASE64_2>"}
      ]
    }
  }' \
  https://api.runpod.ai/v2/<ENDPOINT_ID>/runsync
```

The `images` list is uploaded to ComfyUI before the workflow runs; `LoadImage` nodes (1, 2) pick them up by name and feed `MiniMaxH3ReferenceToVideo` via `ref_images`. Response contains the MP4 as base64.

## Files

| File | Purpose |
|---|---|
| `Dockerfile` | ComfyUI 0.30.0 + LeonQ8 node + handler (no models — they're on the volume) |
| `handler.py` | RunPod serverless worker entrypoint (`runpod.serverless.start`) |
| `network_volume.py` | Volume diagnostics helper (used by handler) |
| `extra_model_paths.yaml` | Maps `/runpod-volume/models/...` into ComfyUI (adds diffusion_models + text_encoders) |
| `workflows/r2v_template.json` | Reference-to-video workflow (API format), `__PROMPT__` placeholder |
| `input/` | Character reference images (baked into image) |
