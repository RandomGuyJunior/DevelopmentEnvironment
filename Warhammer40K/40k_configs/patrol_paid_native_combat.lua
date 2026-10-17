-- Ordinary paid products are admitted only by the completed repeat driver.
-- One surface missile question; enemy creation is funded, no own resource grant.
local M={}
local physical=VFS.Include('40k_configs/guard_factory_egress_geometry.lua')
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
function M.New(S,D,W,paid,enemy,frame,emit)
 local C={start=frame,phase='setup',pids={},pending={},count=0}
 local function fail(reason)C.result='INCONCLUSIVE '..reason;return C.result end
 local dn=UnitDefNames.fortyk_ork_patrol_boat;local tn=UnitDefNames.fortyk_guard_naval_constructor
 local d=dn and D[dn.id];local td=tn and D[tn.id]
 for _,name in ipairs({'GetUnitCollisionVolumeData','GetUnitVectors','GetUnitBuildFacing','AreTeamsAllied','GetGaiaTeamID','ValidUnitID','GetUnitIsDead','GetUnitDefID','GetUnitTeam','GetUnitAllyTeam','GetUnitHealth','GetUnitCosts','GetUnitPosition','GetUnitVelocity','GetGroundHeight','TestMoveOrder','GetUnitsInCylinder','GetFeaturesInCylinder','CreateUnit','GiveOrderToUnit','GetUnitStates','GetUnitCurrentCommand','GetUnitLosState','GetUnitWeaponTestTarget','GetUnitWeaponTestRange','GetUnitWeaponHaveFreeLineOfFire','GetGameFrame','GetProjectilePosition'})do
  if type(S[name])~='function'then fail('missing_native_'..name);return C end
 end
 if type(paid)~='table'or type(paid.products)~='table'or#paid.products~=2 or paid.products[1]==paid.products[2]or not paid.result or not paid.result:match('^PASS two_distinct_ordinary_patrol')then fail('completed_ordinary_two_product_context_required');return C end
 if not d or not td or(d.customParams or{}).prototype40k_native_donor~='corpt'or(td.customParams or{}).prototype40k_native_donor~='corcs'or tostring(d.scriptName):lower()~='units/corpt.cob'or d.minWaterDepth~=6 or td.minWaterDepth~=15 or td.canFly or#(d.weapons or{})~=2 then fail('exact_ready_native_donors_required');return C end
 C.actor=paid.products[1];C.sibling=paid.products[2];C.team=S.GetUnitTeam(C.actor);C.enemy=enemy;C.def=dn.id;C.targetDef=tn.id;C.weapon=d.weapons[2].weaponDef
 if paid.factory==nil then fail('original_paid_factory_required');return C end
 C.factoryDef=S.GetUnitDefID(paid.factory);local fd=D[C.factoryDef]
 if not fd or(fd.customParams or{}).prototype40k_native_donor~='corsy'or not fd.isFactory or fd.minWaterDepth~=30 then fail('original_native_corsy_required');return C end
 local wd=W[C.weapon]
 if not wd or wd.type~='MissileLauncher'or wd.range~=650 or wd.reload~=2 or S.AreTeamsAllied(C.team,enemy)~=false or enemy==S.GetGaiaTeamID()then fail('native_surface_missile_hostile_role_required');return C end
 local function live(id,owner,def)
  if S.ValidUnitID(id)~=true or S.GetUnitIsDead(id)~=false or S.GetUnitTeam(id)~=owner or S.GetUnitDefID(id)~=def then return false end
  local hp,_,_,_,built=S.GetUnitHealth(id);return finite(hp)and hp>0 and built==1
 end
 local function nativeGeometryTyped(id)
   local facing=S.GetUnitBuildFacing(id)
   if not finite(facing)or facing%1~=0 or facing<0 or facing>3 then return false end
   local front,up,right=S.GetUnitVectors(id)
   for _,v in pairs({front=front,up=up,right=right})do if type(v)~='table'then return false end;for i=1,3 do if not finite(v[i])then return false end end end
   if type(front)~='table'or type(up)~='table'or type(right)~='table'then return false end
  return true
 end
 local function ownPaid()
  local fw,fm,fe=S.GetUnitCosts(paid.factory)
  if not nativeGeometryTyped(paid.factory)or not live(paid.factory,C.team,C.factoryDef)or fw~=5100 or fm~=450 or fe~=950 then return false end
  for _,id in ipairs({C.actor,C.sibling})do local work,m,e=S.GetUnitCosts(id);if not nativeGeometryTyped(id)or not live(id,C.team,C.def)or work~=2500 or m~=210 or e~=1400 or physical.Outside(S,D,paid.factory,id)~=true then return false end end
  return true
 end
 local function legal(x,z,def,exempt)
  local a=D[def]
  if not a or not finite(x)or not finite(z)or not finite(a.xsize)or not finite(a.zsize)or a.xsize<=0 or a.zsize<=0 or not finite(a.minWaterDepth)or a.minWaterDepth<=0 or not finite(Game.mapSizeX)or not finite(Game.mapSizeZ)then return false end
  local cv=a.collisionVolume
  if type(cv)~='table'then return false end
  for _,v in ipairs({'scaleX','scaleY','scaleZ'})do if not finite(cv[v])or cv[v]<=0 then return false end end
  for _,v in ipairs({'offsetX','offsetY','offsetZ'})do if not finite(cv[v])then return false end end
  local r=math.max(a.xsize,a.zsize)*4+16
  r=math.max(r,math.sqrt((math.abs(cv.offsetX)+cv.scaleX/2)^2+(math.abs(cv.offsetZ)+cv.scaleZ/2)^2)+16)
  local minX,maxX,minZ,maxZ=x-r,x+r,z-r,z+r
  if exempt~=nil then
   if not nativeGeometryTyped(exempt)then return false end
   local envelope=physical.Envelope(S,D,exempt)
   if type(envelope)~='table'or not finite(envelope.minX)or not finite(envelope.maxX)or not finite(envelope.minZ)or not finite(envelope.maxZ)or envelope.minX>envelope.maxX or envelope.minZ>envelope.maxZ then return false end
   minX,maxX,minZ,maxZ=math.min(minX,envelope.minX-16),math.max(maxX,envelope.maxX+16),math.min(minZ,envelope.minZ-16),math.max(maxZ,envelope.maxZ+16)
   r=math.max(x-minX,maxX-x,z-minZ,maxZ-z)
  end
  if x<r+64 or z<r+64 or x>Game.mapSizeX-r-64 or z>Game.mapSizeZ-r-64 then return false end
  if r>256 then return false end -- bounded representative hull, never omit large geometry
  for gx=math.floor(minX/8)*8,math.ceil(maxX/8)*8,8 do for gz=math.floor(minZ/8)*8,math.ceil(maxZ/8)*8,8 do local h=S.GetGroundHeight(gx,gz);if not finite(h)or h>-a.minWaterDepth then return false end end end
  if S.TestMoveOrder(def,x,0,z,0,0,0,true,true,false)~=true then return false end
  local units=S.GetUnitsInCylinder(x,z,r+32);local features=S.GetFeaturesInCylinder(x,z,r+32)
  if type(units)~='table'or type(features)~='table'then return false end
  for _,id in pairs(units)do if id~=exempt then return false end end
  return next(features)==nil
 end
 local function ready()
  if not ownPaid()then return false end
  if not live(C.target,C.enemy,C.targetDef)then return false end
  local ax,_,az=S.GetUnitPosition(C.actor);local tx,_,tz=S.GetUnitPosition(C.target)
  if not legal(ax,az,C.def,C.actor)or not legal(tx,tz,C.targetDef,C.target)then return false end
  local vx,vy,vz=S.GetUnitVelocity(C.target)
  if not finite(vx)or not finite(vy)or not finite(vz)or vx*vx+vy*vy+vz*vz>=.01 then return false end
  local los=S.GetUnitLosState(C.target,S.GetUnitAllyTeam(C.actor),false)
  return type(los)=='table'and los.los==true and S.GetUnitWeaponTestTarget(C.actor,2,C.target)==true and S.GetUnitWeaponTestRange(C.actor,2,C.target)==true and S.GetUnitWeaponHaveFreeLineOfFire(C.actor,2,C.target)==true
 end
 function C.Projectile(pid,owner,weapon)
  if C.result or C.phase~='fire'or owner~=C.actor or weapon~=C.weapon then return end
  if not finite(pid)or pid<0 or pid%1~=0 or C.pids[pid]then fail('duplicate_or_invalid_native_pid');return end
  local x,y,z=S.GetProjectilePosition(pid)
  if not finite(x)or not finite(y)or not finite(z)then fail('native_projectile_position_missing');return end
  C.count=C.count+1;if C.count>64 then fail('bounded_native_projectiles_exhausted');return end
  C.pids[pid]={frame=S.GetGameFrame()};emit('PROJECTILE',pid,owner,weapon,x,y,z,'native_Query_Shot_unaccepted=true')
 end
 function C.Explosion(weapon,x,y,z,owner,pid)
  if C.result or owner~=C.actor or weapon~=C.weapon then return false end
  local p=C.pids[pid];if not p or p.explosion or not finite(x)or not finite(y)or not finite(z)then fail('unbound_or_duplicate_native_explosion');return false end
  p.explosion=S.GetGameFrame();emit('EXPLOSION',pid,owner,weapon,x,y,z);return false
 end
 function C.Pre(id,damage,para,weapon,pid,attacker)
  if C.result or C.phase~='fire'or id~=C.target then return end
  if attacker~=C.actor or weapon~=C.weapon or para~=false or not finite(damage)or damage<=0 or not C.pids[pid]then fail('unbound_native_target_predamage');return end
  local hp=S.GetUnitHealth(id);if not finite(hp)or hp<=0 or not ready()then fail('native_target_predamage_readiness');return end
  C.pending[id]={pid=pid,before=hp,frame=S.GetGameFrame()}
 end
 function C.Damaged(id,damage,para,weapon,pid,attacker)
  if C.result or C.phase~='fire'or id~=C.target then return end
  local p=C.pids[pid];local q=C.pending[id];C.pending[id]=nil;local hp=S.GetUnitHealth(id)
  if attacker~=C.actor or weapon~=C.weapon or para~=false or not finite(damage)or damage<=0 or not p or p.loss or not q or q.pid~=pid or q.frame~=S.GetGameFrame()or not finite(hp)or q.before-hp<=0 then fail('native_pid_health_loss_binding');return end
  p.loss=q.before-hp;p.hitFrame=S.GetGameFrame();emit('HP_DAMAGE',pid,attacker,weapon,id,damage,q.before,hp,p.loss)
 end
 function C.Step(f)
  if C.result then return C.result end
  if f-C.start>900 then return fail('paid_patrol_surface_missile_timeout_'..C.phase)end
  if not ownPaid()then return fail('ordinary_paid_products_lost_or_changed')end
  if C.phase=='setup'then
   local x,_,z=S.GetUnitPosition(C.actor);local chosen
   if not finite(x)or not finite(z)then return fail('legal_full_draft_actor_position_missing')end
   for distance=192,320,64 do for a=0,15 do local angle=a*math.pi/8;local tx,tz=math.floor(x+distance*math.cos(angle)+.5),math.floor(z+distance*math.sin(angle)+.5)
    if legal(tx,tz,C.targetDef)then chosen={tx,0,tz};break end
   end;if chosen then break end end
   if not chosen then return fail('legal_full_draft_hostile_water_target_missing')end
   C.target=S.CreateUnit('fortyk_guard_naval_constructor',chosen[1],chosen[2],chosen[3],0,C.enemy)
   if C.target==nil or not live(C.target,C.enemy,C.targetDef)then return fail('funded_hostile_native_creation')end
   if S.GiveOrderToUnit(C.target,CMD.FIRE_STATE,{0},0)~=true or S.GiveOrderToUnit(C.target,CMD.MOVE_STATE,{0},0)~=true then return fail('hostile_stationary_control_refused')end
   local state=S.GetUnitStates(C.target);if type(state)~='table'or state.firestate~=0 or state.movestate~=0 then return fail('hostile_stationary_control_readback')end
   C.phase='wait';emit('FUNDED_HOSTILE_ONLY',C.target,C.enemy,C.targetDef,unpack(chosen));emit('OWN_PAID_CONTEXT',C.actor,C.sibling,'ordinary_two_product_lifecycle_source_gated=true exact_debit_unaccepted=true');return
  elseif C.phase=='wait'then
   if not ready()then return end
   if S.GiveOrderToUnit(C.actor,CMD.ATTACK,{C.target},0)~=true then return fail('ordinary_attack_dispatch_refused')end
   local cmd,_,_,target=S.GetUnitCurrentCommand(C.actor);if cmd~=CMD.ATTACK or target~=C.target then return fail('ordinary_attack_queue_readback')end
   C.phase='fire';emit('NORMAL_ATTACK',C.actor,C.target,'natural_los_range_lof=true funded_hostile_non_economy=true');return
  elseif C.phase=='fire'then
   if S.GetUnitTeam(C.target)~=C.enemy or S.GetUnitDefID(C.target)~=C.targetDef then return fail('hostile_target_identity_changed')end
   for pid,p in pairs(C.pids)do if p.loss and p.explosion and p.explosion>=p.frame and p.hitFrame>=p.frame then
    C.result='PASS ordinary_paid_patrol_native_surface_missile_pid_explosion_positive_HP_loss_funded_hostile_not_economy_Query_Shot_render_unaccepted';emit('MATCHED_NATIVE_CHAIN',pid,p.frame,p.explosion,p.hitFrame,p.loss);return C.result
   end end
   if not ready()then return fail('natural_water_weapon_readiness_lost')end
  end
 end
 return C
end
return M
