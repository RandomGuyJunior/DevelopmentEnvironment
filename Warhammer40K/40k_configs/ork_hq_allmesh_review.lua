-- Exact-source isolated HQ candidate; ordinary registration and acceptance external.
local M={Key='ork_settlement',Asset='ork_hq_allmesh_review',Addon='ork_source_hq_addon'}
local source='attrib/ebps/races/orks/structures/ork_hq.lua'
local sourceSHA='186ab2a68d848d657de2344c95b144183ce516f634775a3b545b6a4db9ce3502'
local modelSHA='0e0cd0bd05c9d53bf1d32590e5521f46e3f1bd3adea6a7d7c6a50b1865dae0ce'
local function finite(x)return type(x)=='number'and x==x and math.abs(x)<math.huge end
local function hash(x)return type(x)=='string'and #x==64 and not x:find('[^0-9a-f]')end
function M.GeometryReady(f)
 if not f or f.asset_key~=M.Asset or f.source_entity~=source or f.source_entity_sha256~=sourceSHA or f.source_model_sha256~=modelSHA
  or f.full_mesh_export~=true or f.mesh_count~=18 or not hash(f.glb_sha256)or not hash(f.anim_sha256)
  or not finite(f.pose_error)or f.pose_error<0 or f.pose_error>=1e-4 or not finite(f.piece_error)or f.piece_error<0 or f.piece_error>=1e-4 then return false end
 if not f.source_unit or f.source_unit.health~=6000 or f.source_unit.metal~=400 or f.source_unit.energy~=0 or f.source_unit.seconds~=169 then return false end
 for _,label in ipairs({'construction_1','construction_2','placement','upgrade_base','upgrade_fort'})do if not f.required_clips or not f.required_clips[label]then return false end end
 local bones={};for _,name in ipairs(f.bones or{})do bones[name]=true end
 local regions={'left','right','hull','main'}
 for i,region in ipairs(regions)do local m=f.mounts and f.mounts[i]
  if not m or m.index~=i or m.source_hardpoint~=i or m.muzzle~='marker_turret_'..region or m.fireclip~=region..'_fire'
   or not bones[m.muzzle]or not bones[m.aimpiece]or not bones[m.pitchpiece]or m.source_weapon_profile~='weapon/ork_shoota_turret.lua'
   or m.source_baseline_active~=(i<=2)or m.source_default_choice~=(i<=2 and 1 or 2)
   or(i>2 and m.source_requires_local_addon~=M.Addon)then return false end
  for level=0,1 do local v=f.levels and(f.levels[level]or f.levels[tostring(level)])
   if not v or v['turret_'..region]~=(i<=2 or level==1)or v['turret_barrel_'..region]~=(i<=2 or level==1)then return false end
  end
 end
 for i=1,3 do if not finite(f.collision_dimensions[i])or f.collision_dimensions[i]<=0 or not finite(f.collision_offsets_predicted[i])then return false end end
 return true
end
function M.Build(f,contract)
 -- Exact real native factory and source-script gates must be installed before
 -- these weapons are exposed, since customparams alone cannot block a Shot.
 if not M.GeometryReady(f)or not contract or type(contract.FactoryReady)~='function'or type(contract.MountGateReady)~='function'or contract.FactoryReady(M.Key)~=true or contract.MountGateReady(M.Key)~=true then return nil end
 local fx,fz=unpack(f.footprint_even);local wd,weapons={},{}
 for i,m in ipairs(f.mounts)do local w=f.weapon;local spread=math.floor((1-w.accuracy)*600+.5)
  wd['mount'..i]={name='Settlement '..({'Left','Right','Hull','Main'})[i]..' Shoota',weapontype='Cannon',turret=true,range=w.range*10,reloadtime=w.reload,burst=1,weaponvelocity=600,
   damage={default=(w.minimum_damage+w.maximum_damage)/2},accuracy=spread,sprayangle=spread,tolerance=3000,areaofeffect=1,cratermult=0,impulsefactor=0,
   collidefriendly=true,collideenemy=true,collideground=true,collidefeature=true,collideneutral=true,collidenontarget=true,avoidfriendly=true,avoidfeature=true,
   explosiongenerator='custom:40k_shoota_impact',size=.25,rgbcolor='1 .8 .3',
   customparams={source_weapon_profile=w.source_profile,source_profile_sha256=f.source_hashes.turret_weapon.sha256,source_muzzle=m.muzzle,source_fireclip=m.fireclip,
    source_aimpiece=m.aimpiece,source_pitchpiece=m.pitchpiece,source_idleclip=m.idleclip,source_weapon_bones=m.weapon_bones,source_weapon_bones_only=1,source_wholebodyaim=0,
    source_cadence_seconds=w.reload,source_accuracy=w.accuracy,source_fx_family='shoota',source_local_addon_required=i>2 and M.Addon or nil,source_baseline_active=i<=2 and 1 or 0}}
  weapons[i]={def='mount'..i,onlytargetcategory='SURFACE'}
 end
 return{name='Ork Settlement',description='Genuine Settlement and Orky Fort review candidate',objectname=M.Asset..'.glb',script='40k_roster.lua',buildpic='40k_ork_settlement.png',
  metalcost=f.source_unit.metal,energycost=f.source_unit.energy,buildtime=f.source_unit.seconds*30,health=f.source_unit.health,speed=0,canmove=false,canattack=true,builder=true,workertime=30,builddistance=180,
  footprintx=fx,footprintz=fz,yardmap=string.rep('e',fx*fz),category='ALL NOTSUB SURFACE',maxslope=15,maxwaterdepth=0,sightdistance=400,
  collisionvolumetype='Box',collisionvolumescales=table.concat(f.collision_dimensions,' '),collisionvolumeoffsets=table.concat(f.collision_offsets_predicted,' '),
  buildoptions={},weapons=weapons,weapondefs=wd,
  customparams={faction='Orks',prototype40k=1,prototype40k_expansion=1,animsource=M.Asset,rosterrole='HQ',source_entity=source,source_model_sha256=modelSHA,
   source_generated_glb_sha256=f.glb_sha256,source_native_pieces=M.Asset..'_native.lua',source_upgrade_geometry_pending=1,source_production_sequence_pending=1,
   source_factory_egress_pending=1,source_products_pending=1,source_collision_midpoint_pending=1,integration_status='genuine_allmesh_source_candidate_native_unaccepted'}}
end
function M.Definitions(f,opts,contract)
 opts=opts or{};if not VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(opts.prototype_source_progression)or(opts.prototype_diagnostic~='roster'and opts.prototype_diagnostic~='expandedproduction')then return{}end
 local d=M.Build(f,contract);return d and{[M.Key]=d}or{}
end
function M.Runtime(S,defs,f,policy)
 assert(M.GeometryReady(f)and type(policy.WholeProfileReady)=='function'and type(policy.AppliedLocal)=='function','Genuine whole-addon ownership provider required')
 local R={}
 local function owned(id)
  local def=S.GetUnitDefID(id);local d=defs[def];local cp=d and d.customParams or{}
  local hp,_,_,_,built=S.GetUnitHealth(id)
  return hp and hp>0 and built and built>=1 and cp.source_entity==source and cp.animsource==M.Asset and S.GetUnitTeam(id)~=nil
 end
 local function addon(id)
  if not owned(id)then return false end
  local okay,ready=pcall(policy.WholeProfileReady,M.Addon);if not okay or ready~=true then return false end
  local success,applied=pcall(policy.AppliedLocal,id,S.GetUnitTeam(id),M.Addon,f.source_hashes.ork_addon.sha256)
  return success and applied==true
 end
 function R.WeaponAllowed(id,n)return owned(id)and(n==1 or n==2 or((n==3 or n==4)and addon(id)))or false end
 function R.CompletedLevel(id)if not owned(id)then return nil end;return addon(id)and 1 or 0 end
 function R.CompletedPose(id)local level=R.CompletedLevel(id);return level and(level==1 and'upgrade_fort'or'upgrade_base')or nil end
 return R
end
return M
