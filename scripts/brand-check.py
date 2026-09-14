#!/usr/bin/env python3
"""Offline brand validation: tokens, asset integrity, contrast and new visual literals."""
import collections
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = (ROOT / 'apps/webapp').is_dir()
DESIGN = ROOT / ('design-system' if WEB else 'packages/edaya_shared/design-system')
SOURCES = [ROOT / 'apps/webapp/src'] if WEB else [ROOT / 'apps/guardian/lib', ROOT / 'apps/teacher/lib', ROOT / 'packages/edaya_shared/lib']
ASSETS = [ROOT / 'apps/webapp/static/brand', ROOT / 'apps/webapp/static/fonts', ROOT / 'apps/webapp/src/lib/assets/favicon.svg'] if WEB else [ROOT / 'packages/edaya_shared/assets', DESIGN / 'logos', ROOT / 'branding/icons']
ASSETS += [ROOT / f'apps/{app}/{part}' for app in ('guardian','teacher') for part in ('android/app/src/main/res','ios/Runner/Assets.xcassets','web/icons','web/favicon.png')] if not WEB else []
LITERAL = re.compile(r'Colors\.[A-Za-z]+(?:\.shade\d+)?|#[0-9a-fA-F]{3,8}\b|0x[0-9a-fA-F]{8}\b|(?:bg|text|border|ring|fill|stroke)-(?:red|orange|amber|yellow|lime|green|emerald|teal|cyan|sky|blue|indigo|violet|purple|fuchsia|pink|rose|slate|gray|zinc|neutral|stone)-\d{2,3}\b|(?:rgba?|hsla?)\(\s*\d|(?:text|rounded(?:-[a-z]+)?|shadow|duration|gap|[mp][xytrbl]?)-\[[^\]]+\]|(?:fontSize|letterSpacing|elevation):\s*-?\d+(?:\.\d+)?|BorderRadius\.circular\(\s*\d+(?:\.\d+)?')


def visual_literals():
    counts = collections.Counter()
    for source in SOURCES:
        for path in source.rglob('*'):
            if path.suffix not in ('.svelte', '.ts', '.css', '.dart') or path.name in ('tokens.css', 'edaya_tokens.g.dart'):
                continue
            if '/l10n/' in str(path):
                continue
            text = path.read_text()
            if re.search(r'fonts\.googleapis|GoogleFonts\.|package:google_fonts', text):
                raise ValueError(f'Runtime font loading: {path}')
            if re.search(r'Fraunces|Nunito|GalakRound|JetBrains', text):
                raise ValueError(f'Retired typography: {path}')
            for literal in LITERAL.findall(text):
                counts[f'{path.relative_to(ROOT)}::{literal}'] += 1
    return dict(sorted(counts.items()))


def assets():
    files = []
    for root in ASSETS:
        files.extend([root] if root.is_file() else [p for p in root.rglob('*') if p.is_file() and not p.name.startswith('.')])
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(files)}


def luminance(color):
    values = [int(color[i:i+2],16)/255 for i in (1,3,5)]
    values = [v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in values]
    return sum(a*b for a,b in zip(values,[.2126,.7152,.0722]))


def contrast(a,b):
    x,y=sorted([luminance(a),luminance(b)])
    return (y+.05)/(x+.05)


def main():
    if '--record-reviewed-baseline' in sys.argv:
        (DESIGN/'visual-literals.json').write_text(json.dumps(visual_literals(),indent=2)+'\n')
        (DESIGN/'assets.json').write_text(json.dumps(assets(),indent=2)+'\n')
        print('Recorded reviewed asset and existing-literal inventory. Review this diff explicitly.')
        return
    subprocess.run([sys.executable,str(ROOT/'scripts/brand-tokens.py'),'--check'],check=True)
    manifest=json.loads((DESIGN/'tokens.json').read_text())
    allowed=json.loads((DESIGN/'visual-literals.json').read_text())
    violations=[key for key,count in visual_literals().items() if count>allowed.get(key,0)]
    if violations:raise ValueError('Unreviewed visual literals: '+', '.join(violations))
    expected=json.loads((DESIGN/'assets.json').read_text())
    if assets()!=expected:raise ValueError('Brand asset/font inventory drift: missing, changed or unregistered file')
    required = ['Inter-Variable.woff2','Poppins-SemiBold.woff2'] if WEB else ['Inter-Regular.ttf','Inter-Medium.ttf','Inter-SemiBold.ttf','Inter-Bold.ttf','Poppins-SemiBold.ttf']
    for filename in [*required,'Inter-OFL.txt','Poppins-OFL.txt']:
        if not any(key.endswith('/'+filename) for key in expected):raise ValueError('Missing local font/license: '+filename)
    report=[]
    for mode,colors in manifest['colors'].items():
        for foreground,background in [('foreground','background'),('foreground','card'),('muted-foreground','card'),('muted-foreground','background'),('primary-foreground','primary'),('highlight','highlight-soft'),('success','success-soft'),('destructive','destructive-soft'),('sky','sky-soft')]:
            ratio=contrast(colors[foreground],colors[background])
            if ratio<4.5:raise ValueError(f'{mode} {foreground}/{background}: {ratio:.2f} < 4.5')
            report.append(ratio)
        if contrast(colors['input'],colors['card'])<3:raise ValueError(mode+' control outline fails 3:1')
    print(f"EDAYA {manifest['version']}: assets/fonts intact; no new visual literals; semantic text pairs >= {min(report):.2f}:1")

if __name__=='__main__':
    try:main()
    except (ValueError,subprocess.CalledProcessError) as error:
        print(str(error),file=sys.stderr);sys.exit(1)
