-- Fractional source WALK sampling. Native orientation is Ry * Rx * Rz.
-- Source tables/cached quaternions are immutable; output storage is per actor.
-- No playback clock, movement speed, fire/contact cue or hierarchy is changed.
local caches=setmetatable({},{__mode='k'})
local sin,cos,sqrt,acos,abs=math.sin,math.cos,math.sqrt,math.acos,math.abs
local atan2=math.atan2 or function(y,x)return math.atan(y,x)end
local function quaternion(v)
 local sx,cx=sin(v[4]/2),cos(v[4]/2)
 local sy,cy=sin(v[5]/2),cos(v[5]/2)
 local sz,cz=sin(v[6]/2),cos(v[6]/2)
 return {cy*sx*cz+sy*cx*sz,sy*cx*cz-cy*sx*sz,
  cy*cx*sz-sy*sx*cz,cy*cx*cz+sy*sx*sz}
end
local function cache(clip)
 local q=caches[clip]
 if q then return q end
 q={segments={}};caches[clip]=q
 for f,row in ipairs(clip.frames) do
  q[f]={};for i,v in ipairs(row) do q[f][i]=quaternion(v) end
 end
 return q
end
-- Each immutable adjacent segment owns flat triples, including last->first.
-- Lazy construction avoids touching segments not sampled by any actor.
local function segment(q,i,j,masks)
 local coefficients=q.segments[i]
 if coefficients then return coefficients end
 coefficients={};q.segments[i]=coefficients
 for bone,a in ipairs(q[i]) do
  local b=q[j][bone];local offset=(bone-1)*3+1
  local m=masks and masks[bone]
  if not m or m.rotation then
   local dot=a[1]*b[1]+a[2]*b[2]+a[3]*b[3]+a[4]*b[4]
   local sign=dot<0 and -1 or 1;dot=math.min(1,abs(dot))
   coefficients[offset]=sign
   if dot<1-1e-12 then
    local angle=acos(dot);coefficients[offset+1]=angle;coefficients[offset+2]=sin(angle)
   else coefficients[offset+1]=false;coefficients[offset+2]=false end
  else coefficients[offset]=false;coefficients[offset+1]=false;coefficients[offset+2]=false end
 end
 return coefficients
end
local function rotation(a,b,t,coefficients,offset)
 local sign=coefficients[offset]
 local wa,wb=1-t,t*sign
 local angle=coefficients[offset+1]
 if angle then
  local divisor=coefficients[offset+2]
  wa=sin((1-t)*angle)/divisor;wb=sign*sin(t*angle)/divisor
 end
 local x,y,z,w=wa*a[1]+wb*b[1],wa*a[2]+wb*b[2],wa*a[3]+wb*b[3],wa*a[4]+wb*b[4]
 local length=sqrt(x*x+y*y+z*z+w*w);x,y,z,w=x/length,y/length,z/length,w/length
 local m10,m11,m12=2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)
 local cx=sqrt(m10*m10+m11*m11)
 local rx=atan2(-m12,cx)
 if cx<1e-10 then return rx,atan2(-2*(x*z-y*w),1-2*(y*y+z*z)),0 end
 local rz=atan2(m10,m11)
 local ry=atan2(2*(x*z+y*w),1-2*(x*x+y*y))
 -- Near a pole recover the coupled yaw from the large first column;
 -- dividing two nearly-zero cos(pitch) entries amplifies rounding noise.
 if abs(sin(rx))>.9 then
  ry=atan2(-2*(x*z-y*w),1-2*(y*y+z*z))+atan2(sin(rx)*sin(rz),cos(rz))
 end
 return rx,ry,rz
end
return function()
 -- Two alternating outputs preserve the previously applied row until a
 -- state-change Snapshot has copied it; a single reused row loses that pose.
 local outputs={{},{}};local outputIndex=0
 return function(clip,age)
  local count=#clip.frames
  local fps=clip.source_fps or count/clip.duration
  local position=(math.max(0,age)*fps)%count
  local i=math.floor(position)+1;local alpha=position-math.floor(position)
  local j=i%count+1
  -- Return ORIGINAL keypose objects at exact endpoints, including loop end.
  if alpha<1e-10 then return clip.frames[i] end
  if 1-alpha<1e-10 then return clip.frames[j] end
  outputIndex=outputIndex%2+1;local out=outputs[outputIndex]
  local aa,bb=clip.frames[i],clip.frames[j];local q=cache(clip)
  local coefficients=segment(q,i,j,clip.keyed_channels)
  for bone,a in ipairs(aa) do
   local b=bb[bone];local v=out[bone]
   if not v then v={};out[bone]=v end
   local m=clip.keyed_channels and clip.keyed_channels[bone]
   for axis=1,3 do v[axis]=(not m or m.position) and a[axis]+(b[axis]-a[axis])*alpha or a[axis] end
   if not m or m.rotation then v[4],v[5],v[6]=rotation(q[i][bone],q[j][bone],alpha,coefficients,(bone-1)*3+1)
   else v[4],v[5],v[6]=a[4],a[5],a[6] end
  end
  return out
 end
end
