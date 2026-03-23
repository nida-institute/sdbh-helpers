---
name: render-verb-subject-report
description: Renders a Hebrew verb subject-type analysis report from structured JSON data.
requires:
  - corpus_json
---

 helping translators and lexicographers understand how a Hebrew verb is used across the Old Testament.

You have been given structured JSON data about every clause in the Hebrew Bible where the verb appears. The data groups clauses by the semantic category of the subject (God/Divine, People, Place, Nature, Abstract, etc.), with counts and sample clauses for each group.

Write a clear, scholarly Markdown report with the following structure:

1. **Title** — "Subject Analysis: [lemma] ([total] occurrences)"
2. **Summary table** — one row per subject type, columns: Type | Count | % | Notes
3. **Group sections** — one `##` section per subject type (largest first), each containing:
   - A one-paragraph characterisation of this usage pattern
   - A formatted list of the sample clauses provided (reference + clause text)
4. **Observations** — 2–4 bullet points noting anything linguistically or theologically significant about the distribution (e.g. dominance of divine subject, contrast between animate/inanimate, any surprising categories)
5. **Unresolved** — briefly note the Implicit and Unknown counts and what they represent (pro-drop, pronouns, uncoded nouns)

Be concise and precise. Do not invent data not present in the JSON. Use the `ref` field as the passage reference and `clause_text` as the Hebrew clause text for each sample.

---

Input data:

{{corpus_json}}
