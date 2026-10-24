# L-3 — protected notes (SEC-02) + teacher notes upload (C-3 notes) — design

> Status: draft · 2026-10-24 · Branch `feat/P1-l3-notes`
> **user** marks a decision the user made. Everything else is the router's call.

## Intent

Students read each topic's notes (PDF) inside the app, with their name on every page, no download, and no way to print them (SEC-02). Opening the notes is a real step on the topic path (LRN-01/02). The teacher uploads the notes from the teacher area. Today `topic_assets` (kind `notes`) and `topic_progress.notes_opened_at` exist, but nothing writes or reads them.

## Inputs already settled

- **user:** notes are English only. Only the watermark may hold an Arabic name, and the spike showed it shapes correctly.
- **user:** one PDF per topic or one per subtopic is **the teacher's call** (decisions board `Q-16`). The design supports both:
  - a topic has **0..n** notes assets;
  - each asset is optionally tied to a subtopic (`topic_assets.subtopic_id` is nullable today).
- **user:** the teacher's book (CRS-05) is **postponed** (board `Q-17`). Nothing book-specific gets built.
- **user:** notes **gate practice**. A topic whose notes exist unlocks practice only after the student has opened any of them once. A topic with **no** notes skips the step, so today's demo topics keep working.
- **Spike** (`docs/spikes/2026-10-08-pdf-viewer.md`):
  - `pdfrx` 2.4.8 (pinned by Flutter 3.44.1), opened from **memory** (`PdfViewer.data`) and never from a URL, so no plain copy lands in the device cache;
  - the watermark comes from `pageOverlaysBuilder`;
  - text selection is off;
  - the notes route is a **deferred import**, so the 5.2 MB `pdfium.wasm` loads only when a viewer opens;
  - the server-side stamp is **not** part of this story (it is for the book or for a leaked PDF later).

## Goals

1. **Storage.** A private Supabase Storage bucket `notes`, PDF only, with a size limit from `settings.notes_max_mb` (20).
   - The object path is `<topic_id>/<asset_id>.pdf`.
   - Storage RLS: `select` only for a caller with `has_access` to the topic's course **and** the topic open for them (`private.topic_states`), or a teacher. `insert`/`update`/`delete` are teacher-only.
   - No public URLs.
2. **Student reading (L-3).**
   - `get_topic` gains a `notes` list `[{asset_id, title, subtopic_title?, page_count}]` plus a `notes_done` flag.
   - The topic page shows a **Notes** step before Practice. Each item opens the viewer.
   - The viewer downloads the bytes once (`storage.from('notes').download(path)` with the user's JWT; RLS does the check) and renders them from memory.
   - The watermark on every page: the student's full name + their email's local part + the date. It's 25 % grey and tiled diagonally.
   - No selection, no share, no download, no print UI.
   - Leaving the viewer drops the bytes.
   - On first open the client calls `mark_notes_opened(asset_id)`. It's idempotent and sets `notes_opened_at` if it is null. It is allowed only when the asset's topic is open for the caller.
3. **Practice gate.** The server-side practice entry (`get_practice_questions`, and `check_practice_answer` defensively) raises the **new** error code `notes_needed` when the topic has ≥ 1 notes asset and `notes_opened_at` is null. The topic page shows Practice as locked with "Open the notes first."
4. **Teacher upload (C-3 notes).** A **Notes** section per topic, inside the course builder's topic row menu: "Notes…".
   - It lists the notes (title, optional subtopic, page count) with upload, rename, reorder and delete.
   - Upload flow:
     - pick a PDF (reuse `FilePickerService`, extended to return bytes and the content type);
     - the client reads the page count with `pdfrx` (for display only);
     - `teacher_create_notes_asset(topic_id, subtopic_id?, title, page_count)` returns `{asset_id, path}`;
     - the client uploads to that path;
     - `teacher_confirm_notes_asset(asset_id)` checks that the object exists, then marks the asset ready.
   - Unconfirmed assets are invisible to students. Delete removes the row and the storage object.
   - Every write is audited.

## Non-goals

- Teacher's book (CRS-05), the server-side PDF stamp, and DRM.
- Video (L-2), which is blocked on the R2 account and content.
- Android/iOS screenshot blocking (SEC-03, separate story). This story is verified on web; mobile builds compile but get no device check.
- Offline reading and annotations.

## Anti-goals

- A plain, un-watermarked copy of the PDF in the browser or device cache. Use memory mode only; never `PdfViewer.uri`.
- A student opening notes of a locked or un-enrolled topic, by guessing the path or the asset id (pgTAP + storage policy test).
- Practice getting stuck on a topic that has no notes.
- The landing or other routes loading `pdfium.wasm` (deferred import).

## Decisions (router's calls)

| # | Decision |
|---|----------|
| D1 | Storage RLS, not an Edge Function. `download()` with the user's JWT goes through the storage policy, which calls `private.notes_object_readable(name)` (security definer: parses `topic_id`/`asset_id` from the path; access + topic open + asset confirmed, or teacher). This needs no secret and no signed-URL TTL. |
| D2 | `topic_assets` gains `ready boolean not null default false` and `updated_at`. Students only ever see `ready` notes. |
| D3 | New error code `notes_needed` (`docs/07` §9, `ErrorCodes`). |
| D4 | Watermark text: `"<full name> · <email local part> · <yyyy-MM-dd>"`. The phone isn't stored yet. Direction-aware text (rule 8). |
| D5 | Max size comes from `settings.notes_max_mb` (20), checked on the client (UX) and enforced by the bucket's `file_size_limit`. The mime type is limited to `application/pdf`. |
| D6 | `docs/15` §0 gains row 9 (notes per topic or per subtopic) to match board `Q-16`. |

## Constraints

- CLAUDE.md rules 1–10, A, B; `docs/16` §2; SQL from templates; pgTAP with the `reset role` rule.
- pgTAP:
  - The storage policy: enrolled + open → can select; locked → cannot; not enrolled → cannot; teacher → can.
  - `mark_notes_opened`: idempotent; refuses a locked topic.
  - The practice gate: has notes + not opened → `notes_needed`; opened → ok; no notes → ok.
  - Teacher RPCs: forbidden for students; confirm fails when the object is missing.
- Codex can't run Docker or Flutter. Claude runs the gates; CI runs pgTAP on a **draft** PR. The PR stays draft until CI is green.

## Left to the builder

- The exact viewer chrome (page counter, zoom), following `docs/design/claude-design-export/Content and Help.dc.html`.
- How the topic page lays out the Notes step (`Learning Path.dc.html`).
- Whether reorder uses up/down buttons (like the builder) or drag.
