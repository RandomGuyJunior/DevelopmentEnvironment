function gadget:GetInfo() return {name='40K opt-in roster validation',desc='Isolated actual movement and per-mount native damage evidence',author='Local project',layer=106,enabled=true} end
if not gadgetHandler:IsSyncedCode() or Spring.GetModOptions().prototype_diagnostic~='roster' then return end
if VFS.Include('40k_configs/hellfire_native_fixture.lua').Enabled(Spring.GetModOptions())then return end
if VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(Spring.GetModOptions().prototype_source_progression) then return end
-- Dedicated real cargo fixture owns completion only under this explicit opt-in.
if tostring(Spring.GetModOptions().prototype_transport_review)=='1' then return end
-- Dedicated Lifta fixture owns seeds only with both explicit opt-ins.
if tostring(Spring.GetModOptions().prototype_lifta_review)=='1' and tostring(Spring.GetModOptions().prototype_lifta_fixture)=='1' then return end
local Filter=VFS.Include('40k_configs/roster_filter.lua')
local names,owned={},{}
local gaitReview=tonumber(Spring.GetModOptions().prototype_gait_review)==1
local gaitBaselines={imp_guardsman=true,imp_marine=true,ork_boy=true}
local active,cursor,nextStart=nil,0,90
local totals={units=0,mounts=0,passes=0,unknowns=0}
local sluggaObserver
local function echo(...) Spring.Echo('40K ROSTER VALIDATION',...) end
local function finite(x) return type(x)=='number' and x==x and math.abs(x)<math.huge end
local function setphase(label)
 active.phase=label;active.start=Spring.GetGameFrame()
 Spring.SetUnitRulesParam(active.id,'40k_roster_phase',label,{public=true})
 Spring.SetUnitRulesParam(active.id,'40k_roster_phase_start',active.start,{public=true})
end
local function cleanup()
 for _,id in ipairs(owned) do if Spring.ValidUnitID(id) and not Spring.GetUnitIsDead(id) then Spring.DestroyUnit(id,false,true) end end
 owned={}
end
local function create(name,x,z,team)
 local id=Spring.CreateUnit(name,x,Spring.GetGroundHeight(x,z),z,0,team)
 if id then owned[#owned+1]=id;Spring.GiveOrderToUnit(id,CMD.FIRE_STATE,{0},{});Spring.GiveOrderToUnit(id,CMD.MOVE_STATE,{0},{}) end
 return id
end
local function envcall(name,...)
 local env=Spring.UnitScript.GetScriptEnv(active.id)
 if env and env[name] then local result=Spring.UnitScript.CallAsUnit(active.id,env[name],...);return result~=false end
 return false
end
local function lane()
 local margin=700
 for z=margin,Game.mapSizeZ-margin,128 do
  for x=margin,Game.mapSizeX-margin,128 do
   local y=Spring.GetGroundHeight(x,z);local valid=y>0
   for dz=-64,640,64 do if math.abs(y-Spring.GetGroundHeight(x,z+dz))>2 then valid=false end end
   if Spring.GetFeaturesInRectangle and #Spring.GetFeaturesInRectangle(x-100,z-100,x+150,z+640)>0 then valid=false end
   if valid then return x,z end
  end
 end
 return Game.mapSizeX*.45,Game.mapSizeZ*.4
end
local function finishunit()
 echo('UNIT COMPLETE',active.name,'mounts',#(active.ud.weapons or {}),'native_hits',active.totalHits,'movement',active.movement or 'not_mobile')
 totals.units=totals.units+1;cleanup();active=nil;nextStart=Spring.GetGameFrame()+30
end
local function startmount()
 active.mount=active.mount+1
 if active.mount>#(active.ud.weapons or {}) then finishunit();return end
 local w=active.ud.weapons[active.mount];local wd=WeaponDefs[w.weaponDef or w.weaponDefID];active.wd=wd;active.hits=0;active.damage=0
 if not wd then echo('UNKNOWN','weapon_definition',active.name,active.mount);totals.unknowns=totals.unknowns+1;setphase('next');return end
 local params=wd.customParams or {}
 if params.source_passive or wd.type=='Shield' then echo('DEFERRED ROLE',active.name,active.mount,'passive_field_requires_native_shield_proof');setphase('next');return end
 if params.requires_native_interception or params.requires_native_beam_interception then echo('DEFERRED ROLE',active.name,active.mount,'strategic_interception_requires_paid_native_proof');setphase('next');return end
 local range=tonumber(wd.range) or 0;local melee=wd.type=='Melee' or wd.weapontype=='Melee'
 local sight=Spring.GetUnitSensorRadius and Spring.GetUnitSensorRadius(active.id,'los') or active.ud.sightDistance or active.ud.sightdistance or 400
 local distance=math.max(12,math.min(550,range*(melee and .55 or .6),sight*.75))
 local aa=(active.ud.customParams or {}).prototype40k_vital=='anti_air' and not ((params.source_fx_family or '')=='heavy_bolter' and active.name=='imp_hydra')
 local x,y,z=Spring.GetUnitPosition(active.id);local targetname=aa and 'armpeep' or UnitDefNames.armflash and 'armflash' or 'imp_marine'
 if active.target and Spring.ValidUnitID(active.target) then Spring.DestroyUnit(active.target,false,true) end
 active.target=create(targetname,x,z+distance,1)
 if not active.target then echo('UNKNOWN','target_create_failed',active.name,active.mount);totals.unknowns=totals.unknowns+1;setphase('next');return end
 if aa then
  if not Spring.MoveCtrl or not Spring.MoveCtrl.Enable or not Spring.MoveCtrl.SetPosition then echo('UNKNOWN','air_fixture_position_api',active.name,active.mount);totals.unknowns=totals.unknowns+1;setphase('next');return end
  Spring.MoveCtrl.Enable(active.target);Spring.MoveCtrl.SetPosition(active.target,x,y+100,z+distance)
  echo('AIR TARGET',active.name,active.mount,targetname,'actual_native_VTOL_model_fixed_position',x,y+100,z+distance)
 end
 Spring.SetUnitMaxHealth(active.target,1000000);Spring.SetUnitHealth(active.target,1000000)
 Spring.SetUnitRulesParam(active.id,'40k_validation_mount',active.mount,{public=true})
 Spring.SetUnitRulesParam(active.id,'40k_roster_mount',active.mount,{public=true})
 Spring.GiveOrderToUnit(active.id,CMD.FIRE_STATE,{2},{})
 Spring.GiveOrderToUnit(active.id,CMD.ATTACK,{active.target},{})
 if Spring.GetUnitLosState then echo('TARGET LOS',active.name,active.mount,Spring.GetUnitLosState(active.target,0,true)) end
 echo('MOUNT START',active.name,active.mount,wd.name,'range',range,'target_distance',distance,'native_fixture_HP_only')
 local px,py,pz,dx,dy,dz=Spring.GetUnitWeaponVectors(active.id,active.mount)
 echo('NATIVE VECTOR',active.name,active.mount,px,py,pz,dx,dy,dz)
 setphase(melee and 'melee' or 'fire')
end
local function nextattachment()
 if active.gaitOnly then echo('GAIT ONLY',active.name,'baseline weapon/attachment validation requires six-unit suite');finishunit();return end
 if #(active.ud.weapons or {})==0 then finishunit();return end
 active.pose=active.pose+1
 if active.pose>4 then envcall('TestRosterMount',nil,nil,nil);active.mount=0;startmount();return end
 local h=active.pose==2 and math.pi/2 or active.pose==3 and -math.pi/2 or 0
 local p=active.pose==4 and -.25 or 0
 local supported=envcall('TestRosterMount',1,h,p)
 setphase('attachment_'..active.pose)
 echo('ATTACHMENT POSE',active.name,active.pose,'hook',supported,'heading',h,'pitch',p)
 if not supported then echo('UNKNOWN','attachment_hook_missing',active.name);totals.unknowns=totals.unknowns+1 end
end
function gadget:Initialize()
 local filter=tostring(Spring.GetModOptions().prototype_roster_filter or '')
 for _,ud in pairs(UnitDefs) do
  local cp=ud.customParams or {};local source=cp.animsource
  if (cp.rosterrole or (gaitReview and gaitBaselines[ud.name])) and cp.prototype40k and source and Filter.Match(filter,ud.name) then
   if VFS.FileExists('objects3d/'..source..'.glb') and VFS.FileExists('scripts/generated/'..source..'_anim.lua') then names[#names+1]=ud.name
   else echo('SKIP MISSING ASSET',ud.name) end
  end
 end
 table.sort(names);echo('BEGIN','available_units',#names,'filter',filter,'no_factory_or_fidelity_claim')
end
function gadget:GameFrame(f)
 if not active then
  if f<nextStart then return end
  cursor=cursor+1
  if cursor>#names then
   if nextStart~=math.huge then echo('COMPLETE','units',totals.units,'mounts',totals.mounts,'mount_passes',totals.passes,'unknowns',totals.unknowns);Spring.SetGameRulesParam('40k_roster_validation_complete',f,{public=true});nextStart=math.huge end
   return
  end
  local name=names[cursor];local ud=UnitDefs[UnitDefNames[name].id];local x,z=lane();local id=create(name,x,z,0)
  if not id then echo('UNKNOWN','unit_create_failed',name);totals.unknowns=totals.unknowns+1;nextStart=f+30;return end
  active={id=id,name=name,ud=ud,x=x,z=z,pose=0,mount=0,totalHits=0,gaitOnly=gaitReview and gaitBaselines[name] and not (ud.customParams or {}).rosterrole}
  Spring.SetUnitRulesParam(id,'40k_roster_validation',cursor,{public=true});Spring.SetUnitRulesParam(id,'40k_validation_mount',0,{public=true})
  local map=Spring.GetUnitPieceMap(id);local count=0;for _ in pairs(map or {}) do count=count+1 end
  echo('CREATED',name,id,'native_pieces',count,'native_radius',Spring.GetUnitRadius(id),'native_height',Spring.GetUnitHeight(id))
  if count==0 then echo('UNKNOWN','empty_native_model',name);totals.unknowns=totals.unknowns+1 end
  for n,w in ipairs(ud.weapons or {}) do
   local wd=WeaponDefs[w.weaponDef or w.weaponDefID];local cp=wd and wd.customParams or {};local p=cp.source_muzzle
   echo('MOUNT PIECE',name,n,p or 'runtime_default',p and map[p] or 'unknown')
   if p and not map[p] then echo('UNKNOWN','missing_muzzle_piece',name,n,p);totals.unknowns=totals.unknowns+1 end
  end
  setphase('idle');return
 end
 if not Spring.ValidUnitID(active.id) or Spring.GetUnitIsDead(active.id) then echo('UNKNOWN','test_actor_died',active.name);totals.unknowns=totals.unknowns+1;cleanup();active=nil;nextStart=f+30;return end
 local age=f-active.start
 if active.name=='ork_slugga'and active.phase=='melee'then
  if not sluggaObserver then sluggaObserver=VFS.Include('40k_configs/40k_slugga_melee_observer.lua').New(Spring,WeaponDefs,echo)end
  sluggaObserver.Observe(active,f)
 end
 if (active.phase=='fire' or active.phase=='melee') and active.hits==0 and age>=120 and age%120==0 then
  if age==120 then envcall('ReportTestNativePose') end
  local id,n,target=active.id,active.mount,active.target
  local function probe(api,...)
   local fn=Spring[api];if not fn then return 'unavailable' end
   local value=fn(...);if value==nil then return 'nil' end;return tostring(value)
  end
  local px,py,pz=Spring.GetUnitWeaponVectors(id,n)
  local tx,ty,tz=Spring.GetUnitPosition(target)
  echo('FIRING GATES',active.name,n,'age',age,'canFire',probe('GetUnitWeaponCanFire',id,n),
   'ignoreAngle',probe('GetUnitWeaponCanFire',id,n,true),
   'ignoreRequestedDir',probe('GetUnitWeaponCanFire',id,n,true,false,true),
   'testTarget',probe('GetUnitWeaponTestTarget',id,n,target),'testRange',probe('GetUnitWeaponTestRange',id,n,target),
   'lineOfFire',probe('GetUnitWeaponHaveFreeLineOfFire',id,n,target),'muzzleLineOfFire',probe('GetUnitWeaponHaveFreeLineOfFire',id,n,px,py,pz,target),
   'tryTarget',probe('GetUnitWeaponTryTarget',id,n,target),'muzzle',px,py,pz,'ground',Spring.GetGroundHeight(px,pz),'target',tx,ty,tz)
 end
 if active.phase=='idle' and age>=90 then
  if active.ud.canMove and (active.ud.speed or 0)>0 then Spring.GiveOrderToUnit(active.id,CMD.MOVE,{active.x+100,Spring.GetGroundHeight(active.x+100,active.z),active.z},{});setphase('walk')
  else nextattachment() end
 elseif active.phase=='walk' then
  local x,y,z=Spring.GetUnitPosition(active.id);local d=math.sqrt((x-active.x)^2+(z-active.z)^2)
  if d>=80 or age>=900 then
   active.movement=d>=80 and 'PASS' or 'UNKNOWN';echo('MOVEMENT',active.name,active.movement,'displacement',d,'frames',age)
   if d<80 then totals.unknowns=totals.unknowns+1 end
   Spring.GiveOrderToUnit(active.id,CMD.STOP,{},{});nextattachment()
  end
 elseif active.phase:find('attachment_',1,true) and age>=60 then
  local x,y,z,dx,dy,dz=Spring.GetUnitWeaponVectors(active.id,1);echo('ATTACHMENT VECTOR',active.name,active.pose,x,y,z,dx,dy,dz)
  nextattachment()
 elseif active.phase=='next' and age>=15 then startmount()
 elseif (active.phase=='fire' or active.phase=='melee') and (active.hits>=2 or age>=900) then
  local shot=Spring.GetUnitRulesParam(active.id,'40k_last_shot_'..active.mount)
  local px,py,pz,dx,dy,dz=Spring.GetUnitWeaponVectors(active.id,active.mount)
  local vector=finite(px) and finite(py) and finite(pz) and finite(dx) and finite(dy) and finite(dz) and dx*dx+dy*dy+dz*dz>0
  local ok=active.hits>0 and shot and shot>=active.start and vector
  if Spring.GetUnitWeaponState then echo('WEAPON STATE',active.name,active.mount,'angleGood',Spring.GetUnitWeaponState(active.id,active.mount,'angleGood'),'reloadState',Spring.GetUnitWeaponState(active.id,active.mount,'reloadState'),'aimReady',Spring.GetUnitWeaponState(active.id,active.mount,'aimReady')) end
  echo('MOUNT RESULT',active.name,active.mount,ok and 'PASS' or 'UNKNOWN','native_hits',active.hits,'damage',active.damage,'shot_frame',shot,'finite_native_vector',vector,'elapsed_frames',age)
  totals.mounts=totals.mounts+1;if ok then totals.passes=totals.passes+1 else totals.unknowns=totals.unknowns+1 end
  Spring.GiveOrderToUnit(active.id,CMD.STOP,{},{});Spring.GiveOrderToUnit(active.id,CMD.FIRE_STATE,{0},{});Spring.SetUnitRulesParam(active.id,'40k_validation_mount',0,{public=true});setphase('next')
 end
end
function gadget:UnitDamaged(id,def,team,damage,paralyzer,weapon,projectile,attacker)
 if active and id==active.target and attacker==active.id and damage>0 then
  local expected=active.ud.weapons[active.mount];local wid=expected and (expected.weaponDef or expected.weaponDefID)
  if weapon==wid then active.hits=active.hits+1;active.totalHits=active.totalHits+1;active.damage=active.damage+damage;echo('NATIVE HIT',active.name,active.mount,weapon,damage,Spring.GetGameFrame())
  else echo('UNKNOWN','unexpected_other_mount_hit',active.name,active.mount,weapon);totals.unknowns=totals.unknowns+1 end
 end
end
function gadget:Shutdown() cleanup() end
