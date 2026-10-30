-- One Great Gargant approach/facing owner. Native BAR owns movement and orders.
return function()
 local definitions=UnitDefs[unitDefID].weapons
 local nativeRange=WeaponDefs[definitions[1].weaponDef].range
 local distinct,seen={},{}
 for _,slot in ipairs(definitions)do
  local r=WeaponDefs[slot.weaponDef].range
  if r and r>0 and not seen[r]then distinct[#distinct+1]=r;seen[r]=true end
 end
 table.sort(distinct,function(a,b)return a>b end)
 local nativeMax=distinct[1]or nativeRange
 local fightRange=distinct[2]or nativeMax
 local lastRange,lastMax
 local function isFight(cmd)
  if cmd==CMD.FIGHT then return true end
  if cmd~=CMD.ATTACK then return false end
  -- MobileCAI adds Attack -> six-parameter return-Fight -> original Fight.
  -- An explicitly queued Attack -> ordinary three-parameter Fight is not this.
  local q=Spring.GetUnitCommands(unitID,2)
  local second=q and q[2]
  return second and second.id==CMD.FIGHT and second.params and #second.params>=6 or false
 end
 local function targetPosition(cmd,a,b,c)
  if cmd==CMD.MOVE or cmd==CMD.RAW_MOVE then return end
  if cmd==CMD.ATTACK and b and c then return a,b,c end
  local target
  if cmd==CMD.ATTACK and a and not b then target=a end
  if not target then
   for n=1,#definitions do
    local kind,_,value=Spring.GetUnitWeaponTarget(unitID,n)
    if kind==1 then target=value;break end
    if kind==2 and type(value)=='table'then return value[1],value[2],value[3]end
   end
  end
  if not target or not Spring.ValidUnitID(target)or Spring.GetUnitIsDead(target)then return end
  local ud=UnitDefs[Spring.GetUnitDefID(target)]
  if not ud or ud.canFly then return end
  local los=Spring.GetUnitLosState(target,Spring.GetUnitAllyTeam(unitID),true)
  if not los or los%2~=1 then return end
  local x,y,z,mx,my,mz=Spring.GetUnitPosition(target,true)
  return mx or x,my or y,mz or z
 end
 local function update()
  local cmd,_,_,a,b,c=Spring.GetUnitCurrentCommand(unitID)
  local fight=isFight(cmd)
  local desiredRange=fight and math.min(nativeRange,fightRange)or nativeRange
  local desiredMax=fight and fightRange or nativeMax
  local tx,ty,tz=targetPosition(cmd,a,b,c)
  if tx then
   local x,y,z=Spring.GetUnitPosition(unitID)
   local dx,dz=tx-x,tz-z;local distance=math.sqrt(dx*dx+dz*dz)
   if distance>1 and distance<=nativeRange then
    local yaw=(math.atan2(dx,dz)-Spring.GetUnitHeading(unitID)*math.pi/32768+math.pi)%(2*math.pi)-math.pi
    if math.abs(yaw)>math.rad(1.5)then desiredRange=1 end
   end
  end
  if desiredRange~=lastRange then
   Spring.SetUnitWeaponState(unitID,1,'range',desiredRange)
   lastRange=desiredRange
  end
  if desiredMax~=lastMax then
   Spring.SetUnitMaxRange(unitID,desiredMax)
   lastMax=desiredMax
  end
 end
 return {Run=function()while true do update();Sleep(100)end end}
end
