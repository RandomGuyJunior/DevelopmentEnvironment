-- Native movement/weapons own simulation; genuine weighted source motion owns art.
GG.Recoil40KMorkanautArtCache=GG.Recoil40KMorkanautArtCache or{}
local cache=GG.Recoil40KMorkanautArtCache
if not cache.data then cache.data=VFS.Include('scripts/generated/ork_morkanaut_anim.lua');cache.facts=VFS.Include('40k_configs/ork_morkanaut_facts.lua')end
local data,facts=cache.data,cache.facts
local handles,index={},{}
for i,name in ipairs(data.bones)do handles[i]=piece(name);index[name]=i end
local mounts=facts.mounts
local emitters={piece(mounts.main),piece(mounts.belly),piece(mounts.rockets),piece(mounts.klaw)}
local rocketPorts={}
for i,name in ipairs(mounts.rocketPorts)do rocketPorts[i]=piece(name)end
local rocketPort=1
local shieldCenter=piece(mounts.pelvis)
local aimSignal={1,2,4}
local yaw={piece(mounts.yaw_main),piece(mounts.yaw_belly),piece(mounts.yaw_rockets)}
local pitch={piece(mounts.pitch_main),piece(mounts.pitch_belly),piece(mounts.pitch_rockets)}
local ownedAim={}
for _,name in ipairs({mounts.yaw_main,mounts.pitch_main,mounts.yaw_belly,mounts.pitch_belly,mounts.yaw_rockets,mounts.pitch_rockets})do ownedAim[index[name]]=true end
local limit={math.rad(18),math.rad(8),math.rad(12)}
local pitchLimit={math.rad(22),math.rad(12),math.rad(20)}
local moving,walkPhase,idlePhase,turnPhase,fireClock=false,0,0,0,-1
local target,union={},{}
for _,clip in pairs(data.clips)do for _,i in ipairs(clip.indices)do union[i]=true end end
local function wrap(x)return(x+math.pi)%(2*math.pi)-math.pi end
local function apply(i,v)
 if ownedAim[i]then return end
 local old=target[i]or{0,0,0,0,0,0};local bone=handles[i]
 for a=1,3 do
  if math.abs(v[a]-old[a])>1e-5 then Move(bone,a,v[a],math.max(.001,math.abs(v[a]-old[a])*30))end
  local d=wrap(v[a+3]-old[a+3])
  if math.abs(d)>1e-5 then Turn(bone,a,v[a+3],math.max(.001,math.abs(d)*30))end
 end
 target[i]={v[1],v[2],v[3],v[4],v[5],v[6]}
end
local zero={0,0,0,0,0,0}
local function sampled(clip,phase)
 local row=clip.frames[math.floor(phase)%#clip.frames+1];local out={}
 for j,i in ipairs(clip.indices)do out[i]=row[j]end
 return out
end
local function motion()
 local heading=Spring.GetUnitHeading(unitID)or 0
 while true do
  local vx,_,vz=Spring.GetUnitVelocity(unitID);local speed=math.sqrt((vx or 0)^2+(vz or 0)^2)*30
  local h=Spring.GetUnitHeading(unitID)or heading;local change=(h-heading+32768)%65536-32768;heading=h
  local clip,phase
  if moving and speed>.15 then
   clip=data.clips.walk;phase=walkPhase
   -- Cadence comes from measured source foot sweep and actual world travel.
   walkPhase=walkPhase+clip.sourceFPS/30*math.min(3,speed/facts.gaitNominalSpeed)
  elseif math.abs(change)>80 then
   clip=data.clips.turn;phase=turnPhase;turnPhase=turnPhase+clip.sourceFPS/30
  else clip=data.clips.idle;phase=idlePhase;idlePhase=idlePhase+clip.sourceFPS/30 end
  local row=sampled(clip,phase)
  if clip==data.clips.turn then
   -- The unit's native heading already turns its root. Retain genuine feet,
   -- pelvis and arm movement without applying the source root yaw twice.
   row[index[mounts.root]]=zero
  end
  if fireClock>=0 then
   local fire=data.clips.fire
   if fireClock<#fire.frames then
    local shot=sampled(fire,fireClock);for i,v in pairs(shot)do row[i]=v end
    fireClock=fireClock+fire.sourceFPS/30
   else fireClock=-1 end
  end
  for i in pairs(union)do apply(i,row[i]or zero)end
  Sleep(33)
 end
end
function script.Create()StartThread(motion)end
function script.StartMoving()moving=true end
function script.StopMoving()moving=false end
function script.AimFromWeapon(n)
 if n==5 then return shieldCenter end
 if n==4 then return emitters[4]end
 return yaw[n]or shieldCenter
end
function script.QueryWeapon(n)
 if n==5 then return shieldCenter end
 return n==3 and rocketPorts[rocketPort]or emitters[n]
end
function script.AimWeapon(n,heading,p)
 if n==4 or n==5 then return true end
 if n>=1 and n<=3 then Signal(aimSignal[n]);SetSignalMask(aimSignal[n])end
 if n<1 or n>3 or math.abs(wrap(heading))>limit[n]or math.abs(p)>pitchLimit[n]then return false end
 Turn(yaw[n],y_axis,heading,1.7);Turn(pitch[n],x_axis,-p,1.3)
 WaitForTurn(yaw[n],y_axis);WaitForTurn(pitch[n],x_axis)
 return true
end
function script.Shot(n)
 if n==1 then fireClock=0 end
 if n==1 then EmitSfx(emitters[1],1026)
 elseif n==2 then EmitSfx(emitters[2],1024)
 elseif n==3 then EmitSfx(rocketPorts[rocketPort],1025);rocketPort=rocketPort%#rocketPorts+1 end
end
-- Returning one native feature index leaves death/reclaim entitlement to the engine.
-- No corpse creation, resource grant or decorative crew salvage is scripted.
function script.Killed()
 local _,_,_,_,progress=Spring.GetUnitHealth(unitID)
 if type(progress)~='number'or progress<1 then return 0 end
 return 1
end
