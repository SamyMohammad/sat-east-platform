# ADR-004: Desmos calculator in the exam engine

**Status:** Proposed · **Date:** 2026-10-05 · **Deciders:** Teacher (cost), Developer

## Context
The digital SAT provides the Desmos graphing calculator; realistic mocks require the same tool.
Desmos's API terms allow free use only for personal non-commercial use or a 90-day trial for
internal evaluation; any production app used by end users is commercial use and needs a paid plan
(Starter: Desmos-hosted, basic integration; Enterprise: full integration, optional self-hosting).
Sources: https://www.desmos.com/api-terms · https://help.desmos.com/hc/en-us/articles/49078363315725

## Decision
Integrate the **Desmos API (graphing calculator)** under a paid commercial plan — Starter is
expected to suffice (we only need a blank calculator per module, no saved content).

## Options considered
| Option | Pros | Cons |
|---|---|---|
| Desmos API, paid (proposed) | Identical to exam experience | Recurring cost; needs WebView on mobile |
| Link out to desmos.com | Free | Breaks exam realism; students leave the app; not allowed to frame without consent |
| Open-source graphing (e.g. GeoGebra/JSXGraph) | Possibly cheaper | Not what students get on test day; GeoGebra also has commercial terms |

## Implementation notes
- Flutter mobile: `webview_flutter` / `flutter_inappwebview` loading a local HTML page that includes the Desmos script with the API key.
- Flutter web: `HtmlElementView` hosting a div with the calculator.
- Calculator state saved per module (`getState`/`setState`) into the attempt `meta` so it survives reconnects.

## Action items
1. [ ] Teacher: request trial key and pricing from Desmos (partnerships contact).
2. [ ] Developer: 1-day spike on web + Android + iOS within the trial window — start the trial close to Phase 3, since it is 90 days.
