-- Reviewed source-only fixed tiers. Native upgrade-yard/lifecycle gates remain.
local M={Families={imp_mex={label='Imperial Guard',template='wh40k_armmoho'},
 imp_marine_mex={label='Space Marine',template='wh40k_armmoho'},ork_listening_post={label='Ork',template='wh40k_cormoho'},
 nec_mex={label='Necron',template='wh40k_armmoho'}}}
local fields={'metalcost','energycost','buildtime','extractsmetal','energyupkeep','metalstorage'}
local strongest={metalcost=2400,energycost=12000,buildtime=32500,extractsmetal=.004,energyupkeep=20,metalstorage=600}
local faction={['Imperial Guard']='imp_mex',['Space Marines']='imp_marine_mex',['Orks']='ork_listening_post',['Necrons']='nec_mex'}
local function copy(v)if type(v)~='table'then return v end;local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out end
function M.Apply(defs,V)
 local profiles=V.Include('40k_configs/listening_post_profiles.lua')
 local bindings=V.Include('40k_configs/listening_post_bindings.lua');local economy={}
 for base,row in pairs(M.Families)do
  assert(defs[base],'Missing current faction extractor '..base)
  local donor=assert(defs[row.template],'Missing actual pinned economy donor')
  economy[base]={};for _,field in ipairs(fields)do economy[base][field]=assert(donor[field],'Missing donor field '..field)end
  local key=assert(bindings[base]).key
  for _,path in ipairs({'objects3d/'..key..'.glb','unittextures/'..key..'_tex1.png','unittextures/'..key..'_tex2.png',
   'scripts/generated/'..key..'_anim.lua','scripts/generated/'..key..'_post.lua','unitpics/lp_'..key..'.png'})do
   assert(V.FileExists(path),'Incomplete existing genuine LP bundle '..path)
  end
 end
 V.Include('40k_configs/listening_post_definitions.lua').Apply(defs,V,profiles,bindings)
 local changed={}
 for base,row in pairs(M.Families)do
  local original=copy(defs[base]);local profile=profiles.Profiles[base]
  assert((original.extractsmetal or 0)>0,'Actual active role is not extraction')
  for tier=1,3 do
   local stage=tier-1;local name=tier==1 and base or base..'_t'..tier
   local d=copy(original);local cp=d.customparams;defs[name]=d
   cp.listening_post_version=2;cp.listening_post_stage=stage;cp.extractor_family=base
   cp.extractor_tier=tier;cp.extractor_economy_tier=math.min(tier,2);cp.techlevel=tier
   cp.prototype40k_donor=name;cp.prototype40k_tech_requires=name;cp.prototype40k_shared_visual_source=base
   cp.standardextractor=tier==1 and original.customparams.standardextractor or tier==2 and true or nil
   cp.prototype40k_economy_template=tier==1 and'preserved_t1'or tier==2 and row.template or'explicit_defensive_t3'
   -- Do not substitute a generic BAR yard for the genuine footprint/geometry.
   cp.prototype40k_fixed_extractor_native_gate='upgrade_yard_and_stock_lifecycle_pending'
   d.health=profile.source_base_health+(stage>0 and profile.stages[stage].health_add or 0)
   if tier>1 then for field,value in pairs(tier==2 and economy[base]or strongest)do d[field]=value end end
   d.weapondefs={};d.weapons={}
   for _,mount in ipairs(original.weapons)do local w=original.weapondefs[mount.def]
    if w.customparams.listening_post_level==stage then d.weapondefs[mount.def]=copy(w);d.weapons[#d.weapons+1]=copy(mount)end
   end
   d.canattack=#d.weapons>0
   assert(d.canattack==(stage==0 and profile.base_armed or stage>0 and profile.stages[stage].armed),'Invented stage armament')
   d.name=row.label..' T'..tier..' Extractor';d.description='T'..tier..(d.canattack and' armed extractor'or' unarmed extractor')
   cp.i18n_en_humanname=d.name;cp.i18n_en_tooltip=d.description;cp.prototype40k_short_role=d.description;cp.prototype40k_ui_description=d.description
   changed[#changed+1]=name
  end
 end
 table.sort(changed);return changed
end
function M.ApplyMenus(defs,P)
 for name,row in pairs(P.Constructors)do if row[2]>=2 and defs[name]then
  local d=defs[name];local base=assert(faction[d.customparams.faction],'Unsupported current constructor faction')
  -- Stock area-mex selection reads ONLY the first mex option per constructor.
  -- Replace that slot with T2, retain T1 and explicit same-yield defensive T3;
  -- retain the relative order of every unrelated build option.
  local t2,t3=base..'_t2',base..'_t3';assert(defs[t2]and defs[t3],'Apply fixed definitions before menus')
  local menu={};local inserted=false;local hadBase=false
  for _,key in ipairs(d.buildoptions)do
   if key==base then hadBase=true end
   if key~=t2 and key~=t3 then
    if not inserted and(defs[key].extractsmetal or 0)>0 then menu[#menu+1]=t2;inserted=true end
    menu[#menu+1]=key
   end
  end
  if not inserted then menu[#menu+1]=t2 end
  if not hadBase then menu[#menu+1]=base end
  menu[#menu+1]=t3;d.buildoptions=menu
 end end
end
function M.ApplyGraph(graph,defs)
 for base in pairs(M.Families)do for tier=2,3 do local key=base..'_t'..tier;local d=assert(defs[key])
  local cp=d.customParams or d.customparams or{}
  assert(cp.extractor_family==base and tonumber(cp.extractor_tier)==tier,'Wrong fixed alias identity')
  graph.Requires[key]={}
 end end
 return graph
end
return M
