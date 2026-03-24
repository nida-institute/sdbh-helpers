"""
prepare_query.py — Pipeline helpers for the verb-subject-report pipeline.

prepare_verb_query : Inject lemma into XQuery template before BaseX execution.
trim_corpus_for_llm : Strip full clause listings so only summary + samples reach the LLM.
"""
import json
import os


def prepare_verb_query(query_template_path: str, lemma: str) -> str:
    """Read XQuery template, substitute __LEMMA__ marker, write to tmp file.

    Returns the path to the prepared .xq file.
    """
    with open(query_template_path, encoding="utf-8") as fh:
        query = fh.read()

    lemma = lemma.strip()
    query = query.replace("__LEMMA__", lemma)

    out_dir = "tmp/queries"
    os.makedirs(out_dir, exist_ok=True)

    safe_lemma = lemma.replace("/", "_").replace("\\", "_")
    out_path = f"{out_dir}/verb-clauses-{safe_lemma}.xq"

    with open(out_path, "w", encoding="utf-8") as fh:
        fh.write(query)

    return out_path


def trim_corpus_for_llm(corpus_json: str) -> str:
    """Strip full clause listings from corpus JSON, keeping only what the LLM needs.

    Retains: lemma, total_clauses, summary, sample_groups.
    Drops:   groups (all clauses — too large), needs_review.

    Accepts either a JSON string or an already-parsed dict (e.g. from checkpoint replay).
    Returns a compact JSON string.
    """
    data = json.loads(corpus_json) if isinstance(corpus_json, str) else corpus_json
    trimmed = {
        "lemma":         data.get("lemma"),
        "total_clauses": data.get("total_clauses"),
        "summary":       data.get("summary"),
        "sample_groups": data.get("sample_groups"),
    }
    return json.dumps(trimmed, ensure_ascii=False)

