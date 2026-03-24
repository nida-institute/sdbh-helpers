# Installing sdbh-helpers

## Prerequisites

- macOS or Linux (zsh or bash)
- Python 3.10+
- An OpenAI API key (used by the LLM report step)

---

## 1. Clone this repository

```bash
git clone https://github.com/nida-institute/sdbh-helpers.git
cd sdbh-helpers
```

---

## 2. Install `sp` (Scripture Pipelines / LLMFlow)

`sp` is the pipeline runner. Follow the instructions in the
[LLMFlow INSTALL.md](https://github.com/nida-institute/LLMFlow/blob/main/INSTALL.md)
to install it and configure your OpenAI API key.

After installation, verify:
```bash
sp --version
```

---

## 3. Install BaseX

The XQuery step queries a local [BaseX](https://basex.org/) database.
Version 9 or later is required (XQuery 3.1 support).

On macOS with Homebrew:
```bash
brew install basex
basex -version
```

For other platforms, download from [basex.org/download](https://basex.org/download/).

---

## 4. Build the macula-hebrew-nodes database

The pipelines query a BaseX database named **`macula-hebrew-nodes`** built
from the [Clear-Bible/macula-hebrew](https://github.com/Clear-Bible/macula-hebrew)
repository (the Macula Hebrew WLC node trees).

### Clone the data

```bash
git clone https://github.com/Clear-Bible/macula-hebrew.git
```

### Create the database

```bash
basex -c "CREATE DB macula-hebrew-nodes /path/to/macula-hebrew/WLC/nodes/"
```

Replace `/path/to/macula-hebrew` with the actual clone location.
This imports all per-chapter XML files (one per chapter of the Hebrew Bible)
into a single queryable database. Initial indexing takes a few minutes.

### Verify

```bash
basex -c "OPEN macula-hebrew-nodes; XQUERY count(//m)"
```

Expected output: a number in the hundreds of thousands (one `<m>` per morpheme
across the entire Hebrew Bible).

---

## 5. Run a report

Generate a subject-type analysis for a Hebrew verb lemma.
The lemma must be given with full vowel markings (niqqud), as stored in Macula:

```bash
./verb-report.sh הָיָה
```

Multiple verbs can be processed in one call:

```bash
./verb-report.sh הָיָה רָבָה
./verb-report.sh "הָיָה,רָבָה,הָלַךְ"
```

### Output files (written to `output/`)

| File | Contents |
|------|----------|
| `<lemma>-subject-data.json` | Full structured data: all clause records grouped by subject type, plus a sample subset and a `needs_review` list |
| `<lemma>.md` | LLM-generated Markdown report: summary table, per-group characterisations, and linguistic observations |

---

## Querying the data directly

You can run the XQuery against the database without the pipeline:

```bash
basex -blemma=הָיָה queries/verb-clauses-by-subject.xq > out.json
```

See the comments at the top of [queries/verb-clauses-by-subject.xq](queries/verb-clauses-by-subject.xq)
for a full description of the output schema and subject-resolution logic.
