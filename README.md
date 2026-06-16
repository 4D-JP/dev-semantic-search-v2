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

|Documents|Passages|Cost|
|-|-|-|
|`3380`|`75973`|`$0.75`|

### 2. Generate the Queries:

Random queries from `full.jsonl`.

|Queries|Model|Cost
|-|-|-|
|`22722`|`gpt-5.4`|`$12.30`

Pass the documents from `test.jsonl` to a frontier LLM to create synthetic natural-language user queries.

### 3. Calculate standard retrieval metrics:

* **Hit Rate @10**: Did the exact matching document from `test.jsonl` show up anywhere in the top 10 search results?
* **NDCG @10**: Did the matching document rank highly (preferably #1), or was it buried down at #10?

## Benchmark - BGE M3

### 1. Build the Haystack:

- Use the standard BGE M3 model to generate embeddings in `1024` dimensions from chunks of `509` tokens.

|Documents|Passages|
|-|-|
|`3380`|`75973`|

### 2. Calculate standard retrieval metrics:

- Run the same tests to compare against the OpenAI model.
