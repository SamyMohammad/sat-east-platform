# LRN-07 — Student Home (beta) — design

Status: approved by the user 2026-11-02. Requirement: `LRN-07` (P0), screen S-12 (`docs/04` §screens).
Design reference: `docs/design/claude-design-export/Learning Path.dc.html` (Home markup L70–142, data L420–434).

## Why
The Home tab (`/`) is a `PlaceholderScreen` ("This page will be available soon."). Home is the
first screen a signed-in student sees, so it must answer one question: *what do I do next?* — and
take them there in one tap. The notifications bell in the shell header is visible but disabled,
which reads as broken.

## Goals
- One tap from Home to the student's next step (video, notes, practice, homework or quiz).
- Show progress through the course at a glance.
- Warn before access runs out.
- Hide the notifications bell until notifications exist.

## Non-goals (beta)
Study-day streak (no server data; user chose to defer), live session card (live sessions deferred),
teacher note, renew/purchase (Paymob deferred), notifications, multi-course switcher.

## Anti-goals
- No new grading/unlock logic on the client: lock state and step data come from the server as today.
- No answer data on Home (rule 1) — only counts.

## Layout, top to bottom
1. **Greeting** — "Hi, {first name}" (first run: "Welcome, {first name}"). Subtitle:
   "{course title} · {unit title}". First name = first word of `MyProfile.fullName`.
2. **Expiry banner** — only when `expires_at` is less than N days away, N = setting
   `access_expiry_warn_days` (default 14). Copy: "Your {course} access ends in {d} days, on {date}."
   CTA "Enter activation code" → `AppRoutes.activate`.
3. **Continue card** — eyebrow "Continue where you left off" (first run "Start here");
   "{unit title}", "{sortLabel} {topic title}"; 5-segment step bar (reuse `app_progress_segments.dart`)
   labelled "Step k of 5 · {Step name}"; one next-step line; one primary button to the step route.
4. **Course card** — "{passed} of {total} topics passed", progress bar, "Open contents" → `/courses`.

## Current step (domain rule, pure function)
Order is fixed (LRN-01): Video → Notes → Practice → Homework → Quiz. The current step is the first
one not done, from `get_topic`:

| Step | Done when | Next-step line | Button → route |
|---|---|---|---|
| Video | `videoDone` | "Watch the lesson video" | first unfinished video → `AppRoutes.video` |
| Notes | `notesDone` | "Read the notes" | first note → `AppRoutes.notes` |
| Practice | `practiceCount >= practiceMin` | "{count} of {min} practice questions" | `AppRoutes.practice` |
| Homework | homework submitted | "{answered} answered, {left} to go" / "{total} questions" | `AppRoutes.homework` |
| Quiz | topic completed | by `QuizStatus` (available / in progress / cooldown until {time}) | `AppRoutes.quiz` |

A topic with no videos or no notes skips that step as done (matches server completion rules).
If the topic has no actionable step (e.g. quiz cooldown), the button opens the topic page.

## States
| State | When | Shows |
|---|---|---|
| Loading | first load | skeleton/spinner in the content area |
| Ready | map has a `continue` topic | all four sections |
| First run | no topic completed and current step is Video with nothing watched | "Welcome", "Start here", "Start topic {sortLabel}" |
| Finished | map has no `continue` topic and every topic is `completed` | card "You finished {course}" → Open contents |
| Expired | `get_course_map` raises `access_expired` | "Your access has ended. Your progress is saved." + activation CTA |
| Not enrolled | `not_enrolled` | "You're not in a course yet" → catalogue |
| Error | any other failure | error copy by code + Retry |

Home refreshes when the student comes back to the tab (a step may have changed).

## Data
No new RPC. Composed client-side in a `GetHomeSummary` use case:
- `CourseMapRepository.getCourseMap()` → course, continue topic, units (count `completed`).
- `TopicRepository` → `TopicDetail` of the continue topic.
- Enrollment expiry → `MyEnrollment.expiresAt` (auth data source).
- `access_expiry_warn_days` → `settings` table read (same pattern as `notes_max_mb`).
- Profile name → `MyProfile.fullName`.

One new setting (rule 5): `access_expiry_warn_days` = 14, a plain `settings` row like
`notes_max_mb` (not in the teacher settings screen — Claude's call, keeps `teacher_setting_spec`
untouched). Migration from `supabase/templates/setting.sql`, with a pgTAP test.

`MyEnrollment` gains `courseId` (select `course_id`) so Home matches the enrolment of the map's
course instead of matching by title.

## Shell bell
`ShellHeader` renders the bell only when `onNotifications` is non-null. The router passes none, so
the bell disappears for everyone until notifications ship.

## Left to the builder
Widget split and naming inside `lib/features/home/`, skeleton style, exact spacing per `DESIGN.md`,
how the tab-return refresh is wired (branch activation vs. route observer).
