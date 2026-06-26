#!/bin/bash
# =============================================================================
#  BGE-M3 Fine-Tuning — Full Pipeline
#  Usage: bash setup_and_run.sh r4
#  Requires env vars: HF_TOKEN, RUNPOD_API_KEY
# =============================================================================
set -euo pipefail

RN="${1:-r4}"
HF_USER="keisuke-miyako"
HF_DATASET="${HF_USER}/bge-m3-lemur-${RN}"
ADAPTER_REPO="${HF_USER}/bge-m3-lemur-${RN}-adapter"
MERGED_REPO="${HF_USER}/bge-m3-lemur-${RN}-merged"
GGUF_REPO="${HF_USER}/bge-m3-lemur-${RN}-gguf"
CKPT_REPO="${HF_USER}/bge-m3-lemur-${RN}-checkpoints"

WORK_DIR="/workspace/bge_m3/${RN}"
ADAPTER_DIR="${WORK_DIR}/adapter"
MERGED_DIR="${WORK_DIR}/merged"
GGUF_DIR="${WORK_DIR}/gguf"
CKPT_DIR="${WORK_DIR}/checkpoints"
LOG_FILE="/workspace/train_${RN}.log"

HF_TOKEN="${HF_TOKEN:?ERROR: set HF_TOKEN env var}"
RUNPOD_API_KEY="${RUNPOD_API_KEY:?ERROR: set RUNPOD_API_KEY env var}"

mkdir -p "$ADAPTER_DIR" "$MERGED_DIR" "$GGUF_DIR" "$CKPT_DIR"

echo "========================================================"
echo "  Run: $RN"
echo "  Adapter : $ADAPTER_REPO"
echo "  Merged  : $MERGED_REPO"
echo "  GGUF    : $GGUF_REPO"
echo "  Ckpts   : $CKPT_REPO"
echo "========================================================"

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 1 — CUDA-safe torch setup
# Strategy: check if CUDA already works → if yes, touch nothing.
#           Only install if broken. Pin exact version. Verify after.
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== [1/8] Checking PyTorch + CUDA ==="

CUDA_OK=$(python -c "import torch; print(int(torch.cuda.is_available()))" 2>/dev/null || echo "0")
GPU_COUNT=$(python -c "import torch; print(torch.cuda.device_count())" 2>/dev/null || echo "0")

if [ "$CUDA_OK" = "1" ] && [ "$GPU_COUNT" -ge "1" ]; then
    TORCH_VER=$(python -c "import torch; print(torch.__version__)")
    GPU_NAME=$(python -c "import torch; print(torch.cuda.get_device_name(0))")
    BF16=$(python -c "import torch; print(torch.cuda.is_bf16_supported())")
    echo "✓ torch $TORCH_VER | $GPU_COUNT GPU(s) | $GPU_NAME | bf16=$BF16"
    echo "  CUDA already working — skipping torch reinstall"
else
    echo "✗ CUDA not working — detecting driver and installing torch"

    # Detect CUDA version from driver
    CUDA_VER=$(nvidia-smi 2>/dev/null \
        | grep -oP "CUDA Version: \K[0-9]+\.[0-9]+" \
        | head -1 \
        || echo "12.4")
    CUDA_MAJOR=$(echo "$CUDA_VER" | cut -d. -f1)
    echo "  Driver CUDA: $CUDA_VER"

    # Safe wheel mapping: cu124 covers all CUDA 12.x (forward-compatible)
    # cu118 for CUDA 11.x; cu124 as default for unknown
    if   [ "$CUDA_MAJOR" = "12" ]; then WHEEL="cu124"; PIN="2.4.1+cu124"
    elif [ "$CUDA_MAJOR" = "11" ]; then WHEEL="cu118"; PIN="2.4.1+cu118"
    else
        echo "  Unknown CUDA major '$CUDA_MAJOR', defaulting to cu124"
        WHEEL="cu124"; PIN="2.4.1+cu124"
    fi

    echo "  Installing torch==$PIN from $WHEEL ..."
    pip install "torch==${PIN}" \
        --index-url "https://download.pytorch.org/whl/${WHEEL}" \
        --force-reinstall --no-cache-dir --quiet

    python -c "
import torch, sys
print(f'  torch {torch.__version__}  cuda={torch.cuda.is_available()}  gpus={torch.cuda.device_count()}')
if not torch.cuda.is_available():
    print('ERROR: CUDA still not available after reinstall')
    sys.exit(1)
print(f'  GPU 0: {torch.cuda.get_device_name(0)}  bf16={torch.cuda.is_bf16_supported()}')
print('✓ torch CUDA working')
"
fi

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 2 — Install packages WITHOUT touching torch
# Trick: write current torch version to a constraint file so pip cannot
# downgrade, upgrade, or replace it while installing other packages.
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== [2/8] Installing packages (torch-locked) ==="

TORCH_INSTALLED=$(python -c "import torch; print(torch.__version__)")
echo "torch==${TORCH_INSTALLED}" > /tmp/torch_pin.txt
echo "  Constraint: torch==${TORCH_INSTALLED}"

pip install \
    "sentence-transformers>=3.3.0,<4.0" \
    "datasets>=2.20" \
    "peft>=0.13,<0.15" \
    "transformers==4.46.3" \
    "accelerate>=0.34" \
    "huggingface_hub>=0.24" \
    "matplotlib" \
    --constraint /tmp/torch_pin.txt \
    --no-cache-dir --quiet

# Hard verify torch CUDA survived package installation
python -c "
import torch, sys
if not torch.cuda.is_available():
    print('FATAL: pip install broke torch CUDA')
    sys.exit(1)
print(f'✓ torch {torch.__version__} CUDA intact after package install')
"

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 3 — llama.cpp (for GGUF export)
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== [3/8] llama.cpp ==="

if [ ! -d "/workspace/llama.cpp" ]; then
    git clone --depth=1 https://github.com/ggerganov/llama.cpp /workspace/llama.cpp
    echo "  Cloned llama.cpp"
else
    echo "  llama.cpp already exists"
fi

# Install ONLY what convert_hf_to_gguf.py needs — never install llama.cpp's
# full requirements.txt because it contains a torch line that fights the pin.
# The converter needs: gguf, sentencepiece, protobuf, numpy — no torch.
pip install "gguf>=0.10" "sentencepiece" "protobuf" \
    --no-cache-dir --quiet

# Verify torch CUDA is still intact
python -c "
import torch, sys
if not torch.cuda.is_available():
    print('FATAL: gguf/sentencepiece install broke torch CUDA')
    sys.exit(1)
print(f'✓ torch {torch.__version__} CUDA intact after llama.cpp deps install')
"

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 4 — Authentication
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== [4/8] Authentication ==="

python -c "
from huggingface_hub import login, HfApi
login(token='${HF_TOKEN}', add_to_git_credential=False)
print('✓ HuggingFace login OK')

api = HfApi(token='${HF_TOKEN}')
repos = ['${ADAPTER_REPO}', '${MERGED_REPO}', '${GGUF_REPO}', '${CKPT_REPO}']
for repo in repos:
    api.create_repo(repo_id=repo, repo_type='model', exist_ok=True, private=False)
    print(f'  repo ready: {repo}')
"

# runpodctl
if ! command -v runpodctl &>/dev/null; then
    echo "  Installing runpodctl..."
    wget -q "https://github.com/runpod/runpodctl/releases/latest/download/runpodctl-linux-amd64" \
         -O /usr/local/bin/runpodctl
    chmod +x /usr/local/bin/runpodctl
fi
runpodctl config --apiKey "${RUNPOD_API_KEY}" 2>/dev/null || true
POD_ID="${RUNPOD_POD_ID:-$(hostname)}"
echo "  Pod ID: $POD_ID"

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 5 — Training
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== [5/8] Training ==="

export NCCL_P2P_DISABLE=1        # Required for PCIe topology (no NVLink)
export NCCL_IB_DISABLE=1
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True,max_split_size_mb:512

NUM_GPUS=$(python -c "import torch; print(torch.cuda.device_count())")
echo "  GPUs: $NUM_GPUS"

torchrun \
    --nproc_per_node="${NUM_GPUS}" \
    --master_addr=localhost \
    --master_port=29500 \
    /workspace/train.py \
        "${RN}" \
        "${WORK_DIR}" \
        "${CKPT_REPO}" \
        "${HF_DATASET}" \
    2>&1 | tee "$LOG_FILE"

echo "✓ Training complete"

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 5b — Plot training loss (reads from HF if local checkpoints missing)
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== [5b/8] Plot training loss ==="

cat > /tmp/plot_loss.py << 'EOF'
import json
import os
import re
import csv
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from huggingface_hub import list_repo_files, hf_hub_download

HF_TOKEN    = os.environ["HF_TOKEN"]
CKPT_REPO   = os.environ["CKPT_REPO"]
RN          = os.environ["RN"]
ADAPTER_DIR = os.environ["ADAPTER_DIR"]
CKPT_DIR    = os.environ["CKPT_DIR"]

# --- Try local first, fall back to HF ---
local_state = os.path.join(ADAPTER_DIR, "trainer_state.json")

if os.path.exists(local_state):
    print(f"Using local trainer_state.json: {local_state}")
    state_file = local_state
else:
    # Try local checkpoints
    import glob
    local_ckpts = sorted(
        glob.glob(os.path.join(CKPT_DIR, "checkpoint-*")),
        key=lambda p: int(p.split("-")[-1])
    )
    if local_ckpts:
        state_file = os.path.join(local_ckpts[-1], "trainer_state.json")
        print(f"Using local checkpoint: {state_file}")
    else:
        # Fall back to HuggingFace
        print(f"No local checkpoints found — fetching from HF: {CKPT_REPO}")
        all_files = list(list_repo_files(CKPT_REPO, token=HF_TOKEN))
        state_files = [f for f in all_files if f.endswith("trainer_state.json")]
        if not state_files:
            raise FileNotFoundError(f"No trainer_state.json found in repo: {CKPT_REPO}")
        def checkpoint_num(path):
            m = re.search(r'checkpoint-(\d+)', path)
            return int(m.group(1)) if m else -1
        state_files.sort(key=checkpoint_num)
        latest = state_files[-1]
        print(f"Using HF file: {latest}")
        state_file = hf_hub_download(
            repo_id=CKPT_REPO,
            filename=latest,
            token=HF_TOKEN,
            repo_type="model",
        )

# --- Load ---
with open(state_file) as f:
    state = json.load(f)

log    = [e for e in state["log_history"] if "loss" in e]
steps  = [e["step"]  for e in log]
losses = [e["loss"]  for e in log]

if not log:
    raise ValueError("No loss entries found in trainer_state.json")

print(f"Found {len(log)} loss entries, steps {steps[0]} to {steps[-1]}")

os.makedirs(ADAPTER_DIR, exist_ok=True)

# --- CSV ---
csv_path = os.path.join(ADAPTER_DIR, "training-loss.csv")
with open(csv_path, "w", newline="") as f:
    writer = csv.writer(f)
    writer.writerow(["step", "loss"])
    writer.writerows(zip(steps, losses))
print(f"CSV  saved -> {csv_path}")

# --- Plot ---
plt.figure(figsize=(10, 5))
plt.plot(steps, losses, marker="o", markersize=2, linewidth=1.5)
plt.title(f"bge-m3-lemur-lora {RN} — Training Loss")
plt.xlabel("Step")
plt.ylabel("Loss")
plt.grid(True)
plt.tight_layout()

png_path = os.path.join(ADAPTER_DIR, "training-loss.png")
plt.savefig(png_path, dpi=150)
print(f"Chart saved -> {png_path}")
EOF

export RN CKPT_REPO ADAPTER_DIR CKPT_DIR HF_TOKEN
python3 /tmp/plot_loss.py

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 5c — Plot eval loss (mirrors 5b; reads eval_loss from log_history)
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== [5c/8] Plot eval loss ==="

cat > /tmp/plot_eval_loss.py << 'EOF'
import json
import os
import re
import csv
import glob
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from huggingface_hub import list_repo_files, hf_hub_download

HF_TOKEN    = os.environ["HF_TOKEN"]
CKPT_REPO   = os.environ["CKPT_REPO"]
RN          = os.environ["RN"]
ADAPTER_DIR = os.environ["ADAPTER_DIR"]
CKPT_DIR    = os.environ["CKPT_DIR"]

# --- Try local first, fall back to HF (identical strategy to plot_loss.py) ---
local_state = os.path.join(ADAPTER_DIR, "trainer_state.json")

if os.path.exists(local_state):
    print(f"Using local trainer_state.json: {local_state}")
    state_file = local_state
else:
    local_ckpts = sorted(
        glob.glob(os.path.join(CKPT_DIR, "checkpoint-*")),
        key=lambda p: int(p.split("-")[-1])
    )
    if local_ckpts:
        state_file = os.path.join(local_ckpts[-1], "trainer_state.json")
        print(f"Using local checkpoint: {state_file}")
    else:
        print(f"No local checkpoints found — fetching from HF: {CKPT_REPO}")
        all_files = list(list_repo_files(CKPT_REPO, token=HF_TOKEN))
        state_files = [f for f in all_files if f.endswith("trainer_state.json")]
        if not state_files:
            raise FileNotFoundError(f"No trainer_state.json found in repo: {CKPT_REPO}")
        def checkpoint_num(path):
            m = re.search(r'checkpoint-(\d+)', path)
            return int(m.group(1)) if m else -1
        state_files.sort(key=checkpoint_num)
        latest = state_files[-1]
        print(f"Using HF file: {latest}")
        state_file = hf_hub_download(
            repo_id=CKPT_REPO,
            filename=latest,
            token=HF_TOKEN,
            repo_type="model",
        )

# --- Load ---
with open(state_file) as f:
    state = json.load(f)

# eval entries carry "eval_loss" but not "loss"
eval_log = [e for e in state["log_history"] if "eval_loss" in e]

if not eval_log:
    print("WARNING: No eval_loss entries found in trainer_state.json — skipping eval chart.")
    print("This is expected if eval_strategy was not set or training was interrupted early.")
    raise SystemExit(0)

steps  = [e["step"]       for e in eval_log]
losses = [e["eval_loss"]  for e in eval_log]

print(f"Found {len(eval_log)} eval entries, steps {steps[0]} to {steps[-1]}")

os.makedirs(ADAPTER_DIR, exist_ok=True)

# --- CSV ---
csv_path = os.path.join(ADAPTER_DIR, "eval-loss.csv")
with open(csv_path, "w", newline="") as f:
    writer = csv.writer(f)
    writer.writerow(["step", "eval_loss"])
    writer.writerows(zip(steps, losses))
print(f"CSV  saved -> {csv_path}")

# --- Eval loss plot ---
plt.figure(figsize=(10, 5))
plt.plot(steps, losses, marker="o", markersize=3, linewidth=1.5, color="darkorange")
plt.title(f"bge-m3-lemur-lora {RN} — Eval Loss")
plt.xlabel("Step")
plt.ylabel("Eval Loss")
plt.grid(True)
plt.tight_layout()

png_path = os.path.join(ADAPTER_DIR, "eval-loss.png")
plt.savefig(png_path, dpi=150)
print(f"Chart saved -> {png_path}")

# --- Combined train + eval plot ---
train_csv_path = os.path.join(ADAPTER_DIR, "training-loss.csv")
if os.path.exists(train_csv_path):
    import csv as csv_mod
    train_steps, train_losses = [], []
    with open(train_csv_path) as f:
        reader = csv_mod.DictReader(f)
        for row in reader:
            train_steps.append(int(row["step"]))
            train_losses.append(float(row["loss"]))

    fig, ax = plt.subplots(figsize=(10, 5))
    ax.plot(train_steps, train_losses, marker="o", markersize=2, linewidth=1.5,
            label="Train loss", color="steelblue")
    ax.plot(steps, losses, marker="o", markersize=3, linewidth=1.5,
            label="Eval loss", color="darkorange")
    ax.set_title(f"bge-m3-lemur-lora {RN} — Train vs Eval Loss")
    ax.set_xlabel("Step")
    ax.set_ylabel("Loss")
    ax.legend()
    ax.grid(True)
    fig.tight_layout()
    combined_path = os.path.join(ADAPTER_DIR, "train-vs-eval-loss.png")
    fig.savefig(combined_path, dpi=150)
    print(f"Combined chart saved -> {combined_path}")
else:
    print("training-loss.csv not found — skipping combined chart")
EOF

export RN CKPT_REPO ADAPTER_DIR CKPT_DIR HF_TOKEN
python3 /tmp/plot_eval_loss.py

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 6 — Merge LoRA + GGUF export
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== [6/8] Merge LoRA ==="

python - <<PYEOF
import torch, os, sys
from transformers import AutoModel, AutoTokenizer
from peft import PeftModel

adapter = "${ADAPTER_DIR}"
merged  = "${MERGED_DIR}"
BASE_MODEL = "${HF_USER}/bge-m3-lemur-r6-merged"
print(f"Loading base {BASE_MODEL} ...")
tokenizer = AutoTokenizer.from_pretrained(BASE_MODEL)
base = AutoModel.from_pretrained(BASE_MODEL, torch_dtype=torch.bfloat16)

# Sanity: record a weight before merge
ref_w = base.encoder.layer[0].attention.self.query.weight.detach().clone()

print(f"Merging LoRA from {adapter} ...")
peft_model = PeftModel.from_pretrained(base, adapter)
merged_model = peft_model.merge_and_unload()

# Verify weights actually changed
diff = (ref_w - merged_model.encoder.layer[0].attention.self.query.weight).abs().max().item()
print(f"Max weight delta (query layer 0): {diff:.8f}")
if diff == 0.0:
    print("WARNING: weights unchanged — merge may have failed")
    sys.exit(1)

merged_model.save_pretrained(merged, safe_serialization=True)
tokenizer.save_pretrained(merged)

# BGE-M3 needs sentencepiece file for GGUF conversion
from huggingface_hub import hf_hub_download
import shutil
for fn in ["tokenizer.json", "tokenizer_config.json", "sentencepiece.bpe.model"]:
    try:
        src = hf_hub_download(repo_id=BASE_MODEL, filename=fn)
        shutil.copy(src, os.path.join(merged, fn))
    except Exception:
        pass  # may already be present from tokenizer.save_pretrained

# Copy sentence-transformers config files from base so next round loads
# with correct CLS pooling instead of falling back to mean pooling
import json
for fn in ["sentence_bert_config.json", "1_Pooling/config.json"]:
    try:
        src = hf_hub_download(repo_id="BAAI/bge-m3", filename=fn)
        dest = os.path.join(merged, fn)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        shutil.copy(src, dest)
        print(f"  ✓ copied {fn}")
    except Exception as e:
        print(f"  WARNING: could not copy {fn}: {e}")

print(f"✓ Merged model saved to {merged}")
PYEOF

echo ""
echo "=== [7/8] GGUF export ==="

GGUF_PATH="${GGUF_DIR}/bge-m3-lemur-${RN}-q8_0.gguf"
python /workspace/llama.cpp/convert_hf_to_gguf.py \
    "${MERGED_DIR}" \
    --outtype q8_0 \
    --outfile "${GGUF_PATH}"

SIZE_MB=$(python -c "import os; print(round(os.path.getsize('${GGUF_PATH}')/1e6))")
echo "✓ GGUF saved: ${GGUF_PATH} (${SIZE_MB} MB)"

# Create a model card for the GGUF repo
cat > "${GGUF_DIR}/README.md" <<EOF
---
base_model: ${HF_USER}/bge-m3-lemur-${RN}-merged
tags:
  - lemur
  - embeddings
  - gguf
  - bge-m3
---
# bge-m3-lemur-${RN} (GGUF q8_0)

Fine-tuned on LEMUR dataset.
Dataset: [${HF_DATASET}](https://huggingface.co/datasets/${HF_DATASET})

## Usage (llama.cpp)
\`\`\`bash
./llama-embedding -m bge-m3-lemur-${RN}-q8_0.gguf --prompt "your query"
\`\`\`
EOF

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 7 — Upload everything to HuggingFace
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== [8/8] Uploading to HuggingFace ==="

python - <<PYEOF
import sys
from huggingface_hub import HfApi

api   = HfApi(token="${HF_TOKEN}")
RN    = "${RN}"
base  = "${WORK_DIR}"
jobs  = [
    ("${ADAPTER_REPO}",  f"{base}/adapter",      "LoRA adapter"),
    ("${MERGED_REPO}",   f"{base}/merged",        "Merged model"),
    ("${GGUF_REPO}",     f"{base}/gguf",          "GGUF q8_0"),
    ("${CKPT_REPO}",     f"{base}/checkpoints",   "Training checkpoints"),
]

failed = []
for repo_id, folder, label in jobs:
    print(f"  Uploading {label} → {repo_id}")
    try:
        api.upload_folder(
            folder_path=folder,
            repo_id=repo_id,
            repo_type="model",
            commit_message=f"{RN} upload — {label}",
            ignore_patterns=["*.lock", "__pycache__/*"],
        )
        print(f"  ✓ {repo_id}")
    except Exception as e:
        print(f"  ✗ {repo_id}: {e}")
        failed.append(repo_id)

if failed:
    print(f"\nFAILED repos: {failed}")
    sys.exit(1)

print("\n✓ All 4 repos uploaded:")
for repo_id, _, label in jobs:
    print(f"  https://huggingface.co/{repo_id}  ({label})")
PYEOF

# ─────────────────────────────────────────────────────────────────────────────
# DONE — remove pod
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "========================================================"
echo "  Run $RN complete. Removing pod $POD_ID ..."
echo "========================================================"

runpodctl remove pod "$POD_ID" \
    && echo "✓ Pod $POD_ID removed" \
    || echo "  Could not auto-remove pod — please remove manually"
