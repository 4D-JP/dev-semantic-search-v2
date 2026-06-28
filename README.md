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

---

**Model:** BAAI/bge-m3  
**Round:** r1  
**Domain:** Legal documents (English, French, German)  
**Date:** June 2026

---

## 1. Base Model: BAAI/bge-m3

BGE-M3 (BAAI General Embedding, Multilingual, Multi-functionality, Multi-granularity) is a state-of-the-art embedding model developed by the Beijing Academy of Artificial Intelligence. It was chosen as the base for this fine-tuning effort for several reasons.

**Multilingual capability.** BGE-M3 was pre-trained on a massive multilingual corpus spanning over 100 languages, with strong coverage of European legal languages including English, French, and German. Its cross-lingual alignment means that semantically equivalent passages across languages share similar positions in the vector space, making it well-suited for multilingual retrieval tasks without requiring language-specific models.

**General retrieval performance.** BGE-M3 supports three retrieval paradigms simultaneously: dense retrieval (embedding-based), sparse retrieval (lexical, similar to BM25), and multi-vector retrieval (ColBERT-style late interaction). Even in dense-only mode, it ranks among the top general-purpose embedding models on the MTEB benchmark, particularly for retrieval tasks. Its 8192-token context window is also a practical advantage for legal documents, which tend to be long.

**Architecture.** BGE-M3 is built on XLM-RoBERTa-large (560M parameters). This transformer backbone is well-understood, and its query, key, value, and feed-forward weight matrices are natural targets for parameter-efficient adaptation via LoRA.

---

## 2. Objective

The goal of this fine-tuning round is to improve the model's ability to retrieve relevant passages from a corpus of domain-specific legal documents in English, French, and German.

Legal text presents distinct retrieval challenges that a general-purpose model may not handle well: highly specialised terminology, citation conventions, clause numbering, and cross-lingual synonymy of legal concepts (e.g. "force majeure", "höhere Gewalt", and "cas fortuit" refer to the same doctrine). Fine-tuning on domain-specific query–passage pairs is expected to shift the model's representation space toward these distinctions, reducing false positives and improving the ranking of genuinely relevant passages.

---

## 3. Evaluation Metrics

### Hit Rate @ 10 (HR@10)

HR@10 measures the proportion of queries for which at least one relevant passage appears in the top 10 retrieved results. It answers the binary question: *did the model find something useful?* A score of 1.0 means that for every query, at least one correct answer was in the top 10; a score of 0.0 means it never was.

This metric is important for real-world retrieval systems where downstream processing (re-ranking, reading comprehension) can tolerate some noise in the candidate set, but needs at least one correct passage present to succeed.

### NDCG @ 10 (Normalised Discounted Cumulative Gain @ 10)

NDCG@10 measures the quality of the *ranking* within the top 10 results. It rewards models that place the most relevant passages at the top of the list, and penalises models that find correct passages but bury them at position 9 or 10. The score is normalised against an ideal ranking, so it always falls between 0 and 1.

NDCG@10 is the more demanding of the two metrics. A model can achieve a high HR@10 simply by retrieving broadly; achieving a high NDCG@10 requires the model to actually rank relevant passages above irrelevant ones.

---

## 4. Benchmark Results

| Model | HR@10 | NDCG@10 |
|---|---|---|
| OpenAI text-embedding-3-small (1024 dim) | `0.7272` | `0.5934` |
| BGE-M3 (original, no fine-tuning) | `0.7787` | `0.5903` |
| BGE-M3 r1 (this run) | **`0.8454`** | **`0.6433`** |

The fine-tuned r1 model improves substantially on both metrics relative to both baselines. Compared to the original BGE-M3:

- HR@10 increases by **+6.7 percentage points** (0.7787 → 0.8454), meaning the model now successfully retrieves at least one relevant passage for significantly more queries.
- NDCG@10 increases by **+5.3 percentage points** (0.5903 → 0.6433), meaning the relevant passages that are retrieved are also ranked higher within the top 10.

Compared to OpenAI text-embedding-3-small, the gains are even larger: +11.8pp on HR@10 and +5.0pp on NDCG@10.

Notably, the base BGE-M3 already outperforms OpenAI text-embedding-3-small on HR@10 (0.7787 vs 0.7272), suggesting the XLM-RoBERTa backbone's multilingual pre-training is an inherent advantage for this legal corpus. Fine-tuning amplifies this advantage.

---

## 5. Training Data

Training data was drawn from the **LEMUR dataset** (`keisuke-miyako/bge-m3-lemur-r1`), a collection of legal query–passage pairs structured as hard-negative triplets.

**Hard negative mining.** Negatives were not sampled randomly from the corpus. They were generated using a dedicated reranker model (`ettin-reranker-1b-v1-Q8_0.gguf`), which identifies passages that are superficially similar to the query but ultimately irrelevant — so-called "hard negatives". Training against hard negatives forces the model to learn fine-grained distinctions rather than simply separating completely unrelated passages, leading to better generalisation.

**Preprocessing.** Markdown tables were excluded from the passage pool. Legal documents often contain structured numerical data (tariff schedules, fee tables, sentence ranges) formatted as markdown tables; these tend to be retrieved spuriously by keyword overlap and were filtered to improve training signal quality.

**Triplet construction.** Each dataset row contains one query, a list of positive passages, and a list of negative passages. The `make_training_pairs` function expands each row into one triplet per positive, pairing each positive with one randomly sampled negative. This uses all positives without a combinatorial explosion, and the random negative selection rotates across training epochs, providing additional variety.

The final flattened training set contained approximately 7,300 triplets, of which 500 were held out as a fixed evaluation split (seed 42, ~7%).

---

## 6. Training Configuration

### LoRA Adapter

Rather than updating all 560M parameters of the BGE-M3 backbone, a LoRA (Low-Rank Adaptation) adapter was applied. LoRA injects small trainable rank-decomposition matrices into selected weight layers while keeping the base model frozen. This dramatically reduces the number of trainable parameters and GPU memory requirements, while still allowing meaningful adaptation.

| Parameter | Value |
|---|---|
| Rank (r) | 32 |
| Alpha (lora_alpha) | 64 |
| Dropout | 0.05 |
| Bias | none |
| Precision | bfloat16 |

**Target modules:** `query`, `key`, `value`, `dense`, `intermediate.dense`

The inclusion of `intermediate.dense` (the feed-forward network's first projection) is a deliberate choice for round 1. The attention projections (`query`, `key`, `value`) are the standard targets for LoRA and primarily affect how the model attends to tokens. The FFN intermediate layer, however, is where the model encodes and transforms semantic content — it is where domain-specific knowledge is stored. By targeting `intermediate.dense`, the adapter is given the capacity to shift the model's internal representations toward legal vocabulary and concepts, not just its attention patterns.

This is an aggressive configuration for a first round. In subsequent rounds, this target may be removed or narrowed depending on the drift analysis (see Section 7).

### Loss Function

Training used **MultipleNegativesRankingLoss (MNRL)**, an InfoNCE-style contrastive loss operating in the query → passage direction only (unidirectional). For each query in a batch, the corresponding positive is the target, and all other positives in the batch serve as additional in-batch negatives alongside the explicit hard negatives.

The temperature parameter was set via `scale = 20` (equivalent to temperature = 0.05), which produces a sharper similarity distribution and encourages the model to make more decisive distinctions between relevant and irrelevant passages.

### Hardware and Schedule

| Parameter | Value |
|---|---|
| Hardware | 4 × A100 80GB PCIe |
| Per-device batch size | 32 |
| Gradient accumulation | 1 |
| Effective batch size | 128 (32 × 1 × 4 GPUs) |
| Epochs | 3 |
| Learning rate | 2e-5 |
| LR scheduler | Cosine |
| Warmup ratio | 10% |
| Weight decay | 0.01 |
| Checkpointing | Every 100 steps, keep last 10 |
| Evaluation | Every 100 steps on held-out split |

---

## 7. Representation Drift Analysis

The improved HR@10 and NDCG@10 scores are encouraging, but a higher hit rate alone is not sufficient evidence of healthy adaptation. A model that assigns uniformly high cosine similarity to all passage pairs — a phenomenon known as **representation collapse** — would also score highly on HR@10 while being useless in practice. To rule this out, cosine similarity drift was measured on both positive (relevant) and negative (irrelevant) pairs.

| Pair type | Mean cosine similarity drift |
|---|---|
| Positive pairs | `-0.1210888110405` |
| Negative pairs | `-0.1409832001499` |

Both positive and negative similarities have shifted downward after fine-tuning. This is an expected consequence of training with MNRL on a domain-specific corpus: when all documents are drawn from a narrow domain (legal text), the overall similarity landscape is compressed — passages that would have appeared highly similar to a general model are now distinguished more finely, and the entire distribution shifts.

The critical observation is that **negative pairs drifted more than positive pairs** (−0.1410 vs −0.1211). This means the model has pushed irrelevant passages further away from queries than it has pushed relevant passages. The gap between positives and negatives has therefore widened, confirming that relevance ranking integrity is maintained and that the model has not collapsed.

This pattern is the expected signature of a well-behaved domain adaptation: the model becomes more discriminating within the domain, not less. Collapse would present as positive drift ≈ negative drift, or — worse — as positive drift exceeding negative drift.

---

## 8. Summary

Round 1 fine-tuning of BGE-M3 via LoRA on the LEMUR legal corpus has produced measurable improvements on both retrieval metrics, outperforming the base model and OpenAI text-embedding-3-small by a meaningful margin. The drift analysis confirms that the model has not undergone representation collapse: negative pairs have drifted further than positive pairs, preserving and improving discriminative ranking.

The inclusion of `intermediate.dense` as a LoRA target appears to have contributed to domain adaptation without catastrophic forgetting. This is consistent with the theory that FFN layers encode factual and domain knowledge, though it will be treated as a variable to revisit in future rounds.

The model is considered a healthy checkpoint for further development. Next steps should include out-of-domain evaluation to assess generalisation, and consideration of whether `intermediate.dense` should be retained or dropped in round 2.

