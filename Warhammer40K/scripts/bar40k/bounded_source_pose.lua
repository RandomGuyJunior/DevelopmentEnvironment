-- Guard artwork interpolation with bounded per-actor workspaces.
-- No commands, callbacks, damage, garbage-collection or engine settings here.
-- Caller-owned output rows may be reused; authored samples remain immutable.
local flatFrame=include('bar40k/numeric_animation_frame.lua')
return function(meta)
 local count=meta.jointCount
 local EMPTY={}
 local function ensure(out,i)local r=out[i];if not r then r={};out[i]=r end;return r end
 local function matrix(r,o,offset)
  o=o or{};offset=offset or 0
  local x,y,z=r[offset+4],r[offset+5],r[offset+6]
  local cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
  o[1],o[2],o[3],o[4]=cy*cz+sy*sx*sz,-cy*sz+sy*sx*cz,sy*cx,r[offset+1]
  o[5],o[6],o[7],o[8]=cx*sz,cx*cz,-sx,r[offset+2]
  o[9],o[10],o[11],o[12]=-sy*cz+cy*sx*sz,sy*sz+cy*sx*cz,cy*cx,r[offset+3]
  return o
 end
 local function multiply(a,b,o)
  o=o or{} -- inputs and output must be distinct
  for r=0,2 do local q=r*4
   for k=1,3 do o[q+k]=a[q+1]*b[k]+a[q+2]*b[4+k]+a[q+3]*b[8+k]end
   o[q+4]=a[q+1]*b[4]+a[q+2]*b[8]+a[q+3]*b[12]+a[q+4]
  end;return o
 end
 local function inverse(a,b)
  b=b or{};b[1],b[2],b[3],b[4]=a[1],a[5],a[9],0;b[5],b[6],b[7],b[8]=a[2],a[6],a[10],0;b[9],b[10],b[11],b[12]=a[3],a[7],a[11],0
  for r=0,2 do local q=r*4;b[q+4]=-b[q+1]*a[4]-b[q+2]*a[8]-b[q+3]*a[12]end;return b
 end
 local function row(a,o)
  o=o or{};local cx=math.sqrt(a[5]*a[5]+a[6]*a[6]);local x=math.atan2(-a[7],cx);local y,z
  if cx>1e-7 then y=math.atan2(a[3],a[11]);z=math.atan2(a[5],a[6])else y=0;z=math.atan2(-a[2],a[1])end
  o[1],o[2],o[3],o[4],o[5],o[6]=a[4],a[8],a[12],x,y,z;return o
 end
 local function quaternion(a,o)
  o=o or{};local trace=a[1]+a[6]+a[11];local x,y,z,w
  if trace>0 then local s=math.sqrt(trace+1)*2;w=s*.25;x=(a[10]-a[7])/s;y=(a[3]-a[9])/s;z=(a[5]-a[2])/s
  elseif a[1]>a[6]and a[1]>a[11]then local s=math.sqrt(1+a[1]-a[6]-a[11])*2;w=(a[10]-a[7])/s;x=s*.25;y=(a[2]+a[5])/s;z=(a[3]+a[9])/s
  elseif a[6]>a[11]then local s=math.sqrt(1+a[6]-a[1]-a[11])*2;w=(a[3]-a[9])/s;x=(a[2]+a[5])/s;y=s*.25;z=(a[7]+a[10])/s
  else local s=math.sqrt(1+a[11]-a[1]-a[6])*2;w=(a[5]-a[2])/s;x=(a[3]+a[9])/s;y=(a[7]+a[10])/s;z=s*.25 end
  o[1],o[2],o[3],o[4],o[5],o[6],o[7]=x,y,z,w,a[4],a[8],a[12];return o
 end
 local function fromQuaternion(q,o)
  o=o or{};local x,y,z,w=q[1],q[2],q[3],q[4]
  o[1],o[2],o[3],o[4]=1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w),q[5]
  o[5],o[6],o[7],o[8]=2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w),q[6]
  o[9],o[10],o[11],o[12]=2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y),q[7];return o
 end
 local function interpolate(a,b,t,o)
  o=o or{};local dot=a[1]*b[1]+a[2]*b[2]+a[3]*b[3]+a[4]*b[4];local sign=dot<0 and -1 or 1;dot=math.min(1,math.abs(dot));local wa,wb=1-t,t
  if dot<.9995 then local theta=math.acos(dot);local s=math.sin(theta);wa=math.sin((1-t)*theta)/s;wb=math.sin(t*theta)/s end
  local n=0;for k=1,4 do o[k]=a[k]*wa+b[k]*wb*sign;n=n+o[k]*o[k]end;n=math.sqrt(n);for k=1,4 do o[k]=o[k]/n end
  for k=5,7 do o[k]=a[k]+(b[k]-a[k])*t end;return o
 end
 local world,ma,mb,mc={},{},{},{}
 local function toLocal(pose,out,flat)
  out=out or{}
  for _,i in ipairs(meta.order)do
   matrix(flat or pose[i],ma,flat and(i-1)*6 or 0);multiply(ma,meta.bind[i],ensure(world,i));local p=meta.parents[i]
   if p>0 then inverse(world[p],mb);multiply(mb,world[i],mc);quaternion(mc,ensure(out,i))else quaternion(world[i],ensure(out,i))end
  end;return out
 end
 local function fromLocal(locals,template,out)
  out=out or{}
  for _,i in ipairs(meta.order)do
   local p=meta.parents[i];fromQuaternion(locals[i],ma)
   if p>0 then multiply(world[p],ma,ensure(world,i))else local w=ensure(world,i);for k=1,12 do w[k]=ma[k]end end
   multiply(world[i],meta.inverseBind[i],mb);row(mb,ensure(out,i))
  end
  for i=count+1,#template do local r=template[i];local o=ensure(out,i);for k=1,6 do o[k]=r[k]end end
  for _,a in ipairs(meta.attachments or EMPTY)do
   multiply(matrix(out[a.parent],ma),meta.bind[a.parent],mb);local p=a.localPoint;local r=out[a.index]
   r[1]=mb[1]*p[1]+mb[2]*p[2]+mb[3]*p[3]+mb[4];r[2]=mb[5]*p[1]+mb[6]*p[2]+mb[7]*p[3]+mb[8];r[3]=mb[9]*p[1]+mb[10]*p[2]+mb[11]*p[3]+mb[12]
   if a.inheritRotation then for k=4,6 do r[k]=out[a.parent][k]end end
  end;return out
 end
 local aa,bb,qq={},{},{}
 local function copy(source,out)
  out=out or{};for i,r in ipairs(source)do local o=ensure(out,i);for k=1,6 do o[k]=r[k]end end;return out
 end
 local function blend(a,b,t,out)
  if not a or t>=1 then return out and copy(b,out)or b end;if t<=0 then return out and copy(a,out)or a end
  toLocal(a,aa);toLocal(b,bb);for i=1,count do interpolate(aa[i],bb[i],t,ensure(qq,i))end;return fromLocal(qq,b,out)
 end
 local template={}
 local function sample(clip,time,loop,out)
  local frameCount=#clip.frames
  local duration=clip.duration
  if not (time>=0 and time<math.huge) then time=0 end
  time=duration>0 and (loop and time%duration or math.min(time,duration)) or 0
  local pos=math.max(0,math.min(loop and frameCount-.000001 or frameCount-1,time*clip.fps))
  local base=math.floor(pos)
  local index=base+1
  local following=index<frameCount and index+1 or (loop and 1 or index)
  local t=pos-base
  local a,b=flatFrame(clip.frames,index),flatFrame(clip.frames,following)
  -- Flat palette helper rows above jointCount pass through exactly as before.
  for i=1,#b/6 do local r=ensure(template,i);local base=(i-1)*6;for k=1,6 do r[k]=b[base+k]end end
  if t<=0 then for i=1,#a/6 do local r=template[i];local base=(i-1)*6;for k=1,6 do r[k]=a[base+k]end end;return copy(template,out)end
  toLocal(nil,aa,a);toLocal(nil,bb,b);for i=1,count do interpolate(aa[i],bb[i],t,ensure(qq,i))end;return fromLocal(qq,template,out)
 end
 local function mergeUpper(a,b,upper,out)
  toLocal(a,aa);toLocal(b,bb);for i=1,count do local o=ensure(qq,i);for k=1,7 do o[k]=aa[i][k]end end
  for _,i in ipairs(upper)do if i<=count then local o=qq[i];for k=1,7 do o[k]=bb[i][k]end end end
  return fromLocal(qq,a,out)
 end
 return{sample=sample,blend=blend,mergeUpper=mergeUpper,matrix=matrix,multiply=multiply,row=row,copy=copy,toLocal=toLocal,fromLocal=fromLocal}
end
