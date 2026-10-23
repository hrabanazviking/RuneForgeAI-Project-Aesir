from pathlib import Path
out=Path('../sealed-collection-native-acceptance-v3');out.mkdir(exist_ok=False)
(out/'pair-all.py').write_bytes(Path('../sealed-collection-native-acceptance-v2/pair-all.py').read_bytes())
p=Path('../sealed-collection-native-development/prepare-acceptance.py');s=p.read_text().replace("Path('../sealed-collection-native-acceptance')", "Path('../sealed-collection-native-acceptance-v3')").replace("Path('../sealed-collection-native-final')", "Path('../sealed-collection-native-final-v2')")
s=s.replace("oldmap={r['binary']:cur[r['source']] for r in primary if r['source'] in cur}","historical=json.load(open('../sealed-metadata-native-baseline/controls.json'))\noldmap={r['binary']:cur[r['source']] for r in historical+primary if r['source'] in cur}")
exec(compile(s,str(p),'exec'))
p=Path('../sealed-collection-native-development/run-acceptance.py');Path('../sealed-collection-native-development/run-acceptance-v3.py').write_text(p.read_text().replace("Path('../sealed-collection-native-acceptance')", "Path('../sealed-collection-native-acceptance-v3')"))
