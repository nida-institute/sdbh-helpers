(: ============================================================
   verb-clauses-by-subject.xq

   PURPOSE
   -------
   For a given Hebrew verb lemma, retrieve every clause in which
   the verb appears from the macula-hebrew-nodes BaseX database,
   classify each by the semantic type of its subject (using SDBH
   LexDomain codes), and produce grouped counts plus sample clauses.

   DATASET: macula-hebrew-nodes
   ----------------------------
   Built from Clear-Bible/macula-hebrew (WLC/nodes/ directory).
   One XML file per chapter; each file holds one <Sentence> per verse.
   Each sentence contains a constituency parse tree of <Node> elements.
   Leaf nodes each wrap a single <m> (morpheme) element:

     <Sentence verse="1CH 14:4">
       <Node Cat="CL">                           clause
         <Node Cat="S">                          subject phrase
           <Node morphId="130140040051" ...>     leaf node — one per word
             <m word="1CH 14:4!5"               word ref: verse!position
                xml:id="o130140040051"
                lemma="הָיָה" pos="verb" .../>
           </Node>
         </Node>
       </Node>
     </Sentence>

   IMPORTANT: @morphId is on the leaf <Node>, NOT on the <m> child.
   To get the morphId of a word from its <m>, use: $m/parent::Node/@morphId

   EXTERNAL VARIABLES
   ------------------
     $lemma   — Hebrew verb lemma with full vowel markings (niqqud required;
                the database uses vowelled lemmas; bare consonants will not match).
                Default "__LEMMA__" is replaced at runtime by the LLMFlow
                prepare-query step. When running directly with basex, either
                edit the default or use: basex -blemma=הָיָה ...
     $samples — max clauses per group to include in sample_groups (default: 5)

   OUTPUT STRUCTURE
   ----------------
   JSON object with these top-level keys:
     "lemma"         — the queried lemma (as injected)
     "total_clauses" — total matching verb occurrences
     "summary"       — array of {type, count, pct}, sorted by count desc
     "groups"        — full clause listing per subject type (all occurrences)
     "sample_groups" — first $samples clauses per group (for LLM input)
     "needs_review"  — flat array of Implicit/Unknown/ambiguous records

   REQUIRES: BaseX 9+ (XQuery 3.1 maps, arrays, group by)
   ============================================================ :)

declare option output:method "json";
declare option output:indent "yes";

declare variable $lemma   external := "__LEMMA__";
declare variable $samples external := 5;   (: max clauses per group in sample_groups :)

(: ============================================================
   local:subject-type($lex, $pos)

   Maps an SDBH LexDomain code to a human-readable subject type.

   LexDomain is a dot-separated numeric code from SDBH-en.JSON.
   Multiple codes may be space-separated; we always use the first
   (primary / most specific) token.

   The 001xxx hierarchy classifies common vocabulary by referent type:
     001001001        Deities
     001001002001     Animals
     001001002002     Spirits / Angels
     001001002003     People
     001005           Scenery / Nature objects
     002xxx           Events, states, abstracts

   The 003001xxx hierarchy classifies proper names by sub-type:
     003001001  Books          → Abstract
     003001002  Constellations → Nature
     003001003  Constructions  → Place
     003001004  Deities        → God/Divine
     003001005  Documents      → Abstract
     003001006  Groups/nations → People
     003001007  Individuals    → People
     003001008  Landforms      → Place
     003001009  Languages      → Abstract
     003001010  Locations      → Place
     003001011  Roads          → Place
     003001012  Supernatural   → Spirit/Angel
     003001013  Times          → Abstract
     003001014  Trees          → Nature
     003001015  Waterbodies    → Nature
     003001016  Self/reflexive → People
     003001017  Titles         → People

   Branches are tested longest-prefix-first so that, e.g.,
   001001002003 (People) is matched before 001001002 (Creature).

   Fallbacks:
     proper noun with no LexDomain → "Referent (ambiguous)"
     any other non-empty LexDomain → "Other"
     empty LexDomain               → "Unknown"
       (pronouns like הוּא, אַתָּה have no LexDomain and correctly land here)
   ============================================================ :)
declare function local:subject-type(
    $lex as xs:string,
    $pos as xs:string
) as xs:string {
    let $first := tokenize($lex, " ")[1]
    return
    if      (starts-with($first, "001001001"))     then "God/Divine"
    else if (starts-with($first, "001001002002"))  then "Spirit/Angel"
    else if (starts-with($first, "001001002003"))  then "People"
    else if (starts-with($first, "001001002001"))  then "Animal"
    else if (starts-with($first, "001001002"))     then "Creature"
    else if (starts-with($first, "001005"))        then "Nature"
    else if (starts-with($first, "002"))           then "Abstract"
    (: 003001 sub-codes — Names of... (from SDBH-en.JSON) :)
    else if (starts-with($first, "003001004"))     then "God/Divine"    (: Deities :)
    else if (starts-with($first, "003001012"))     then "Spirit/Angel"  (: Supernatural Beings :)
    else if (starts-with($first, "003001006"))     then "People"        (: Groups / nations :)
    else if (starts-with($first, "003001007"))     then "People"        (: People / individuals :)
    else if (starts-with($first, "003001016"))     then "People"        (: Self / reflexive :)
    else if (starts-with($first, "003001017"))     then "People"        (: Titles :)
    else if (starts-with($first, "003001003"))     then "Place"         (: Constructions :)
    else if (starts-with($first, "003001008"))     then "Place"         (: Landforms :)
    else if (starts-with($first, "003001010"))     then "Place"         (: Locations :)
    else if (starts-with($first, "003001011"))     then "Place"         (: Roads :)
    else if (starts-with($first, "003001002"))     then "Nature"        (: Constellations :)
    else if (starts-with($first, "003001014"))     then "Nature"        (: Trees :)
    else if (starts-with($first, "003001015"))     then "Nature"        (: Waterbodies :)
    else if (starts-with($first, "003001001"))     then "Abstract"      (: Books :)
    else if (starts-with($first, "003001005"))     then "Abstract"      (: Documents :)
    else if (starts-with($first, "003001009"))     then "Abstract"      (: Languages :)
    else if (starts-with($first, "003001013"))     then "Abstract"      (: Times :)
    else if ($pos = "proper noun" and $lex = "")   then "Referent (ambiguous)"
    else if ($lex != "")                           then "Other"
    else                                                "Unknown"
        (: Pronouns (הוּא, אַתָּה, אֲנִי, etc.) have no LexDomain in Macula
           and are correctly classified Unknown. They appear in needs_review. :)
};

(: ============================================================
   local:record($verb-m, $cl, $ref, $ref-map)

   Builds one JSON map for a single verb occurrence.

   Parameters:
     $verb-m   — the <m> element of the verb word
     $cl       — the ancestor <Node Cat="CL"> (clause) containing it
     $ref      — verse reference string, e.g. "1CH 14:4"
     $ref-map  — pre-built map of morphId → Node for implicit-subject
                 resolution (see Pass 2 below)

   Subject resolution strategy
   ---------------------------
   EXPLICIT subject: the clause has a direct <Node Cat="S"> child.
     - $subj-words  = all <m> descendants of that S node
     - $head-m      = the most semantically informative word, selected by:
                        1. noun/proper noun with a LexDomain  (best)
                        2. noun/proper noun without LexDomain
                        3. any word with a LexDomain
                        4. first word in the phrase            (fallback)
     - subj_ref     = space-joined @morphId of every word's parent <Node>
                      (NB: @morphId lives on the leaf Node, not on <m> itself)

   IMPLICIT subject (pro-drop): no S node in this clause.
     - The verb's direct parent <Node> carries @SubjRef — a space-separated
       list of morphIds pointing to the referent word(s), which may be
       anywhere in the corpus (often in a preceding verse or sentence).
     - $ref-map resolves each id to its <Node>; we collect one representative
       <m> per id (preferring one with a LexDomain).
     - All co-referents contribute to subject_lemma and subject_english;
       only the first ($ref-word) drives type and subject_lex_domain.
     - subj_ref echoes the raw @SubjRef string for traceability.

   Output fields
   -------------
     ref                  verse reference ("GEN 1:1")
     verb_ref             word-level reference ("GEN 1:1!3") — uniquely
                          identifies this verb occurrence within the verse
     type                 subject semantic type (from local:subject-type)
     has_explicit_subject true if a S node is present in this clause
     subject_lemma        dictionary lemma of the head/referent word(s)
     subject_english      English gloss of the head/referent word(s)
     subject_lex_domain   SDBH LexDomain code of the head/referent word
     subj_ref             for explicit: space-joined morphIds of subject words;
                          for implicit: raw @SubjRef value from the annotation
     verb_morph           full morphological code (e.g. "Vqp3ms")
     verb_stem            stem label (qal, niphal, piel, …)
     verb_person / gender / number  — inflection details
     clause_text          space-joined surface text of every word in the clause
   ============================================================ :)
declare function local:record(
    $verb-m    as element(),
    $cl        as element(),
    $ref       as xs:string,
    $ref-map   as map(*)
) as map(*) {
    let $subj-node     := $cl/Node[@Cat = "S"][1]     (: explicit subject phrase, if any :)
    let $subj-words    := $subj-node//m               (: all morpheme words inside it :)
    (: Head-word selection: prefer the most semantically informative word.
       Articles, prepositions, and conjunctions typically have no LexDomain,
       so selecting by LexDomain presence avoids classifying those as Unknown. :)
    let $head-m        := (
        $subj-words[@pos = ("noun", "proper noun") and @LexDomain != ""][1],
        $subj-words[@pos = ("noun", "proper noun")][1],
        $subj-words[@LexDomain != ""][1],
        $subj-words[1]
    )[.][1]
    let $lex           := string($head-m/@LexDomain)
    let $pos           := string($head-m/@pos)
    (: @SubjRef on the verb's parent Node: space-separated morphIds of the
       referent(s) for implicit (pro-drop) subjects. May be empty string
       when the subject is truly unspecified (some imperatives, etc.). :)
    let $subj-ref-str  := string($verb-m/parent::Node/@SubjRef)
    let $subj-ref-ids  := tokenize($subj-ref-str, "\s+")[. != ""]
    (: Resolve implicit subject co-referents from the pre-built morphId map.
       SubjRef can list multiple ids (e.g. compound or plural antecedents);
       we collect one representative <m> per id, skipping any not in the map. :)
    let $ref-words     := if (empty($subj-node) and exists($subj-ref-ids))
                          then
                              for $id in $subj-ref-ids
                              let $n := $ref-map($id)
                              where exists($n)
                              return ($n//m[@LexDomain != ""])[1]
                          else ()
    let $ref-word      := $ref-words[1]   (: first referent drives type and lex_domain :)
    let $ref-lex       := string($ref-word/@LexDomain)
    let $ref-pos       := string($ref-word/@pos)
    return map {
        "ref":                  $ref,
        "verb_ref":             string($verb-m/@word),   (: e.g. "1CH 14:4!5" — verse + word position :)
        "type":                 if   (exists($subj-node)) then local:subject-type($lex, $pos)
                                else if (exists($ref-word)) then local:subject-type($ref-lex, $ref-pos)
                                else "Implicit",         (: no S node and no @SubjRef resolution :)
        "has_explicit_subject": exists($subj-node),
        "subject_lemma":        if (exists($subj-node)) then string($head-m/@lemma)
                                else string-join(distinct-values($ref-words ! string(@lemma)), " "),
        "subject_english":      if (exists($subj-node)) then string($head-m/@english)
                                else string-join(distinct-values($ref-words ! string(@english)), "; "),
        "subject_lex_domain":   if (exists($subj-node)) then $lex else $ref-lex,
        (: subj_ref provides word-level identifiers for the subject:
             explicit — space-joined @morphId of every word in the S phrase
                        (@morphId is on the parent Node of each <m>, not on <m> itself)
             implicit — the raw @SubjRef string from the verb's parent Node :)
        "subj_ref":             if (exists($subj-node))
                                then string-join($subj-words/parent::Node ! string(@morphId), " ")
                                else $subj-ref-str,
        "verb_morph":           string($verb-m/@morph),
        "verb_stem":            string($verb-m/@stem),
        "verb_person":          string($verb-m/@person),
        "verb_gender":          string($verb-m/@gender),
        "verb_number":          string($verb-m/@number),
        "clause_text":          string-join($cl//m/text(), " ")
    }
};

(: ============================================================
   MAIN QUERY — three-pass approach
   ============================================================

   WHY THREE PASSES?
   -----------------
   Implicit-subject resolution requires looking up @SubjRef morphIds
   anywhere in the corpus. Doing that lookup inside a per-clause loop
   would issue a full-corpus scan for every implicit verb occurrence.
   Instead we:
     Pass 1 — collect all (verb-m, clause, ref) triples cheaply
     Pass 2 — gather the distinct morphIds we need, then build a
               single morphId → Node map in one batch corpus scan
     Pass 3 — build all records using the pre-built map (no extra scans)
   ============================================================ :)

(: Pass 1: find every occurrence of the verb and its enclosing clause.
   We only keep occurrences that actually sit inside a CL node — a small
   number of verb forms appear in non-clausal contexts and are skipped. :)
let $raw :=
    for $verb-m in db:get("macula-hebrew-nodes")//m[@lemma = $lemma]
    let $cl  := $verb-m/ancestor::Node[@Cat = "CL"][1]
    where exists($cl)
    return map {
        "verb-m": $verb-m,
        "cl":     $cl,
        "ref":    string($verb-m/ancestor::Sentence[1]/@verse)
    }

(: Pass 2: collect ONLY the SubjRef morphIds needed for implicit subjects,
   then do a single batch lookup to build the resolution map.
   Using distinct-values avoids redundant map entries for shared antecedents. :)
let $needed-ref-ids := distinct-values(
    for $r in $raw
    where empty($r?cl/Node[@Cat = "S"][1])        (: implicit subject only :)
    return tokenize(string($r("verb-m")/parent::Node/@SubjRef), "\s+")[. != ""]
)

(: Single corpus scan — produces map of morphId → Node :)
let $ref-map := map:merge(
    for $node in db:get("macula-hebrew-nodes")//Node[@morphId = $needed-ref-ids]
    return map:entry(string($node/@morphId), $node),
    map { "duplicates": "use-first" }
)

(: Pass 3: build all clause records :)
let $all :=
    for $r in $raw
    return local:record($r("verb-m"), $r?cl, $r?ref, $ref-map)

let $total := count($all)

(: ---- Summary: one row per type, sorted by frequency ---- :)
let $summary := array {
    for $r in $all
    let $t := $r?type
    group by $t
    let $n := count($r)
    order by $n descending
    return map {
        "type":  $t,
        "count": $n,
        "pct":   round($n div $total * 1000) div 10
    }
}

(: ---- Groups: all clause records, sorted by reference within each type.
        This section is saved to the intermediate JSON file but is NOT
        sent to the LLM (too large). It is the authoritative full dataset. ---- :)
let $groups := array {
    for $r in $all
    let $t := $r?type
    group by $t
    order by count($r) descending
    return map {
        "type":    $t,
        "count":   count($r),
        "clauses": array {
            for $c in $r order by $c?ref return $c
        }
    }
}

(: ---- Sample groups: first $samples clauses per type (sent to the LLM).
        Sorted by reference so samples are not biased toward any one book. ---- :)
let $sample-groups := array {
    for $r in $all
    let $t := $r?type
    group by $t
    order by count($r) descending
    return map {
        "type":    $t,
        "count":   count($r),
        "clauses": array {
            for $c in subsequence(
                for $x in $r order by $x?ref return $x,
                1, xs:integer($samples)
            )
            return $c
        }
    }
}

(: ---- Needs review: flat array of all Implicit, Unknown, and ambiguous records.
        Implicit — no S node and @SubjRef resolved to nothing (true pro-drop or
                   unresolved reference)
        Unknown  — subject carries no LexDomain (typically pronouns: הוּא, אַתָּה, etc.)
        Referent (ambiguous) — proper noun flag set but LexDomain absent ---- :)
let $needs-review := array {
    for $r in $all
    where $r?type = ("Implicit", "Unknown", "Referent (ambiguous)")
    order by $r?ref
    return $r
}

return map {
    "lemma":         $lemma,
    "total_clauses": $total,
    "summary":       $summary,
    "groups":        $groups,
    "sample_groups": $sample-groups,
    "needs_review":  $needs-review
}
