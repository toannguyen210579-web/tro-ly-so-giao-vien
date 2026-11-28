"""Dựng lib/quoc_te/ngon_ngu.dart từ bảng chữ (tool/quoc_te/chu.json). Chạy: python3 tool/quoc_te/tao_ngon_ngu.py"""
import json, os
goc = os.path.dirname(os.path.abspath(__file__))
d = json.load(open(os.path.join(goc, 'chu.json'), encoding='utf-8'))
T, N = d['T'], d['N']
def chuoi(s): return json.dumps(s, ensure_ascii=False).replace('$', r'\$')
ra = ['// Tệp do tool/quoc_te/tao_ngon_ngu.py dựng từ tool/quoc_te/chu.json. Không sửa tay.', '',
      '/// Tên từng thứ tiếng, viết bằng chính tiếng đó.', 'const tenTieng = <String, String>{']
ra += [f'  {chuoi(k)}: {chuoi(v)},' for k, v in N.items()]
ra += ['};', '', '/// Bảng chữ của bản quốc tế: mã tiếng → khóa → chữ.', 'const bangChu = <String, Map<String, String>>{']
for k in N:
    ra.append(f'  {chuoi(k)}: {{')
    ra += [f'    {chuoi(a)}: {chuoi(b)},' for a, b in T[k].items()]
    ra.append('  },')
ra += ['};', '']
open(os.path.join(goc, '..', '..', 'lib', 'quoc_te', 'ngon_ngu.dart'), 'w', encoding='utf-8').write('\n'.join(ra))
print('số tiếng', len(N), '| số khóa', len(T['en']))
