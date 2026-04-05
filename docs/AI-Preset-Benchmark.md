# AI Preset Benchmark

## Purpose

This benchmark gives StyleAgent a repeatable way to evaluate preset quality.

It is designed to answer three questions:
- Does the generated preset match the requested creative direction?
- Is the preset numerically reasonable and usable in Capture One?
- Does the result stay consistent across prompt, intensity, and export paths?

This document is the baseline for manual review first. It can later be extended into automated scoring and image-based evaluation.

## Scope

Current benchmark covers:
- prompt -> `style_spec` generation
- `subtle` / `balanced` / `bold` intensity behavior
- save + export path to `.costyle`
- qualitative review of creative direction
- natural-language robustness through the 100-prompt user force test

Current benchmark does not yet cover:
- rendered image comparison
- full visual A/B scoring on a standard image set
- Capture One side-by-side visual validation at scale

## Evaluation Workflow

Run one of these flows:

```bash
cd /Users/josemiguelmangas/PROGRAMACION/styleagent/styleagent-platform
make up
```

For local real-model validation:

```bash
make smoke-ollama
```

For manual prompt inspection:

```bash
curl -X POST http://localhost:8000/ai/debug/prompt-preview \
  -H "Content-Type: application/json" \
  -d '{"prompt":"cinematic portrait with cool teal shadows","intent":["cinematic","portrait"]}'
```

For broad natural-language validation against user-style prompts:

```bash
make force-test
```

This writes a run under:

```bash
/Users/josemiguelmangas/PROGRAMACION/styleagent/styleagent-platform/.artifacts/user-force/
```

Each run contains:
- `summary.json`
- `REPORT.md`
- one JSON file per case under `cases/`

For each benchmark prompt:
1. Generate with `subtle`
2. Generate with `balanced`
3. Generate with `bold`
4. Save preset
5. Export `.costyle`
6. Review the generated `style_spec`
7. Review whether the exported `.costyle` still contains the expected keys
8. Score using the rubric below

## User Force Test

The force test complements `canon`, `stress`, and `expansion`.

Purpose:
- simulate the way a real user actually asks for looks
- catch planner drift on short prompts, mixed descriptors, and Spanish phrasing
- validate that intensity words in the prompt are interpreted correctly

Current force-test suite:
- `100` prompts
- `20` creative families
- `5` phrasing variants per family:
  - plain English
  - `Make it subtle`
  - `Make it bold`
  - plain Spanish
  - `Keep it natural`

Tracked checks:
- expected family match
- expected intensity when the prompt explicitly asks for one
- no fallback
- all tracked Capture One keys present
- family-specific numeric signature still looks plausible

Validated progression:
- baseline:
  - `/Users/josemiguelmangas/PROGRAMACION/styleagent/styleagent-platform/.artifacts/user-force/pass-2026-04-05/summary.json`
  - `66%`
- first planner hardening:
  - `/Users/josemiguelmangas/PROGRAMACION/styleagent/styleagent-platform/.artifacts/user-force/pass-2026-04-05b/summary.json`
  - `80%`
- second planner pass:
  - `/Users/josemiguelmangas/PROGRAMACION/styleagent/styleagent-platform/.artifacts/user-force/pass-2026-04-05c/summary.json`
  - `89%`
- current validated baseline:
  - `/Users/josemiguelmangas/PROGRAMACION/styleagent/styleagent-platform/.artifacts/user-force/pass-2026-04-05d/summary.json`
  - `100%`

Use this suite when:
- you change family matching
- you change intensity interpretation
- you add new prompt aliases or multilingual normalization

Use `canon/stress/expansion` when:
- you are calibrating artistic quality and monotonicity more than raw prompt robustness

## Scoring Rubric

Score each axis from `1` to `5`.

### 1. Creative Match
How well the preset matches the requested look.

- `1`: clearly wrong direction
- `2`: weak match, only a few signals are right
- `3`: generally correct but still generic or incomplete
- `4`: strong match with clear style identity
- `5`: very convincing and production-usable

### 2. Parameter Richness
How complete and useful the preset is.

Look for meaningful use of:
- exposure / contrast
- saturation / clarity
- highlights / shadows
- white balance
- color balance
- tone curve

- `1`: almost empty or trivial preset
- `2`: only basic controls used
- `3`: decent range of controls, still limited
- `4`: rich and coherent preset
- `5`: rich, coherent, and clearly intentional

### 3. Numerical Quality
Whether values feel sane for real-world use.

Watch for values that are too extreme or too timid.

- `1`: broken or absurd values
- `2`: clearly overcooked or too flat
- `3`: usable but needs hand correction
- `4`: strong default values
- `5`: excellent out-of-the-box balance

### 4. Intensity Separation
Whether `subtle`, `balanced`, and `bold` meaningfully differ.

- `1`: barely any difference
- `2`: weak separation
- `3`: some difference, still compressed
- `4`: clear and useful separation
- `5`: excellent progression across modes

### 5. Export Fidelity
Whether the saved/exported `.costyle` preserves the important generated adjustments.

- `1`: export loses most of the preset
- `2`: export keeps only a minimal subset
- `3`: export keeps enough, but some important intent is lost
- `4`: export keeps most important parameters
- `5`: export reliably preserves the creative intent

### 6. Overall Usefulness
Would a photographer actually keep and refine this preset?

- `1`: no
- `2`: probably not
- `3`: maybe as a rough starting point
- `4`: yes, useful base preset
- `5`: yes, strong starting point or better

## Benchmark Prompt Set

These prompts are the initial canon set for iterative evaluation.

### A. Cinematic / Portrait
1. `cinematic portrait with cool teal shadows, warm skin, soft highlight rolloff`
2. `gothic fantasy portrait with moonlit blue, porcelain skin and twisted whimsy`
3. `editorial fashion portrait with sculpted contrast, muted color and polished skin`

### B. Documentary / Travel
4. `vivid documentary travel portrait with rich reds, warm earth and natural skin`
5. `national geographic inspired environmental portrait with warm dust, vivid fabrics and honest skin tones`
6. `street portrait with realism, crisp texture and restrained color`

### C. Film / Analog
7. `kodak portra inspired portrait with soft highlights, gentle warmth and natural skin`
8. `ektar inspired travel image with punchy reds, vivid blue sky and crisp detail`
9. `vintage faded film look with lifted blacks, soft contrast and nostalgic color`

### D. Neon / Night / Urban
10. `tokyo night portrait with neon reflections, cool shadows and warm face tones`
11. `wet streets cinematic night scene with blue ambience and amber practical lights`
12. `cyberpunk portrait with teal shadows, magenta accents and glossy contrast`

### E. Seasonal / Landscape
13. `cozy autumn forest landscape with warm foliage, soft haze and rich earth tones`
14. `crisp winter landscape with cold air, clean whites and restrained saturation`
15. `golden hour mountain scene with luminous highlights and soft depth`

### F. Commercial / Beauty / Clean
16. `clean beauty portrait with luminous skin, low color cast and soft tonal shaping`
17. `commercial lifestyle image with bright whites, natural warmth and polished clarity`
18. `minimal scandinavian interior look with neutral tones and soft contrast`

### G. Food / Product / Specialty
19. `rich food photography preset with appetizing warmth, strong texture and clean shadows`
20. `high-end product shot with crisp edges, restrained color and premium tonal contrast`

## Prompt Families To Track Over Time

Keep the benchmark balanced across these families:
- cinematic portrait
- documentary portrait
- editorial fashion
- film emulation
- neon night
- seasonal landscape
- clean commercial
- specialty product / food

If a future change improves one family but damages another, it should be treated as a regression.

## Expansion Suite

Use the expansion suite for newer families that are backed by curated preset packs but are not part of the CI gate yet.

Current expansion families:
- moody woodland
- soft airy portrait
- soft film matte
- editorial teal-orange
- emotive matte
- muted urban soft

Promoted into `stress` after calibration:
- rainy urban night
- deep monochrome

Recommended command:

```bash
python3 /Users/josemiguelmangas/PROGRAMACION/styleagent/styleagent-platform/scripts/run_preset_benchmark.py --suite expansion --output-dir /Users/josemiguelmangas/PROGRAMACION/styleagent/styleagent-platform/.artifacts/benchmark/expansion-pass-$(date +%Y-%m-%d)
```

Use `--suite all` when you want one combined run with:
- `canon`
- `stress`
- `expansion`

## Expected Signals Per Family

### Cinematic portrait
Expect:
- moderate to strong contrast
- controlled highlights
- shaped shadows
- meaningful warm/cool separation
- some curve character

### Documentary portrait
Expect:
- believable skin
- vibrant but not cartoonish color
- usable clarity
- warm earth / textile response when requested
- less stylization than editorial or cinematic

### Film emulation
Expect:
- coherent warmth/coolness
- more tonal character than generic digital looks
- softer highlight handling
- some color bias consistent with the requested stock

### Neon night
Expect:
- strong cool side of the palette
- preserved skin warmth where relevant
- deeper contrast, but not crushed unusably
- clear separation from normal cinematic portrait

### Clean commercial / beauty
Expect:
- restrained color casts
- luminous but not flat tonality
- moderate clarity
- fewer dramatic moves than cinematic, gothic, or neon looks

## Failure Modes To Watch

Flag these immediately:
- preset only changes exposure and contrast
- white balance gets removed unexpectedly
- all three intensity modes look nearly identical
- values become extreme when profiles mix
- documentary prompts become too stylized
- cinematic prompts stay too generic
- export loses key parameters from `style_spec`
- model copies artist names without translating them into visual traits

## Review Template

Use this table for each prompt.

```text
Prompt:
Intensity: subtle | balanced | bold

Creative Match:  /5
Parameter Richness:  /5
Numerical Quality:  /5
Intensity Separation:  /5
Export Fidelity:  /5
Overall Usefulness:  /5

What worked:
- 

What felt wrong:
- 

Keys worth checking:
- Exposure:
- Contrast:
- Saturation:
- Clarity:
- Highlights:
- Shadows:
- WhiteBalanceTemperature:
- WhiteBalanceTint:
- ColorBalanceRed:
- ColorBalanceGreen:
- ColorBalanceBlue:
- ToneCurve:
```

## Recommended First Benchmark Pass

Start with these five prompts first:
1. `cinematic portrait with cool teal shadows, warm skin, soft highlight rolloff`
2. `gothic fantasy portrait with moonlit blue, porcelain skin and twisted whimsy`
3. `vivid documentary travel portrait with rich reds, warm earth and natural skin`
4. `kodak portra inspired portrait with soft highlights, gentle warmth and natural skin`
5. `tokyo night portrait with neon reflections, cool shadows and warm face tones`

These five give a good first read on:
- profile mixing
- intensity differentiation
- color richness
- realism vs stylization
- export fidelity

## Next Evolution

Once the manual benchmark is stable, extend it with:
- stored benchmark results under `.artifacts/benchmark/`
- automated JSON diff checks for key fields
- standard review image set
- image render comparison after preset application
- prompt version tracking in generation history
