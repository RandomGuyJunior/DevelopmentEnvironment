-- Native rockets own launch direction, delayed turning, collision and damage.
-- This spawn-only adapter selects one ordinary inaccurate surface aim point.
function gadget:GetInfo()
 return {name='Gork source rokkit scatter',desc='Spawn-only scoped surface aim dispersion',author='BAR 40K project',layer=0,enabled=true}
end
if not gadgetHandler:IsSyncedCode()then return end
local radii={}
function gadget:Initialize()
 for id,def in pairs(WeaponDefs)do
  local radius=tonumber(def.customParams and def.customParams.gork_rokkit_scatter_radius)
  if radius and radius>0 then
   radii[id]=radius
   Script.SetWatchProjectile(id,true)
  end
 end
end
function gadget:ProjectileCreated(id,owner,defID)
 local radius=radii[defID];if not radius then return end
 local kind,target=Spring.GetProjectileTarget(id)
 local x,y,z
 if kind==string.byte('g')and type(target)=='table'then x,y,z=target[1],target[2],target[3]
 elseif kind==string.byte('u')and Spring.ValidUnitID(target)and not Spring.GetUnitIsDead(target)then x,y,z=Spring.GetUnitPosition(target)
 else return end
 if not x or not z then return end
 local angle=math.random()*2*math.pi
 local r=radius*math.sqrt(math.random())
 x,z=x+math.cos(angle)*r,z+math.sin(angle)*r
 -- Surface rokkits seek a real ground impact point, including on uneven terrain.
 y=Spring.GetGroundHeight(x,z)
 Spring.SetProjectileTarget(id,x,y,z)
end
