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
