-- Lancer-only contact preparation. Native weapon slot2 remains the only damage
-- owner; this helper only aligns the authored strike and gates its real shot.
return function(data)
 local source=data.clips.melee
 local members=data.aimGroups[1].members
 local pivotJoint=data.aimGroups[1].pivotJoint
 local tipJoint
 for i,name in ipairs(data.bones)do if name=='muzzle_lance'then tipJoint=i end end
 local function rotate(r,v)return{r[1]*v[1]+r[2]*v[2]+r[3]*v[3],r[4]*v[1]+r[5]*v[2]+r[6]*v[3],r[7]*v[1]+r[8]*v[2]+r[9]*v[3]}end
 local function rotation(x,y,z)
  local cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
  return{cy*cz+sy*sx*sz,-cy*sz+sy*sx*cz,sy*cx,cx*sz,cx*cz,-sx,-sy*cz+cy*sx*sz,sy*sz+cy*sx*cz,cy*cx}
 end
 local function multiply(a,b)local r={}for i=0,2 do for j=1,3 do r[i*3+j]=a[i*3+1]*b[j]+a[i*3+2]*b[3+j]+a[i*3+3]*b[6+j]end end;return r end
 local function euler(r)
  local x=math.asin(math.max(-1,math.min(1,-r[6])))
  if math.abs(math.cos(x))<1e-6 then return x,math.atan2(-r[7],r[1]),0 end
  return x,math.atan2(r[3],r[9]),math.atan2(r[4],r[5])
 end
 local function axisAngle(axis,a)local x,y,z=unpack(axis);local c,s=math.cos(a),math.sin(a);local v=1-c;return{c+x*x*v,x*y*v-z*s,x*z*v+y*s,y*x*v+z*s,c+y*y*v,y*z*v-x*s,z*x*v-y*s,z*y*v+x*s,c+z*z*v}end
 local function localTarget(target)
  local x,y,z=Spring.GetUnitPosition(unitID);local tx,ty,tz,mx,my,mz=Spring.GetUnitPosition(target,true)
  if not(x and tx)then return end;tx,ty,tz=mx or tx,my or ty,mz or tz
  local _,_,_,ox,oy,oz=Spring.GetUnitCollisionVolumeData(target)
  if ox then local h=Spring.GetUnitHeading(target)*math.pi/32768;tx,ty,tz=tx+ox*math.cos(h)+oz*math.sin(h),ty+oy,tz-ox*math.sin(h)+oz*math.cos(h)end
  local h=Spring.GetUnitHeading(unitID)*math.pi/32768;local dx,dz=tx-x,tz-z
  return{dx*math.cos(h)-dz*math.sin(h),ty-y,dx*math.sin(h)+dz*math.cos(h)}
 end
 local function targetID()
  local kind,_,target=Spring.GetUnitWeaponTarget(unitID,2)
  if kind~=1 or not target or not Spring.ValidUnitID(target)or Spring.GetUnitIsDead(target)then return end
  local def=UnitDefs[Spring.GetUnitDefID(target)];if not def or def.canFly then return end
  local team=Spring.GetUnitTeam(target);if not team or Spring.AreTeamsAllied(Spring.GetUnitTeam(unitID),team)then return end
  return target
 end
 local function prepare(target)
  local goal=localTarget(target);if not goal then return end
  local reference=source.frames[24];local p=reference[pivotJoint];local tip=reference[tipJoint]
  local a,b={tip[1]-p[1],tip[2]-p[2],tip[3]-p[3]},{goal[1]-p[1],goal[2]-p[2],goal[3]-p[3]}
  local la=math.sqrt(a[1]^2+a[2]^2+a[3]^2);local lb=math.sqrt(b[1]^2+b[2]^2+b[3]^2)
  if la<1e-6 or lb<1e-6 then return end
  for k=1,3 do a[k],b[k]=a[k]/la,b[k]/lb end
  local axis={a[2]*b[3]-a[3]*b[2],a[3]*b[1]-a[1]*b[3],a[1]*b[2]-a[2]*b[1]};local length=math.sqrt(axis[1]^2+axis[2]^2+axis[3]^2)
  local angle=math.acos(math.max(-1,math.min(1,a[1]*b[1]+a[2]*b[2]+a[3]*b[3])))
  if length<1e-7 then axis={1,0,0};angle=0 else for k=1,3 do axis[k]=axis[k]/length end end
  -- Out-of-reach vertical targets stay blocked; never fold the arm backwards.
  if angle>math.rad(90)then return end
  local clip={};for k,v in pairs(source)do clip[k]=v end;clip.frames={}
  for f,rows in ipairs(source.frames)do
   local out={};for i,row in ipairs(rows)do out[i]={unpack(row)}end;clip.frames[f]=out
   local weight=math.max(0,math.min(1,(f-1)/17,(#source.frames-f)/17));weight=weight*weight*(3-2*weight)
   local delta=axisAngle(axis,angle*weight);local pivot=rows[pivotJoint]
   for _,i in ipairs(members)do
    local row=out[i];local q=rotate(delta,{row[1]-pivot[1],row[2]-pivot[2],row[3]-pivot[3]})
    row[1],row[2],row[3]=q[1]+pivot[1],q[2]+pivot[2],q[3]+pivot[3]
    row[4],row[5],row[6]=euler(multiply(delta,rotation(row[4],row[5],row[6])))
    local previous=clip.frames[f-1]and clip.frames[f-1][i]
    if previous then for k=4,6 do row[k]=previous[k]+(row[k]-previous[k]+math.pi)%(2*math.pi)-math.pi end end
   end
  end
  return clip
 end
 local function touches(target,a,b)
  local sx,sy,sz,ox,oy,oz,kind,_,primary,ignored=Spring.GetUnitCollisionVolumeData(target)
  if not sx or ignored then return false end
  local x,y,z,mx,my,mz=Spring.GetUnitPosition(target,true);x,y,z=mx or x,my or y,mz or z
  local h=Spring.GetUnitHeading(target)*math.pi/32768;local c,s=math.cos(h),math.sin(h)
  local function localPoint(p)local dx,dz=p[1]-x,p[3]-z;return{dx*c-dz*s-ox,p[2]-y-oy,dx*s+dz*c-oz}end
  a,b=localPoint(a),localPoint(b);local halves={sx*.5+3,sy*.5+3,sz*.5+3};local lo,hi=0,1
  local function interval(k)
   local d=b[k]-a[k]
   if math.abs(d)<1e-7 then return math.abs(a[k])<=halves[k]end
   local t1,t2=(-halves[k]-a[k])/d,(halves[k]-a[k])/d
   if t1>t2 then t1,t2=t2,t1 end;lo,hi=math.max(lo,t1),math.min(hi,t2)
   return lo<=hi
  end
  if kind==2 then for k=1,3 do if not interval(k)then return false end end;return true end
  local axis=kind==1 and(primary+1)or nil
  if axis and not interval(axis)then return false end
  local A,B,C=0,0,-1
  for k=1,3 do if k~=axis then local p=a[k]/halves[k];local d=(b[k]-a[k])/halves[k];A=A+d*d;B=B+2*p*d;C=C+p*p end end
  if A<1e-12 then return C<=0 end
  local discriminant=B*B-4*A*C;if discriminant<0 then return false end
  local root=math.sqrt(discriminant);lo,hi=math.max(lo,(-B-root)/(2*A)),math.min(hi,(-B+root)/(2*A))
  return lo<=hi
 end
 return{Target=targetID,Prepare=prepare,Touches=touches}
end

