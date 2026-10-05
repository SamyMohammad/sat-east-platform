# 04 — User Flows & Screen Inventory

## 1. Core student flows

### 1.1 Discover → buy
```
Landing page → Course page → Sign up → (Free Topic 1)
     → Checkout → Payment gateway → Webhook → Enrolment active → Course map
```

### 1.2 Topic loop
```
Course map → Topic
   Video (≥80% watched)
     → Notes (opened)
       → Practice (≥10 attempted)
         → Homework (submit → auto-grade → report)
           → Quiz ──pass (≥75%)──→ Next topic unlocked
                 └─fail──→ Review set on missed skills → cooldown 12h → Retake (new questions)
```

### 1.3 Mock phase
```
All topics passed  OR  ≤30 days to test date
   → Mock plan (suggested schedule)
     → Pre-exam screen (rules, device tip: use laptop/tablet)
       → Module 1 (22 Q, 35 min)
         → Module 2 routed easy/hard (22 Q, 35 min)
           → Score report → Drill set → Next mock
```

### 1.4 Ask for help
```
Answered question → "Ask AI" → AI explains from stored solution
   → "Still confused" → Teacher inbox → Teacher reply / added to live session
```

### 1.5 Teacher daily loop
```
Dashboard (alerts: stuck, inactive, reports, escalations)
   → Completion matrix → filter "homework not submitted" → announce / message
   → Review queue (reported questions) → fix key → auto re-grade
```

## 2. Screen inventory

### Public
| # | Screen | Notes |
|---|--------|-------|
| S-01 | Landing page | Hero, courses, teacher bio, results/testimonials (real only), FAQ |
| S-02 | Course page | Syllabus by unit/topic, free topic CTA, price in local currency |
| S-03 | Sign up / Sign in / Reset password | Email + Google |
| S-04 | Legal: Terms, Privacy, Refund policy | Required by payment gateway |

### Student
| # | Screen | Notes |
|---|--------|-------|
| S-10 | Onboarding: profile + target test + test date | Sets access window |
| S-11 | Device limit screen | List devices, remove one |
| S-12 | Home | Continue card, next deadline-free step, streak, upcoming live session |
| S-13 | My courses | SAT / EST cards, access expiry |
| S-14 | Course map | Units → topics, lock states, progress rings |
| S-15 | Topic page | 5-step stepper (Video, Notes, Practice, Homework, Quiz) |
| S-16 | Video player | DRM player, chapters, watermark |
| S-17 | Notes viewer | Paged PDF viewer with watermark, no download |
| S-18 | Practice setup | Subtopic + difficulty filters |
| S-19 | Question player (practice mode) | Immediate feedback, hint, explanation, Ask AI |
| S-20 | Homework player | Navigator, autosave, submit confirm |
| S-21 | Result report (homework/quiz) | Score, per-skill, time per Q, review answers |
| S-22 | Quiz player | Timer, no feedback, spiral questions |
| S-23 | Quiz failed → review set | Missed skills, cooldown countdown |
| S-24 | Skills / analytics | Mastery bars, weak skills, trend |
| S-25 | Mistake notebook | Filter by topic/skill, re-attempt |
| S-26 | AI tutor panel | Chat bound to one question; escalate button |
| S-27 | Mock hub | Mock list, plan, score history, log official score |
| S-28 | Mock pre-exam | Rules, tools tour |
| S-29 | **Exam screen (Bluebook-style)** | See 08 §4 |
| S-30 | Module break / transition | |
| S-31 | Mock score report | Range, domains, time analysis, drill set CTA |
| S-32 | Live sessions | Upcoming (local time) + recordings |
| S-33 | Checkout / order history / receipts | |
| S-34 | Profile & settings | Devices, test date, password |
| S-35 | Notifications center | |

### Teacher (admin area of the same app, best on laptop)
| # | Screen | Notes |
|---|--------|-------|
| T-01 | Dashboard | KPIs, alerts, sales |
| T-02 | Course builder | Tree editor for units/topics/subtopics, drag reorder |
| T-03 | Topic editor | Attach videos, notes, pool settings, publish |
| T-04 | Video upload | Direct upload to video host, processing status |
| T-05 | Question bank browser | Filters: topic, subtopic, skill, difficulty, status, pool |
| T-06 | Question editor | Markdown+LaTeX live preview, choices, answer, explanation, tags |
| T-07 | Import | Upload JSON/CSV, validation report, commit |
| T-08 | Review queue | Needs-review + student reports |
| T-09 | Completion matrix | Students × steps, filters, export |
| T-10 | Student detail | Progress, attempts, devices, enrolments, override unlock |
| T-11 | Class insights | Hardest questions, wrong-option stats, stuck students |
| T-12 | AI escalations inbox | Reply / add to live session |
| T-13 | Live sessions manager | Schedule, attach recording |
| T-14 | Mock templates & mock sets | Blueprint config, generate set |
| T-15 | Coupons & activation codes | |
| T-16 | Announcements | |
| T-17 | Settings | Pass mark, cooldown, device limit, access window, pool split |

## 3. Responsive rules
- Phone (≤ 600 px): bottom nav, single column, question player full screen.
- Tablet (600–1024 px): two-pane where useful (navigator + question).
- Laptop (≥ 1024 px): exam screen mirrors Bluebook split layout; teacher area designed for this size first.
- Exam screen on phone: allowed but shows a warning recommending tablet/laptop.
