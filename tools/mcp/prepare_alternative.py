#!/usr/bin/env python3
"""Prepare a fresh satellite test copy. Never replace an existing addon/project."""
import argparse
import shutil
from pathlib import Path

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--satellite-source', type=Path, required=True)
p.add_argument('--destination', type=Path, required=True)
a = p.parse_args()
source = Path(__file__).resolve().parents[2]
dest = a.destination.resolve()
addon = a.satellite_source.resolve() / 'godot/addons/godot_mcp'
assert (addon/'plugin.cfg').is_file(), 'Missing satellite addon'
assert not dest.exists(), 'Destination must be NEW; refusing to overwrite'
assert not dest.is_relative_to(source), 'Test copy must be outside the real project'

def ignore(directory, names):
    excluded = {'.git', '.godot', 'node_modules', '__pycache__'}
    if Path(directory) == source/'addons': excluded.add('godot_mcp')
    return set(names) & excluded

shutil.copytree(source, dest, ignore=ignore)
s = (dest/'project.godot').read_text()
s = '\n'.join(line for line in s.split('\n') if not line.startswith('MCPRuntimeProbe='))
(dest/'project.godot').write_text(s)
shutil.copytree(addon, dest/'addons/godot_mcp')
shutil.copy2(a.satellite_source/'LICENSE', dest/'addons/godot_mcp/LICENSE')
print(dest)
print('Only satellite addon installed. Real project remains on hybrid.')
