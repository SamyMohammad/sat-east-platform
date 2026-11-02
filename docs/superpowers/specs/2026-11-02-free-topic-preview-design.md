# Free topic preview (CRS-06, PAY-01, Q-07)

Date: 2026-11-02 · Status: decisions approved by user in chat (2026-11-02)

## Why

The owner confirmed (Q-07) that the first topic of every course is free. The flag exists (`topics.is_free_preview`, CRS-06; the teacher sets it in the course builder) and the course page shows a "Free" badge. But no student without an enrolment can open anything: every student RPC goes through `private.practice_access`, which raises `not_enrolled`. The free topic is the main way a student decides to buy, so it has to work end to end before launch.

## Decisions (user, 2026-11-02)

1. **Entry: course map preview.** On the course page, a signed-in student without an enrolment in that course gets a "Try the free topic" action. It opens that course's map in preview mode. Free topics are open; every other topic is shown locked with the reason "Enter an activation code to unlock" and a link to `/activate`. Signed-out visitors keep today's sign-up CTA.
2. **Scope: everything.** Inside a free topic the student can use the video, notes, practice, homework, the topic quiz, the skill report and attempt review, exactly as an enrolled student.
3. **After the quiz: prompt to activate.** Passing a free topic's quiz shows the normal result plus "Enter an activation code to open the next topic" (link to `/activate`). Progress is stored against the user and topic as today, so it carries over once they activate.

## Rules (builder's calls, stated)

- **Preview applies only when the student has no enrolment in that course.** An existing enrolment that ended keeps today's `access_expired` behaviour. Renewal is a separate flow.
- **In preview, a topic is open only if it is `is_free_preview`.** The usual unlock rules (first position, previous topic done, teacher unlock) do not apply to non-free topics. If the teacher hasn't flagged any topic free, the preview map shows everything locked. The teacher must flag topic 1 in the course builder; this goes in the launch checklist.
- **Device limit and watermark still apply** (video grant keeps its device check; notes keep the watermark).
- Answer keys stay server-side (rule 1). Nothing about grading changes.
- No new tables. No change for enrolled students.

## Server changes

| Piece | Change |
|---|---|
| `private.practice_access(uid, topic)` | If no enrolment row exists for the topic's course: allow when the topic is published and `is_free_preview`, otherwise raise `not_enrolled` (unchanged code). An enrolment that is not active or is expired still raises `access_expired`. |
| `private.topic_states` | Needs a preview variant (a parameter or a wrapper). With no enrolment, non-free topics are `locked` with the reason `needs_access`, and free topics are `open` or `completed`. |
| `public.get_course_map(p_slug)` | With a slug and no enrolment, return the map in preview mode instead of raising: add `"access": "preview"` (and `"access": "full"` for enrolled). Without a slug and no enrolment, keep `not_enrolled`. |
| `get_topic` | Must not expose asset lists of non-free topics to a non-enrolled user. The current asset selects have no enrolment check; gate them through `practice_access`, or the same free/enrolled rule. |
| Storage `notes` read policy | Use `has_access_topic` (free preview OR access) instead of course-level `has_access`, so the free topic's notes PDF is readable. |
| `finish_quiz` / result | Include `"next_needs_access": true` when the next topic is locked only because the student has no enrolment. |
| Docs | Update `docs/07` lines on `get_course_map` ("no map without active access"), `video_playback_grant` and `start_homework` to state the free-preview branch. Update `docs/06` if `topic_states` changes. |

Every changed function keeps its grants. pgTAP covers, in `supabase/tests/`:
- a non-enrolled user can run the whole loop on a free topic;
- a non-enrolled user is refused on a non-free topic, with `not_enrolled`;
- an expired enrolment is still refused, with `access_expired`;
- `get_topic` does not leak non-free assets;
- the notes object is readable for a free topic only;
- enrolled behaviour is unchanged.

## Client changes

- **Course page** (`catalogue`): signed in and not enrolled, with at least one free topic, shows a "Try the free topic" action that opens the preview map for that course slug. Keep "Enter activation code" as the secondary action.
- **Course map:** loads by slug for preview. It shows a slim banner: "You're previewing this course. Enter an activation code to unlock every topic." Locked rows with reason `needs_access` say "Activation needed" and link to `/activate`.
- **Topic screen:** unchanged for free topics. A `not_enrolled` error on a non-free topic keeps today's copy.
- **Quiz result:** when `next_needs_access`, replace "Next topic" with "Enter activation code" (to `/activate`).
- **Routing:** the preview map needs a slugged entry (for example `/courses?course=<slug>`, or a new route); the builder picks it. Never use `Navigator.push`.
- The English copy follows the teacher's voice (PRODUCT.md).

## Non-goals

No purchase UI, no free-topic analytics dashboard, no guest (signed-out) access to topic content.
