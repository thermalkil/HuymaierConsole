from pathlib import Path
import json,re
ROOT=Path(__file__).resolve().parents[2]
# Neo Geo stays staged alongside Jaguar until the current FBNeo Windows binary
# resolver is live-probed. This script is safe whether the earlier partial
# graduation has already run or not.
p=ROOT/'EmulatorPlatforms'/'NeoGeo'/'platform.json'
if p.exists():
 d=json.loads(p.read_text(encoding='utf-8-sig'));d['enabled']=False;p.write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')
regp=ROOT/'EmulatorPlatforms'/'platform-registry.json';reg=json.loads(regp.read_text(encoding='utf-8-sig'))
for entry in reg.get('platforms',[]):
 if str(entry.get('id','')).lower()=='neogeo':entry['enabled']=False;entry['readiness']='staged-pending-fbneo-binary-resolution'
regp.write_text(json.dumps(reg,indent=2)+'\n',encoding='utf-8')
validator=ROOT/'.github'/'workflows'/'validate-v0264-expansion.yml'
if validator.exists():
 v=validator.read_text(encoding='utf-8-sig')
 # Ensure NeoGeo is present in the disabled-until-graduated list by inserting it
 # before Jaguar if it is currently absent.
 if "'NeoGeo'" not in v:
  v=v.replace("'Jaguar'","'NeoGeo','Jaguar'",1)
 validator.write_text(v,encoding='utf-8')
status=ROOT/'Docs'/'PLATFORM-IMPLEMENTATION-STATUS-v0.26.4.md'
if status.exists():
 s=status.read_text(encoding='utf-8-sig');s=s.replace('Atari Lynx, Neo Geo, Neo Geo Pocket Color and PrimeHack','Atari Lynx, Neo Geo Pocket Color and PrimeHack');s=s.replace('Jaguar staged pending','Neo Geo and Jaguar staged pending');status.write_text(s,encoding='utf-8')
print('Neo Geo readiness corrected to staged until FBNeo Windows binary resolution is proven')
