import json
import glob
import os
import re

with open('docs/quarantined_features_remediation_plan.md', 'r', encoding='utf-8') as f:
    text = f.read()

# Split text into sections 4.1 to 4.14
sections = re.split(r'### 4\.\d+\s+', text)[1:]

row_pattern = r'\|\s*`([^`]+)`(?:\s*\([^)]+\))?\s*\|\s*(\d+)\s*\|\s*(Tier \d+)\s*\|'

for sec in sections:
    lines = sec.splitlines()
    header = lines[0] # e.g. Artificer (12 Quarantined Features)
    cname = header.split()[0]
    
    matches = re.findall(row_pattern, sec)
    t1 = sum(1 for m in matches if m[2] == 'Tier 1')
    t2 = sum(1 for m in matches if m[2] == 'Tier 2')
    t3 = sum(1 for m in matches if m[2] == 'Tier 3')
    t4 = sum(1 for m in matches if m[2] == 'Tier 4')
    total = len(matches)
    print(f"{cname:<12} | T1: {t1} | T2: {t2} | T3: {t3} | T4: {t4} | Total: {total}")

