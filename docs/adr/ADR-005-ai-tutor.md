# ADR-005: AI tutor grounded in teacher-approved solutions

**Status:** Proposed · **Date:** 2026-10-05 · **Deciders:** Teacher, Developer

## Context
The teacher works alone and cannot answer every student question. An LLM can explain solutions,
but free-form math answers from an LLM can be wrong, which would damage trust.

## Decision
A question-scoped tutor: each conversation is bound to one question; the model receives the stem,
choices, the **approved key and worked explanation**, the student's answer and the relevant notes
excerpt, and is instructed to explain only from that material. Escalation to the teacher is one tap.
Called only from the `ai-tutor` Edge Function (key never on device).

## Options considered
| Option | Pros | Cons |
|---|---|---|
| Grounded, per-question tutor (proposed) | Low hallucination risk, cheap prompts, auditable | Can't answer general "teach me X" questions |
| Open general chatbot | Flexible | Wrong answers, off-topic use, high cost, cheating risk |
| No AI, teacher inbox only | Zero risk | Teacher overwhelmed |

## Consequences
- Depends on explanation quality from the content pipeline (09).
- Disabled during active quiz/mock attempts (anti-cheating).
- Per-student daily cap + teacher cost dashboard.
- Model/provider is swappable behind the EF; log tokens per message.

## Action items
1. [ ] Prompt + eval set of 50 real student questions before launch.
2. [ ] Escalation inbox (T-12).
