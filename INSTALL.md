# Installing sdbh-helpers

## 1. Install Scripture Pipelines (LLMFlow)

Follow the instructions in the [LLMFlow INSTALL.md](https://github.com/nida-institute/LLMFlow/blob/main/INSTALL.md) to install the `sp` binary and configure your API key.

## 2. Install BaseX

Download and install [BaseX](https://basex.org/download/) (version 9 or later is required).

On macOS with Homebrew:
```bash
brew install basex
```

Verify:
```bash
basex -version
```

## 3. Load the Macula Hebrew data into BaseX

The pipelines query a BaseX database named **`macula-hebrew-nodes`** built from the [macula-hebrew](https://github.com/Clear-Bible/macula-hebrew) repository.

### Clone the data

```bash
git clone https://github.com/Clear-Bible/macula-hebrew.git
```

### Create the BaseX database

From the BaseX GUI or the command line, create a database named `macula-hebrew-nodes` from the `WLC/nodes/` subdirectory:

```bash
basex -c "CREATE DB macula-hebrew-nodes /path/to/macula-hebrew/WLC/nodes/"
```

Replace `/path/to/macula-hebrew` with the actual path where you cloned the repo.

This imports all per-chapter XML files (e.g. `01-Gen-001.xml`) into a single queryable database. Indexing takes a few minutes.

### Verify

```bash
basex -c "OPEN macula-hebrew-nodes; XQUERY count(//m)"
```

You should see a large number (several hundred thousand morphemes).

## 4. Run a pipeline

```bash
./verb-report.sh הָיָה
```

Output is written to `output/הָיָה.md` and `output/הָיָה-subject-data.json`.
