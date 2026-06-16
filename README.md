# dev-semantic-search-v2

Custom Embedding Model

## Dataset

The dataset is the public [**G4KMU/LEMUR**](https://huggingface.co/datasets/G4KMU/LEMUR) collection. It is primarily a large-scale multilingual legal corpus explicitly designed for the robust fine-tuning of multilingual law embedding models for legal document retrieval.

Here is a breakdown of its core components, methodologies, and use cases:

---

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
