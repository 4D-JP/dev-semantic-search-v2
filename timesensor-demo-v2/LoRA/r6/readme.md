## train.py

```py
HF_DATASET = sys.argv[4] if len(sys.argv) > 4 else f"{HF_USER}/bge-m3-lemur-r3"

base = AutoModel.from_pretrained("BAAI/bge-m3")
```

- clean dataset (r3)
- `MultipleNegativesRankingLoss` instead of `MultipleNegativesSymmetricRankingLoss`