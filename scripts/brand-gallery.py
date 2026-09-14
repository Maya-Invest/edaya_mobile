#!/usr/bin/env python3
"""Index current review captures with source and viewing provenance (standard library only)."""
import datetime, hashlib, html, json, struct, subprocess
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
WEB = (ROOT/'apps/webapp').is_dir()
VERSION = json.loads((ROOT/('design-system' if WEB else 'packages/edaya_shared/design-system')/'tokens.json').read_text())['version']
REVISION = subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
SOURCES = ['apps/webapp/src','apps/webapp/static','design-system/tokens.json'] if WEB else ['apps/guardian/lib','apps/teacher/lib','packages/edaya_shared/lib','packages/edaya_shared/assets','packages/edaya_shared/design-system/tokens.json']
def digest():
    h=hashlib.sha256()
    for source in SOURCES:
        p=ROOT/source
        for f in sorted([p] if p.is_file() else p.rglob('*')):
            if f.is_file():h.update(str(f.relative_to(ROOT)).encode()+b'\0'+f.read_bytes())
    return h.hexdigest()
SOURCE_DIGEST=digest()
for app in (['webapp'] if WEB else ['guardian','teacher']):
    folder=ROOT/('docs/reference/design-review' if WEB else f'apps/{app}/design-review')
    previous = json.loads((folder/'manifest.json').read_text()).get('captures',[]) if (folder/'manifest.json').exists() else []
    previous = {entry['file']: entry for entry in previous}
    entries=[]
    for image in sorted((folder/'current').glob('*.png')):
        name=image.stem
        data=image.read_bytes()
        if data[:8] != b'\x89PNG\r\n\x1a\n':
            raise SystemExit(f'Encode {image} as PNG before indexing; changing an extension does not convert an image.')
        width,height=struct.unpack('>II',data[16:24])
        desktop='desktop' in name
        viewport=([1440,1000] if name.startswith(('students-','student-')) else [1280,800]) if desktop else ([1024,1366] if 'tablet' in name else [390,844])
        if WEB and name.startswith('components-'):viewport=[1280,1000] if desktop else [390,844]
        composition='components' in name
        entries.append(dict(file=f'current/{image.name}', app=app, sourceRevision=REVISION, sourceDigest=SOURCE_DIGEST, sourceState='working-tree', designSystemVersion=VERSION, locale='en' if '-en' in name else 'fr', theme='dark' if '-dark' in name else 'light', viewport=dict(width=viewport[0],height=viewport[1]), imagePixels=dict(width=width,height=height),textScale=2 if '-large' in name else 1, keyboardInset=320 if '-keyboard' in name else 0, captureKind='production-component-composition' if composition else 'production-page', fixtureSource=('dev-only /__design; fictional values, no API writes' if composition else 'isolated local Identity/School API with disposable seeded data') if WEB else ('deterministic widget fixture; production widgets, no network; not a live API journey'),capturedAt=datetime.datetime.fromtimestamp(image.stat().st_mtime,datetime.timezone.utc).isoformat(),sha256=hashlib.sha256(image.read_bytes()).hexdigest()))
    for entry in entries:
        old = previous.get(entry['file'])
        if old and old['sha256'] == entry['sha256'] and old['capturedAt'] == entry['capturedAt']:
            # Reindexing must not falsely reattribute older captures to new source.
            for key in ('sourceRevision','sourceDigest','sourceState','designSystemVersion'):
                entry[key] = old[key]
    (folder/'manifest.json').write_text(json.dumps(dict(app=app,designSystemVersion=VERSION,sourceDigestInputs=SOURCES,captures=entries),indent=2)+'\n')
    cards=[]
    for e in entries:
        label=e['file'].removeprefix('current/').removesuffix('.png').replace('-',' ')
        meta=f"{e['locale'].upper()} · {e['theme']} · {e['viewport']['width']} × {e['viewport']['height']} · text {e['textScale']}×"
        cards.append(f'<figure><a href="{e["file"]}"><img src="{e["file"]}" alt="{html.escape(label)}" loading="lazy"></a><figcaption><strong>{html.escape(label)}</strong><p>{meta}</p><small>{e["captureKind"]}</small></figcaption></figure>')
    page='<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>EDAYA '+app+' current UI</title><style>body{font:16px/1.6 system-ui;color:#1e293b;background:#f0f7ff;margin:0;padding:32px}main{max-width:1500px;margin:auto}h1{font-size:28px}a{color:#2563eb}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,330px),1fr));gap:24px}figure{margin:0;background:white;border:1px solid #e2e8f0;border-radius:16px;overflow:hidden}img{width:100%;height:440px;object-fit:contain;object-position:top;background:#eef2f6}figcaption{padding:20px}p{margin:4px 0}small{color:#5b6b82}</style><main><h1>EDAYA '+app.title()+' · current UI</h1><p>Design system '+VERSION+' · <a href="README.md">Review annotations</a> · <a href="manifest.json">Source and capture metadata</a></p><p>Current working-tree captures using isolated fixtures. These images document presentation, not complete feature or API verification.</p><div class="grid">'+''.join(cards)+'</div></main></html>'
    (folder/'index.html').write_text(page)
    print(f'{app}: indexed {len(entries)} current captures at {REVISION[:12]} + source digest {SOURCE_DIGEST[:12]}')
