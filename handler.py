import runpod
from handler_impl import handler

# RunPod serverless entrypoint — kept at the top of handler.py so RunPod's
# GitHub-repo validator can find it (it scans the top of the file).
runpod.serverless.start({"handler": handler})
