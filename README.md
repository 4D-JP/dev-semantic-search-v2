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

## Limitations of Training Embedding Models

**MNRL symmetric loss risking reverse-direction noise**

The symmetric part adds a second InfoNCE term: for each positive pair it also treats the positive as a query and the original query as the target. If your positives are noisy or domain-shifted from typical queries, this reverse pass can push the query embedding in a direction that makes no semantic sense. The model appears to improve on retrieval benchmarks but the general sentence-to-sentence similarity space quietly degrades. This is hard to catch because standard retrieval evals don't measure it.

**Sometimes there is no genuine textual signal making a passage relevant**

Relevance can be grounded in external context — user intent, domain ontology, business classification, implicit world knowledge — none of which is recoverable from the text pair alone. The bi-encoder sees tokens. If the tokens don't carry the signal, there is nothing to learn.

**Encoder-only embedding models can't be trained on semantic similarities that don't exist**

This is a fundamental architectural constraint. A bi-encoder produces independent embeddings for query and passage and measures their geometric distance. It cannot reason about the relationship between them jointly. If the relevance is relational rather than semantic — i.e. it only exists when you consider both texts together in context — a bi-encoder cannot represent it. A cross-encoder can approximate it but even that has limits if the signal is truly external.

**The remaining uncaught passages likely belong to that category and 100% retrieval is unreachable**

This is an important thing to accept clearly. In any real retrieval system there is a ceiling imposed by how much relevance signal is textually recoverable. Passages above that ceiling are not failures of training or architecture — they are genuinely outside what embedding-based retrieval can do. Chasing them with more fine-tuning produces exactly the overfitting and space distortion we discussed. The right response is to acknowledge the ceiling and design the system around it — hybrid retrieval, reranking, or metadata filtering for the cases that fall outside the textual signal space.

Realistic target for the traning pipeline: optimize the bi-encoder for what it can genuinely learn, measure where the ceiling is empirically, and route the remainder to a different mechanism rather than asking the embedding model to do something its architecture cannot support.

## Removal of Markdown Tables

### Reason

Markdown tables are structured data encoded as text. A typical table entry consists of pipe-delimited cells containing numeric values, identifiers, or short labels with no surrounding prose context. When a query asks about information contained in such a table, the relevance relationship is **interpretive and positional** — it depends on understanding column headers, row structure, and schema — none of which is recoverable from token-level text similarity alone.

A bi-encoder embedding model produces independent embeddings for query and passage and measures their geometric distance. It has no mechanism to interpret tabular structure. As a result, query–table pairs that are genuinely relevant produce near-zero cosine similarity, indistinguishable from hard negatives. During contrastive training with MNRL, these pairs generate failed gradients — the loss cannot be satisfied because the model cannot distinguish the positive from the negative. These failed gradients do not simply cancel out; they distort the surrounding embedding space as a side effect, degrading the model's ability to match queries to legitimate text passages.

Markdown table passages were therefore identified as a structurally unliftable category: no amount of fine-tuning on a bi-encoder can recover the relevance signal, and their continued presence in the training data causes net harm.

### Method

Passages were scanned using a regular expression match against the raw source text. Any file containing a sequence of 20 or more pipe-delimited segments was classified as a markdown table and moved to a separate folder for exclusion from the training dataset.

```4d
ARRAY LONGINT($pos; 0)
ARRAY LONGINT($len; 0)
For each ($file; $files)
    $text:=$file.getText()
    If (Match regex("(?:[^|]+\\|){20,}"; $text; 1; $pos; $len))
        $file.moveTo($targetFolder)
    End if
End for each
```

The regex `(?:[^|]+\|){20,}` matches any sequence of 20 or more non-pipe segments each terminated by a pipe character. This threshold reliably identifies tables while avoiding false positives from prose containing occasional pipe characters.

### Effect

Removing this category reduces dataset size but increases the proportion of examples carrying genuine textual signal. The expected outcome is a more meaningful loss floor, reduced gradient noise during training, and improved retrieval quality on text-based queries — even if raw loss metrics appear higher due to the removal of examples the model could previously satisfy trivially.

<img width="500" height="auto" alt="r6_combined" src="https://github.com/user-attachments/assets/23e0b60e-9b06-4faf-b185-c5e76af74265" />

