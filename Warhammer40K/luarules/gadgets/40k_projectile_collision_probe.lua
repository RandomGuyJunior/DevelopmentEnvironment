function gadget:GetInfo()
 return {name="40K physical projectile probes",desc="Collision-only native WeaponDef fixtures, opt-in six mode",author="Local project",layer=104,enabled=true}
end
if not gadgetHandler:IsSyncedCode() then return end
if Spring.GetModOptions().prototype_diagnostic~="six" then return end
local cases,tracked,owners,owned={}, {}, {}, {}
local weaponID,weaponSpeed,gravity
local function emit(event,c,fields)
 Spring.Echo('40K_COLLISION {"event":"'..event..'","frame":'..Spring.GetGameFrame()..
  ',"case":"'..(c and c.name or "setup")..'"'..(fields or "")..'}')
end
local function create(name,x,z,team)
 local id=Spring.CreateUnit(name,x,Spring.GetGroundHeight(x,z),z,0,team)
 if id then
  owned[#owned+1]=id
  Spring.GiveOrderToUnit(id,CMD.FIRE_STATE,{0},{})
  Spring.GiveOrderToUnit(id,CMD.MOVE_STATE,{0},{})
 end
 return id
end
local function lanes()
 local found={}
 for z=1664,Game.mapSizeZ-320,96 do
  for x=384,Game.mapSizeX-512,64 do
   local y=Spring.GetGroundHeight(x,z)
   local clear=y>10
   for dx=-64,256,32 do
    if math.abs(y-Spring.GetGroundHeight(x+dx,z))>1.5 then clear=false;break end
   end
   for _,p in ipairs(found) do
    if (x-p[1])^2+(z-p[2])^2<320^2 then clear=false end
   end
   if clear and Spring.GetFeaturesInRectangle and
    #Spring.GetFeaturesInRectangle(x-64,z-32,x+256,z+32)>0 then clear=false end
   if clear then
    found[#found+1]={x,z}
    if #found==4 then return found end
   end
  end
 end
 return found
end
local function setup()
 if not Spring.SpawnProjectile or not Spring.GetProjectilePosition or not Spring.SetProjectileTarget then
  emit("unsupported_api",nil);return
 end
 local marine=UnitDefNames.imp_marine
 weaponID=marine and UnitDefs[marine.id].weapons[1].weaponDef
 if not weaponID or not WeaponDefs[weaponID] then emit("missing_weapon",nil);return end
 local wd=WeaponDefs[weaponID]
 weaponSpeed=wd.projectilespeed
 if not weaponSpeed or weaponSpeed<=0 then emit("missing_native_speed",nil);return end
 -- CCannon::Init uses the WeaponDef gravity override or map gravity.
 local override=wd.myGravity or 0
 gravity=override~=0 and -override or -Game.gravity/(Game.gameSpeed*Game.gameSpeed)
 if Script.SetWatchProjectile then Script.SetWatchProjectile(weaponID,true) end
 if Script.SetWatchExplosion then Script.SetWatchExplosion(weaponID,true) end
 local sites=lanes()
 if #sites<4 then emit("insufficient_dry_lanes",nil,',"found":'..#sites);return end
 for i,name in ipairs({"clear_control","friendly_blocker","enemy_nontarget_blocker","terrain_crossing"}) do
  local x,z=sites[i][1],sites[i][2]
  local c={name=name,x=x,z=z,hits={},explosions=0}
  c.owner=create("imp_marine",x-48,z,0)
  if name~="terrain_crossing" then
   c.target=create("wh40k_cormex",x+220,z,1)
   c.targetBefore=c.target and Spring.GetUnitHealth(c.target)
   if name=="friendly_blocker" then c.blocker=create("wh40k_armmex",x+110,z,0)
   elseif name=="enemy_nontarget_blocker" then c.blocker=create("wh40k_cormex",x+110,z,1) end
   c.blockerBefore=c.blocker and Spring.GetUnitHealth(c.blocker)
  end
  if not c.owner or (name~="terrain_crossing" and not c.target) or
   ((name=="friendly_blocker" or name=="enemy_nontarget_blocker") and not c.blocker) then
   c.failed=true;emit("fixture_creation_failed",c)
  end
  cases[#cases+1]=c
  if c.owner then owners[c.owner]=c end
  emit("fixture",c,',"owner":'..(c.owner or -1)..',"target":'..(c.target or -1)..
   ',"blocker":'..(c.blocker or -1)..',"x":'..x..',"z":'..z..',"weapon_id":'..weaponID..
   ',"native_speed":'..weaponSpeed..',"native_gravity":'..gravity)
 end
end
local function launch(c)
 if c.failed then return end
 local sx,sz=c.x+20,c.z
 local sy=Spring.GetGroundHeight(sx,sz)+(c.name=="terrain_crossing" and 50 or 8)
 local tx,tz=c.x+220,c.z
 local ty=Spring.GetGroundHeight(tx,tz)+(c.name=="terrain_crossing" and -20 or 8)
 local dx,dy=tx-sx,ty-sy
 local vx=weaponSpeed
 local vy
 -- A bounded low-arc calculation at native speed/gravity. The metadata
 -- target is the far unit, not the incidental intervening blocker.
 for _=1,5 do
  local t=dx/vx
  vy=dy/t-gravity*(t-1)*.5
  if math.abs(vy)>=weaponSpeed then emit("unreachable_fixture",c);c.failed=true;return end
  vx=math.sqrt(weaponSpeed*weaponSpeed-vy*vy)
 end
 local predicted=math.ceil(dx/vx)
 local pid=Spring.SpawnProjectile(weaponID,{owner=c.owner,team=0,weapon=1,
  pos={sx,sy,sz},speed={vx,vy,0},["end"]={tx,ty,tz},gravity=gravity,ttl=predicted*2})
 if not pid then c.failed=true;emit("spawn_failed",c);return end
 c.projectile=pid;c.last={sx,sy,sz};tracked[pid]=c
 if c.target then
  c.targetMetadata=Spring.SetProjectileTarget(pid,c.target,117)
 end
 emit("native_projectile",c,',"projectile_id":'..pid..',"sx":'..sx..',"sy":'..sy..
  ',"sz":'..sz..',"vx":'..vx..',"vy":'..vy..',"predicted_frames":'..predicted..
  ',"target_metadata":'..tostring(c.targetMetadata==true))
end
function gadget:UnitDamaged(id,def,team,damage,paralyzer,weapon,projectile,attacker)
 local c=tracked[projectile] or owners[attacker]
 if not c or weapon~=weaponID or paralyzer or damage<=0 then return end
 c.hits[id]=(c.hits[id] or 0)+damage
 emit("native_damage",c,',"victim":'..id..',"victim_team":'..team..',"damage":'..damage..
  ',"projectile_id":'..(projectile or -1))
end
function gadget:Explosion(def,x,y,z,owner,projectile)
 local c=tracked[projectile] or owners[owner]
 if not c or def~=weaponID then return false end
 c.explosions=c.explosions+1;c.impact={x,y,z}
 emit("native_impact",c,',"projectile_id":'..(projectile or -1)..',"x":'..x..',"y":'..y..
  ',"z":'..z..',"ground_y":'..Spring.GetGroundHeight(x,z))
 return false -- Never suppress the normal collision/explosion.
end
function gadget:ProjectileDestroyed(pid)
 local c=tracked[pid]
 if not c then return end
 c.deleted=true;tracked[pid]=nil
 local p=c.last
 emit("native_deleted",c,',"projectile_id":'..pid..',"last_x":'..p[1]..',"last_y":'..p[2]..
  ',"last_z":'..p[3]..',"native_impact_seen":'..tostring(c.explosions>0))
end
local function summarize(c)
 local targetDamage=c.target and (c.hits[c.target] or 0) or 0
 local blockerDamage=c.blocker and (c.hits[c.blocker] or 0) or 0
 local passed=false
 if not c.failed and c.deleted and c.explosions>0 then
  if c.name=="clear_control" then passed=targetDamage>0
  elseif c.name=="terrain_crossing" then
   passed=c.impact and math.abs(c.impact[2]-Spring.GetGroundHeight(c.impact[1],c.impact[3]))<=5
  else
   local bx,_,bz=Spring.GetUnitPosition(c.blocker)
   local impactNear=c.impact and bx and (c.impact[1]-bx)^2+(c.impact[3]-bz)^2<=36^2
   -- Friendly fire may be filtered by game policy; stopping at its native
   -- volume with no far-target damage is the physical-blocking proof.
   passed=c.targetMetadata==true and targetDamage==0 and impactNear
  end
 end
 emit("result",c,',"passed":'..tostring(not not passed)..',"target_damage":'..targetDamage..
  ',"blocker_damage":'..blockerDamage..',"deleted":'..tostring(c.deleted==true)..
  ',"native_impacts":'..c.explosions)
end
function gadget:GameFrame(f)
 if f==180 then setup() end
 if f==210 then for _,c in ipairs(cases) do launch(c) end end
 if f>=210 and f<330 then
  for _,c in ipairs(cases) do
   if c.projectile and tracked[c.projectile] then
    local x,y,z=Spring.GetProjectilePosition(c.projectile)
    if x then c.last={x,y,z} end
   end
  end
 end
 if f==330 then
  for _,c in ipairs(cases) do summarize(c) end
  emit("complete",nil,',"cases":'..#cases)
 end
 if f==360 then
  -- Cleanup is after evidence. Any unexpected surviving projectile is an
  -- incomplete case, never passed merely because it is silently removed.
  for _,c in ipairs(cases) do
   if c.projectile and tracked[c.projectile] then
    emit("cleanup_live_projectile",c)
    if Spring.DeleteProjectile then Spring.DeleteProjectile(c.projectile) end
    tracked[c.projectile]=nil
   end
  end
  for _,id in ipairs(owned) do
   if Spring.ValidUnitID(id) and not Spring.GetUnitIsDead(id) then Spring.DestroyUnit(id,false,true) end
  end
  owners={};owned={}
 end
end
