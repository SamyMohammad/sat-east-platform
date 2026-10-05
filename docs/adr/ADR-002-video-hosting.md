# ADR-002: Video hosting with DRM and dynamic watermark

**Status:** Proposed · **Date:** 2026-10-05 · **Deciders:** Teacher (cost), Developer

## Context
Paid course videos are the main leak risk. Need: DRM streaming, per-student dynamic watermark,
playback on Flutter web/Android/iOS, pay-as-you-go pricing for a small start.
YouTube (unlisted) and Google Drive were rejected: links are shareable, no per-user watermark,
Drive is not built for streaming at scale and allows download.

## Decision
Use **VdoCipher** (DRM + dynamic annotation watermark, Flutter SDK). Keep Bunny Stream as fallback.

## Options considered

### A: VdoCipher (proposed)
| Dimension | Assessment |
|---|---|
| Complexity | Low (OTP API + SDK) |
| Cost | Higher per-GB/plan than Bunny — check current pricing |
| Security | Strong: Widevine/FairPlay DRM, dynamic watermark built-in |
| Familiarity | Common in Egyptian/MENA ed-tech |

### B: Bunny Stream
Cheaper; token auth + optional DRM; watermark needs custom overlay. Weaker against screen capture attribution.

### C: Mux
Excellent DX and signed playback; DRM and watermark require more work; pricing in USD per minute.

## Consequences
- Every playback goes through `video-otp` EF (access check + watermark with name/phone/short id).
- Verify the Flutter SDK's **web** support; fallback is the VdoCipher web player inside an iframe (HtmlElementView).
- Costs scale with watch-minutes — monitor monthly.

## Action items
1. [ ] Teacher: open account, confirm current pricing/plan.
2. [ ] Spike (1 day): play a DRM video with watermark on web, Android, iOS from Flutter.
3. [ ] Naming convention for uploads: `SAT_T05_Linear_03_Parallel-Perpendicular.mp4`.
