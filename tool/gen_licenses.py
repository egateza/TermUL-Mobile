import json, os, re, subprocess, sys, urllib.request, datetime
proj = sys.argv[1]; out = sys.argv[2]
raw = subprocess.run(['flutter.bat' if os.name=='nt' else 'flutter','pub','deps','--json'],cwd=proj,capture_output=True,text=True).stdout
deps = json.loads(raw)['packages']
cache = r'D:\dev\pub-cache\hosted\pub.dev'
def classify(t):
    f=[]
    if re.search(r'GNU AFFERO|GNU (LESSER |LIBRARY )?GENERAL PUBLIC|Mozilla Public',t): f.append('COPYLEFT')
    if 'Redistribution and use in source and binary forms' in t: f.append('bsd-3-clause' if re.search('Neither the name|endorse',t) else 'bsd-2-clause')
    if 'Apache License' in t: f.append('apache-2.0')
    if 'Permission is hereby granted, free of charge' in t: f.append('mit')
    return f
def pubdev(n):
    for _ in range(3):
        try:
            d=json.load(urllib.request.urlopen(f'https://pub.dev/api/packages/{n}/score',timeout=20))
            return sorted(x[8:] for x in d['tags'] if x.startswith('license:') and x not in('license:fsf-libre','license:osi-approved'))
        except Exception: pass
    return None
rows=[]
for p in deps:
    if p['kind']=='root' or p['source']!='hosted': continue
    d=os.path.join(cache,f"{p['name']}-{p['version']}")
    lic=[f for f in os.listdir(d) if re.match(r'(LICENSE|LICENCE|COPYING)',f)]
    f=classify(open(os.path.join(d,lic[0]),encoding='utf-8',errors='replace').read()) if lic else []
    pd=pubdev(p['name'])
    ok = pd is not None and sorted(f)==pd
    rows.append((p['name'],p['version'],p['kind'],f,pd,ok))
sdk=[p for p in deps if p['source']=='sdk']
bad=[r for r in rows if not r[5]]
cop=[r for r in rows if 'COPYLEFT' in r[3] or (r[4] and any(x in ('agpl-3.0','gpl-3.0','gpl-2.0','lgpl-3.0','lgpl-2.1','mpl-2.0') for x in r[4]))]
today=datetime.date.today().isoformat()
L=[]
L.append('# Lisensi dependensi\n')
L.append(f'Dihasilkan dari `pubspec.lock` pada {today}. Setiap paket hosted diperiksa dua arah: (1) berkas `LICENSE` di arsip paket, dan (2) tag `license:` dari API pub.dev (`/api/packages/<nama>/score`). Kolom "Cocok" bernilai ya bila keduanya sama. Klasifikasi `LICENSE` memakai pencocokan teks; ini bukan pembacaan hukum.\n')
L.append(f'- Paket hosted diperiksa: **{len(rows)}**; cocok: **{len(rows)-len(bad)}**; tidak cocok atau gagal diambil: **{len(bad)}**.')
L.append(f'- Paket berlisensi copyleft (GPL, LGPL, AGPL, MPL): **{len(cop)}**.')
L.append('- Paket SDK ('+', '.join(sorted(p["name"] for p in sdk))+') mengikuti lisensi Flutter SDK (BSD-3-Clause); `sky_engine` memuat Apache-2.0.')
L.append('- `xterm` 4.0.0 (MIT) dipakai, bukan `xterm3` (AGPL-3.0).')
L.append('- Belum diverifikasi: lisensi font (IBM Plex Sans, JetBrains Mono), paket yang belum ditambahkan, dan apakah paket platform non-Android ikut masuk APK.')
L.append('- Perbarui berkas ini setiap `pubspec.lock` berubah.\n')
L.append('| Paket | Versi | Jenis | Lisensi (LICENSE) | Lisensi (pub.dev) | Cocok |')
L.append('|---|---|---|---|---|---|')
order={'direct':0,'dev':1,'transitive':2}
for n,v,k,f,pd,ok in sorted(rows,key=lambda r:(order.get(r[2],3),r[0])):
    L.append(f"| `{n}` | {v} | {k} | {', '.join(f) or '-'} | {', '.join(pd) if pd else 'gagal diambil'} | {'ya' if ok else 'TIDAK'} |")
open(out,'w',encoding='utf-8').write('\n'.join(L)+'\n')
print(len(rows),'paket; tidak cocok:',[(r[0],r[3],r[4]) for r in bad],'copyleft:',[r[0] for r in cop])
