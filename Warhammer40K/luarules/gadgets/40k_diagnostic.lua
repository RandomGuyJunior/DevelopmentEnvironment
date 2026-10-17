function gadget:GetInfo() return {name="40K separate diagnostic",desc="Explicit private model validation",author="Local project",layer=100,enabled=true} end
if not gadgetHandler:IsSyncedCode() then return end
if Spring.GetModOptions().prototype_diagnostic~="six" then return end
local names={"imp_guardsman","imp_marine","imp_russ","ork_boy","ork_meganob","ork_killa_kan"}
local force,targets={},{}
function gadget:GameFrame(f)
 if f==90 then
  for i,name in ipairs(names) do
   local x,z=4250,850+(i-1)*105
   local id=Spring.CreateUnit(name,x,Spring.GetGroundHeight(x,z),z,0,0)
   force[i]=id
   Spring.SetUnitRulesParam(id,"40k_diagnostic_slot",i,{public=true})
   Spring.GiveOrderToUnit(id,CMD.FIRE_STATE,{0},{})
   local tx,tz=x+(i==6 and -200 or 260),z
   targets[i]=Spring.CreateUnit(names[({4,5,6,1,2,3})[i]],tx,Spring.GetGroundHeight(tx,tz),tz,0,1)
   Spring.GiveOrderToUnit(targets[i],CMD.FIRE_STATE,{0},{});Spring.GiveOrderToUnit(targets[i],CMD.MOVE_STATE,{0},{});Spring.SetUnitMaxHealth(targets[i],100000);Spring.SetUnitHealth(targets[i],100000)
   Spring.Echo("40K CREATED",name,id)
   Spring.Echo("40K COLLISION VOLUME",name,Spring.GetUnitCollisionVolumeData(id))
   Spring.Echo("40K MODEL MIDPOINT",name,Spring.GetUnitPosition(id,true,true))
  end
 end
 if f==300 then
  for i,id in ipairs(force) do
   local x,y,z=Spring.GetUnitPosition(id)
   Spring.GiveOrderToUnit(id,CMD.MOVE,{x+100,y,z},{})
  end
 end
 if f==900 then
  for i,id in ipairs(force) do Spring.GiveOrderToUnit(id,CMD.FIRE_STATE,{2},{});Spring.GiveOrderToUnit(id,CMD.ATTACK,{targets[i]},{}) end
 end
 if f==1500 then
  for _,i in ipairs({5,6}) do
   local id=force[i];local x,y,z=Spring.GetUnitPosition(id)
   local tx=x+(i==5 and 30 or -28);local target=Spring.CreateUnit("imp_marine",tx,Spring.GetGroundHeight(tx,z),z,0,1)
   Spring.GiveOrderToUnit(target,CMD.FIRE_STATE,{0},{});Spring.GiveOrderToUnit(target,CMD.MOVE_STATE,{0},{});Spring.SetUnitMaxHealth(target,100000);Spring.SetUnitHealth(target,100000)
   Spring.GiveOrderToUnit(id,CMD.STOP,{},{});Spring.GiveOrderToUnit(id,CMD.ATTACK,{target},{})
   Spring.Echo("40K CLAW FIXTURE",id,target,Spring.GetUnitWeaponTarget(id,2))
  end
 end
 if f==2200 or f==2260 or f==2320 or f==2380 then
  local id=force[3];Spring.GiveOrderToUnit(id,CMD.STOP,{},{});Spring.GiveOrderToUnit(id,CMD.FIRE_STATE,{0},{})
  local env=Spring.UnitScript.GetScriptEnv(id)
  if env and env.TestMountPose then
   local heading=f==2260 and math.pi/2 or f==2320 and -math.pi/2 or 0
   local pitch=f==2380 and -.25 or 0
   Spring.UnitScript.CallAsUnit(id,env.TestMountPose,heading,pitch)
   Spring.SetUnitRulesParam(id,"40k_attachment_pose",f,{public=true})
  end
 end
 if f==2201 or f==2261 or f==2321 or f==2381 then
  local id=force[3];local map=Spring.GetUnitPieceMap(id)
  for _,name in ipairs({"closed_hatch","aim_horz_main","marker_turret_barrel"}) do
   local x,y,z=Spring.GetUnitPiecePosDir(id,map[name]);Spring.Echo("40K ATTACHMENT",f,name,x,y,z)
  end
 end
 if f%30==0 then
  for i,id in ipairs(force) do
   local x,y,z=Spring.GetUnitPosition(id);local vx,vy,vz=Spring.GetUnitVelocity(id)
   Spring.Echo("40K MOTION",f,names[i],x,y,z,vx,vy,vz)
  end
 end
 if f==2500 then Spring.Echo("40K DIAGNOSTIC COMPLETE") end
end
function gadget:UnitDamaged(id,def,team,damage,paralyzer,weapon,projectile,attacker,attackerDef)
 if attackerDef and UnitDefs[attackerDef].customParams.prototype40k then Spring.Echo("40K NATIVE HIT",UnitDefs[attackerDef].name,weapon and WeaponDefs[weapon].name,damage,Spring.GetUnitHealth(id)) end
end
