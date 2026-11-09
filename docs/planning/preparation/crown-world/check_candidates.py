"""Check authoring coverage and retained source identity; never simulate game rules."""
import hashlib
import json
import re
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]


def read(p):
    return json.loads(p.read_text(encoding='utf-8-sig'))


def pointer(value, path):
    for part in path.split('/')[1:]:
        part = part.replace('~1', '/').replace('~0', '~')
        value = value[int(part)] if isinstance(value, list) else value[part]
    return value


pins = 0
hashes = {}


def check_pins(value):
    global pins
    if isinstance(value, list):
        for v in value:
            check_pins(v)
    elif isinstance(value, dict):
        if 'path' in value and 'sha256' in value:
            path = ROOT / value['path']
            assert path.is_file(), path
            if path not in hashes:
                hashes[path] = hashlib.sha256(path.read_bytes()).hexdigest()
            assert hashes[path] == value['sha256'], (path, 'source changed; re-review needed')
            if 'payload' in value:
                assert pointer(read(path), value['pointer']) == value['payload'], (path, 'retained rules changed')
            pins += 1
        for v in value.values():
            check_pins(v)


index = read(HERE / 'index.json')
entries = index['candidates']
assert len(entries) == len({r['id'] for r in entries}) == index['counts']['total'] == 74
assert dict(Counter(r['kind'] for r in entries), total=len(entries)) == index['counts']
expected = {r['path'] for r in entries}
actual = {p.relative_to(HERE).as_posix() for r in {e['kind'] for e in entries} for p in (HERE / r).glob('*.json')}
assert expected == actual
for p in HERE.rglob('*.json'):
    check_pins(read(p))
for p in index['links']:
    assert (HERE / p).is_file(), p

for row in read(HERE / 'consumer-trace.json')['sources']:
    lines = (ROOT / row['source']['path']).read_text(encoding='utf-8').splitlines()
    for function in row['functions']:
        start = function['line'] - 1
        retained = function['text'].splitlines()
        assert lines[start:start + len(retained)] == retained, (row['source']['path'], function['name'])

groups = {r['id']: r for r in read(HERE / 'required-extensions.json')['groups']}
pages = {r['page'] for r in read(HERE / 'source-pages.json')['pages']}
for entry in entries:
    d = read(HERE / entry['path'])
    assert d['status'] == index['status']
    assert d['authored_operations'] and d['required_extensions']
    assert set(d['required_extensions']) <= groups.keys()
    for g in d['required_extensions']:
        assert entry['path'] in groups[g]['members']
    assert set(d.get('source_context_pages', [])) <= pages

campaign = read(ROOT / 'data/core/campaigns/the_lost_crown.json')
assert len(campaign['map']['tiles']) == 43
assert len({(t['q'], t['r']) for t in campaign['map']['tiles']}) == 43
for id, d in campaign['dungeons'].items():
    assert read(HERE / ('dungeons/' + id + '.json'))['retained_input']['payload'] == d
    assert read(HERE / ('rewards/' + id + '_clear.json'))['retained_input']['payload'] == d['loot']
room = campaign['dungeons']['ruins_of_ashvale']['tactical_rooms']['1']
assert len(room['objects']) == index['counts']['objects'] == 9
for obj in room['objects']:
    assert read(HERE / ('objects/' + obj['id'] + '.json'))['retained_input']['payload'] == obj
assert len(campaign['milestones']) == index['counts']['milestones'] == 4

event_count = 0
for path in (ROOT / 'data/core/events').glob('*.json'):
    table = read(path)
    assert read(HERE / ('tables/' + table['table_id'] + '.json'))['retained_input']['payload'] == table
    todo = list(table['events'])
    for ev in todo:
        d = read(HERE / ('events/' + table['table_id'] + '__' + ev['id'] + '.json'))
        assert d['retained_input']['payload'] == ev
        # Every check, consequence and reward branch has an explicit plan, including empty effects.
        def visit(v, ptr=''):
            if isinstance(v, dict):
                for key in ['check', 'effects', 'reward']:
                    if key in v:
                        assert any(op.get('seed_pointer') == ptr + '/' + key for op in d['authored_operations']), (d['id'], ptr, key)
                for k, x in v.items():
                    visit(x, ptr + '/' + k)
            elif isinstance(v, list):
                for i, x in enumerate(v):
                    visit(x, ptr + '/' + str(i))
        visit(ev)
        event_count += 1
        if 'chain_event' in ev:
            todo.append(ev['chain_event'])
assert event_count == len(index['events']) == 29

deps = read(HERE / 'dependency-map.json')
spells = read(ROOT / 'docs/planning/preparation/crown-spells/index.json')['spells']
assert {r['id'] for r in spells} == {r['id'] for r in deps['spells']}
assert len(deps['spells']) == 183
chars = read(ROOT / 'docs/planning/preparation/crown-characters/index.json')['candidates']
assert len(deps['characters']) == len(chars) + 1 == 80
assert {r['id'] for r in deps['characters']} == {r['id'] for r in chars} | {'multiclass'}
for row in deps['spells']:
    source = read(ROOT / row['source']['path'])
    assert pointer(source, row['full_rules_pointer'])
    assert set(row['world_procedures']) <= groups.keys()
for row in deps['characters']:
    source = read(ROOT / row['source']['path'])
    expected_units = len(source['features']) if isinstance(source.get('features'), list) else 1
    assert len(row['units']) == expected_units
    for unit in row['units']:
        assert isinstance(pointer(source, unit['pointer']), dict)
        assert pointer(source, unit['source_rules_pointer'])
        assert set(unit['world_procedures']) <= groups.keys()

links = read(HERE / 'acquisition-links.json')['occurrences']
assert links and all(r['candidate'] for r in links)
assert {r['id'] for r in links if r['kind'] == 'creature'} == {'bandit','giant_spider','goblin','goblin_chief','lich_king','ooze','skeleton','wight','wolf','zombie'}
assert {'crown_fragment','gold_50','gold_100','potion_healing','potion_greater_healing','ashvale_brass_key'} <= {r['id'] for r in links if r['kind'] == 'item'}

# Local relative documentation links, excluding URL/anchor-only references.
for file in [HERE / 'README.md']:
    for target in re.findall(r'\]\(([^)]+)\)', file.read_text(encoding='utf-8')):
        if '://' in target or target.startswith('#'):
            continue
        assert (file.parent / target.split('#')[0]).is_file(), (file, target)
print(f'PASS: 74 candidates, 4 tables/29 events, 9 objects, 183 spells, 79 characters + multiclass; {len(links)} acquisition links; {pins} source pins. Structure/source only; no gameplay acceptance.')
