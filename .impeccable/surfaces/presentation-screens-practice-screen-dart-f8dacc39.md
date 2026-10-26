---
version: 1
slug: "presentation-screens-practice-screen-dart-f8dacc39"
primary_target: "apps/client/lib/features/practice/presentation/screens/practice_screen.dart"
related_targets: ["apps/client/lib/shared/widgets/question_view/question_view.dart"]
---

# Practice question screen

Scope: student practice question (shared `QuestionView`, practice mode) as the first surface of the app-wide redesign. Mode: Operate.
Job: answer one question, get feedback that teaches, move on. Many short phone sessions; laptop for longer runs.
Constraints: PRODUCT.md (answer keys server-side, mixed-direction content, LaTeX legibility, status never by colour alone).

## Direction contract

THESIS: The category standard (Khan Academy calm, Brilliant polish, Linear/Notion type and spacing discipline, Duolingo's decisive Check structure) executed at full craft. Refuses: grey SaaS screens, gamified chrome, exam-software imitation.

OWN-WORLD: White ground, one cool off-white surface, near-black ink. One confident brand blue for selection and primary action. Correct = green, incorrect = coral, each with an icon and a word. Teacher feedback on a warm tinted panel. Rounded 12px choices, 10px buttons, soft offset shadows only on the feedback sheet. One workhorse UI sans with tabular numerals; LaTeX in a math face.

STORY: The student sees where they are (3 of 10), reads a large clean stem, picks a choice, presses Check, and the bottom sheet rises with the verdict, the teacher's one-line next step and the action.

FIRST VIEWPORT: Top bar: close, thin segmented progress, count, hint. Stem at 20-22px under a small skill line. Four full-width choice rows. Sticky bottom action bar with a full-width Check (phone) or right-aligned Check (desktop, centred 720px column).

FORM: Category standard (canon), seed e85e1605.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
