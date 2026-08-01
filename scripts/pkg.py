import zipfile, os, sys
os.chdir(os.path.join(os.path.dirname(__file__), '..'))
paths = ['manifest']
for d in ('source', 'components', 'images'):
    if not os.path.isdir(d):
        continue
    for f in os.listdir(d):
        p = os.path.join(d, f)
        if os.path.isfile(p):
            paths.append(p.replace(os.sep, '/'))
os.makedirs('dist', exist_ok=True)
out = 'dist/Cartridge-0.6.0.zip'
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
    for p in paths:
        z.write(p, p)  # arcname with forward slashes — Roku requires this
print('wrote', out, 'with', len(paths), 'entries')
for p in paths:
    print('  ', p)
