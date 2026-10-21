-- Gunship-specific pure geometry. Native weapons still own target selection,
-- ballistics, visibility, reloads and damage; these are physical mount limits.
local M={Version=3,trackingTolerance=math.rad(.5),angleEpsilon=1e-6}
function M.Finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
function M.Wrap(a)return(a+math.pi)%(2*math.pi)-math.pi end
local function vector(v)return type(v)=='table'and M.Finite(v[1])and M.Finite(v[2])and M.Finite(v[3])end
function M.Angles(x,y,z,front,up,right,fallbackYaw)
 if not(M.Finite(x)and M.Finite(y)and M.Finite(z)and vector(front)and vector(up)and vector(right))then return nil end
 local length=math.sqrt(x*x+y*y+z*z);if length<1e-9 then return nil end
 local function dot(v)return(x*v[1]+y*v[2]+z*v[3])/length end
 local horizontalX,horizontalZ=-dot(right),dot(front)
 -- Heading has no geometric meaning at the zenith. Preserve the current
 -- mount heading there instead of making a directly overhead fighter spin it.
 local yaw=(horizontalX*horizontalX+horizontalZ*horizontalZ<1e-10)and(fallbackYaw or 0)or math.atan2(horizontalX,horizontalZ)
 return yaw,math.asin(math.max(-1,math.min(1,dot(up))))
end
function M.Direction(yaw,pitch,front,up,right)
 local x,y,z=math.sin(yaw)*math.cos(pitch),math.sin(pitch),math.cos(yaw)*math.cos(pitch)
 return -right[1]*x+up[1]*y+front[1]*z,-right[2]*x+up[2]*y+front[2]*z,-right[3]*x+up[3]*y+front[3]*z
end
function M.PitchFloor(g,yaw)
 local floor=-g.down
 if not g.floors then return floor end
 local relative=M.Wrap(yaw-g.center)
 for i=1,#g.floors-1 do
  local a,b=g.floors[i],g.floors[i+1]
  if relative>=a.yaw and relative<=b.yaw then return math.max(floor,a.pitch,b.pitch)end
 end
 return g.up -- malformed/uncovered geometry fails closed
end
function M.Allowed(g,yaw,pitch)
 return M.Finite(yaw)and M.Finite(pitch)and math.abs(M.Wrap(yaw-g.center))<=g.limit+M.angleEpsilon and pitch>=M.PitchFloor(g,yaw)-M.angleEpsilon and pitch<=M.PitchCeiling(g,yaw)+M.angleEpsilon
end
function M.PitchCeiling(g,yaw)
 if not g.ceilings then return g.up end
 local relative=M.Wrap(yaw-g.center)
 for i=1,#g.ceilings-1 do
  local a,b=g.ceilings[i],g.ceilings[i+1]
  if relative>=a.yaw and relative<=b.yaw then return math.min(g.up,a.pitch,b.pitch)end
 end
 return -math.huge -- malformed/uncovered geometry fails closed
end
function M.TraverseEnvelope(g,from,to)
 local result=math.max(M.PitchFloor(g,from),M.PitchFloor(g,to))
 local ceiling=math.min(M.PitchCeiling(g,from),M.PitchCeiling(g,to))
 local delta=M.Wrap(to-from)
 -- Native Turn uses the shortest wrapped path. Do not cross a forbidden yaw
 -- seam simply because both endpoints lie inside a partial mechanical arc.
 local first=M.Wrap(from-g.center);local last=first+delta
 if first< -g.limit-M.angleEpsilon or first>g.limit+M.angleEpsilon then return nil,nil end
 if g.limit<math.pi-M.angleEpsilon and(last< -g.limit-M.angleEpsilon or last>g.limit+M.angleEpsilon)then return nil,nil end
 for _,rows in ipairs({g.floors or{},g.ceilings or{}})do
  for i,row in ipairs(rows)do
   local d=M.Wrap(g.center+row.yaw-from)
   if(delta>=0 and d>=0 and d<=delta)or(delta<0 and d<=0 and d>=delta)then
    -- Include both neighboring intervals at every crossed boundary.
    local before=rows[i>1 and i-1 or #rows-1]
    local after=rows[i<#rows and i+1 or 2]
    if rows==g.floors then result=math.max(result,row.pitch,before.pitch,after.pitch)
    else ceiling=math.min(ceiling,row.pitch,before.pitch,after.pitch)end
   end
  end
 end
 if result>ceiling+M.angleEpsilon then return nil,nil end
 return result,ceiling
end
function M.TraverseFloor(g,from,to)
 -- Retain the historical floor-only API for old consumers.
 return M.TraverseEnvelope(g,from,to)
end
function M.Build(cp)
 if tonumber(cp.bar40k_gunship_mount_count)~=7 or cp.bar40k_gunship_loadout_policy~='gunship_approved_kan_turrets_no_bomb_v5'then return nil end
 local revised=(tonumber(cp.bar40k_gunship_runtime_revision)or 0)>=11
 local result={};local n=1
 for _,name in ipairs({'nose','port_fore','port_aft','starboard_fore','starboard_aft','port_gantry','starboard_gantry'})do
  local prefix='bar40k_'..name
  local g={name=name,primary=n,center=tonumber(cp[prefix..'_yaw_center']),limit=tonumber(cp[prefix..'_yaw_limit']),down=tonumber(cp[prefix..'_pitch_down_limit']),up=tonumber(cp[prefix..'_pitch_up_limit']),axis=name..'_axis'}
  if not(M.Finite(g.center)and M.Finite(g.limit)and M.Finite(g.down)and M.Finite(g.up))then return nil end
  -- UnitDef customParams numbers cross a native float/string round trip.
  -- Canonicalize ONLY full-circle/zenith endpoints within~.000057degrees;
  -- this precision allowance is not a wider mechanical aiming sector.
  if g.limit<=0 or g.limit>math.pi+M.angleEpsilon or g.down<0 or g.down>math.pi*.5+M.angleEpsilon or g.up<=0 or g.up>math.pi*.5+M.angleEpsilon then return nil end
  if math.abs(g.limit-math.pi)<=M.angleEpsilon then g.limit=math.pi end
  if math.abs(g.up-math.pi*.5)<=M.angleEpsilon then g.up=math.pi*.5 end
  for _,kind in ipairs({'floor','ceiling'})do
   local rawCount=cp[prefix..'_pitch_'..kind..'_count']
   local count=rawCount==nil and 0 or tonumber(rawCount)
   if not M.Finite(count)or count<0 or count>721 or count~=math.floor(count)then return nil end
   if count>0 then
   local rows={};if count<2 or count>721 or count~=math.floor(count)then return nil end
   for i=1,count do
    local yaw,pitch=tonumber(cp[prefix..'_pitch_'..kind..'_yaw_'..i]),tonumber(cp[prefix..'_pitch_'..kind..'_pitch_'..i])
    if not(M.Finite(yaw)and M.Finite(pitch))or yaw< -math.pi-M.angleEpsilon or yaw>math.pi+M.angleEpsilon or pitch< -g.down-M.angleEpsilon or pitch>g.up+M.angleEpsilon then return nil end
    if i==1 and math.abs(yaw+math.pi)<=M.angleEpsilon then yaw=-math.pi end
    if i==count and math.abs(yaw-math.pi)<=M.angleEpsilon then yaw=math.pi end
    if i>1 and yaw<=rows[i-1].yaw then return nil end
    rows[i]={yaw=yaw,pitch=pitch}
   end
   if rows[1].yaw~= -math.pi or rows[count].yaw~=math.pi or math.abs(rows[1].pitch-rows[count].pitch)>M.angleEpsilon then return nil end
   local seam=kind=='floor'and math.max(rows[1].pitch,rows[count].pitch)or math.min(rows[1].pitch,rows[count].pitch)
   rows[1].pitch=seam;rows[count].pitch=seam
   g[kind=='floor'and'floors'or'ceilings']=rows
   end
  end
  if revised and name~='nose'and not(g.floors and g.ceilings)then return nil end
  result[n]=g;n=n+1
 end
 return result
end
-- Same selected continuous solution as pinned CCannon::CalcWantedDir;
-- candidate filtering uses the current target aim point. Native leading and
-- per-shot dispersion remain native, with final live-direction guards in LUS.
function M.LaunchDirection(dx,dy,dz,speed,gravity,highTrajectory)
 if not(M.Finite(dx)and M.Finite(dy)and M.Finite(dz)and M.Finite(speed)and speed>0 and M.Finite(gravity))then return nil end
 local horizontal=math.sqrt(dx*dx+dz*dz)
 if horizontal<1e-6 then
  -- Pinned CCannon's exact vertical branch returns +Y; keep filtering
  -- consistent with its actual solver rather than divide by zero.
  if math.abs(gravity)>=1e-10 then return 0,1,0 end
  if math.abs(dy)<1e-9 then return nil end
  return 0,dy>0 and 1 or -1,0
 end
 local pitch
 if math.abs(gravity)<1e-10 then pitch=math.atan2(dy,horizontal)
 else
  local v2=speed*speed;local discriminant=v2*v2+2*v2*gravity*dy-gravity*gravity*horizontal*horizontal
  if discriminant<0 then return nil end
  -- Stable low root avoids cancellation. The explicit high root matches a
  -- native Cannon with highTrajectory=1; no projectile steering or mode write.
  local root=math.sqrt(discriminant)
  local tangent=highTrajectory and(-v2-root)/(gravity*horizontal)or(gravity*horizontal*horizontal-2*v2*dy)/(horizontal*(-v2-root))
  pitch=math.atan(tangent)
 end
 local factor=math.cos(pitch)/horizontal
 return dx*factor,math.sin(pitch),dz*factor
end
return M
