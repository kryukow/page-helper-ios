"""Allow only reviewed source types. Never inspect sibling PC credentials."""
from pathlib import Path
import re
root = Path(__file__).resolve().parents[1]
allowed = {'.swift','.js','.json','.html','.plist','.entitlements','.yml','.md','.py'}
bad = []
for p in root.rglob('*'):
    if not p.is_file() or any(x in p.relative_to(root).parts for x in ('build','.git','DerivedData')): continue
    if p.name != '.gitignore' and p.suffix not in allowed: bad.append(str(p.relative_to(root))); continue
    if p.name in ('connection.json','session.json') or p.name.startswith('.env'): bad.append(str(p.relative_to(root)))
    s = p.read_text(encoding='utf-8')
    patterns = [r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----', r'\bsk-(?:proj-)?[A-Za-z0-9_-]{20,}',r'\bgh[pousr]_[A-Za-z0-9]{30,}',r'\beyJ[A-Za-z0-9_-]{12,}\.[A-Za-z0-9_-]{12,}\.[A-Za-z0-9_-]{12,}']
    if any(re.search(pattern,s) for pattern in patterns): bad.append(str(p.relative_to(root)))
if bad: raise SystemExit('Publication check FAILED: '+', '.join(sorted(set(bad))))
print('Publication check passed: source files only; no recognized credentials.')
