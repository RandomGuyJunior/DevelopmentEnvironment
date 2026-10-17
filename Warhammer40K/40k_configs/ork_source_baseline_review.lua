-- Opt-in definition compatibility: exact source baselines, actual native labor.
-- Factory work rates, income, weapons, menus and normal definitions are preserved.
local M={}
local expected={ork_settlement='ork_hq',ork_boyz_hut='ork_boy_hut',ork_pile_o_guns='ork_pile_o_guns',ork_mek_shop='ork_mek_shop',ork_hq_super='ork_hq_super',ork_giant_waagh_banner_sp_dxp3='ork_giant_waagh_banner_sp_dxp3',ork_waaagh_banner='ork_waagh_banner',ork_listening_post='ork_gork_totem',ork_generator='ork_generator',ork_boomy_platform='ork_boomy_platform',ork_bigger_generator='ork_bigger_generator',ork_mek_lab='ork_bilda_pit',ork_stormboy='ork_stormboy',ork_slugga='ork_slugga_boy'}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
function M.Apply(defs,options,evidence)
 if not VFS.Include('40k_configs/ork_source_consumers_native.lua').Enabled(options)then return{enabled=false}end
 if not evidence then local path='scripts/generated/ork_source_consumer_bundle_evidence.lua';if not VFS.FileExists(path)then return{enabled=true,applied=false,reason='private_evidence_missing'}end;evidence=VFS.Include(path)end
 if type(evidence)~='table'or evidence.version~=1 or type(evidence.entries)~='table'then return{enabled=true,applied=false,reason='invalid_private_evidence'}end
 local plans={}
 for key,stem in pairs(expected)do
  local row=evidence.entries[key];local d=defs[key];local cp=d and d.customparams or{}
  local branch=key=='ork_stormboy'or key=='ork_slugga';local path='attrib/ebps/races/orks/'..(branch and 'troops/'or 'structures/')..stem..'.lua'
  if not row or row.reviewed~=true or row.source_entity~=path or not d or cp.faction~='Orks'or tostring(cp.prototype40k)~='1'or(cp.source_entity and cp.source_entity~=path)or d.objectname~=row.asset..'.glb'or cp.animsource~=row.asset then return{enabled=true,applied=false,reason='genuine_complete_definition_missing',key=key}end
  local labor=branch and 'ork_boyz_hut'or 'ork_grot';local producer=defs[labor]
  if row.labor_reference~=labor or not producer or not finite(producer.workertime)or producer.workertime<=0 or producer.workertime~=row.native_workrate then return{enabled=true,applied=false,reason='actual_native_labor_changed',key=key}end
  if not VFS.FileExists('objects3d/'..row.asset..'.glb')or not VFS.FileExists('scripts/generated/'..row.asset..'_anim.lua')then return{enabled=true,applied=false,reason='actual_bundle_missing',key=key}end
  for _,field in ipairs({'health','metal','energy','buildTime','seconds','native_workrate'})do if not finite(row[field])or row[field]<0 then return{enabled=true,applied=false,reason='source_baseline_invalid',key=key}end end
  if row.health<=0 or row.seconds<=0 or row.buildTime<=0 or math.abs(row.buildTime-row.seconds*row.native_workrate)>math.max(.0001,row.buildTime*1e-7)then return{enabled=true,applied=false,reason='native_float_baseline_inconsistent',key=key}end
  plans[key]={definition=d,row=row}
 end
 -- Validate the entire target set before changing any field or publishing identity.
 local count=0
 for _,p in pairs(plans)do local d,row=p.definition,p.row
  d.health=row.health;d.metalcost=row.metal;d.energycost=row.energy;d.buildtime=row.buildTime
  d.customparams.source_build_seconds=row.seconds;d.customparams.source_labor_reference=row.labor_reference
  d.customparams.source_baseline_adaptation='exact_source_price_hp_native_float32_labor_v1';count=count+1
 end
 return{enabled=true,applied=true,count=count,per_producer_time_pending={producer='ork_settlement',actual_workrate=defs.ork_settlement.workertime,slugga_definition_reference=defs.ork_boyz_hut.workertime,source_products={'ork_grot','ork_slugga','ork_warboss'}}}
end
return M
