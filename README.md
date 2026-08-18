# Sherlock H3 Serverless

RunPod Serverless endpoint running **ComfyUI 0.30.0** + **LeonQ8 ALL-in-One MiniMax H3** for reference-to-video generation with native audio.

## Cost model

- **Active Workers: 0** — pay only when a generation request is running
- **Idle Timeout: 5s** — worker shuts down 5 seconds after each job
- Estimated film cost (300 × 15s clips): **$10-15**

## Deploy

1. Connect this repo to RunPod:
   - RunPod Console → **Serverless** → **New Endpoint** → **"Start from GitHub Repo"**
2. Select repo `coolkgk1-lab/sherlock-h3-serverless`, branch `main`
3. Dockerfile Path: `Dockerfile`
4. GPU: **RTX PRO 4500 (32GB)**
5. Workers: Active `0`, Max `3`, Idle Timeout `5s`
6. Deploy → get Endpoint ID

## Call the endpoint — dynamic references

The worker accepts **per-request reference images** (base64) — no need to bake them into the image. Any script can send its own refs.

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

**How it works:**
1. The `images` list is uploaded to ComfyUI's `/upload/image` before the workflow runs
2. The workflow's `LoadImage` nodes (`"1"` and `"2"`) reference them by name
3. `MiniMaxH3ReferenceToVideo` receives them via `ref_images`
4. The response contains the generated MP4 as base64

**For per-shot character refs** (different characters per clip): swap the `name` + base64 per request, and the workflow automatically picks up the new images.

## Files

| File | Purpose |
|---|---|
| `Dockerfile` | Builds ComfyUI 0.30.0 + LeonQ8 node + all 5 H3 models |
| `workflows/r2v_template.json` | Reference-to-video workflow (API format), `__PROMPT__` placeholder |
| `input/` | Put character reference images here (baked into image) |
