function gadget:GetInfo()
 return {name='Grot bomb drop and ignition',desc='Finite drop, then ordinary native missile guidance and damage',author='BAR 40K project',layer=0,enabled=true}
end
if not gadgetHandler:IsSyncedCode()then VFS.Include('luarules/utilities/bar40k_grotbomb_exhaust.lua')(gadget);return end
local S=Spring
local definitions,active={},{}
local fps=Game.gameSpeed
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
function gadget:Initialize()
 for id,def in pairs(WeaponDefs)do
  local cp=def.customParams or{};local frames=tonumber(cp.bar40k_grot_drop_frames)
  if frames and frames>0 then
   definitions[id]={frames=math.min(60,math.floor(frames)),tail=(tonumber(cp.bar40k_grot_bomb_length)or 20)*.5}
   Script.SetWatchProjectile(id,true)
  end
 end
end
function gadget:ProjectileCreated(id,owner,defID)
 local cfg=definitions[defID];if not cfg then return end
 local x,y,z=S.GetProjectilePosition(id);if not x then return end
 local vx,vy,vz=0,0,0
 if owner and S.ValidUnitID(owner)then vx,vy,vz=S.GetUnitVelocity(owner)end
 vx,vy,vz=vx or 0,vy or 0,vz or 0
 active[id]={cfg=cfg,x=x,y=y,z=z,vx=vx,vy=math.min(-.6,vy),vz=vz,release=S.GetGameFrame()+cfg.frames,ignited=false}
 S.SetProjectileMoveControl(id,true)
 S.SetProjectileVelocity(id,vx,math.min(-.6,vy),vz)
end
local function target(id,x,y,z)
 local kind,t=S.GetProjectileTarget(id)
 if kind==string.byte('u')and S.ValidUnitID(t)and not S.GetUnitIsDead(t)then return S.GetUnitPosition(t)end
 if kind==string.byte('g')and type(t)=='table'then return t[1],t[2],t[3]end
 local vx,vy,vz=S.GetProjectileVelocity(id)
 return x+(vx or 0),y+(vy or 0),z+(vz or 1)
end
function gadget:GameFrame(frame)
 local gravity=(Game.gravity or 130)/(fps*fps)
 for id,row in pairs(active)do
  local x,y,z=S.GetProjectilePosition(id)
  if not x then active[id]=nil
  elseif not row.ignited then
   if frame<row.release then
    row.vy=row.vy-gravity;row.x=row.x+row.vx;row.y=row.y+row.vy;row.z=row.z+row.vz
    S.SetProjectilePosition(id,row.x,row.y,row.z)
    S.SetProjectileVelocity(id,row.vx,row.vy,row.vz)
   else
    local tx,ty,tz=target(id,x,y,z)
    local dx,dy,dz=(tx or x)-x,(ty or y)-y,(tz or(z+1))-z
    local length=math.sqrt(dx*dx+dy*dy+dz*dz)
    if not finite(length)or length<1e-8 then dx,dy,dz,length=0,0,1,1 end
    S.SetProjectileVelocity(id,dx/length*4,dy/length*4,dz/length*4)
    S.SetProjectileMoveControl(id,false)
    row.ignited=true
    SendToUnsynced('bar40k_grotbomb_ignite',id)
   end

  end
 end
end
function gadget:ProjectileDestroyed(id)active[id]=nil end
function gadget:Shutdown()
 for id,row in pairs(active)do if not row.ignited and S.GetProjectilePosition(id)then S.SetProjectileMoveControl(id,false)end end
end
