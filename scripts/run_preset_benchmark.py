#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import time
import urllib.request
from http.client import RemoteDisconnected
from pathlib import Path
from statistics import mean
from urllib.error import HTTPError, URLError
from uuid import uuid4


API_BASE_URL = "http://localhost:8000"
INTENSITIES = ("subtle", "balanced", "bold")
WATCH_KEYS = (
    "Exposure",
    "Contrast",
    "Saturation",
    "Clarity",
    "Highlights",
    "Shadows",
    "WhiteBalanceTemperature",
    "WhiteBalanceTint",
    "ColorBalanceRed",
    "ColorBalanceGreen",
    "ColorBalanceBlue",
    "ToneCurve",
)
SUITES: dict[str, list[tuple[str, str]]] = {
    "canon": [
        ("cinematic_portrait", "cinematic portrait with cool teal shadows, warm skin, soft highlight rolloff"),
        ("gothic_fantasy", "gothic fantasy portrait with moonlit blue, porcelain skin and twisted whimsy"),
        ("documentary_travel", "vivid documentary travel portrait with rich reds, warm earth and natural skin"),
        ("kodak_portra", "kodak portra inspired portrait with soft highlights, gentle warmth and natural skin"),
        ("tokyo_night", "tokyo night portrait with neon reflections, cool shadows and warm face tones"),
    ],
    "stress": [
        ("underwater_editorial", "underwater editorial portrait with aqua caustics, pearlescent skin and drifting fabric"),
        ("wildlife_safari", "safari wildlife portrait with dry golden grass, dusty air and restrained documentary realism"),
        ("aerial_coastline", "drone aerial of a chalk coastline with deep cyan sea, midday glare and crisp edges"),
        ("jazz_club", "moody jazz club portrait with red velvet light, brass glow and smoky shadows"),
        ("product_tech", "luxury smartwatch product shot on black acrylic with icy highlights and precise contrast"),
        ("pastel_maternity", "pastel maternity portrait with milky tones, luminous skin and gentle blush warmth"),
        ("snowy_architecture", "minimal winter architecture scene with clean whites, cold steel and soft blue daylight"),
        ("food_firelight", "restaurant food photo with firelit warmth, glossy sauce and rich charred texture"),
    ],
}


def request(method: str, path: str, payload: dict | None = None, timeout: int = 180) -> dict | str:
    last_error: Exception | None = None
    for attempt in range(5):
        try:
            data = None if payload is None else json.dumps(payload).encode()
            req = urllib.request.Request(
                f"{API_BASE_URL}{path}",
                data=data,
                method=method,
                headers={"Content-Type": "application/json"},
            )
            with urllib.request.urlopen(req, timeout=timeout) as response:
                raw = response.read()
                ctype = response.headers.get("Content-Type", "")
                if "application/json" in ctype or raw.startswith((b"{", b"[")):
                    return json.loads(raw.decode())
                return raw.decode(errors="replace")
        except (HTTPError, URLError, ConnectionError, RemoteDisconnected) as exc:
            last_error = exc
            if attempt == 4:
                raise
            time.sleep(1.5)
    raise RuntimeError(f"request failed unexpectedly: {last_error}")


def wait_for_health(timeout_seconds: int = 120) -> None:
    deadline = time.time() + timeout_seconds
    while time.time() < deadline:
        try:
            backend = request("GET", "/health", timeout=10)
            ai = request("GET", "/ai/health", timeout=10)
            if isinstance(backend, dict) and backend.get("status") == "ok" and isinstance(ai, dict):
                return
        except Exception:
            pass
        time.sleep(1.5)
    raise TimeoutError("backend or AI health did not become ready in time")


def slugify(text: str) -> str:
    normalized = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    if len(normalized) <= 48:
        return normalized
    tail = normalized[-8:]
    head = normalized[:39].rstrip("-")
    return f"{head}-{tail}"


def run_suite(name: str, prompts: list[tuple[str, str]], output_dir: Path) -> dict:
    suite_dir = output_dir / name
    (suite_dir / "cases").mkdir(parents=True, exist_ok=True)
    results: list[dict] = []

    for family, prompt in prompts:
        family_dir = suite_dir / "cases" / family
        family_dir.mkdir(parents=True, exist_ok=True)
        rows: list[dict] = []
        print(f"[{name}] {family}")
        for intensity in INTENSITIES:
            print(f"  - {intensity}")
            generated = request(
                "POST",
                "/ai/generate-style-spec",
                {
                    "prompt": prompt,
                    "constraints": {"intensity": intensity},
                    "target": "captureone",
                },
            )
            assert isinstance(generated, dict)
            style_spec = generated["style_spec"]
            style_name = f"Benchmark {name} {family} {intensity} {int(time.time())} {uuid4().hex[:8]}"
            created = request(
                "POST",
                "/styles",
                {"name": style_name, "slug": slugify(style_name)},
            )
            assert isinstance(created, dict)
            style_id = created["style_id"]
            version_created = request(
                "POST",
                f"/styles/{style_id}/versions",
                {
                    "version": "v1",
                    "safe_policy": {"remove_white_balance": False},
                    "style_spec": style_spec,
                },
            )
            assert isinstance(version_created, dict)
            compiled = request(
                "POST",
                f"/styles/{style_id}/versions/v1/compile?target=captureone",
            )
            assert isinstance(compiled, dict)
            artifact_xml = request("GET", compiled["download_url"])
            assert isinstance(artifact_xml, str)

            case_data = {
                "family": family,
                "prompt": prompt,
                "intensity": intensity,
                "generation": generated,
                "style_create": created,
                "version_create": version_created,
                "compile": compiled,
            }
            (family_dir / f"{intensity}.json").write_text(json.dumps(case_data, indent=2))
            (family_dir / f"{intensity}.costyle").write_text(artifact_xml)

            keys = style_spec.get("captureone", {}).get("keys", {})
            exported_keys = [
                key
                for key in WATCH_KEYS
                if (key == "ToneCurve" and f'K="{key}"' in artifact_xml)
                or (key != "ToneCurve" and f'K="{key}"' in artifact_xml)
            ]
            rows.append(
                {
                    "intensity": intensity,
                    "generation_ms": generated.get("generation_ms"),
                    "keys": keys,
                    "exported_keys": exported_keys,
                    "artifact_id": compiled["artifact_id"],
                    "style_id": style_id,
                }
            )
            time.sleep(0.2)

        contrasts = [row["keys"].get("Contrast", 0) for row in rows]
        clarities = [row["keys"].get("Clarity", 0) for row in rows]
        saturations = [row["keys"].get("Saturation", 0) for row in rows]
        highlights = [row["keys"].get("Highlights", 0) for row in rows]
        temps = [row["keys"].get("WhiteBalanceTemperature", 0) for row in rows]
        richness_vals = [sum(1 for key in WATCH_KEYS if key in row["keys"]) for row in rows]
        monotonic = (
            contrasts[0] <= contrasts[1] <= contrasts[2]
            and clarities[0] <= clarities[1] <= clarities[2]
        )
        results.append(
            {
                "family": family,
                "prompt": prompt,
                "cases": rows,
                "metrics": {
                    "avg_generation_ms": round(mean(row["generation_ms"] for row in rows), 1),
                    "avg_richness_keys": round(mean(richness_vals), 1),
                    "all_exports_full": all(set(WATCH_KEYS).issubset(set(row["exported_keys"])) for row in rows),
                    "contrast_monotonic": contrasts[0] <= contrasts[1] <= contrasts[2],
                    "clarity_monotonic": clarities[0] <= clarities[1] <= clarities[2],
                    "saturation_monotonic": saturations[0] <= saturations[1] <= saturations[2],
                    "intensity_monotonic_core": monotonic,
                    "intensity_delta_score": round(
                        abs(contrasts[2] - contrasts[0])
                        + abs(clarities[2] - clarities[0])
                        + abs(saturations[2] - saturations[0])
                        + abs(highlights[2] - highlights[0])
                        + abs(temps[2] - temps[0]) / 200.0,
                        1,
                    ),
                },
            }
        )

    summary = {
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "suite": name,
        "results": results,
    }
    (suite_dir / "summary.json").write_text(json.dumps(summary, indent=2))
    return summary


def render_markdown_report(output_dir: Path, summaries: list[dict]) -> None:
    lines = [
        "# Full Benchmark Report",
        "",
        f"Timestamp: {time.strftime('%Y-%m-%d')}",
        "Model: `ollama / llama3.1:8b`",
        "",
    ]
    for summary in summaries:
        lines.extend([f"## Suite: {summary['suite']}", ""])
        for result in summary["results"]:
            metrics = result["metrics"]
            lines.extend(
                [
                    f"### {result['family']}",
                    f"Prompt: `{result['prompt']}`",
                    "",
                    f"- avg_generation_ms: `{metrics['avg_generation_ms']}`",
                    f"- avg_richness_keys: `{metrics['avg_richness_keys']}`",
                    f"- all_exports_full: `{metrics['all_exports_full']}`",
                    f"- contrast_monotonic: `{metrics['contrast_monotonic']}`",
                    f"- clarity_monotonic: `{metrics['clarity_monotonic']}`",
                    f"- saturation_monotonic: `{metrics['saturation_monotonic']}`",
                    f"- intensity_monotonic_core: `{metrics['intensity_monotonic_core']}`",
                    f"- intensity_delta_score: `{metrics['intensity_delta_score']}`",
                    "",
                ]
            )
    (output_dir / "REPORT.md").write_text("\n".join(lines) + "\n")


def evaluate_gates(
    summaries: list[dict],
    *,
    require_full_exports: bool,
    min_richness_keys: int,
    require_intensity_monotonic_core: bool,
) -> list[str]:
    failures: list[str] = []
    for summary in summaries:
        for result in summary["results"]:
            metrics = result["metrics"]
            family = result["family"]
            suite = summary["suite"]
            if require_full_exports and not metrics["all_exports_full"]:
                failures.append(f"[{suite}] {family}: exported artifact is missing required keys")
            if metrics["avg_richness_keys"] < min_richness_keys:
                failures.append(
                    f"[{suite}] {family}: avg_richness_keys={metrics['avg_richness_keys']} < {min_richness_keys}"
                )
            if require_intensity_monotonic_core and not metrics["intensity_monotonic_core"]:
                failures.append(f"[{suite}] {family}: intensity_monotonic_core is false")
    return failures


def main() -> int:
    parser = argparse.ArgumentParser(description="Run the StyleAgent preset benchmark suites.")
    parser.add_argument(
        "--suite",
        choices=("canon", "stress", "full"),
        default="full",
        help="Benchmark suite to run.",
    )
    parser.add_argument(
        "--output-dir",
        default=str(
            Path("/Users/josemiguelmangas/PROGRAMACION/styleagent/styleagent-platform/.artifacts/benchmark")
            / f"full-pass-{time.strftime('%Y-%m-%d')}"
        ),
        help="Directory where benchmark outputs will be written.",
    )
    parser.add_argument(
        "--enforce-gates",
        action="store_true",
        help="Fail with a non-zero exit code when benchmark gates are not met.",
    )
    parser.add_argument(
        "--min-richness-keys",
        type=int,
        default=len(WATCH_KEYS),
        help="Minimum average number of tracked keys required per family.",
    )
    args = parser.parse_args()

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    wait_for_health()
    selected_suites = ("canon", "stress") if args.suite == "full" else (args.suite,)
    summaries = [run_suite(name, SUITES[name], output_dir) for name in selected_suites]
    render_markdown_report(output_dir, summaries)
    failures = evaluate_gates(
        summaries,
        require_full_exports=True,
        min_richness_keys=args.min_richness_keys,
        require_intensity_monotonic_core=True,
    )
    (output_dir / "gate-results.json").write_text(
        json.dumps({"passed": not failures, "failures": failures}, indent=2)
    )
    if failures:
        print("Benchmark gate failures:")
        for failure in failures:
            print(f"- {failure}")
        if args.enforce_gates:
            return 1
    print(output_dir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
