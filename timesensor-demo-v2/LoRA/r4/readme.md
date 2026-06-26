## train.py

```py
HF_DATASET = sys.argv[4] if len(sys.argv) > 4 else f"{HF_USER}/bge-m3-lemur-{RN}"

base = AutoModel.from_pretrained("{HF_USER}/bge-m3-lemur-r6-merged")
```

```py
model = SentenceTransformer(
    f"{HF_USER}/bge-m3-lemur-r6-merged",
    model_kwargs={"torch_dtype": torch.bfloat16},
)
```


python3 - <<'EOF'
from huggingface_hub import hf_hub_download, upload_file
import os

TOKEN = os.environ["HF_TOKEN"]

for filename in ["sentence_bert_config.json", "1_Pooling/config.json"]:
    local = hf_hub_download(repo_id="BAAI/bge-m3", filename=filename, token=TOKEN)
    upload_file(
        path_or_fileobj=local,
        path_in_repo=filename,
        repo_id="keisuke-miyako/bge-m3-lemur-r6-merged",
        repo_type="model",
        token=TOKEN,
    )
    print(f"✓ uploaded {filename}")
EOF
