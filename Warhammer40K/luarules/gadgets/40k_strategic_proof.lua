function gadget:GetInfo()
 return {name='40K paid strategic and field proof',desc='Opt-in native interception evidence without economy or ammo grants',author='Local project',layer=106,enabled=true}
end
if not gadgetHandler:IsSyncedCode() then return end
local opts=Spring.GetModOptions()
if opts.prototype_diagnostic~='vital' or tostring(opts.prototype_strategic_proof)~='1' then return end
local field=opts.prototype_strategic_case=='shield'
local commander,enemy,base,plan,defender,factory,faction
local births,mexes={},{}
local fieldDefs={}
local function fieldOwnerValid(id,expectedTeam)return id~=nil and fieldDefs[id]~=nil and Spring.GetUnitTeam(id)==expectedTeam and Spring.GetUnitDefID(id)==fieldDefs[id]end
local stage,pending,issued,result=1,false,0,0
local started,launchFrame,pid,last,deleted,damage,impact=false,nil,nil,nil,false,0,nil
local shotBefore,ammoBefore,consumed,shieldHit,powerBefore,powerDropped=0,nil,false,false,nil,false
local missileWeapon,defenceWeapon,defenceNum,ttl= nil,nil,1,900
local spawnPosition,travelled=nil,false
local function log(event,... ) Spring.Echo('40K STRATEGIC',event,Spring.GetGameFrame(),...) end
local function finish(pass,why)
 if result~=0 then return end
 result=pass and 1 or -1;Spring.SetGameRulesParam('40k_strategic_result',result)
 Spring.SetGameRulesParam('40k_strategic_reason',why);log(pass and 'PASS' or 'FAIL',why,faction or 'unknown')
 if not pass and faction=='Necrons' and not field then
  log('BEAM_CANDIDATE_REMAINS_UNVALIDATED','If the engine rejects BeamLaser interception, use a genuine source particle projectile adaptation and repeat this proof; ordinary shields do not intercept mask-zero strategic weapons.')
 end
end
local function economy(event)
 local m,_,mp,mi,me=Spring.GetTeamResources(0,'metal');local e,_,ep,ei,ee=Spring.GetTeamResources(0,'energy')
 log('NATIVE_RESOURCE_READBACK',event,m or -1,e or -1,mp or -1,ep or -1,mi or -1,ei or -1,me or -1,ee or -1)
end
local function shot() return tonumber((Spring.GetUnitRulesParam(defender,'40k_last_shot_'..defenceNum))) or 0 end
-- A paired barrel is stamped by the real Shot; single-barrel runtimes have
-- no last_muzzle rule. Read their genuine native QueryWeapon instead, without
-- synthesizing Shot, projectile, damage or public evidence parameters.
local function sourceMuzzleProof()
 local wd=WeaponDefs[defenceWeapon];local cp=wd and wd.customParams or {}
 local map=Spring.GetUnitPieceMap and Spring.GetUnitPieceMap(defender)
 if not map or not Spring.GetUnitPiecePosDir then return nil end
 local handle
 if cp.source_muzzle_pair then
  handle=tonumber((Spring.GetUnitRulesParam(defender,'40k_last_muzzle_'..defenceNum)))
  local belongs=false
  for name in tostring(cp.source_muzzle_pair):gmatch('[^,;]+')do
   local trimmed=name:match('^%s*(.-)%s*$');if map[trimmed]~=nil and map[trimmed]==handle then belongs=true end
  end
  if not belongs then return nil end
 else
  local expected=cp.source_muzzle and map[cp.source_muzzle]
  local api=Spring.UnitScript
  local env=api and api.GetScriptEnv and api.GetScriptEnv(defender)
  local query=env and env.script and env.script.QueryWeapon
  if expected==nil or type(query)~='function' or not api.CallAsUnit then return nil end
  local ok,value=pcall(api.CallAsUnit,defender,query,defenceNum)
  if not ok or value~=expected then return nil end
  handle=value
 end
 local x,y,z=Spring.GetUnitPiecePosDir(defender,handle)
 local function finite(v)return type(v)=='number' and v==v and math.abs(v)<math.huge end
 if not finite(x) or not finite(y) or not finite(z) then return nil end
 log('NATIVE_SOURCE_MUZZLE_READBACK',handle,x,y,z,cp.source_muzzle_pair and 'real_shot_paired_barrel' or 'single_source_QueryWeapon')
 return handle
end
local function option(id,target)
 for _,d in ipairs(UnitDefs[Spring.GetUnitDefID(id)].buildOptions or {})do if d==target then return true end end
 return false
end
local function site(d,x,z)
 for ring=0,16 do for k=0,15 do
  local a=k*math.pi/8;local xx=math.floor((x+ring*32*math.cos(a))/16)*16+8;local zz=math.floor((z+ring*32*math.sin(a))/16)*16+8
  local clear=xx>64 and zz>64 and xx<Game.mapSizeX-64 and zz<Game.mapSizeZ-64
  if factory then local fx,_,fz=Spring.GetUnitPosition(factory);if fx and math.abs(xx-fx)<200 and zz>fz-80 and zz<fz+320 then clear=false end end
  if clear then local y=Spring.GetGroundHeight(xx,zz);if y>=0 and Spring.TestBuildOrder(d,xx,y,zz,0)==2 then return {xx,y,zz,0}end end
 end end
end
local function mexsite(d)
 local candidates={}
 for x=math.max(64,base[1]-900),math.min(Game.mapSizeX-64,base[1]+900),16 do
  for z=math.max(64,base[3]-900),math.min(Game.mapSizeZ-64,base[3]+900),16 do
   if (select(3,Spring.GetGroundInfo(x,z)) or 0)>0 then candidates[#candidates+1]={x,z,(x-base[1])^2+(z-base[3])^2}end
  end
 end
 table.sort(candidates,function(a,b)if a[3]~=b[3]then return a[3]<b[3]end;if a[1]~=b[1]then return a[1]<b[1]end;return a[2]<b[2]end)
 for _,p in ipairs(candidates)do local clear=true
  for _,m in ipairs(mexes)do if (p[1]-m[1])^2+(p[2]-m[2])^2<128^2 then clear=false end end
  if clear then local pos=site(d,p[1],p[2]);if pos then mexes[#mexes+1]=pos;return pos end end
 end
end
local function build()
 local p=plan[stage];local ud=UnitDefNames[p.name];local builder=p.factory and factory or commander
 if not ud or not builder or not option(builder,ud.id)then finish(false,'missing_paid_build_edge_'..p.name);return end
 local params={}
 if not p.factory then
  params=p.mex and mexsite(ud.id) or site(ud.id,base[1]+((stage-1)%3-1)*240,base[3]+math.floor((stage-1)/3)*240-240)
  if not params then finish(false,'missing_dry_build_site_'..p.name);return end
 end
 pending=true;issued=Spring.GetGameFrame();Spring.GiveOrderToUnit(builder,-ud.id,params,{})
 log('PAID_BUILD_ORDER',p.name,builder,ud.metalCost or 0,ud.energyCost or 0);economy('build_order')
end
local function setup()
 for _,id in ipairs(Spring.GetTeamUnits(0))do
  local name=UnitDefs[Spring.GetUnitDefID(id)].name
  if name=='imp_field_commander' or name=='ork_big_mek_commander' or name=='nec_lord' then commander=id;faction=name=='imp_field_commander' and 'Imperium' or name=='ork_big_mek_commander' and 'Orks' or 'Necrons';break end
 end
 for _,id in ipairs(Spring.GetTeamUnits(1))do enemy=id;break end
 if commander and tostring((UnitDefs[Spring.GetUnitDefID(commander)].customParams or {}).prototype40k)~='1' then finish(false,'engine_initial_commander_not_converted');return end
 if not commander or not enemy then finish(false,'engine_initial_commander_or_hostile_owner_missing');return end
 if Spring.AreTeamsAllied(0,1)then finish(false,'teams_must_be_hostile');return end
 local x,y,z=Spring.GetUnitPosition(commander);base={x,y,z};plan={}
 local prefix=faction=='Imperium' and 'arm' or faction=='Orks' and 'cor' or 'nec_'
 for _=1,2 do plan[#plan+1]={name=prefix..'mex',mex=true}end
 for _=1,6 do plan[#plan+1]={name=faction=='Necrons' and 'nec_generator' or prefix..'solar'}end
 if faction=='Orks' then plan[#plan+1]={name=field and 'wh40k_corlab' or 'corvp',isfactory=true}end
 if field and faction=='Imperium' then finish(false,'no_source_imperial_field_candidate');return end
 plan[#plan+1]={name=field and (faction=='Orks' and 'ork_big_mek_defence' or 'nec_shield_spike') or
  (faction=='Imperium' and 'imp_missile_defence' or faction=='Orks' and 'ork_rokkit_interceptor' or 'nec_particle_interceptor'),factory=faction=='Orks',defender=true}
 for _,p in ipairs(plan)do if not UnitDefNames[p.name]then finish(false,'asset_gated_definition_'..p.name);return end end
 if field then fieldDefs[commander]=Spring.GetUnitDefID(commander);fieldDefs[enemy]=Spring.GetUnitDefID(enemy)end
 started=true;log('ENGINE_INITIAL_PROVENANCE',commander,enemy,faction,field and 'ordinary_field' or 'strategic')
 Spring.SetGameRulesParam('40k_strategic_result',0);Spring.SetGameRulesParam('40k_strategic_case',field and 'shield' or 'strategic')
end
function gadget:UnitCreated(id,def,team,builder) if team==0 then births[id]={builder=builder,frame=Spring.GetGameFrame()}end end
function gadget:UnitFinished(id,def,team)
 if result~=0 then return end
 if team~=0 or not started or not pending then return end
 local p=plan[stage];local b=births[id];local expected=p.factory and factory or commander
 if UnitDefs[def].name~=p.name or not b or b.builder~=expected or b.frame<issued then return end
 log('PAID_FINISHED_PROVENANCE',p.name,id,b.builder);economy('unit_finished')
 if field then fieldDefs[id]=def end
 if p.isfactory then factory=id end
 if p.defender then
  defender=id;local weapons=UnitDefs[def].weapons or {}
  for n,m in ipairs(weapons)do local w=WeaponDefs[m.weaponDef]
   if (field and w.type=='Shield') or (not field and (w.interceptor or 0)>0)then defenceNum=n;defenceWeapon=m.weaponDef;break end
  end
  if not defenceWeapon then finish(false,'required_native_weapon_missing');return end
  Spring.GiveOrderToUnit(id,CMD.STOP,{},{})
  if p.factory then local fx,_,fz=Spring.GetUnitPosition(factory);local ex=math.min(Game.mapSizeX-96,fx+280);local ez=math.min(Game.mapSizeZ-96,fz+320)
   Spring.GiveOrderToUnit(id,CMD.MOVE,{ex,Spring.GetGroundHeight(ex,ez),ez},{})
   log('NATIVE_FACTORY_EGRESS_ORDER',id,factory,ex,ez)
  end
  if not field and faction~='Necrons' then
   if not Spring.FindUnitCmdDesc(id,CMD.STOCKPILE)then finish(false,'native_stockpile_command_missing');return end
   Spring.GiveOrderToUnit(id,CMD.STOCKPILE,{},{})
   log('PAID_STOCKPILE_ORDER',id,defenceNum,WeaponDefs[defenceWeapon].metalCost or 0,WeaponDefs[defenceWeapon].energyCost or 0);economy('stockpile_order')
  end
 end
 pending=false;stage=stage+1
end
local function launch()
 if not Spring.SpawnProjectile or not Spring.GetProjectilePosition or not Spring.SetProjectileTarget or not Script.SetWatchProjectile or not Script.SetWatchExplosion then finish(false,'native_projectile_api_missing');return end
 local source=UnitDefNames[field and 'imp_marine' or 'armsilo']
 if source then for _,w in ipairs(UnitDefs[source.id].weapons or {})do
  local wd=WeaponDefs[w.weaponDef]
  if field or (wd.targetable or 0)>0 then missileWeapon=w.weaponDef;break end
 end end
 if not missileWeapon then finish(false,'pinned_hostile_weapon_missing');return end
 local wd=WeaponDefs[missileWeapon]
 local mask=wd.interceptedByShieldType or wd.interceptedbyshieldtype or 0
 if field and mask==0 then finish(false,'ordinary_fixture_weapon_does_not_hit_shields');return end
 if not field and mask~=0 then finish(false,'strategic_fixture_requires_mask_zero');return end
 local x,y,z=Spring.GetUnitPosition(defender)
 local radius=field and (WeaponDefs[defenceWeapon].shieldRadius or 280) or 0
 local distance=field and radius+180 or 900
 local sign=x+distance<Game.mapSizeX-64 and 1 or -1
 if x+sign*distance<64 then finish(false,'insufficient_projectile_lane');return end
 local sx,sy,sz=x+sign*distance,y+(field and 35 or 650),z
 local tx,ty,tz=x,y+15,z;local dx,dy=tx-sx,ty-sy;local len=math.sqrt(dx*dx+dy*dy)
 local speed=wd.projectilespeed
 if not speed or speed<=0 then finish(false,'missing_native_projectile_speed');return end
 if field then ttl=math.ceil(len/speed)+120 end
 if Script.SetWatchProjectile then Script.SetWatchProjectile(missileWeapon,true);Script.SetWatchProjectile(defenceWeapon,true)end
 if Script.SetWatchExplosion then Script.SetWatchExplosion(missileWeapon,true)end
 shotBefore=shot();ammoBefore=tonumber((Spring.GetUnitStockpile(defender)))
 if field then local enabled,power=Spring.GetUnitShieldState(defender,defenceNum);if enabled~=true and enabled~=1 or not power or power<=0 then finish(false,'native_field_not_charged');return end;powerBefore=power
  if tonumber((Spring.GetUnitRulesParam(defender,'40k_passive_mount_'..defenceNum)))~=1 then finish(false,'genuine_field_origin_not_validated');return end
 end
 launchFrame=Spring.GetGameFrame();last={sx,sy,sz};spawnPosition={sx,sy,sz};damage=0
 pid=Spring.SpawnProjectile(missileWeapon,{owner=enemy,team=1,weapon=1,pos=last,speed={dx/len*speed,dy/len*speed,0},['end']={tx,ty,tz},gravity=0,ttl=ttl})
 if not pid then finish(false,'native_spawn_failed');return end
 local target=Spring.SetProjectileTarget(pid,defender,117)
 if target~=true then finish(false,'native_projectile_target_rejected');return end
 log('HOSTILE_NATIVE_PROJECTILE',pid,missileWeapon,wd.name,wd.targetable or 0,mask,defender,ammoBefore or -1,shotBefore,ttl)
end
function gadget:StockpileChanged(id,def,team,num,old,new)
 if id==defender then log('NATIVE_STOCKPILE_CHANGED',id,num,old,new)
  if launchFrame and num==defenceNum and new<old then consumed=true end
 end
end
function gadget:ProjectileCreated(id,owner,weapon)
 if owner==defender and weapon==defenceWeapon then log('NATIVE_INTERCEPTOR_PROJECTILE',id,owner,weapon)end
end
function gadget:ProjectileDestroyed(id)
 if id~=pid then return end
 local x,y,z=Spring.GetProjectilePosition(id);if x then last={x,y,z}end
 deleted=true;Spring.SetGameRulesParam('40k_strategic_deleted_frame',Spring.GetGameFrame());log('NATIVE_HOSTILE_DELETED',id,last[1],last[2],last[3])
end
function gadget:Explosion(weapon,x,y,z,owner,projectile)
 if weapon==missileWeapon and (projectile==pid or owner==enemy)then impact={x,y,z};log('NATIVE_HOSTILE_EXPLOSION',projectile or -1,x,y,z)end
 return false -- never suppress engine damage or explosions
end
function gadget:UnitDamaged(id,def,team,amount,paralyzer,weapon,projectile)
 if id==defender and weapon==missileWeapon then damage=damage+amount;log('NATIVE_TARGET_DAMAGE',amount,projectile or -1)end
end
-- Recoil current signature; observation only, false leaves engine shield handling intact.
function gadget:ShieldPreDamaged(projectile,owner,num,carrier,bounce,beamNum,beamOwner,sx,sy,sz,hx,hy,hz)
 if field and result==0 and projectile==pid and carrier==defender and num==defenceNum then
  if owner~=enemy or not fieldOwnerValid(carrier,0)or not fieldOwnerValid(enemy,1)then finish(false,'native_field_callback_owner_changed');return false end
  shieldHit=true;log('NATIVE_FIELD_CALLBACK',projectile,carrier,num,hx or -1,hy or -1,hz or -1)
 end
 return false
end
function gadget:UnitDestroyed(id)
 if id==commander or id==defender or id==factory then finish(false,'paid_fixture_unit_destroyed')end
 births[id]=nil
end
-- Native UnitTaken is oldTeam,newTeam; UnitGiven is newTeam,oldTeam.
-- Observation refuses stale paid-owner proof; native transfer/shield charge is untouched.
local function fieldTransfer(id,def,newTeam)
 if field and result==0 and fieldDefs[id]~=nil and(id==commander or id==factory or id==defender or id==enemy)then
  local expected=id==enemy and 1 or 0
  if def~=fieldDefs[id]or newTeam~=expected then finish(false,'paid_field_fixture_unit_transferred')end
 end
end
-- Taken runs before native team assignment; trust the explicit newTeam argument.
-- Given reverses the native team argument order. Same-owner notifications remain valid.
local function captured(id,def,newTeam)
 if id~=nil and(id==commander or id==defender or id==factory or id==enemy or births[id])then
  local expected=id==enemy and 1 or 0
  if newTeam~=expected then finish(false,'paid_fixture_ownership_changed')end
 end
end
function gadget:UnitTaken(id,def,oldTeam,newTeam)
 captured(id,def,newTeam);fieldTransfer(id,def,newTeam)
end
function gadget:UnitGiven(id,def,newTeam,oldTeam)
 captured(id,def,newTeam);fieldTransfer(id,def,newTeam)
end
function gadget:GameFrame(f)
 if result~=0 then return end
 if field and started then
  if not fieldOwnerValid(commander,0)or not fieldOwnerValid(enemy,1)or(factory~=nil and not fieldOwnerValid(factory,0))or(defender~=nil and not fieldOwnerValid(defender,0))then finish(false,'paid_field_fixture_identity_changed');return end
 end
 if launchFrame then
  local x,y,z=Spring.GetProjectilePosition(pid);if x then last={x,y,z}
   if (x-spawnPosition[1])^2+(y-spawnPosition[2])^2+(z-spawnPosition[3])^2>16^2 then travelled=true end
  end
  if field then local _,power=Spring.GetUnitShieldState(defender,defenceNum);if power and power<powerBefore then powerDropped=true end end
  if deleted and f>=launchFrame+30 then
   local dx,dy,dz=Spring.GetUnitPosition(defender);local p=impact or last
   local away=dx and ((p[1]-dx)^2+(p[3]-dz)^2>100^2 or p[2]>Spring.GetGroundHeight(p[1],p[3])+60)
   local early=(tonumber((Spring.GetGameRulesParam('40k_strategic_deleted_frame'))) or f)<launchFrame+ttl-10
   local shotNow=shot();local sourceMuzzle=not field and shotNow>=launchFrame and shotNow>shotBefore and sourceMuzzleProof() or nil
   local fired=shotNow>=launchFrame and shotNow>shotBefore and sourceMuzzle~=nil and sourceMuzzle>=0
   local ammo=tonumber((Spring.GetUnitStockpile(defender)));if ammoBefore and ammo and ammo<ammoBefore then consumed=true end
   local passed=travelled and early and away and damage==0 and (field and shieldHit and powerDropped or not field and fired and (faction=='Necrons' or consumed))
   Spring.SetGameRulesParam('40k_strategic_source_shot',fired and 1 or 0);Spring.SetGameRulesParam('40k_strategic_ammo_consumed',consumed and 1 or 0)
   Spring.SetGameRulesParam('40k_strategic_field_callback',shieldHit and 1 or 0)
   log('EVIDENCE',travelled,early,away,damage,shotBefore,shotNow,sourceMuzzle or -1,ammoBefore or -1,ammo or -1,consumed,shieldHit,powerDropped)
   finish(passed,'native_'..(field and 'ordinary_field' or 'strategic_interception')..(passed and '_verified' or '_evidence_incomplete'));return
  end
  if f>launchFrame+ttl+60 then finish(false,'native_projectile_not_intercepted_before_timeout')end
  return
 end
 if f%30~=0 then return end
 if not started then if f>=180 then setup()end;return end
 if f>54000 then finish(false,'paid_economy_or_stockpile_timeout');return end
 if pending then if f-issued>18000 then finish(false,'paid_build_timeout_'..plan[stage].name)end;return end
 if plan[stage]then build();return end
 if not defender then finish(false,'paid_defender_missing');return end
 if not field and faction~='Necrons' then local count=tonumber((Spring.GetUnitStockpile(defender)));if not count or count<1 then return end end
 -- Allow finished factory products to leave the factory and fields to activate naturally.
 if f-issued<180 then return end
 if factory then local fx,_,fz=Spring.GetUnitPosition(factory);local x,_,z=Spring.GetUnitPosition(defender)
  if not x or (x-fx)^2+(z-fz)^2<120^2 then return end
  Spring.GiveOrderToUnit(defender,CMD.STOP,{},{})
 end
 economy('projectile_launch');launch()
end
