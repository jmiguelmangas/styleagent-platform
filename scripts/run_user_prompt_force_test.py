#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import time
import urllib.request
from collections import Counter, defaultdict
from dataclasses import dataclass
from http.client import RemoteDisconnected
from pathlib import Path
from statistics import mean
from urllib.error import HTTPError, URLError

API_BASE_URL = 'http://localhost:8000'
WATCH_KEYS = (
    'Exposure',
    'Contrast',
    'Saturation',
    'Clarity',
    'Highlights',
    'Shadows',
    'WhiteBalanceTemperature',
    'WhiteBalanceTint',
    'ColorBalanceRed',
    'ColorBalanceGreen',
    'ColorBalanceBlue',
    'ToneCurve',
)


@dataclass(frozen=True)
class PromptCase:
    family_id: str
    prompt: str
    expected_intensity: str | None = None


def request(method: str, path: str, payload: dict | None = None, timeout: int = 180) -> dict | str:
    last_error: Exception | None = None
    for attempt in range(5):
        try:
            data = None if payload is None else json.dumps(payload).encode()
            req = urllib.request.Request(
                f'{API_BASE_URL}{path}',
                data=data,
                method=method,
                headers={'Content-Type': 'application/json'},
            )
            with urllib.request.urlopen(req, timeout=timeout) as response:
                raw = response.read()
                ctype = response.headers.get('Content-Type', '')
                if 'application/json' in ctype or raw.startswith((b'{', b'[')):
                    return json.loads(raw.decode())
                return raw.decode(errors='replace')
        except (HTTPError, URLError, ConnectionError, RemoteDisconnected) as exc:
            last_error = exc
            if attempt == 4:
                raise
            time.sleep(1.5)
    raise RuntimeError(f'request failed unexpectedly: {last_error}')


def wait_for_health(timeout_seconds: int = 120) -> None:
    deadline = time.time() + timeout_seconds
    while time.time() < deadline:
        try:
            backend = request('GET', '/health', timeout=10)
            ai = request('GET', '/ai/health', timeout=10)
            if isinstance(backend, dict) and backend.get('status') == 'ok' and isinstance(ai, dict):
                return
        except Exception:
            pass
        time.sleep(1.5)
    raise TimeoutError('backend or AI health did not become ready in time')


def family_cases() -> list[PromptCase]:
    families: list[tuple[str, str, str]] = [
        ('cinematic_portrait', 'cinematic portrait with cool teal shadows, warm skin and soft highlight rolloff', 'retrato cinematográfico con sombras teal y piel cálida'),
        ('gothic_fantasy', 'gothic fantasy portrait with moonlit blue, porcelain skin and twisted whimsy', 'retrato de fantasía gótica con luz de luna azul y piel porcelana'),
        ('vivid_documentary', 'vivid documentary travel portrait with rich reds, warm earth and natural skin', 'retrato documental de viaje con rojos ricos y tonos tierra cálidos'),
        ('portra_film', 'kodak portra inspired portrait with soft highlights, gentle warmth and natural skin', 'retrato tipo portra con calidez suave y piel natural'),
        ('night_neon', 'tokyo night portrait with neon reflections, cool shadows and warm face tones', 'retrato nocturno urbano con reflejos neón y sombras frías'),
        ('editorial_fashion', 'editorial fashion portrait with sculpted contrast, muted color and polished skin', 'retrato editorial de moda con contraste esculpido y color apagado'),
        ('moody_monochrome', 'deep monochrome portrait with dramatic matte blacks and sculpted tonal contrast', 'retrato monocromo profundo con negros mate y contraste tonal'),
        ('pastel_airy', 'soft airy portrait with luminous skin, delicate pastel softness and lifted blacks', 'retrato suave y aireado con piel luminosa y pastel delicado'),
        ('travel_earth', 'travel portrait with dusty air, warm earth tones and restrained documentary realism', 'retrato de viaje con aire polvoriento y tonos tierra'),
        ('aerial_coastline', 'drone aerial of a chalk coastline with deep cyan sea, midday glare and crisp edges', 'toma aérea de costa con mar cian profundo y bordes nítidos'),
        ('clean_commercial', 'clean commercial portrait with bright whites, restrained color and polished clarity', 'retrato comercial limpio con blancos brillantes y claridad pulida'),
        ('food_rich_color', 'restaurant food photo with firelit warmth, glossy sauce and rich charred texture', 'foto gastronómica con calidez de fuego y textura tostada'),
        ('crisp_winter', 'minimal winter architecture scene with clean whites, cold steel and soft blue daylight', 'escena invernal minimalista con blancos limpios y acero frío'),
        ('jazz_club', 'moody jazz club portrait with red velvet light, brass glow and smoky shadows', 'retrato en club de jazz con luz de terciopelo rojo y humo'),
        ('underwater_editorial', 'underwater editorial portrait with aqua caustics, pearlescent skin and drifting fabric', 'retrato editorial bajo el agua con cáusticas aqua y piel perlada'),
        ('moody_woodland', 'moody woodland portrait with moonlit pines, ember warmth and shadowed trails', 'retrato de bosque oscuro con pinos a la luna y senderos en sombra'),
        ('soft_film_matte', 'soft film matte portrait with nostalgic color, gentle contrast and lifted shadows', 'retrato matte de película con color nostálgico y sombras levantadas'),
        ('emotive_matte', 'emotive matte portrait with washed contrast, soft color and nostalgic softness', 'retrato matte emotivo con contraste lavado y suavidad nostálgica'),
        ('clean_beauty', 'clean beauty portrait with luminous skin, low color cast and soft tonal shaping', 'retrato beauty limpio con piel luminosa y color cast bajo'),
        ('minimal_scandi', 'minimal scandinavian interior look with neutral tones and soft contrast', 'look escandinavo minimalista con tonos neutros y contraste suave'),
    ]

    template_specs: list[tuple[str, str | None]] = [
        ('I want a {}.', None),
        ('Make it subtle: {}.', 'subtle'),
        ('Make it bold: {}.', 'bold'),
        ('Quiero un look de {}.', None),
        ('Keep it natural: {}.', 'subtle'),
    ]

    cases: list[PromptCase] = []
    for family_id, english_anchor, spanish_desc in families:
        anchors = [english_anchor, english_anchor, english_anchor, spanish_desc, english_anchor]
        for (template, expected_intensity), anchor in zip(template_specs, anchors, strict=True):
            cases.append(PromptCase(family_id=family_id, prompt=template.format(anchor), expected_intensity=expected_intensity))
    assert len(cases) == 100
    return cases


def family_signature_ok(family_id: str, keys: dict[str, int | float | str]) -> bool:
    checks = {
        'cinematic_portrait': lambda k: float(k.get('Contrast', 0)) >= 10 and float(k.get('Clarity', 0)) >= 9,
        'gothic_fantasy': lambda k: k.get('ToneCurve') == 'Film Extra Shadow' and float(k.get('WhiteBalanceTemperature', 9999)) <= 4600,
        'vivid_documentary': lambda k: float(k.get('Contrast', 0)) >= 9 and float(k.get('ColorBalanceRed', 0)) >= 4,
        'portra_film': lambda k: float(k.get('WhiteBalanceTemperature', 0)) >= 5800 and float(k.get('ColorBalanceRed', 0)) >= 4,
        'night_neon': lambda k: float(k.get('Contrast', 0)) >= 10 and float(k.get('ColorBalanceBlue', 0)) >= 0,
        'editorial_fashion': lambda k: float(k.get('Contrast', 0)) >= 9 and float(k.get('Clarity', 0)) >= 7,
        'moody_monochrome': lambda k: float(k.get('Saturation', 99)) <= 1,
        'pastel_airy': lambda k: float(k.get('Shadows', 0)) >= 10 and float(k.get('Contrast', 99)) <= 10,
        'travel_earth': lambda k: float(k.get('WhiteBalanceTemperature', 0)) >= 5600 and float(k.get('ColorBalanceRed', 0)) >= 4,
        'aerial_coastline': lambda k: float(k.get('Contrast', 0)) >= 8 and float(k.get('Clarity', 0)) >= 7,
        'clean_commercial': lambda k: float(k.get('Clarity', 0)) >= 8 and float(k.get('Saturation', 99)) <= 8,
        'food_rich_color': lambda k: float(k.get('WhiteBalanceTemperature', 0)) >= 5700 and float(k.get('Saturation', 0)) >= 7,
        'crisp_winter': lambda k: float(k.get('WhiteBalanceTemperature', 9999)) <= 5500 and float(k.get('Clarity', 0)) >= 11,
        'jazz_club': lambda k: float(k.get('Contrast', 0)) >= 8 and float(k.get('ColorBalanceRed', 0)) >= 4,
        'underwater_editorial': lambda k: float(k.get('Contrast', 0)) >= 8 and float(k.get('WhiteBalanceTemperature', 9999)) <= 5620,
        'moody_woodland': lambda k: float(k.get('Contrast', 0)) >= 9 and float(k.get('Highlights', 99)) <= -11,
        'soft_film_matte': lambda k: float(k.get('Contrast', 99)) <= 8 and float(k.get('Shadows', 0)) >= 12,
        'emotive_matte': lambda k: float(k.get('Contrast', 99)) <= 8 and float(k.get('Clarity', 99)) <= 6,
        'clean_beauty': lambda k: float(k.get('Exposure', -99)) >= 0.15 and float(k.get('Clarity', 99)) <= 8,
        'minimal_scandi': lambda k: float(k.get('Saturation', 99)) <= 5 and float(k.get('Contrast', 99)) <= 8,
    }
    return checks[family_id](keys)


def run_force_test(output_dir: Path) -> dict:
    wait_for_health()
    cases = family_cases()
    output_dir.mkdir(parents=True, exist_ok=True)
    case_dir = output_dir / 'cases'
    case_dir.mkdir(parents=True, exist_ok=True)

    results = []
    family_pass = defaultdict(lambda: {'total': 0, 'passed': 0})
    family_counter = Counter()

    for index, case in enumerate(cases, start=1):
        print(f'[{index:03d}/100] {case.family_id}')
        started = time.time()
        response = request(
            'POST',
            '/ai/generate-style-spec',
            {'prompt': case.prompt, 'target': 'captureone'},
        )
        assert isinstance(response, dict)
        planner = response.get('planner_trace') or {}
        keys = response.get('style_spec', {}).get('captureone', {}).get('keys', {})
        actual_family = planner.get('family_id')
        actual_intensity = planner.get('intensity')
        key_count = sum(1 for key in WATCH_KEYS if key in keys)
        failures: list[str] = []

        if response.get('fallback_used'):
            failures.append('fallback_used')
        if actual_family != case.family_id:
            failures.append(f'family={actual_family}')
        if case.expected_intensity and actual_intensity != case.expected_intensity:
            failures.append(f'intensity={actual_intensity}')
        if key_count < len(WATCH_KEYS):
            failures.append(f'keys={key_count}')
        if not family_signature_ok(case.family_id, keys):
            failures.append('signature')

        passed = not failures
        family_pass[case.family_id]['total'] += 1
        family_pass[case.family_id]['passed'] += int(passed)
        family_counter[actual_family or 'unknown'] += 1

        result = {
            'index': index,
            'prompt': case.prompt,
            'expected_family': case.family_id,
            'expected_intensity': case.expected_intensity,
            'actual_family': actual_family,
            'actual_intensity': actual_intensity,
            'generation_ms': response.get('generation_ms'),
            'roundtrip_ms': round((time.time() - started) * 1000),
            'fallback_used': response.get('fallback_used'),
            'warnings': response.get('warnings', []),
            'key_count': key_count,
            'keys': keys,
            'planner_trace': planner,
            'passed': passed,
            'failures': failures,
        }
        results.append(result)
        (case_dir / f'{index:03d}-{case.family_id}.json').write_text(json.dumps(result, indent=2))
        time.sleep(0.1)

    passed_count = sum(1 for result in results if result['passed'])
    summary = {
        'timestamp': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
        'suite': 'user_force_100',
        'total_cases': len(results),
        'passed_cases': passed_count,
        'failed_cases': len(results) - passed_count,
        'pass_rate': round((passed_count / len(results)) * 100, 1),
        'avg_generation_ms': round(mean(result['generation_ms'] or 0 for result in results), 1),
        'avg_roundtrip_ms': round(mean(result['roundtrip_ms'] for result in results), 1),
        'family_breakdown': dict(family_pass),
        'actual_family_counts': dict(family_counter),
        'failures': [
            {
                'index': result['index'],
                'prompt': result['prompt'],
                'expected_family': result['expected_family'],
                'actual_family': result['actual_family'],
                'expected_intensity': result['expected_intensity'],
                'actual_intensity': result['actual_intensity'],
                'failures': result['failures'],
            }
            for result in results
            if not result['passed']
        ],
    }
    (output_dir / 'summary.json').write_text(json.dumps(summary, indent=2))

    lines = [
        '# User Prompt Force Test',
        '',
        f"Timestamp: {summary['timestamp']}",
        f"Total cases: `{summary['total_cases']}`",
        f"Passed: `{summary['passed_cases']}`",
        f"Failed: `{summary['failed_cases']}`",
        f"Pass rate: `{summary['pass_rate']}%`",
        f"Average generation ms: `{summary['avg_generation_ms']}`",
        f"Average roundtrip ms: `{summary['avg_roundtrip_ms']}`",
        '',
        '## Family Breakdown',
        '',
    ]
    for family_id, stats in sorted(summary['family_breakdown'].items()):
        lines.append(f"- `{family_id}`: `{stats['passed']}/{stats['total']}`")
    lines.extend(['', '## Failures', ''])
    if not summary['failures']:
        lines.append('- none')
    else:
        for failure in summary['failures']:
            lines.append(
                f"- `#{failure['index']:03d}` expected `{failure['expected_family']}` got `{failure['actual_family']}`"
                f" failures={failure['failures']} prompt=`{failure['prompt']}`"
            )
    (output_dir / 'REPORT.md').write_text('\n'.join(lines) + '\n')
    return summary


def main() -> int:
    parser = argparse.ArgumentParser(description='Run 100 user-like prompt force tests against AI generation.')
    parser.add_argument(
        '--output-dir',
        default=str(
            Path('/Users/josemiguelmangas/PROGRAMACION/styleagent/styleagent-platform/.artifacts/user-force')
            / f'pass-{time.strftime('%Y-%m-%d')}'
        ),
        help='Directory where outputs will be written.',
    )
    args = parser.parse_args()
    summary = run_force_test(Path(args.output_dir))
    print(json.dumps({'output_dir': args.output_dir, 'pass_rate': summary['pass_rate'], 'failed_cases': summary['failed_cases']}, indent=2))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
