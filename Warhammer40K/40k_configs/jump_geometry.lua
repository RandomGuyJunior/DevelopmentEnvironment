-- Deterministic geometry for the native synced jump controller.
local M={Command=34573,Tag=4034573}
function M.Finite(v)return type(v)=='number'and v==v and v~=math.huge and v~=-math.huge end
function M.PointSegmentSquared(px,py,pz,a,b)
 local dx,dy,dz=b[1]-a[1],b[2]-a[2],b[3]-a[3]
 local n=dx*dx+dy*dy+dz*dz;local t=0
 if n>0 then t=math.max(0,math.min(1,((px-a[1])*dx+(py-a[2])*dy+(pz-a[3])*dz)/n))end
 return (px-a[1]-dx*t)^2+(py-a[2]-dy*t)^2+(pz-a[3]-dz*t)^2
end
function M.Distance(a,b)return math.sqrt((b[1]-a[1])^2+(b[3]-a[3])^2)end
function M.Arc(a,b,phase,height)
 return {a[1]+(b[1]-a[1])*phase,a[2]+(b[2]-a[2])*phase+4*height*phase*(1-phase),a[3]+(b[3]-a[3])*phase}
end
function M.Step(a,b,maxStep)
 local dx,dy,dz=b[1]-a[1],b[2]-a[2],b[3]-a[3];local n=math.sqrt(dx*dx+dy*dy+dz*dz)
 if n<=maxStep then return {b[1],b[2],b[3]},true end
 local t=maxStep/n;return {a[1]+dx*t,a[2]+dy*t,a[3]+dz*t},false
end
function M.Config(cp)
 local function positive(k,default)local v=cp[k]==nil and default or tonumber(cp[k]);assert(M.Finite(v)and v>0,'Invalid jump config '..k);return v end
 return {range=positive('jump_range',480),flight=math.floor(positive('jump_flight_frames',90)),
  launch=math.floor(positive('jump_launch_frames',13)),land=math.floor(positive('jump_land_frames',11)),
  capacity=positive('jump_charge_capacity',135)*30,cost=positive('jump_charge_cost',45)*30,
  regen=positive('jump_charge_regen',1),maxStep=positive('jump_recovery_step',6)}
end
return M
