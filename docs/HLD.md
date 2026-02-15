# StyleAgent — HLD (MVP: Capture One)

## 1. Purpose
StyleAgent MVP generates **Capture One Styles (.costyle)** from a structured specification (StyleSpec), applying safe policies so styles are **reproducible** across photos and do not depend on camera/lens specifics.

Primary outcomes:
- Create a style definition (StyleSpec)
- Compile/export a .costyle artifact
- Store versions and artifacts for later reuse and selling

## 2. Scope (MVP)
### In scope
- Backend (FastAPI) API:
  - create style + versions
  - compile/export to Capture One `.costyle`
  - list/download artifacts
- Safe Policy system:
  - remove disallowed keys by default (LensLightFallOff, WhiteBalance*)
- Local filesystem storage (no S3 yet)
- Synchronous compilation (queue optional later)

### Out of scope
- Lightroom presets
- DaVinci LUTs
- PRO render automation
- Multi-user auth and billing
- Frontend UI (optional later)

## 3. Users & Roles
- **Creator (you)**: defines looks and exports `.costyle`
- **System (StyleAgent)**: validates, compiles and stores artifacts

## 4. Architecture Overview
### Components
1) **FastAPI Backend**
   - REST endpoints
   - validation (Pydantic)
   - exporter pipeline
   - local artifact store

2) **Capture One Exporter**
   - transforms StyleSpec → `.costyle` XML format
   - applies SafePolicy rules

3) **Storage**
   - local directory structure
   - metadata index (JSON + later Postgres)

### High-level Data Flow
1) Client sends StyleSpec to `/styles/{id}/versions`
2) Backend validates + persists version
3) Client calls `/styles/{id}/versions/{v}/compile?target=captureone`
4) Exporter generates `.costyle`
5) SafePolicy removes disallowed keys
6) Artifact is saved + returned for download

## 5. Key Design Decisions (MVP)
### D1 — StyleSpec is the single source of truth
We store the abstract style intent as JSON (Pydantic). `.costyle` is a generated artifact.

### D2 — “Safe by default”
Default safe policy removes:
- `LensLightFallOff`
- `WhiteBalance`, `WhiteBalanceTemperature`, `WhiteBalanceTint`

Optional safe removals (configurable):
- absolute `Exposure` (if we detect it’s too image-dependent)

### D3 — Deterministic artifacts
Exporter output should be stable:
- consistent ordering of keys
- stable XML formatting
- stable artifact naming

## 6. Non-functional Requirements
- **Reproducibility**: same StyleSpec must generate same `.costyle`
- **Traceability**: every artifact points to style version + timestamp
- **Testability**: safe policy + exporter must be unit-tested
- **Extensibility**: later add Lightroom/LUT without redesign

## 7. Risks & Constraints
- Capture One `.costyle` is a custom XML-like format; keys and semantics can be app-version dependent.
- Some parameters may not translate 1:1 from an abstract spec.
- We mitigate by:
  - supporting “template-based export” (read a baseline `.costyle`, patch values)
  - enforcing safe policy to avoid brittle/lens-specific settings
