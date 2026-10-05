# 09 — Content Pipeline: Teacher PDFs → Published Question Bank

> **This is on the critical path.** ~40 SAT topics × ~400 questions ≈ 16,000 questions, plus EST
> (~45 topics), arriving as PDFs **without answer keys**. Auto-grading, analytics and the AI tutor
> are useless without verified keys and explanations. Start this in week 1, in parallel with the app.

## 1. Pipeline overview

```
PDF per topic
  │ 1. Extract       (PDF → page images + text; crop figures)
  ▼
Raw items  [stem, choices, figures, source_page]
  │ 2. Structure     (LLM: split into questions, convert math to LaTeX, detect type MCQ/SPR)
  ▼
Draft items  status=draft
  │ 3. Tag           (LLM: subtopic, skill code, difficulty E/M/H, desmos_friendly)
  │ 4. Solve ×2      (two independent LLM solves → answer + worked explanation)
  ▼
  agree?  ── yes ──▶ status=solved   (sample-reviewed by teacher)
          ── no  ──▶ status=needs_review (teacher must solve/fix)
  │ 5. Validate      (schema, LaTeX compiles, choices count, SPR key format, duplicates)
  │ 6. Teacher review in a spreadsheet / review UI
  ▼
approved  → 7. Pool assignment (practice / quiz / mock_reserve)
  │ 8. Import (import-questions EF) → status=published
```

## 2. Tooling (lives in `tools/content-pipeline/`, Python)

| Step | Tool |
|------|------|
| Extract | `pymupdf` for text + page rasters; manual or LLM-assisted figure cropping; OCR fallback for scanned pages |
| Structure / tag / solve | LLM with vision (page image + text) via API; batch processing; JSON-schema-constrained output |
| Validate | Python validator: JSON schema, KaTeX/LaTeX render check, duplicate detection (normalised stem hash + embedding similarity) |
| Review | Export to `.xlsx` (one row per question) **and** the in-app review queue (T-08) |
| Import | Upload JSON to T-07 → `import-questions` EF |

Cost/throughput: estimate LLM cost on a 400-question pilot before running all topics.

## 3. Question JSON schema (import format)

```json
{
  "external_ref": "SAT-T05-0123",
  "course_codes": ["SAT"],
  "topic_slug": "linear-equations",
  "subtopic_slug": "parallel-perpendicular",
  "skill_codes": ["ALG.LIN.PARALLEL_PERP"],
  "type": "mcq",
  "difficulty": "M",
  "stem_md": "Line $\\ell$ has equation $y = 3x - 2$. Which line is perpendicular to $\\ell$?",
  "images": ["SAT-T05-0123-fig1.png"],
  "choices": [
    {"label": "A", "body_md": "$y = 3x + 1$"},
    {"label": "B", "body_md": "$y = -3x + 1$"},
    {"label": "C", "body_md": "$y = -\\tfrac{1}{3}x + 4$"},
    {"label": "D", "body_md": "$y = \\tfrac{1}{3}x - 2$"}
  ],
  "key": {"choice": "C"},
  "explanation_md": "Perpendicular slopes multiply to $-1$, so the slope is $-\\tfrac13$ …",
  "misconceptions": {"A": "used parallel slope", "B": "negated but did not take reciprocal", "D": "took reciprocal but not negative"},
  "hint_md": "What is the product of the slopes of perpendicular lines?",
  "desmos_friendly": false,
  "source": "teacher_bank_linear.pdf",
  "source_page": 12,
  "solved_by": "ai_double_agree"
}
```
SPR key: `"key": {"accepted": ["7/2", "3.5"], "tolerance": 0}`.

(Example question above is illustrative — written for this spec, not from any source.)

## 4. Skill taxonomy

- Codes: `DOMAIN.TOPIC.SKILL`, e.g. `ALG.LIN.SLOPE`, `ADV.QUAD.VERTEX_FORM`, `PSD.STAT.MEAN_MEDIAN`, `GEO.TRIG.RIGHT_TRIANGLE`.
- The teacher approves the list of topics → subtopics → skills **before** bulk tagging
  (deliverable `content/taxonomy.csv`). Tagging quality determines analytics quality.

## 5. Pool assignment (QB-03)

Per topic, after approval (default, configurable):
- 60% `practice` (homework draws from here too, excluding what the student saw in practice)
- 20% `quiz`
- 20% `mock_reserve` — prefer the most "SAT-like" items (exam-style wording, mixed difficulty)
Stratify each pool by subtopic × difficulty so every pool covers every subtopic.

## 6. Launch content targets (MVP)

Do **not** wait for all 400/topic. For launch:
- 100–150 approved questions per topic (covers practice + homework + quiz).
- Mock reserve: enough for 4–5 full forms (≈ 264–330 questions) before the mock phase opens.
- Remaining questions released in weekly batches after launch.

## 7. Legal / rights gate
- Each source PDF is labelled `teacher_owned` / `licensed` / `third_party`.
- Only `teacher_owned` and `licensed` sources may be published. `third_party` (published prep books,
  College Board material) may be used **only** as a style/blueprint reference to write new original items.

## 8. Teacher review effort (estimate)
- Disagreement rate of double-solve is unknown — measure on the pilot topic.
- Plan for: 100% review of `needs_review`, plus a ~10% random sample of `solved` per topic; if the
  sample error rate > 2%, review that topic fully.
