-- Genuine building candidates; generation/diagnostics are not normal acceptance.
local M={}
M.Bindings={marine_hq='imp_marine_hq',marine_barracks='imp_marine_barracks',marine_armoury='imp_marine_armoury',marine_relay='imp_orbital_relay',marine_artifact='imp_sacred_artifact'}
M.Profiles={
 imp_marine_hq={name='Space Marine Stronghold',role='command_factory',metal=450,energy=0,seconds=200,health=7500,source='space_marine_hq',factory=true,buildpiece='marker_door_front',products={'imp_scout'},upgradeGeometry=true},
 imp_marine_barracks={name='Space Marine Barracks',role='infantry_factory',metal=250,energy=0,seconds=60,health=2500,source='space_marine_barracks',factory=true,buildpiece='marker_barracks_doors_front',products={'imp_marine','imp_assault_marine','imp_devastator','imp_terminator'}},
 imp_marine_armoury={name='Space Marine Armoury',role='equipment_research',metal=175,energy=50,seconds=60,health=2500,source='space_marine_armoury',products={}},
 imp_orbital_relay={name='Space Marine Orbital Relay',role='orbital_support',metal=175,energy=100,seconds=80,health=1500,source='space_marine_orbital_relay',products={},addon='imp_source_hq_addon_2'},
 imp_sacred_artifact={name='Space Marine Sacred Artifact',role='hero_research_support',metal=125,energy=50,seconds=45,health=1600,source='space_marine_ability_building',products={},addon='imp_source_hq_addon_1'},
}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
function M.GeometryReady(key,f)
 local p=M.Profiles[key]
 if not p or type(f)~='table' or f.converted~=true or f.source_entity~='attrib/ebps/races/space_marines/structures/'..p.source..'.lua'
  or f.required_clips_complete~=true or not finite(f.pose_error)or f.pose_error<0 or f.pose_error>=1e-4 or not f.bounds or not f.bones
  or type(f.model_sha256)~='string'or #f.model_sha256~=64 or type(f.glb_sha256)~='string'or #f.glb_sha256~=64 then return false end
 for axis=1,3 do if not finite(f.bounds.min[axis])or not finite(f.bounds.max[axis])or f.bounds.max[axis]<=f.bounds.min[axis]then return false end end
 if p.buildpiece and not f.bones[p.buildpiece]then return false end
 return true
end
function M.Build(key,f,factoryContract)
 local p=M.Profiles[key]
 if not M.GeometryReady(key,f)or(p.factory and not(factoryContract and factoryContract(key)==true))then return end
 local size,offset={},{0,0,0};for axis=1,3 do
  size[axis]=f.native_metadata and f.collision_dimensions[axis]or(f.bounds.max[axis]-f.bounds.min[axis])
  if f.native_metadata then offset[axis]=f.collision_offsets_predicted[axis];assert(finite(size[axis])and size[axis]>0 and finite(offset[axis]),'Verified completed visible envelope required')end
 end
 local function footprint(v)return math.max(2,2*math.ceil(v/32))end -- 16 native units/square; rounded up to even grid.
 local fx,fz=footprint(size[1]),footprint(size[3])
 local cp={faction='Imperium',prototype40k=1,prototype40k_expansion=1,animsource=key,rosterrole=p.role,production_role=p.role,unitgroup=p.factory and 'builder' or 'util',
  source_entity=f.source_entity,source_model_sha256=f.model_sha256,source_generated_glb_sha256=f.glb_sha256,
  source_native_pieces=f.native_metadata,source_collision_midpoint_pending=f.native_metadata and 1 or nil,
  source_buildpiece=p.buildpiece,source_buildclip=p.factory and 'production' or nil,
  prototype40k_tech_requires=key,integration_status='genuine_source_candidate_native_unaccepted',
  source_balance_adaptation='source requisition/power direct; source seconds x30 work; actual builder workertime controls elapsed time',
  source_factory_egress_pending=p.factory and 1 or nil,source_production_sequence_pending=p.factory and 1 or nil,
  source_upgrade_geometry_pending=p.upgradeGeometry and f.upgrade_geometry_complete~=true and 1 or nil,
  source_missing_products_pending=(key=='imp_marine_hq'or key=='imp_sacred_artifact')and 1 or nil,
  source_orbital_deepstrike_pending=key=='imp_orbital_relay'and 1 or nil}
 return {name=p.name,description=p.name..': '..p.role:gsub('_',' '),objectname=key..'.glb',script='40k_roster.lua',buildpic='40k_'..key..'.png',
  metalcost=p.metal,energycost=p.energy,buildtime=p.seconds*30,health=p.health,speed=0,footprintx=fx,footprintz=fz,
  canmove=false,canattack=false,builder=p.factory==true,workertime=p.factory and 30 or 0,builddistance=p.factory and 200 or 0,
  buildoptions={},canrepeat=p.factory==true,sightdistance=400,maxslope=15,maxwaterdepth=0,category='ALL NOTSUB SURFACE',
  collisionvolumetype='Box',collisionvolumescales=table.concat(size,' '),collisionvolumeoffsets=table.concat(offset,' '),
  yardmap=string.rep(p.factory and 'e' or 'o',fx*fz),customparams=cp}
end
function M.Graph()
 local g={Requires={},Research={},MarineInfrastructure=true}
 for key,p in pairs(M.Profiles)do g.Requires[key]=key=='imp_marine_hq'and{}or{buildings={'imp_marine_hq'}}
  if p.addon then g.Requires[key].production_method='marine_addon_adapter_unattached' end
 end
 return g -- Addon conditions require the live physical source-addon adapter below.
end
function M.Attach(C,defs,graph)
 assert(graph and graph.MarineInfrastructure,'Actual building graph required')
 for key in pairs(M.Profiles)do assert(C.requirements[key]==graph.Requires[key],'Building graph must be attached to paid runtime')end
 local old=C.CanBuild
 function C.CanBuild(team,def,builder,initial)
  local d=defs[def];local cp=d and d.customParams or{};local p=M.Profiles[cp.prototype40k_tech_requires or(d and d.name)]
  if p and p.addon then
   local a=C.sourceVariantAdapter
   if not a or not a.GlobalAddon or not a.GlobalAddon(team,p.addon)then return false end
  end
  return old(team,def,builder,initial)
 end
 for key,p in pairs(M.Profiles)do if p.addon then graph.Requires[key].production_method='factory'end end
end
function M.Definitions(facts,options,factoryContract)
 options=options or{};local review=VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(options.prototype_source_progression)and(options.prototype_diagnostic=='roster'or options.prototype_diagnostic=='expandedproduction')
 local defs={}
 for key,p in pairs(M.Profiles)do local f=facts and facts[key]
  local normal=VFS.FileExists('40k_configs/validated/'..key..'.lua')and(not p.upgradeGeometry or(f and f.upgrade_geometry_complete==true))
  if(review or normal or VFS.Include('40k_configs/development_playtest.lua').Allowed(key,options))and VFS.FileExists('objects3d/'..key..'.glb')and VFS.FileExists('scripts/generated/'..key..'_anim.lua')
   and(not(f and f.native_metadata)or VFS.FileExists('scripts/generated/'..f.native_metadata))
   and VFS.FileExists('scripts/40k_roster.lua')and VFS.FileExists('unitpics/40k_'..key..'.png')then
   local d=M.Build(key,f,factoryContract);if d then defs[key]=d end
  end
 end
 return defs
end
function M.ApplyMenus(defs,ready,makers)
 local added={}
 for key,p in pairs(M.Profiles)do local d=defs[key]
  if d and ready(key)then
   d.buildoptions={}
   for _,product in ipairs(p.products)do if defs[product]and ready(product)then d.buildoptions[#d.buildoptions+1]=product end end
   added[#added+1]=key
  end
 end
 for _,maker in ipairs(makers or{})do local d=defs[maker]
  if d and d.builder and ready(maker)then d.buildoptions=d.buildoptions or{}
   for _,key in ipairs(added)do local found=false;for _,v in ipairs(d.buildoptions)do if v==key then found=true end end;if not found then d.buildoptions[#d.buildoptions+1]=key end end
  end
 end
 table.sort(added);return added
end
return M
