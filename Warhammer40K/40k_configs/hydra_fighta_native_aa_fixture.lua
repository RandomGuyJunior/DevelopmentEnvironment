-- D04: one genuine Hydra/Fighta, funded setup only, ordinary native physics.
local M={}
function M.New(S,D,W,team,enemy,frame,emit)
 local C={phase='setup',start=frame,shots={},hits=0,travel=0}
 local hn,fn=UnitDefNames.imp_hydra,UnitDefNames.ork_fighta_bomba
 local h,f=hn and D[hn.id],fn and D[fn.id]
 if not h or not f or h.canFly or not f.canFly or not f.hoverAttack or(h.customParams or{}).animsource~='imp_hydra'
  or(f.customParams or{}).animsource~='ork_fighta_bomba'or not tostring(h.scriptName):lower():match('40k_roster%.lua$')
  or S.AreTeamsAllied(team,enemy)then C.result='FAIL genuine_conventional_Hydra_Fighta_required';return C end
 C.entries={};local seen={}
 for slot=1,4 do
  local e=h.weapons and h.weapons[slot];local w=e and W[e.weaponDef]
  if not w or w.type~='Cannon'or w.range~=600 or w.projectilespeed and w.projectilespeed<=0
   or(w.customParams or{}).source_fx_family~='autocannon'then C.result='FAIL native_Hydra_AA_autocannon_contract';return C end
  if seen[e.weaponDef]then C.result='INCONCLUSIVE same_WD_AA_mount_ambiguity';return C end
  seen[e.weaponDef]=true;C.entries[e.weaponDef]=slot
 end
 local function groundClear(def,x,z)
  local d=D[def];local hx,hz=(d.xsize or 8)*4+16,(d.zsize or 8)*4+16
  if x<hx+64 or z<hz+64 or x>Game.mapSizeX-hx-64 or z>Game.mapSizeZ-hz-64 then return false end
  for _,dx in ipairs({-hx,0,hx})do for _,dz in ipairs({-hz,0,hz})do if S.GetGroundHeight(x+dx,z+dz)<0 then return false end end end
  return S.TestMoveOrder(def,x,S.GetGroundHeight(x,z),z,0,0,0,true,true,false)
   and#(S.GetUnitsInRectangle(x-hx-32,z-hz-32,x+hx+32,z+hz+32)or{})==0
   and#(S.GetFeaturesInRectangle(x-hx-32,z-hz-32,x+hx+32,z+hz+32)or{})==0
 end
 -- Placement is a diagnostic ground-site preflight, not a flight controller.
 -- Aircraft have no MoveDef: native TestMoveOrder necessarily returns false.
 local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
 for _,name in ipairs({'GetGroundHeight','GetGroundNormal','TestBuildOrder','TestMoveOrder','GetUnitsInRectangle','GetFeaturesInRectangle'})do
  if type(S[name])~='function'then C.result='INCONCLUSIVE native_site_API_required_'..name;return C end
 end
 local cv=f.collisionVolume
 if not finite(f.xsize)or f.xsize<=0 or f.xsize%1~=0 or not finite(f.zsize)or f.zsize<=0 or f.zsize%1~=0
  or not finite(f.radius)or f.radius<=0 or type(cv)~='table'
  or not finite(cv.scaleX)or cv.scaleX<=0 or not finite(cv.scaleZ)or cv.scaleZ<=0
  or not finite(cv.offsetX)or not finite(cv.offsetZ)then C.result='INCONCLUSIVE actual_aircraft_native_site_shape_required';return C end
 local airHX=math.max(f.xsize*4,f.radius,math.abs(cv.offsetX)+cv.scaleX*.5)+16
 local airHZ=math.max(f.zsize*4,f.radius,math.abs(cv.offsetZ)+cv.scaleZ*.5)+16
 -- Bounded pilot scan; oversized/invalid geometry is unavailable, never guessed.
 if airHX>256 or airHZ>256 then C.result='INCONCLUSIVE aircraft_site_shape_outside_bounded_pilot';return C end
 local function aircraftClear(x,z)
  if x<airHX+64 or z<airHZ+64 or x>Game.mapSizeX-airHX-64 or z>Game.mapSizeZ-airHZ-64 then return false end
  local low,high=math.huge,-math.huge
  local xs,zs={x-airHX,x+airHX},{z-airHZ,z+airHZ}
  -- Cover every native 8-unit grid vertex in whole cells intersecting the
  -- envelope, plus exact edges. Arbitrarily shifted samples can miss a shallow
  -- wet vertex. Outside rounding is conservative and remains within edge margins.
  for sx=math.floor((x-airHX)/8)*8,math.ceil((x+airHX)/8)*8,8 do xs[#xs+1]=sx end
  for sz=math.floor((z-airHZ)/8)*8,math.ceil((z+airHZ)/8)*8,8 do zs[#zs+1]=sz end
  for _,sx in ipairs(xs)do for _,sz in ipairs(zs)do
   local y=S.GetGroundHeight(sx,sz);local ax,ay,az,slope=S.GetGroundNormal(sx,sz,true)
   if not finite(y)or y<0 or not finite(ax)or not finite(ay)or not finite(az)or not finite(slope)
    or ay<=0 or ay>1.001 or slope<0 or slope>.1 then return false end
   low=math.min(low,y);high=math.max(high,y)
   if high-low>8 then return false end
  end end
  local y=S.GetGroundHeight(x,z);if not finite(y)then return false end
  -- Pinned API internally snaps BuildInfo and maps native OPEN(3) to Lua 2.
  -- Reclaimable obstruction also returns 2, but supplies a featureID. The extra
  -- 16-unit envelope covers native half-square snapping around this exact birth.
  local status,feature=S.TestBuildOrder(fn.id,x,y,z,0)
  if status~=2 or feature~=nil then return false end
  local units=S.GetUnitsInRectangle(x-airHX-32,z-airHZ-32,x+airHX+32,z+airHZ+32)
  local features=S.GetFeaturesInRectangle(x-airHX-32,z-airHZ-32,x+airHX+32,z+airHZ+32)
  return type(units)=='table'and next(units)==nil and type(features)=='table'and next(features)==nil
 end
 local function airborne()
  local x,y,z=S.GetUnitPosition(C.target);local mt=S.GetUnitMoveTypeData(C.target)
  return x and mt and mt.name=='gunship'and mt.aircraftState=='flying'and y-S.GetGroundHeight(x,z)>=40,x,y,z
 end
 function C.Projectile(pid,owner,weapon)
  if C.phase~='fire'or owner~=C.actor or not C.entries[weapon]then return end
  if C.shots[pid]then C.result='FAIL duplicate_native_AA_projectile';return end
  local air=airborne();local los=S.GetUnitLosState(C.target,S.GetUnitAllyTeam(C.actor),false)or{}
  local x,y,z=S.GetProjectilePosition(pid);local mx,my,mz=S.GetUnitWeaponVectors(C.actor,C.entries[weapon])
  if not air or not los.los or not x or not mx or(x-mx)^2+(y-my)^2+(z-mz)^2>64^2 then C.result='FAIL AA_native_flight_LOS_or_origin';return end
  C.shots[pid]={weapon=weapon};emit('NATIVE_AA_PROJECTILE',pid,weapon,'native_origin_sanity_not_per_Query_or_render_acceptance=true')
 end
 function C.Damaged(id,damage,para,weapon,pid,attacker)
  if C.result or id~=C.target or para or damage<=0 then return end
  if C.phase~='fire'or attacker~=C.actor or not C.entries[weapon]then C.result='FAIL unrelated_or_preflight_aircraft_damage';return end
  local shot=C.shots[pid];if not shot or shot.hit or shot.weapon~=weapon then C.result='FAIL AA_native_projectile_binding_missing_or_duplicate';return end
  local air=airborne();local hp=S.GetUnitHealth(id);local los=S.GetUnitLosState(id,S.GetUnitAllyTeam(C.actor),false)or{}
  if not air or not los.los or not hp or hp>=C.lastHP then C.result='FAIL AA_airborne_native_health_loss_or_LOS_missing';return end
  shot.hit=true;C.lastHP=hp;C.hits=C.hits+1;emit('NATIVE_AA_HEALTH_LOSS',pid,weapon,damage,hp,C.hits)
 end
 function C.UnitDestroyed(id,attacker)
  if id==C.actor then C.result='FAIL funded_Hydra_lost'
  elseif id==C.target then C.result='INCONCLUSIVE Fighta_died_before_observer_completion' end
 end
 function C.Step(fr)
  if C.result then return C.result end
  if fr-C.start>1800 then return'INCONCLUSIVE funded_AA_real_flight_projectile_hit_timeout_'..C.phase end
  if C.phase=='setup'then
   local x,z
   for gx=512,Game.mapSizeX-768,128 do for gz=512,Game.mapSizeZ-512,128 do
    if groundClear(hn.id,gx,gz)and aircraftClear(gx+450,gz+300)then x,z=gx,gz;break end
   end;if x then break end end
   if not x then return'INCONCLUSIVE clear_legal_dry_AA_and_Fighta_sites_missing'end
   C.x,C.z=x,z;C.actor=S.CreateUnit('imp_hydra',x,S.GetGroundHeight(x,z),z,0,team)
   C.target=S.CreateUnit('ork_fighta_bomba',x+450,S.GetGroundHeight(x+450,z+300),z+300,0,enemy)
   if not C.actor or not C.target then return'FAIL funded_genuine_AA_aircraft_birth'end
   for _,id in ipairs({C.actor,C.target})do S.GiveOrderToUnit(id,CMD.FIRE_STATE,{0},0);S.GiveOrderToUnit(id,CMD.MOVE_STATE,{0},0)end
   C.leg=-1;S.GiveOrderToUnit(C.target,CMD.MOVE,{x-192,0,z+300},0);C.phase='flight'
   emit('FUNDED_SETUP','Hydra_and_Fighta_non_economy=true conventional_physics_and_costs_unchanged=true')
  else
   if S.GetUnitIsDead(C.actor)or S.GetUnitTeam(C.actor)~=team or S.GetUnitIsDead(C.target)or S.GetUnitTeam(C.target)~=enemy then return'FAIL fixture_actor_lost_or_transferred'end
   local ahp,_,_,_,abuilt=S.GetUnitHealth(C.actor);if not ahp or ahp<=0 or abuilt~=1 then return'FAIL funded_Hydra_incomplete'end
   local air,x,y,z=airborne();local built=S.GetUnitHealth(C.target);local _,_,_,_,completion=S.GetUnitHealth(C.target)
   if completion~=1 or not built then return'FAIL funded_aircraft_incomplete'end
   if air then
    C.airSince=C.airSince or fr
    if C.prevX then C.travel=C.travel+math.sqrt((x-C.prevX)^2+(z-C.prevZ)^2)end
    C.prevX,C.prevZ=x,z
   else C.airSince=nil;C.travel=0;C.prevX,C.prevZ=nil,nil end
   if x and(x-(C.x+C.leg*192))^2+(z-(C.z+300))^2<48^2 then C.leg=-C.leg;S.GiveOrderToUnit(C.target,CMD.MOVE,{C.x+C.leg*192,0,C.z+300},0)end
   if C.phase=='flight'and C.airSince and fr-C.airSince>=90 and C.travel>=256 then
    local los=S.GetUnitLosState(C.target,S.GetUnitAllyTeam(C.actor),false)or{}
    local ax,_,az=S.GetUnitPosition(C.actor)
    if los.los and(x-ax)^2+(z-az)^2<450^2 then
     C.lastHP=S.GetUnitHealth(C.target);C.phase='fire';emit('REAL_FLIGHT_READY',fr,C.travel,'native_flying_altitude40_duration90_normal_MOVE=true')
     S.GiveOrderToUnit(C.actor,CMD.FIRE_STATE,{2},0);S.GiveOrderToUnit(C.actor,CMD.ATTACK,{C.target},0)
    end
   elseif C.phase=='fire'and C.hits>=2 then
    S.GiveOrderToUnit(C.actor,CMD.STOP,{},0)
    return'PASS funded_non_economy_genuine_Hydra_AA_two_unique_native_autocannon_projectiles_airborne_Fighta_health_loss natural_LOS real_flight source_mount_render_death_economy_unaccepted'
   end
  end
 end
 return C
end
return M
