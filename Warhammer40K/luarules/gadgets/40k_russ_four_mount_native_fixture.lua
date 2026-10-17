function gadget:GetInfo()return{name='40K funded Russ four-mount native witness',desc='Native hostile/ground witnesses; no economy or hull certification',author='Local project',layer=161,enabled=true}end
local M=VFS.Include('40k_configs/russ_four_mount_native_fixture.lua')
if not M.Enabled(Spring.GetModOptions()or{})then return false end
if not gadgetHandler:IsSyncedCode()then return false end
local S=Spring;local actor,target,leaf,witness;local owned={};local phase='setup';local start,phaseStart;local stable=0;local anchor;local ground
local function emit(label,...)local t={...};for i=1,#t do t[i]=tostring(t[i])end;S.Echo('40K_RUSS_FOUR_MOUNT '..label..' '..table.concat(t,' '))end
local function close(reason)
 if phase=='closed'then return end;phase='closed';if leaf then leaf.Close()end
 if GG.Recoil40KWalkerBurstWitness==witness then GG.Recoil40KWalkerBurstWitness=nil end
 emit('COMPLETE',reason,'funded_non_economy=true paidAccepted=false hullSafetyAccepted=false renderAccepted=false nativeReceiptRequired=true')
end
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function legal(def,x,z)
 local d=UnitDefs[def];local radius=math.max(d.xsize*4,d.zsize*4,tonumber(d.radius)or 0)+32
 if x-radius<32 or z-radius<32 or x+radius>Game.mapSizeX-32 or z+radius>Game.mapSizeZ-32 then return end
 local y=S.GetGroundHeight(x,z);if not finite(y)or y<0 then return end
 for gx=math.floor((x-radius)/8)*8,math.ceil((x+radius)/8)*8,8 do for gz=math.floor((z-radius)/8)*8,math.ceil((z+radius)/8)*8,8 do
  local h=S.GetGroundHeight(gx,gz);if not finite(h)or h<0 or math.abs(h-y)>4 then return end
 end end
 if #(S.GetUnitsInRectangle(x-radius,z-radius,x+radius,z+radius)or{})>0 or #(S.GetFeaturesInRectangle(x-radius,z-radius,x+radius,z+radius)or{})>0 or S.TestMoveOrder(def,x,y,z,0,0,0,true,true,false)~=true then return end
 return{x,y,z}
end
local function spawn(pos,team)
 local id=S.CreateUnit('imp_russ',pos[1],pos[2],pos[3],0,team);if not id then return end;owned[#owned+1]={id=id,team=team,def=S.GetUnitDefID(id)}
 if S.GiveOrderToUnit(id,CMD.FIRE_STATE,{0},0)==false or S.GiveOrderToUnit(id,CMD.MOVE_STATE,{0},0)==false then return end
 return id
end
function gadget:Initialize()
 if GG.Recoil40KWalkerBurstWitness then close('INCONCLUSIVE fresh_exclusive_observer_required');return end
 start=0;phaseStart=0
end
local function preflight(terrain)
 local ally=S.GetUnitAllyTeam(actor);local x,y,z
 if terrain then x,y,z=ground[1],ground[2],ground[3]
 else
  if not S.ValidUnitID(target)or S.GetUnitIsDead(target)or S.AreTeamsAllied(S.GetUnitTeam(actor),S.GetUnitTeam(target))then return false end
  local los=S.GetUnitLosState(target,ally,false);if not los or los.los~=true then return false end
  x,y,z=S.GetUnitPosition(target)
 end
 if not S.IsPosInLos(x,y,z,ally)then return false end
 for n=1,4 do
  if terrain then
   if S.GetUnitWeaponTestRange(actor,n,x,y,z)~=true or S.GetUnitWeaponTestTarget(actor,n,x,y,z)~=true or S.GetUnitWeaponTryTarget(actor,n,x,y,z)~=true then return false end
  elseif S.GetUnitWeaponTestRange(actor,n,target)~=true or S.GetUnitWeaponTestTarget(actor,n,target)~=true or S.GetUnitWeaponTryTarget(actor,n,target)~=true or S.GetUnitWeaponHaveFreeLineOfFire(actor,n,target)~=true then return false end
  local mx,my,mz=S.GetUnitWeaponVectors(actor,n)
  if not finite(mx)or not finite(my)or not finite(mz)then return false end
  if terrain then if S.GetUnitWeaponHaveFreeLineOfFire(actor,n,mx,my,mz,x,y,z)~=true then return false end
  elseif S.GetUnitWeaponHaveFreeLineOfFire(actor,n,mx,my,mz,target)~=true then return false end
 end
 return true
end
function gadget:GameFrame(frame)
 if phase=='closed'then return end
 if not finite(frame)or frame%1~=0 then close('INCONCLUSIVE typed_native_frame_required');return end
 if frame<1 then return end
 if phase=='setup'and(frame~=1 or type(S.GetGameFrame)~='function'or S.GetGameFrame()~=frame)then close('INCONCLUSIVE fresh_native_frame_one_required');return end
 if frame-start>1800 then close('INCONCLUSIVE bounded_native_timeout_'..phase);return end
 if leaf and leaf.result then close(leaf.result);return end
 if actor and(not S.ValidUnitID(actor)or S.GetUnitIsDead(actor)or S.GetUnitTeam(actor)~=0)then close('INCONCLUSIVE actor_lost_or_captured');return end
 if phase=='setup'then
  local n=UnitDefNames.imp_russ;if not n then close('INCONCLUSIVE current_Russ_missing');return end
  local pos
  for i=1,32 do pos=legal(n.id,Game.mapSizeX*.35+(i%8)*160,Game.mapSizeZ*.35+math.floor(i/8)*160);if pos then break end end
  if not pos then close('INCONCLUSIVE native_actor_site');return end;actor=spawn(pos,0)
  if not actor then close('INCONCLUSIVE native_actor_birth');return end
  local front=S.GetUnitVectors(actor);local fx,fz=front[1],front[3];local len=math.sqrt(fx*fx+fz*fz)
  if not finite(len)or len<.99 then close('INCONCLUSIVE native_forward_basis');return end
  local t=legal(n.id,pos[1]+fx/len*240,pos[3]+fz/len*240)
  ground=legal(n.id,pos[1]+fx/len*160,pos[3]+fz/len*160)
  if not t or not ground then close('INCONCLUSIVE distinct_native_target_ground_sites');return end
  target=spawn(t,1);if not target then close('INCONCLUSIVE native_hostile_birth');return end
  leaf=M.New(S,UnitDefs,WeaponDefs,actor,target,emit);if leaf.result then close(leaf.result);return end
  witness=VFS.Include('40k_configs/walker_burst_observer.lua').New(S,UnitDefs,function(row)leaf.Telemetry(row)end,256)
  if not witness.Register(actor)then close('INCONCLUSIVE real_Russ_observer_registration');return end;GG.Recoil40KWalkerBurstWitness=witness
  for _,m in ipairs(leaf.mounts)do Script.SetWatchProjectile(m.wd,true);Script.SetWatchExplosion(m.wd,true)end
  phase='settle';phaseStart=frame;emit('SETUP',actor,target,'funded_actors=true resource_grants=false mount_filtering=false')
 elseif phase=='settle'then
  if not preflight(false)then stable=0;return end
  local x,y,z=S.GetUnitPosition(target);if anchor and(x-anchor[1])^2+(y-anchor[2])^2+(z-anchor[3])^2<.01 then stable=stable+1 else stable=0 end;anchor={x,y,z}
  if stable>=30 then leaf.Begin(false);phase='hostile';phaseStart=frame;if S.GiveOrderToUnit(actor,CMD.ATTACK,{target},0)==false then close('INCONCLUSIVE native_attack_refused')end end
 elseif phase=='hostile'or phase=='terrain'then
  if not preflight(phase=='terrain')then close('INCONCLUSIVE native_visibility_range_or_LOF_lost');return end
  if leaf.Ready()then S.GiveOrderToUnit(actor,CMD.FIRE_STATE,{0},0);S.GiveOrderToUnit(actor,CMD.STOP,{},0);leaf.phase='drain';phase=phase=='hostile'and'drain_hostile'or'drain_terrain';phaseStart=frame end
 elseif phase=='drain_hostile'and frame-phaseStart>=90 then
  -- A distinct empty ground site avoids calling target/wreck impacts terrain.
  if not preflight(true)then close('INCONCLUSIVE native_ground_preflight');return end
  leaf.Begin(true,ground);phase='terrain';phaseStart=frame
  if S.GiveOrderToUnit(actor,CMD.ATTACK,ground,0)==false then close('INCONCLUSIVE native_ground_attack_refused')end
 elseif phase=='drain_terrain'and frame-phaseStart>=90 then close('OBSERVED all_four_native_Query_Shot_PID_WD_two_cycles_hostile_HP_and_ground_impact')end
end
function gadget:ProjectileCreated(...)if witness and phase~='closed'then witness.Projectile(...)end end
function gadget:UnitDamaged(...)if leaf and phase~='closed'then leaf.Damaged(...)end end
function gadget:Explosion(...)if leaf and phase~='closed'then return leaf.Explosion(...)end;return false end
function gadget:UnitDestroyed(id)
 for _,row in ipairs(owned)do if row.id==id then row.destroyed=true end end
 if phase~='closed'and(id==actor or id==target)then close('INCONCLUSIVE owned_actor_or_target_destroyed')end
end
function gadget:Shutdown()
 close('SHUTDOWN')
 for _,row in ipairs(owned)do if not row.destroyed and S.ValidUnitID(row.id)and not S.GetUnitIsDead(row.id)and S.GetUnitDefID(row.id)==row.def and S.GetUnitTeam(row.id)==row.team then S.DestroyUnit(row.id,false,true)end end
end
