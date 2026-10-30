-- Only the Gorkanaut's primary complete gun arm uses this reachability gate.
-- The engine owns turning and the command queue; no orders or headings are written.
return function()
 local nativeRange=WeaponDefs[UnitDefs[unitDefID].weapons[1].weaponDef].range
 local gated=false
 local aimFrom=piece('gork_primary_aim_from')
 local function targetPosition()
  local cmd,_,_,a,b,c=Spring.GetUnitCurrentCommand(unitID)
  if cmd==CMD.MOVE or cmd==CMD.RAW_MOVE then return end
  if cmd==CMD.ATTACK and b and c then return a,b,c end
  local meleeTarget=GG and GG.SquadMelee and GG.SquadMelee[unitID]
  local target=meleeTarget
  if not target and cmd==CMD.ATTACK and a and not b then target=a end
  if not target then
   for n=1,4 do
    local kind,_,value=Spring.GetUnitWeaponTarget(unitID,n)
    if kind==1 then target=value;break end
    if kind==2 and type(value)=='table' then return value[1],value[2],value[3]end
   end
  end
  if not target or not Spring.ValidUnitID(target)or Spring.GetUnitIsDead(target)then return end
  local ud=UnitDefs[Spring.GetUnitDefID(target)]
  if not ud or ud.canFly then return end
  local los=Spring.GetUnitLosState(target,Spring.GetUnitAllyTeam(unitID),true)
  if not los or los%2~=1 then return end
  local x,y,z,mx,my,mz=Spring.GetUnitPosition(target,true)
  return mx or x,my or y,mz or z,meleeTarget~=nil
 end
 local function update()
  local tx,ty,tz,melee=targetPosition()
  local shouldGate=false
  if tx then
   local x,y,z=Spring.GetUnitPosition(unitID)
   local dx,dz=tx-x,tz-z
   local distance=math.sqrt(dx*dx+dz*dz)
   if distance>1 and distance<=nativeRange then
    if not melee then local ax,_,az=Spring.GetUnitPiecePosDir(unitID,aimFrom);if ax then dx,dz=tx-ax,tz-az end end
    local yaw=(math.atan2(dx,dz)-Spring.GetUnitHeading(unitID)*math.pi/32768+math.pi)%(2*math.pi)-math.pi
    shouldGate=melee and math.abs(yaw)>math.rad(10)or not melee and(yaw<math.rad(-28)or yaw>math.rad(43))
   end
  end
  if gated~=shouldGate then
   gated=shouldGate
   -- An unreachable first weapon makes native KeepPointingTo turn the chassis.
   -- Restore its authored range before allowing the arm shot.
   Spring.SetUnitWeaponState(unitID,1,'range',gated and 1 or nativeRange)
  end
 end
 return {Run=function()while true do update();Sleep(100)end end}
end
