#!/usr/bin/env python3
"""
BGE-M3 fine-tuning — round 1 (domain adaptation on BAAI/bge-m3)
  - sentence-transformers 3.x + MultipleNegativesRankingLoss (asymmetric)
  - LoRA via PEFT (rank 32, targets query/key/value/dense/intermediate.dense)
    intermediate.dense included for domain adaptation (FFN encodes domain knowledge)
  - Multi-GPU via torchrun (DDP handled by HF Trainer under the hood)
  - Checkpoints every 100 steps, pushed to HuggingFace
  - 500-row held-out eval split (~7%); eval loss logged every 100 steps
  - ddp_find_unused_parameters=True required: frozen LoRA base_layer weights
    never receive gradients; DDP must be told to expect this

Usage (via torchrun in setup_and_run.sh):
  torchrun --nproc_per_node=N train.py <RN> <WORK_DIR> <CKPT_REPO> <HF_DATASET>
"""
import os, sys, random, logging
import torch
from datasets import load_dataset
from huggingface_hub import login
from peft import LoraConfig, get_peft_model, TaskType
from sentence_transformers import SentenceTransformer, SentenceTransformerTrainer
from sentence_transformers.losses import MultipleNegativesRankingLoss
from sentence_transformers.training_args import SentenceTransformerTrainingArguments


logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)s  %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger(__name__)

# ── Args ──────────────────────────────────────────────────────────────────────
HF_USER="keisuke-miyako"
RN         = sys.argv[1] if len(sys.argv) > 1 else "r2"
WORK_DIR   = sys.argv[2] if len(sys.argv) > 2 else f"/workspace/bge_m3/{RN}"
CKPT_REPO  = sys.argv[3] if len(sys.argv) > 3 else f"{HF_USER}/bge-m3-lemur-{RN}-checkpoints"
HF_DATASET = sys.argv[4] if len(sys.argv) > 4 else f"{HF_USER}/bge-m3-lemur-r2"
HF_TOKEN   = os.environ.get("HF_TOKEN", "")

ADAPTER_DIR = os.path.join(WORK_DIR, "adapter")
CKPT_DIR    = os.path.join(WORK_DIR, "checkpoints")
os.makedirs(ADAPTER_DIR, exist_ok=True)
os.makedirs(CKPT_DIR, exist_ok=True)

# ── Distributed setup ─────────────────────────────────────────────────────────
LOCAL_RANK = int(os.environ.get("LOCAL_RANK", 0))
WORLD_SIZE = int(os.environ.get("WORLD_SIZE", 1))
IS_MAIN    = LOCAL_RANK == 0

# ─────────────────────────────────────────────────────────────────────────────
# Hyperparameters — tuned for 4 × A100 80GB PCIe
# Effective batch = PER_DEVICE_BATCH × GRAD_ACCUM × WORLD_SIZE
#                 = 32 × 1 × 4 = 128
# Eval split: 500 rows held out before training (fixed seed, ~7% of ~7 300 triplets)
# ─────────────────────────────────────────────────────────────────────────────
PER_DEVICE_BATCH = 32
GRAD_ACCUM       = 1
LEARNING_RATE    = 1e-5 # 2e-5
EPOCHS           = 2 # 3
WARMUP_RATIO     = 0.10
EVAL_SIZE        = 500     # rows held out from the flattened triplet pool (~7% of ~7 300 triplets)

# LoRA — rank 32 hits the sweet spot between expressiveness and adapter size
# target_modules uses short names: PEFT matches any layer ending in these names
LORA_R           = 32
LORA_ALPHA       = 64
LORA_DROPOUT     = 0.10 # 0.05
LORA_TARGETS     = ["query", "key", "value", "dense"]
MNRL_SCALE       = 16 # 20  

def make_training_pairs(example):
    """
    Convert one dataset row (query, pos:list, neg:list) into
    (anchor, positive, negative) triplets.

    For each positive, we pair it with ONE randomly sampled negative.
    This uses all positives without a full cross-product explosion.
    Negatives rotate across epochs due to random.choice.
    """
    query     = example["query"]
    pos_list  = example["pos"]  if isinstance(example["pos"],  list) else [example["pos"]]
    neg_list  = example["neg"]  if isinstance(example["neg"],  list) else [example["neg"]]

    if not pos_list or not neg_list:
        return {"anchor": [], "positive": [], "negative": []}

    anchors, positives, negatives = [], [], []
    for pos in pos_list:
        neg = random.choice(neg_list)
        anchors.append(query)
        positives.append(pos)
        negatives.append(neg)

    return {"anchor": anchors, "positive": positives, "negative": negatives}


def main():
    if IS_MAIN:
        if HF_TOKEN:
            login(token=HF_TOKEN, add_to_git_credential=False)
        log.info(f"Run: {RN}  |  GPUs: {torch.cuda.device_count()}  |  world_size: {WORLD_SIZE}")
        log.info(f"Dataset: {HF_DATASET}")
        log.info(f"Effective batch: {PER_DEVICE_BATCH} × {GRAD_ACCUM} × {WORLD_SIZE} = "
                 f"{PER_DEVICE_BATCH * GRAD_ACCUM * WORLD_SIZE}")

    # ── Load + preprocess dataset ─────────────────────────────────────────────
    if IS_MAIN:
        log.info("Loading dataset ...")

    raw_ds = load_dataset(HF_DATASET, split="train", token=HF_TOKEN if HF_TOKEN else None)

    if IS_MAIN:
        log.info(f"Raw rows: {len(raw_ds)}  columns: {raw_ds.column_names}")

    train_ds = raw_ds.map(
        make_training_pairs,
        batched=False,
        remove_columns=raw_ds.column_names,
        desc="Building triplets",
    )
    # Remove empty rows (queries with no pos/neg)
    train_ds = train_ds.filter(lambda x: len(x["anchor"]) > 0)

    # Flatten: map produces lists-per-row; we need one row per triplet
    train_ds = train_ds.map(
        lambda batch: {
            "anchor":   [a for row in batch["anchor"]   for a in row],
            "positive": [p for row in batch["positive"] for p in row],
            "negative": [n for row in batch["negative"] for n in row],
        },
        batched=True,
        remove_columns=train_ds.column_names,
        desc="Flattening triplets",
    )

    if IS_MAIN:
        log.info(f"Total triplets before split: {len(train_ds)}")

    # ── Train / eval split ────────────────────────────────────────────────────
    # Fixed seed so the same rows are always held out across re-runs.
    # EVAL_SIZE rows are drawn from the full flattened pool.
    split    = train_ds.train_test_split(test_size=EVAL_SIZE, seed=42)
    train_ds = split["train"]
    eval_ds  = split["test"]

    if IS_MAIN:
        log.info(f"Train triplets: {len(train_ds)}  |  Eval triplets: {len(eval_ds)}")

    # ── Model ─────────────────────────────────────────────────────────────────
    if IS_MAIN:
        log.info("Loading merged model ...")

    model = SentenceTransformer(
        f"{HF_USER}/bge-m3-lemur-r1-merged",
        model_kwargs={"torch_dtype": torch.bfloat16},
    )

    # Apply LoRA to the transformer backbone
    lora_config = LoraConfig(
        task_type=TaskType.FEATURE_EXTRACTION,
        r=LORA_R,
        lora_alpha=LORA_ALPHA,
        target_modules=LORA_TARGETS,
        lora_dropout=LORA_DROPOUT,
        bias="none",
        inference_mode=False,
    )
    backbone = model[0].auto_model
    backbone_lora = get_peft_model(backbone, lora_config)
    model[0].auto_model = backbone_lora

    if IS_MAIN:
        backbone_lora.print_trainable_parameters()

    # MultipleNegativesRankingLoss (InfoNCE, unidirectional):
    #   - query → passage direction only (task is asymmetric by design)
    #   - scale = 1/temperature (20 ≈ temperature 0.05)
    loss = MultipleNegativesRankingLoss(model, MNRL_SCALE)

    # ── Training arguments ────────────────────────────────────────────────────
    total_steps = (len(train_ds) * EPOCHS) // (PER_DEVICE_BATCH * GRAD_ACCUM * WORLD_SIZE)
    warmup_steps = max(100, int(total_steps * WARMUP_RATIO))

    if IS_MAIN:
        log.info(f"Total steps ~{total_steps}  warmup {warmup_steps}")

    training_args = SentenceTransformerTrainingArguments(
        # Paths
        output_dir=CKPT_DIR,
        run_name=RN,

        # Schedule
        num_train_epochs=EPOCHS,
        per_device_train_batch_size=PER_DEVICE_BATCH,
        gradient_accumulation_steps=GRAD_ACCUM,
        learning_rate=LEARNING_RATE,
        warmup_steps=warmup_steps,
        weight_decay=0.01,
        lr_scheduler_type="cosine",

        # Precision
        bf16=True,
        fp16=False,
        gradient_checkpointing=True,
        gradient_checkpointing_kwargs={"use_reentrant": False},
        ddp_find_unused_parameters=True,

        # Checkpointing — save every 100 steps, keep last 10
        save_strategy="steps",
        save_steps=100,
        save_total_limit=10,

        # Evaluation — run on held-out split every 100 steps (aligned with save)
        eval_strategy="steps",
        eval_steps=100,

        # Push checkpoints to HuggingFace after each save
        push_to_hub=True,
        hub_model_id=CKPT_REPO,
        hub_strategy="every_save",
        hub_token=HF_TOKEN if HF_TOKEN else None,

        # Logging
        logging_strategy="steps",
        logging_steps=10,
        report_to="none",

        # DataLoader
        dataloader_num_workers=4,
        remove_unused_columns=False,
    )

    # ── Trainer ───────────────────────────────────────────────────────────────
    trainer = SentenceTransformerTrainer(
        model=model,
        args=training_args,
        train_dataset=train_ds,
        eval_dataset=eval_ds,
        loss=loss,
    )

    trainer.train()

    # ── Save LoRA adapter (only on main process) ──────────────────────────────
    if IS_MAIN:
        log.info(f"Saving LoRA adapter to {ADAPTER_DIR}")

        # Save PEFT adapter config + weights
        model[0].auto_model.save_pretrained(ADAPTER_DIR)

        # Save tokenizer alongside so adapter is self-contained
        model[0].tokenizer.save_pretrained(ADAPTER_DIR)

        # Save a minimal adapter README
        with open(os.path.join(ADAPTER_DIR, "README.md"), "w") as f:
            f.write(f"""---
base_model: BAAI/bge-m3
tags:
  - lemur
  - embeddings
  - peft
  - lora
---
# bge-m3-lemur-{RN} LoRA adapter

LoRA adapter (r={LORA_R}) fine-tuned on LEMUR dataset.
Dataset: [{HF_DATASET}](https://huggingface.co/datasets/{HF_DATASET})

## Load
```python
from peft import PeftModel
from transformers import AutoModel
base = AutoModel.from_pretrained("{HF_USER}/bge-m3-lemur-r1-merged")
model = PeftModel.from_pretrained(base, "{HF_USER}/bge-m3-lemur-{RN}-adapter")
```
""")

        log.info(f"✓ Adapter saved: {ADAPTER_DIR}")


if __name__ == "__main__":
    main()
