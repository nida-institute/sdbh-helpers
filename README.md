# sdbh-helpers

Tools for corpus-level analysis of Hebrew verbs using the
[Macula Hebrew](https://github.com/Clear-Bible/macula-hebrew) syntactic
database and SDBH (Semantic Dictionary of Biblical Hebrew) LexDomain codes.

Given a verb lemma, the pipeline queries every clause in the Hebrew Bible
where the verb appears, classifies each by the semantic type of its subject
(God/Divine, People, Place, Abstract, etc.), and produces both a structured
JSON dataset and a readable Markdown report.

**→ [INSTALL.md](INSTALL.md)** — setup instructions

---

## Quick start

```bash
./verb-report.sh הָיָה          # single verb
./verb-report.sh הָיָה רָבָה    # multiple verbs
```

Output is written to `output/`:
- `<lemma>-subject-data.json` — full structured dataset
- `<lemma>.md` — LLM-generated analysis report

---

## Repository layout

```
verb-report.sh                  entry point — run one or more verbs
pipelines/
  verb-subject-report.yaml      LLMFlow pipeline definition (4 steps)
queries/
  verb-clauses-by-subject.xq    XQuery — corpus extraction and classification
scripts/
  prepare_query.py              lemma injection + corpus trimming helpers
prompts/
  render-report.md              LLM prompt for the Markdown report
output/                         generated files (committed for reference)
```

---

## Output schema

Each record in `groups[].clauses[]` and `needs_review[]` has these fields:

| Field | Description |
|---|---|
| `ref` | Verse reference, e.g. `"1CH 14:4"` |
| `verb_ref` | Word-level reference, e.g. `"1CH 14:4!5"` (verse + word position) |
| `type` | Subject semantic type (see below) |
| `has_explicit_subject` | `true` if the clause has an overt subject phrase |
| `subject_lemma` | Dictionary lemma of the subject head word (or all co-referents for implicit) |
| `subject_english` | English gloss |
| `subject_lex_domain` | Primary SDBH LexDomain code |
| `subj_ref` | For explicit: space-joined morphIds of subject words; for implicit: raw `@SubjRef` value |
| `verb_morph` | Full morphological code, e.g. `"Vqp3ms"` |
| `verb_stem` | `qal`, `niphal`, `piel`, … |
| `verb_person` / `verb_gender` / `verb_number` | Inflection |
| `clause_text` | Space-joined surface text of the clause |

### Subject types

| Type | Covers |
|---|---|
| `God/Divine` | YHWH, Elohim, divine names |
| `People` | Individuals, groups, nations, titles, self-reference |
| `Place` | Locations, landforms, constructions, roads |
| `Nature` | Plants, constellations, waterbodies, natural objects |
| `Animal` | Animals |
| `Creature` | Other living beings |
| `Spirit/Angel` | Supernatural beings |
| `Abstract` | Events, states, documents, times, languages |
| `Other` | Has a LexDomain but doesn't fit the above |
| `Unknown` | No LexDomain — typically pronouns (הוּא, אַתָּה, etc.) |
| `Implicit` | Pro-drop: no overt subject and no resolvable `@SubjRef` |
| `Referent (ambiguous)` | Proper noun flag set but LexDomain absent |

`Unknown` and `Implicit` records appear in `needs_review[]` for manual triage.

---

## Running the XQuery directly (without the pipeline)

```bash
basex -blemma=הָיָה queries/verb-clauses-by-subject.xq > out.json
```

See the comments in [queries/verb-clauses-by-subject.xq](queries/verb-clauses-by-subject.xq)
for a detailed description of the subject-resolution logic and the three-pass
query design.

---

## Known limitations

- **Niqqud required.** The database stores vowelled lemmas; bare consonants
  will match nothing. Use the standard dictionary form with full pointing.
- **Unknown ~8% for הָיָה.** Pronouns (הוּא, אַתָּה, etc.) carry no LexDomain
  in Macula and are classified Unknown. They land in `needs_review`.
- **Implicit ~23% for הָיָה.** Hebrew pro-drop is common; when `@SubjRef` is
  absent or unresolvable the subject cannot be identified automatically.
- **One anomaly: AMO 5:5.** The construct chain `בֵּית אֵל` produces an
  explicit subject record with an empty `subj_ref` — a tree-structure quirk,
  not a query bug.

