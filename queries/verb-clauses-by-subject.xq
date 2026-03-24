(: ============================================================
   verb-clauses-by-subject.xq

   For a given verb lemma, retrieve all clauses from the
   macula-hebrew-nodes database, classify each subject using
   SDBH LexDomain codes, then group and count by subject type.

   External variable:
     $lemma  — Hebrew verb lemma (default: "הָיָה")
     $samples — max clauses per group to include in samples (default: 5)

NOTE: The lemma is injected by the LLMFlow pipeline via a prepare-query function step
      that replaces the __LEMMA__ marker before passing the file to BaseX.
      When running directly with basex, edit the default string or use BaseX -bind.

   Output: JSON with three top-level keys:
     "summary"       — grouped counts (all groups, sorted by count desc)
     "groups"        — full clause listing per group
     "samples"       — first $samples clauses per group (for LLM input)
     "needs_review"  — Implicit / Unknown / ambiguous cases

   Requires BaseX 9+ (XQuery 3.1 maps, arrays, group by).
   ============================================================ :)

declare option output:method "json";
declare option output:indent "yes";

declare variable $lemma   external := "__LEMMA__";
declare variable $samples external := 5;   (: max clauses per group in samples :)

(: ---- LexDomain prefix → subject type ---- :)
(: LexDomain may be space-separated (e.g. "003001006 003001010"); always use
   the first token, which is the primary/most specific classification.
   Domain hierarchy (SDBH-en.JSON):
     001001001      Deities
     001001002001   Animals
     001001002002   Spirits / Angels
     001001002003   People
     001005         Scenery / Nature
     002            Events / Abstract
     003001004      Names of Deities        → God/Divine
     003001012      Names of Supernatural   → Spirit/Angel
     003001006/007  Names of Groups/People  → People
     003001016      Self (reflexive)        → People
     003001017      Titles                  → People
     003001003/008/010/011  Places          → Place
     003001002/014/015      Nature names    → Nature
     003001001/005/009/013  Abstract names  → Abstract
   Prefixes are matched longest-first. :)
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
};

(: ---- record constructor — one map per clause occurrence ---- :)
(: $ref-map: pre-built map of morphId → Node for implicit-subject resolution :)
declare function local:record(
    $verb-m    as element(),
    $cl        as element(),
    $ref       as xs:string,
    $ref-map   as map(*)
) as map(*) {
    let $subj-node     := $cl/Node[@Cat = "S"][1]
    let $subj-words    := $subj-node//m
    (: Prefer words that carry a LexDomain; fall back to first noun, then any word :)
    let $head-m        := (
        $subj-words[@pos = ("noun", "proper noun") and @LexDomain != ""][1],
        $subj-words[@pos = ("noun", "proper noun")][1],
        $subj-words[@LexDomain != ""][1],
        $subj-words[1]
    )[.][1]
    let $lex           := string($head-m/@LexDomain)
    let $pos           := string($head-m/@pos)
    let $subj-ref-str  := string($verb-m/parent::Node/@SubjRef)
    let $subj-ref-ids  := tokenize($subj-ref-str, "\s+")[. != ""]
    (: Resolve implicit subject via SubjRef → @morphId lookup.
       SubjRef may list multiple co-referent morphIds; collect a word from each. :)
    let $ref-words     := if (empty($subj-node) and exists($subj-ref-ids))
                          then
                              for $id in $subj-ref-ids
                              let $n := $ref-map($id)
                              where exists($n)
                              return ($n//m[@LexDomain != ""])[1]
                          else ()
    let $ref-word      := $ref-words[1]   (: first referent drives type/domain :)
    let $ref-lex       := string($ref-word/@LexDomain)
    let $ref-pos       := string($ref-word/@pos)
    return map {
        "ref":                  $ref,
        "type":                 if   (exists($subj-node)) then local:subject-type($lex, $pos)
                                else if (exists($ref-word)) then local:subject-type($ref-lex, $ref-pos)
                                else "Implicit",
        "has_explicit_subject": exists($subj-node),
        "subject_lemma":        if (exists($subj-node)) then string($head-m/@lemma)
                                else string-join(distinct-values($ref-words ! string(@lemma)), " "),
        "subject_english":      if (exists($subj-node)) then string($head-m/@english)
                                else string-join(distinct-values($ref-words ! string(@english)), "; "),
        "subject_lex_domain":   if (exists($subj-node)) then $lex else $ref-lex,
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

(: ---- collect all records ---- :)
(: Pass 1: gather (verb-m, cl, ref) triples for all matching verbs :)
let $raw :=
    for $verb-m in db:get("macula-hebrew-nodes")//m[@lemma = $lemma]
    let $cl  := $verb-m/ancestor::Node[@Cat = "CL"][1]
    where exists($cl)
    return map {
        "verb-m": $verb-m,
        "cl":     $cl,
        "ref":    string($verb-m/ancestor::Sentence[1]/@verse)
    }

(: Pass 2: collect the SubjRef morphIds needed for implicit-subject resolution :)
let $needed-ref-ids := distinct-values(
    for $r in $raw
    where empty($r?cl/Node[@Cat = "S"][1])
    return tokenize(string($r("verb-m")/parent::Node/@SubjRef), "\s+")[. != ""]
)

(: Single batch lookup → map of morphId → Node :)
let $ref-map := map:merge(
    for $node in db:get("macula-hebrew-nodes")//Node[@morphId = $needed-ref-ids]
    return map:entry(string($node/@morphId), $node),
    map { "duplicates": "use-first" }
)

let $all :=
    for $r in $raw
    return local:record($r("verb-m"), $r?cl, $r?ref, $ref-map)

let $total := count($all)

(: ---- build grouped summary ---- :)
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

(: ---- full groups (saved as intermediate; not sent to LLM) ---- :)
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

(: ---- samples: first $samples clauses per group (sent to LLM) ---- :)
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

(: ---- needs_review: Implicit + Unknown + ambiguous ---- :)
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
