#!/usr/bin/env python3
"""Full project ZIP including untracked/ignored files and Git; verify every hash."""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--output-dir', type=Path, required=True)
p.add_argument('--label', default='checkpoint')
a = p.parse_args()
root = Path(__file__).resolve().parents[1]
out = a.output_dir.resolve()
assert not out.is_relative_to(root), 'Backup must be outside the project'
assert a.label.replace('-', '').isalnum(), 'Simple label required'
out.mkdir(parents=True, exist_ok=True)
stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
archive = out/f'SpiderCity-{a.label}-{stamp}.zip'
files = sorted(f for f in root.rglob('*') if f.is_file())
manifest = {}
with ZipFile(archive, 'x', ZIP_DEFLATED, compresslevel=6) as z:
    for f in files:
        rel = f.relative_to(root).as_posix()
        data = f.read_bytes()
        manifest[rel] = {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
        z.write(f, 'SpiderCity/'+rel)
    z.writestr('SNAPSHOT-MANIFEST.json', json.dumps(manifest, indent=2))
with ZipFile(archive) as z:
    assert z.testzip() is None
    for name, record in manifest.items():
        data = z.read('SpiderCity/'+name)
        assert len(data) == record['bytes'] and hashlib.sha256(data).hexdigest() == record['sha256'], name
    assert 'project.godot' in manifest
    for extension in ('.tscn', '.gd', '.glb', '.blend', '.png', '.wav'):
        assert any(n.endswith(extension) for n in manifest), extension
checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
archive.with_suffix('.zip.sha256').write_text(checksum+'  '+archive.name+'\n')
(out/'LATEST.txt').write_text(str(archive)+'\n')
print(json.dumps({'archive':str(archive),'files':len(files),'bytes':archive.stat().st_size,'sha256':checksum},indent=2))
