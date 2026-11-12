-- Display only. Native weapons, projectile damage and script timing are untouched.
local function finite(n)return type(n)=='number'and n==n and n>=0 and n<math.huge end
local function clean(n)return math.floor(n*1e6+.5)/1e6 end
local function nativeDps(w,damage,weaponInfo)
 if w.type=='BeamLaser'then return weaponInfo.GetDamagePerSecond(w,damage)end
 local count=(w.salvoSize or 1)*(w.projectiles or 1)
 local normal=damage*count/w.reload
 local stock=damage*count/(w.stockpile and w.stockpileTime/30 or w.reload)
 return math.min(normal,stock),math.max(normal,stock)
end
local M={}
function M.Apply(unit,info,definitions,weaponInfo,entries,armor)
 local entry=entries[unit.name]
 if not entry or not info then return false end
 local cp=unit.customParams or{};local minimum,maximum,cap,aliveParam,commanderWeapon
 if entry.kind=='scripted'then
  local slot=unit.weapons[1];local w=slot and definitions[slot.weaponDef]
  if not w or(w.type~='Cannon'and w.type~='Flame'and w.type~='MissileLauncher'and w.type~='LaserCannon')or w.paralyzer or w.stockpile or(w.salvoSize or 1)~=1 or(w.projectiles or 1)~=1 then return false end
  local capacity=tonumber(cp.squad_capacity)or entry.capacity
  local interval=tonumber(cp.squad_shot_interval)or .1
  local cooldown=tonumber(cp.squad_member_cooldown)or(cp.tenboy_squad and 27 or 14)
  local period=tonumber(cp.squad_salvo_period)or entry.period
  if not finite(capacity)or capacity<1 or not finite(interval)or interval<=0 or not finite(cooldown)then return false end
  local rate
  if period then
   local spacing=tonumber(cp.squad_salvo_spacing)or .18
   if not finite(period)or period<=0 or spacing*(capacity-1)>=period or cooldown>period*30 then return false end
   rate=capacity/period
  else
   if cooldown>capacity*interval*30+1e-6 then return false end
   rate=1/interval
  end
  if not finite(w.reload)or w.reload<=0 or w.reload>1/30+1e-5 then return false end
  local damage=w.damages[0]
  if not finite(damage)then return false end
  minimum=clean(damage*rate);maximum=minimum;cap=capacity
  local prefix=cp.squad_prefix or(cp.tenguard_squad and'tenguard'or'tenboy')
  aliveParam=prefix..'_alive'
 elseif entry.kind=='native'and entry.slots and #entry.slots>0 then
  minimum,maximum=0,0
  for _,n in ipairs(entry.slots or{})do
   local slot=unit.weapons[n];local w=slot and definitions[slot.weaponDef]
   if not w or not finite(w.reload)or w.reload<=0 or w.type=='Shield'or w.paralyzer then return false end
   local damage=w.damages[0]
   if unit.weapons[1].onlyTargets and unit.weapons[1].onlyTargets.vtol~=nil then damage=w.damages[armor.vtol]end
   if not finite(damage)then return false end
   local low,high=nativeDps(w,damage,weaponInfo)
   if not finite(low)or not finite(high)then return false end
   minimum=minimum+((w.customParams or{}).weapons_role=='secondary'and 0 or low)
   maximum=maximum+high
  end
  if entry.primaryCommander then
   commanderWeapon=definitions[unit.weapons[1].weaponDef]
  end
  if entry.ownerScaled then
   cap=tonumber(cp.squad_capacity)or entry.capacity
   aliveParam=(cp.squad_prefix or'tenboy')..'_alive'
  end
 else return false
 end
 if not finite(minimum)or not finite(maximum)then return false end
 if commanderWeapon then
  info.energyPerShot=(commanderWeapon.energyCost or 0)>0 and commanderWeapon.energyCost or nil
  info.metalPerShot=(commanderWeapon.metalCost or 0)>0 and commanderWeapon.metalCost or nil
 end
 info.mindps,info.maxdps=minimum,maximum
 info.bar40kRangedDps=true;info.bar40kDpsScriptCap=entry.kind=='scripted'
 info.bar40kDpsCapacity=cap;info.bar40kDpsAliveParam=aliveParam
 return true
end
function M.AliveScale(info,id,mode,getParam)
 if not info.bar40kDpsCapacity or not id or mode~='unit'then return 1 end
 local alive=getParam(id,info.bar40kDpsAliveParam)
 if not finite(alive)then return 1 end
 return math.max(0,math.min(1,alive/info.bar40kDpsCapacity))
end
return M
