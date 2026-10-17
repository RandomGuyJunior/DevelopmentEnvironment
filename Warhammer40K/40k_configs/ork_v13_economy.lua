-- Orks-first v1.3 economy. Caller applies after the existing fixed-extractor helper.
-- No runtime resource owner: native UnitDefs, stock placement and mex refunds remain authoritative.
local M={Version=1}
M.Power={
 ork_generator_t2={id='ORK-ENE-2',label='Paired Ork Generator',tier=2,power=75,metal=180,energy=900,work=2160,health=1100,
  object='ork_generator_t2.glb',bank='ork_generator_t2',icon='40k_ork_generator.png',source='attrib/ebps/races/orks/structures/ork_generator.lua',model='1a994433be2e92733033ff6c0c7961ff9028be83542a4961cc6da8f5904866d1'},
 ork_generator_t3={id='ORK-ENE-3',label='Even Bigga and Meanest Generator',tier=3,power=600,metal=2400,energy=12000,work=28800,health=6000,
  object='ork_generator_t3.glb',bank='ork_generator_t3',icon='40k_ork_generator_t3.png',source='attrib/ebps/races/orks/structures/ork_even_bigger_generator.lua',model='04a83f582b666dd248d99e7f20e01416a4d0f5ef7cd563d133d1b2de829f6731'},
 ork_geothermal={id='ORK-GEO-2',label='Bigga Geothermal Generator',tier=2,power=180,metal=400,energy=2000,work=4800,health=2500,geo=true,
  object='ork_bigger_generator.glb',bank='ork_bigger_generator',icon='40k_ork_bigger_generator.png',source='attrib/ebps/races/orks/structures/ork_bigger_generator.lua',model='afdc4716bf9e50f454553714156d9a1d24889081fc2c4baf15c306379b2a521a'},
}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function sha(v)return type(v)=='string'and #v==64 and v:match('^[0-9a-f]+$')end
local function text(d,label,description)
 d.name=label;d.description=description;local cp=d.customparams
 cp.i18n_en_humanname=label;cp.i18n_en_tooltip=description;cp.prototype40k_short_role=description;cp.prototype40k_ui_description=description
end
function M.Yard(bounds,geo)
 assert(type(bounds)=='table'and type(bounds.min)=='table'and type(bounds.max)=='table','Completed envelope required')
 for i=1,3 do assert(finite(bounds.min[i])and finite(bounds.max[i])and bounds.max[i]>bounds.min[i],'Invalid completed envelope')end
 local function size(axis)local n=math.max(2,math.ceil((math.max(math.abs(bounds.min[axis]),math.abs(bounds.max[axis]))+2)/8));return n+n%2 end
 local x,z=size(1),size(3);assert(x<=64 and z<=64,'Economy envelope exceeds reviewed building range')
 local cells={};for row=0,z-1 do for col=0,x-1 do
  local centre=geo and(col==x/2-1 or col==x/2)and(row==z/2-1 or row==z/2)
  cells[#cells+1]=centre and'g'or'o'
 end end
 return x,z,table.concat(cells)
end
function M.Build(key,V,facts)
 local row=assert(M.Power[key],'Unknown v1.3 power recipe')
 if type(facts)~='table'then return nil,'generated_bundle_pending'end
 if facts.key~=key or facts.recipe~=row.id or facts.object~=row.object or facts.bank~=row.bank or facts.source_model_sha256~=row.model or not sha(facts.generated_glb_sha256)then return nil,'generated_bundle_identity'end
 if key=='ork_generator_t2'and(facts.components~=2 or facts.material_policy~='blue_source_emissive_green_only_v1')then return nil,'paired_blue_generator_recipe'end
 -- Metadata is generated offline and sealed by the freezer; no geometry import at startup.
 for _,path in ipairs({'objects3d/'..row.object,'scripts/generated/'..row.bank..'_anim.lua','unittextures/'..row.bank..'_tex1.png','unittextures/'..row.bank..'_tex2.png','unitpics/'..row.icon})do
  if not V.FileExists(path)then return nil,'missing_'..path end
 end
 for _,path in ipairs({'objects3d/twisted_metal.glb','unittextures/twisted_metal_tex1.png','unittextures/twisted_metal_tex2.png'})do
  if not V.FileExists(path)then return nil,'missing_native_scrap_'..path end
 end
 local valid,x,z,yard=pcall(M.Yard,facts.bounds,row.geo);if not valid then return nil,'completed_envelope_required'end
 local d={name=row.label,description='',objectname=row.object,script='40k_roster.lua',buildpic=row.icon,
  metalcost=row.metal,energycost=row.energy,buildtime=row.work,health=row.health,energymake=row.power,energyupkeep=0,
  metalmake=0,makesmetal=0,extractsmetal=0,windgenerator=0,tidalgenerator=0,metalstorage=0,energystorage=0,
  speed=0,canmove=false,canattack=false,canfly=false,builder=false,buildoptions={},weapondefs={},weapons={},
  footprintx=x,footprintz=z,yardmap=yard,maxslope=24,maxwaterdepth=0,sightdistance=430,upright=true,
  customparams={prototype40k=1,faction='Orks',rosterrole='generator',unitgroup='energy',animsource=row.bank,
   techlevel=row.tier,prototype40k_source_progression=1,prototype40k_donor=key,prototype40k_tech_requires=key,
   prototype40k_ork_v13_recipe=row.id,source_entity=row.source,source_model_sha256=row.model,
   source_native_glb_sha256=facts.generated_glb_sha256,prototype40k_economy='native_static_energyMake',
   building_placement_policy='origin_envelope_v1',building_placement_model=facts.generated_glb_sha256}}
 -- The native death path creates this one entitlement for completed units only.
 -- Native reclaim/cancellation never calls Killed; no manual feature creation or refund.
 d.corpse='machinery_scrap'
 d.featuredefs={machinery_scrap={name='Ork generator machinery scrap',description='Salvageable Ork generator machinery',object='twisted_metal.glb',
  blocking=false,reclaimable=true,autoreclaimable=true,resurrectable=0,indestructible=true,flammable=false,damage=100,health=100,
  metal=row.metal*.25,energy=row.energy*.25,reclaimtime=math.max(30,math.min(6000,row.work*.25)),footprintx=4,footprintz=4,featuredead='',
  customparams={prototype40k_ork_v13_economy_wreck=1,source_scenery='art/ebps/environment/urban/dressing/dressing_twistedmetal_01.whm'}}}
 text(d,row.label,row.power..' energy/s'..(row.geo and'; requires a geothermal site; T1 builders can construct it'or'; fixed T'..row.tier..' power structure'))
 return d
end
function M.Apply(defs,V,ready)
 local report={changed={},pending={}};ready=ready or{}
 local generator=assert(defs.ork_generator,'Existing genuine Ork generator required')
 assert(generator.objectname=='ork_generator.glb'and generator.customparams.animsource=='ork_generator'and generator.energymake==30,'Existing T1 power identity/economy drift')
 -- The existing T1 price, bill, life and visual identity remain unchanged.
 generator.customparams.prototype40k_ork_v13_recipe='ORK-ENE-1'
 text(generator,'Ork Generator','30 energy/s; fixed T1 power structure')
 report.changed[#report.changed+1]='ork_generator'
 for tier=1,3 do
  local key=tier==1 and'ork_listening_post'or'ork_listening_post_t'..tier
  local d=assert(defs[key],'Apply existing fixed-extractor helper before v1.3 economy')
  local cp=d.customparams
  assert(cp.extractor_family=='ork_listening_post'and tonumber(cp.extractor_tier)==tier and tonumber(cp.listening_post_stage)==tier-1,'Fixed extractor stage identity drift')
  assert(d.objectname=='ork_post_stages.glb'and d.script=='40k_listening_post.lua'and d.extractsmetal>0 and(d.energyupkeep or 0)>=0,'Genuine fixed extractor role required')
  assert((d.energymake or 0)==0 and(d.metalmake or 0)==0 and(d.makesmetal or 0)==0,'Fixed extractor must retain native spot income only')
  cp.prototype40k_ork_v13_recipe='ORK-MEX-'..tier
  local description=tier==1 and'Metal-spot extractor with shoota; no visual upgrade'or tier==2 and'Higher metal-spot extraction with twin big shoota; 20 energy/s upkeep'or'T2 extraction rate with higher durability and rokkit defence; 20 energy/s upkeep'
  text(d,({'Da Listening Post','Bigga Listening Post','Biggest Listening Post'})[tier],description)
  report.changed[#report.changed+1]=key
 end
 assert(defs.ork_listening_post_t2.extractsmetal==defs.ork_listening_post_t3.extractsmetal,'T3 same-yield tooltip requires actual same yield')
 for _,key in ipairs({'ork_generator_t2','ork_generator_t3','ork_geothermal'})do
  local d,why=M.Build(key,V,ready[key])
  if d then
   assert(not defs[key]or defs[key].customparams.prototype40k_ork_v13_recipe==M.Power[key].id,'Refuse unrelated economy identity overwrite')
   defs[key]=d;report.changed[#report.changed+1]=key
  else report.pending[key]=why end
 end
 return report
end
return M
