-- Source-local interpolation for explicitly opted-in flattened native palettes.
-- Source bind transforms and dynamic local translations remain authoritative.
-- One controller writes pieces; this module only returns immutable pose rows.
return function(meta)
 local count=meta.jointCount
 local localCache=setmetatable({},{__mode='k'})
 local function multiply(a,b)
  local c={}
  for r=0,2 do
   local q=r*4
   for k=1,3 do c[q+k]=a[q+1]*b[k]+a[q+2]*b[4+k]+a[q+3]*b[8+k] end
   c[q+4]=a[q+1]*b[4]+a[q+2]*b[8]+a[q+3]*b[12]+a[q+4]
  end
  return c
 end
 local function inverse(a)
  local b={a[1],a[5],a[9],0,a[2],a[6],a[10],0,a[3],a[7],a[11],0}
  for r=0,2 do local q=r*4;b[q+4]=-b[q+1]*a[4]-b[q+2]*a[8]-b[q+3]*a[12] end
  return b
 end
 local function matrix(row)
  local x,y,z=row[4],row[5],row[6]
  local cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
  return {cy*cz+sy*sx*sz,-cy*sz+sy*sx*cz,sy*cx,row[1],cx*sz,cx*cz,-sx,row[2],-sy*cz+cy*sx*sz,sy*sz+cy*sx*cz,cy*cx,row[3]}
 end
 local function row(a)
  local cx=math.sqrt(a[5]*a[5]+a[6]*a[6]);local x=math.atan2(-a[7],cx)
  local y,z
  if cx>1e-7 then y=math.atan2(a[3],a[11]);z=math.atan2(a[5],a[6])
  else y=0;z=math.atan2(-a[2],a[1])end
  return {a[4],a[8],a[12],x,y,z}
 end
 local function quaternion(a)
  local trace=a[1]+a[6]+a[11];local x,y,z,w
  if trace>0 then local s=math.sqrt(trace+1)*2;w=s*.25;x=(a[10]-a[7])/s;y=(a[3]-a[9])/s;z=(a[5]-a[2])/s
  elseif a[1]>a[6] and a[1]>a[11] then local s=math.sqrt(1+a[1]-a[6]-a[11])*2;w=(a[10]-a[7])/s;x=s*.25;y=(a[2]+a[5])/s;z=(a[3]+a[9])/s
  elseif a[6]>a[11] then local s=math.sqrt(1+a[6]-a[1]-a[11])*2;w=(a[3]-a[9])/s;x=(a[2]+a[5])/s;y=s*.25;z=(a[7]+a[10])/s
  else local s=math.sqrt(1+a[11]-a[1]-a[6])*2;w=(a[5]-a[2])/s;x=(a[3]+a[9])/s;y=(a[7]+a[10])/s;z=s*.25 end
  return {x,y,z,w,a[4],a[8],a[12]}
 end
 local function fromQuaternion(q)
  local x,y,z,w=q[1],q[2],q[3],q[4]
  return {1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w),q[5],2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w),q[6],2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y),q[7]}
 end
 local function interpolate(a,b,t)
  local dot=a[1]*b[1]+a[2]*b[2]+a[3]*b[3]+a[4]*b[4];local sign=dot<0 and -1 or 1;dot=math.min(1,math.abs(dot))
  local wa,wb=1-t,t
  if dot<.9995 then local theta=math.acos(dot);local s=math.sin(theta);wa=math.sin((1-t)*theta)/s;wb=math.sin(t*theta)/s end
  local q={};local n=0
  for k=1,4 do q[k]=a[k]*wa+b[k]*wb*sign;n=n+q[k]*q[k]end
  n=math.sqrt(n);for k=1,4 do q[k]=q[k]/n end
  for k=5,7 do q[k]=a[k]+(b[k]-a[k])*t end
  return q
 end
 local function toLocal(pose)
  if localCache[pose]then return localCache[pose]end
  local world,locals={},{}
  for _,i in ipairs(meta.order)do
   world[i]=multiply(matrix(pose[i]),meta.bind[i]);local p=meta.parents[i]
   locals[i]=quaternion(p>0 and multiply(inverse(world[p]),world[i])or world[i])
  end
  localCache[pose]=locals;return locals
 end
 local function fromLocal(locals,template)
  local world,out={},{}
  for _,i in ipairs(meta.order)do
   local p=meta.parents[i];local m=fromQuaternion(locals[i]);world[i]=p>0 and multiply(world[p],m)or m
   out[i]=row(multiply(world[i],meta.inverseBind[i]))
  end
  for i=count+1,#template do local r=template[i];out[i]={r[1],r[2],r[3],r[4],r[5],r[6]}end
  for _,a in ipairs(meta.attachments or{})do
   local m=multiply(matrix(out[a.parent]),meta.bind[a.parent]);local p=a.localPoint;local r=out[a.index]
   r[1]=m[1]*p[1]+m[2]*p[2]+m[3]*p[3]+m[4]
   r[2]=m[5]*p[1]+m[6]*p[2]+m[7]*p[3]+m[8]
   r[3]=m[9]*p[1]+m[10]*p[2]+m[11]*p[3]+m[12]
   if a.inheritRotation then for k=4,6 do r[k]=out[a.parent][k]end end
  end
  return out
 end
 local function blend(a,b,t)
  if not a or t>=1 then return b end;if t<=0 then return a end
  local aa,bb=toLocal(a),toLocal(b);local out={}
  for i=1,count do out[i]=interpolate(aa[i],bb[i],t)end
  return fromLocal(out,b)
 end
 local function sample(clip,time,loop)
  time=loop and time%clip.duration or math.max(0,math.min(time,clip.duration))
  local pos=time*clip.fps;local index=math.min(#clip.frames,1+math.floor(pos));local following=index<#clip.frames and index+1 or(loop and 1 or index)
  return blend(clip.frames[index],clip.frames[following],pos-math.floor(pos))
 end
 local function mergeUpper(a,b,upper)
  local aa,bb=toLocal(a),toLocal(b);local out={};for i=1,count do out[i]=aa[i]end
  for _,i in ipairs(upper)do if i<=count then out[i]=bb[i]end end
  return fromLocal(out,a)
 end
 local function recoil(base,fire,ready)
  local a,b,c=toLocal(base),toLocal(fire),toLocal(ready);local out={}
  for i=1,count do out[i]=quaternion(multiply(fromQuaternion(a[i]),multiply(inverse(fromQuaternion(c[i])),fromQuaternion(b[i]))))end
  return fromLocal(out,base)
 end
 local function yawUpper(pose,upper,turn,chest)
  local selected={};for _,i in ipairs(upper)do selected[i]=true end
  local root=chest
  for _,i in ipairs(meta.order)do if selected[i]and not selected[meta.parents[i]]then root=i;break end end
  local pivot=multiply(matrix(pose[root]),meta.bind[root]);local y=matrix({0,0,0,0,turn,0});local o=meta.referenceOrigin or{0,0,0}
  local p={pivot[1]*o[1]+pivot[2]*o[2]+pivot[3]*o[3]+pivot[4],pivot[5]*o[1]+pivot[6]*o[2]+pivot[7]*o[3]+pivot[8],pivot[9]*o[1]+pivot[10]*o[2]+pivot[11]*o[3]+pivot[12]}
  y[4]=p[1]-y[1]*p[1]-y[3]*p[3];y[8]=0;y[12]=p[3]-y[9]*p[1]-y[11]*p[3]
  local out={};for i,r in ipairs(pose)do out[i]=r end
  for _,i in ipairs(upper)do out[i]=row(multiply(y,matrix(pose[i])))end
  return out
 end
 return {blend=blend,sample=sample,mergeUpper=mergeUpper,recoil=recoil,yawUpper=yawUpper,toLocal=toLocal,fromLocal=fromLocal,matrix=matrix,multiply=multiply,row=row}
end
