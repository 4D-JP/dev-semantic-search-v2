# dev-semantic-search-v2

Custom Embedding Model

## Dataset

The dataset is the public [**G4KMU/LEMUR**](https://huggingface.co/datasets/G4KMU/LEMUR) collection. It is primarily a large-scale multilingual legal corpus explicitly designed for the robust fine-tuning of multilingual law embedding models for legal document retrieval.

### 1. Structure & Core Specifications

* **The Source Material:** It is constructed from **24,953 official EUR-Lex PDF documents** focusing heavily on EU environmental legislation.
* **Multilingual Scope:** The dataset spans **25 different languages**, covering both highly represented (high-resource) and low-resource languages across European jurisdictions.
* **Goal:** To resolve the massive amount of noise introduced by imperfect PDF-to-text extractions and the lack of domain-specific, open-source embedding models tailored for dense legal retrieval.

### 2. Key Methodological Contributions

* **Lexical Filtering (The LCS Metric):** Real-world legal documents are notoriously messy when scraped via standard PDF parsers. The authors introduced the **Lexical Content Score (LCS)** to rigorously measure and quantify the fidelity of the PDF-to-text extraction by comparing it against authoritative HTML counterparts, creating a clean, dependable data standard.
* **Contrastive Fine-Tuning Setup:** The dataset is structured to support contrastive training objectives in both **monolingual** and **bilingual** settings to replicate realistic cross-border legal search scenarios.

### 3. Practical Applications & Findings

* **Boosting Low-Resource Languages:** Training on LEMUR significantly boosts the Top-$k$ retrieval accuracy over vanilla architectures, with the most dramatic performance spikes observed in low-resource regional languages.
* **Cross-Lingual Domain Transfer:** Evaluations show that models fine-tuned on this dataset naturally transfer their learnings to *unseen* languages. This proves the corpus helps embedding models pick up on content-level, language-independent legal logic rather than merely memorizing local linguistic cues.

## Benchmark - OpenAI

### 1. Build the Haystack:

- Import German, English, French documents from `full.jsonl`.
- Split the document into chunks of `509` tokens using the `cl100k` base tokeniser (GTP-4, `100277` tokens) for chunking. [GGUF convered version](https://huggingface.co/keisuke-miyako/cl100k_tokenizer-gguf) has been prepared on Hugging Face.
- Use the OpenAI embedding model [`text-embedding-3-small`](https://developers.openai.com/api/docs/models/text-embedding-3-small) to generate embeddings in `1024` dimensions, the same size as BAAI BGE M3.
- Check usage and cost.

### 2. Generate the Queries:

Pass the documents from `test.jsonl` to a frontier LLM to create synthetic natural-language user queries.

|Documents|Queries|Passages|Query Passages|Cost|
|-:|-:|-:|-:|-:|
|`3380`|`22692`|`75973`|`3787`|`$13.05`|

### 3. Calculate standard retrieval metrics:

* **Hit Rate @10**: Did the exact matching document from `test.jsonl` show up anywhere in the top 10 search results?
* **NDCG @10**: Did the matching document rank highly (preferably #1), or was it buried down at #10?

## Benchmark - BGE M3

### 1. Build the Haystack:

- Use the standard BGE M3 model to generate embeddings in `1024` dimensions from chunks of `509` tokens.

|Documents|Queries|Passages|Query Passages
|-:|-:|-:|-:|
|`3380`|`31900`|`108190`|`5325`

### 2. Calculate standard retrieval metrics:

- Run the same tests to compare against the OpenAI model.

## Test Form

### 1. Compare OpenAI vs Original BGE M3

* Run the "TEST" form.
* Click on "Posiitve".
* Red lines indicate the document that the search was supposed to match.
* While lines indicate similar (but possibly irrelavant) documents.

<img width="500" height="auto" alt="Screenshot 2026-06-17 at 12 38 50" src="https://github.com/user-attachments/assets/727f6900-eb4b-4696-9ea3-4849049442e0" />

* Click on "Open Weight" to test BGE M3.

<img width="500" height="auto" alt="Screenshot 2026-06-17 at 12 39 02" src="https://github.com/user-attachments/assets/ccded753-9528-4e7b-aa6b-c0a9ef85e818" />

* If you have LEMUR dataset downloaded, the PDF will open when you double click a line.

<img width="500" height="auto" alt="Screenshot 2026-06-17 at 12 42 32" src="https://github.com/user-attachments/assets/f863584e-510a-4808-a938-63e3dbf214e6" />

## LoRA

### 1. Upload Dataset

- [keisuke-miyako/bge-m3-lemur-r1](https://huggingface.co/datasets/keisuke-miyako/bge-m3-lemur-r1)
- Number of rows: `52809`

### 2. Multiple Negatives Symmetric Ranking Loss

- torch 2.4.1+cu124
- NVIDIA A40x4
- per_device_train_batch_size: `32`
- gradient_accumulation_steps: `1`
- learning_rate: `2e-5`
- num_train_epochs: `3`
- lora_alpha: `64`
- r: `32`
- scale: `20`

### 3. Calculate standard retrieval metrics:

- Train

|Model|BM@10|NDCG@10
|-|-:|-:
|OpenAI|`0.722222`|`0.586204`|
|Original BGE M3|`0.781818`|`0.586923`|
|Fine-tuned BGE M3 R1|`0.881504`|`0.663531`

- Full

|Model|BM@10|NDCG@10
|-|-:|-:
|OpenAI|`0.665784`|`0.538284`|
|Original BGE M3|`0.715987`|`0.534895`|
|Fine-tuned BGE M3 R1|`0.811912`|`0.601433`

### r1

<img width="500" height="auto" alt="train-vs-eval-loss" src="https://github.com/user-attachments/assets/a5dcc6d0-99bd-48a1-994a-cf57f3d68eab" />

### r2

<img width="500" height="auto" alt="train-vs-eval-loss" src="https://github.com/user-attachments/assets/61d8cac1-c557-4c9c-9d0c-f525d672427f" />
