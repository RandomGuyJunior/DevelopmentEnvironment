-- One pose writer. Native BAR owns orders, projectiles, damage and construction.
return function(file)
local EMPTY={}
 local footfall=include('bar40k/titan_footfalls.lua')()
local artwork=include('bar40k/animation_data.lua')(file)
local d={};for k,v in pairs(artwork)do d[k]=v end
-- Handles are instance-local; never mutate cached immutable clip/mount artwork.
d.mounts={}
for i,m in ipairs(artwork.mounts)do local own={};for k,v in pairs(m)do own[k]=v end;d.mounts[i]=own
 if m.extraMuzzles then own.extraMuzzles={};for j,e in ipairs(m.extraMuzzles)do local item={};for k,v in pairs(e)do item[k]=v end;own.extraMuzzles[j]=item end end
end
local frameAt=include('bar40k/numeric_animation_frame.lua')
local pose=d.flat and include('bar40k/bounded_source_pose.lua')(include('bar40k/animation_data.lua')(d.hierarchy))
local bones,index={},{};for i,n in ipairs(d.bones)do bones[i]=piece(n);index[n]=i end
local root=piece('unit_aim');local previous={};local moving,dead=false,false
local aim,shot,cursor={}, {}, {};local nextCursor,spin={},{};local distance=0;local last=Spring.GetGameFrame()
local function copyRows(rows,out)out=out or{};for i,r in ipairs(rows)do local o=out[i];if not o then o={};out[i]=o end;for k=1,6 do o[k]=r[k]end end;return out end
local function delta(a,b)return(b-a+math.pi)%(2*math.pi)-math.pi end
local function approach(a,b,v)return a+math.max(-v,math.min(v,delta(a,b)))end
local function write(h,r,dt)
 local old=previous[h];local out=old or{}
 for a=1,3 do
  local p=r[a];local v=old and old[a+3]+delta(old[a+3],r[a+3])or r[a+3]
  if not old or math.abs(p-old[a])>1e-5 then Move(h,a,p,old and math.abs(p-old[a])/dt or nil)end
  if not old or math.abs(v-old[a+3])>1e-5 then Turn(h,a,v,old and math.abs(v-old[a+3])/dt or nil)end
  out[a],out[a+3]=p,v
 end
 previous[h]=out
end
local function sample(c,t,loop,out)
 out=out or{}
 if not c then for i=1,#bones do local a=out[i];if not a then a={};out[i]=a end;for k=1,6 do a[k]=0 end end;return out end
 if pose then return pose.sample(c,t,loop,out)end
 if not (t>=0 and t<math.huge) then t=0 end
 local duration=c.duration
 t=duration>0 and (loop and t%duration or math.min(t,duration)) or 0
 local pos=duration>0 and math.max(0,math.min(#c.frames-1,t/duration*(#c.frames-1))) or 0
 local k=1+math.floor(pos);local j=math.min(#c.frames,k+1)
 local aa,bb=frameAt(c.frames,k),frameAt(c.frames,j)
 for i=1,#bones do local offset=(i-1)*6;local r=out[i]or{};for v=1,6 do local a,b=aa[offset+v],bb[offset+v];r[v]=a+(v<=3 and(b-a)or delta(a,b))*(pos-math.floor(pos))end;out[i]=r end
 return out
end
-- Aim scratch vectors/matrices are private to this actor and reused for every mount.
local pm,base,rot,work,yaw,pitch={},{},{},{},{},{}
local pivot,hinge,forward,tip,wanted,temp={},{},{},{},{},{}
local axis={0,1,0};local markerRow={}
local function writeMarker(h,x,y,z,rx,ry,rz,dt)
 markerRow[1],markerRow[2],markerRow[3],markerRow[4],markerRow[5],markerRow[6]=x,y,z,rx,ry,rz;write(h,markerRow,dt)
end
local function point(m,p,o)o=o or{};o[1],o[2],o[3]=m[1]*p[1]+m[2]*p[2]+m[3]*p[3]+m[4],m[5]*p[1]+m[6]*p[2]+m[7]*p[3]+m[8],m[9]*p[1]+m[10]*p[2]+m[11]*p[3]+m[12];return o end
local function direction(m,p,o)o=o or{};o[1],o[2],o[3]=m[1]*p[1]+m[2]*p[2]+m[3]*p[3],m[5]*p[1]+m[6]*p[2]+m[7]*p[3],m[9]*p[1]+m[10]*p[2]+m[11]*p[3];return o end
local function rotateAxis(axis,angle,p,r)
 local x,y,z=axis[1],axis[2],axis[3];local c,s=math.cos(angle),math.sin(angle);local q=1-c
 r[1],r[2],r[3],r[4]=c+x*x*q,x*y*q-z*s,x*z*q+y*s,0;r[5],r[6],r[7],r[8]=y*x*q+z*s,c+y*y*q,y*z*q-x*s,0;r[9],r[10],r[11],r[12]=z*x*q-y*s,z*y*q+x*s,c+z*z*q,0
 direction(r,p,temp);r[4],r[8],r[12]=p[1]-temp[1],p[2]-temp[2],p[3]-temp[3];return r
end
local function rotateBetween(a,b,p,r)
 local n=math.sqrt(a[1]^2+a[2]^2+a[3]^2);for i=1,3 do a[i]=a[i]/math.max(n,1e-9)end
 local x,y,z=a[2]*b[3]-a[3]*b[2],a[3]*b[1]-a[1]*b[3],a[1]*b[2]-a[2]*b[1];local s=math.sqrt(x*x+y*y+z*z);local c=math.max(-1,math.min(1,a[1]*b[1]+a[2]*b[2]+a[3]*b[3]))
 if s<1e-7 then if c>0 then for i=1,12 do r[i]=0 end;r[1],r[6],r[11]=1,1,1;return r else x,y,z,s=0,1,0,1 end end
 x,y,z=x/s,y/s,z/s;if c<-.999999 then s=0 end;local q=1-c
 r[1],r[2],r[3],r[4]=c+x*x*q,x*y*q-z*s,x*z*q+y*s,0;r[5],r[6],r[7],r[8]=y*x*q+z*s,c+y*y*q,y*z*q-x*s,0;r[9],r[10],r[11],r[12]=z*x*q-y*s,z*y*q+x*s,c+z*z*q,0
 direction(r,p,temp);r[4],r[8],r[12]=p[1]-temp[1],p[2]-temp[2],p[3]-temp[3];return r
end
local function flatAim(rows,m,a)
 pose.matrix(rows[m.parent],pm);point(pose.matrix(rows[m.yawRoot or m.root],work),m.pivot,pivot)
 direction(pm,m.forward,forward);local h=math.atan2(forward[1],forward[3]);local turn=m.fixedYaw and 0 or delta(h,a.h)
 axis[1],axis[2],axis[3]=0,1,0;rotateAxis(axis,turn,pivot,yaw)
 for _,i in ipairs(m.members)do pose.row(pose.multiply(yaw,pose.matrix(rows[i],work),rot),rows[i])end
 local pitched=m.pitchMembers or m.members
 if not m.fixedLaunch and #pitched>0 then
  point(pose.matrix(rows[m.pitchRoot or m.root],base),m.pitchPivot or m.pivot,hinge)
  direction(pose.matrix(rows[m.parent],pm),m.forward,forward);h=math.atan2(forward[1],forward[3]);local elevation=math.atan2(forward[2],math.sqrt(forward[1]^2+forward[3]^2))
  axis[1],axis[2],axis[3]=math.cos(h),0,-math.sin(h);rotateAxis(axis,elevation-a.p,hinge,pitch)
  for _,i in ipairs(pitched)do pose.row(pose.multiply(pitch,pose.matrix(rows[i],work),rot),rows[i])end
 end
 direction(pose.matrix(rows[m.parent],pm),m.forward,forward)
 return point(pm,m.point,tip),pivot,math.atan2(forward[1],forward[3]),math.atan2(forward[2],math.sqrt(forward[1]^2+forward[3]^2))
end
local function loop()
 local lastRows,modeBefore,transition,blendFrom
 local rowsBuffer,fireBuffer,blendBuffer={},{},{}
 while not dead do
  local frame=Spring.GetGameFrame();local dt=math.max(1,frame-last)/Game.gameSpeed;last=frame
  local vx,_,vz=Spring.GetUnitVelocity(unitID);local speed=math.sqrt((vx or 0)^2+(vz or 0)^2)*Game.gameSpeed;local walk=moving and speed>.05 and d.clips.walk and not d.staticWheels
  if walk then distance=distance+speed*dt end
  local mode=walk and'walk'or'idle';local sampleTime=frame/Game.gameSpeed
  if walk then
   local phase=(distance/math.max(.1,d.stride))%1;local lut=d.walkDistancePhase
   if lut then local pos=phase*(#lut-1);local k=1+math.floor(pos);phase=lut[k]+(lut[k+1]-lut[k])*(pos-math.floor(pos))end
   sampleTime=phase*d.clips.walk.duration
  end
  local rows=sample(d.clips[mode],sampleTime,true,rowsBuffer)
  for n,m in ipairs(d.mounts)do
   local c=d.clips[m.fire or'fire'];local age=shot[n]and(frame-shot[n])/Game.gameSpeed
   if c and age and age<c.duration then
    local firing=sample(c,age,false,fireBuffer)
    if pose and m.members then rows=pose.mergeUpper(rows,firing,m.fireMembers or m.members,rows)
    else
     for _,name in ipairs(c.active_bones or EMPTY)do local i=index[name];local low=name:lower();if i and(not walk or not(low:find('leg')or low:find('foot')or low:find('calf')or low:find('thigh')or low:find('pelvis')or low=='bip01'))then local o,r=rows[i],firing[i];for k=1,6 do o[k]=r[k]end end end
    end
   end
  end
  if modeBefore~=mode then modeBefore,transition=mode,frame;if lastRows then blendFrom=copyRows(lastRows,blendFrom)end end
  if pose and blendFrom and frame-transition<5 then rows=pose.blend(blendFrom,rows,(frame-transition)/5,blendBuffer)end
  lastRows=copyRows(rows,lastRows)
  -- Indexed source barrel group: one existing pose writer, fixed top firing point.
  for n,m in ipairs(d.mounts)do local s=m.indexedSpin;local state=spin[n]
   if s and state then
    local phase=math.max(0,math.min(1,(frame-state.started)/(s.period*Game.gameSpeed)))
    local angle=state.from+(state.target-state.from)*phase
    pose.matrix(rows[s.parent],pm);point(pm,s.pivot,pivot);direction(pm,s.axis,axis)
    rotateAxis(axis,angle,pivot,rot)
    for _,i in ipairs(s.members)do pose.row(pose.multiply(rot,pose.matrix(rows[i],work),base),rows[i])end
   end
  end
  for n,m in ipairs(d.mounts)do
   local a=aim[m.sharedAim or n]
   if m.sharedAim and pose then pose.matrix(rows[m.parent],pm);point(pm,m.point,tip);point(pose.matrix(rows[m.root],work),m.pivot,pivot);writeMarker(m.muzzlePiece,tip[1],tip[2],tip[3],-a.p,a.h,0,dt);writeMarker(m.aimPiece,pivot[1],pivot[2],pivot[3],0,0,0,dt) end
   if not m.sharedAim then
   local active=frame<a.untilFrame;a.h=approach(a.h,active and a.wantH or (m.restYaw or 0),d.yawRate*dt);a.p=approach(a.p,active and a.wantP or 0,d.pitchRate*dt)
   if pose then
    local h,p
    if m.axisAim then tip,pivot,h,p=flatAim(rows,m,a)
    else
     pose.matrix(rows[m.parent],pm);point(pm,m.point,tip);point(pose.matrix(rows[m.root],work),m.pivot,pivot);wanted[1],wanted[2],wanted[3]=math.sin(a.h)*math.cos(a.p),math.sin(a.p),math.cos(a.h)*math.cos(a.p);rotateBetween(direction(pm,m.forward,forward),wanted,pivot,rot)
     for _,i in ipairs(m.members)do pose.row(pose.multiply(rot,pose.matrix(rows[i],work),base),rows[i])end
     point(rot,tip,temp);tip[1],tip[2],tip[3]=temp[1],temp[2],temp[3];h,p=a.h,a.p
    end
    writeMarker(m.muzzlePiece,tip[1],tip[2],tip[3],-p,h,0,dt);writeMarker(m.aimPiece,pivot[1],pivot[2],pivot[3],0,0,0,dt)
    for _, follower in ipairs(m.aimFollowers or EMPTY) do
     pose.matrix(rows[follower.parent],pm)
     point(pose.matrix(rows[follower.root],work),follower.pivot,pivot)
     wanted[1],wanted[2],wanted[3]=math.sin(a.h)*math.cos(a.p),math.sin(a.p),math.cos(a.h)*math.cos(a.p)
     rotateBetween(direction(pm,follower.forward,forward),wanted,pivot,rot)
     for _,i in ipairs(follower.members) do
      pose.row(pose.multiply(rot,pose.matrix(rows[i],work),base),rows[i])
     end
    end
   else
    local yi,pi=index[m.yaw],index[m.pitch]
    if yi then rows[yi][5]=rows[yi][5]+a.h elseif m.yaw~='unit_aim'then Turn(piece(m.yaw),2,a.h,d.yawRate)elseif m.yaw=='unit_aim'and d.wholeBodyAim then Turn(root,2,a.h,d.yawRate)end
    if pi then rows[pi][4]=rows[pi][4]-a.p elseif m.pitch then Turn(piece(m.pitch),1,-a.p,d.pitchRate)end
   end
   end
  end
  -- Alternate flat muzzle helpers use the same final source pose as the gun.
  -- They are marker transforms, never independent pose controllers.
  if pose then for _,m in ipairs(d.mounts)do for _,e in ipairs(m.extraMuzzles or EMPTY)do
   pose.matrix(rows[e.parent],pm);point(pm,e.point,tip);direction(pm,e.forward or m.forward,forward)
   local h=math.atan2(forward[1],forward[3]);local p=math.atan2(forward[2],math.sqrt(forward[1]^2+forward[3]^2))
   writeMarker(e.piece,tip[1],tip[2],tip[3],-p,h,0,dt)
  end end end
  for i,r in ipairs(rows)do write(bones[i],r,dt)end
  footfall(walk and sampleTime/d.clips.walk.duration or 0,walk)
  Sleep(1000/Game.gameSpeed)
 end
end
function script.Create()
 for n,m in ipairs(d.mounts)do m.muzzlePiece=piece(m.muzzle);m.aimPiece=piece(m.aim or m.yaw or m.muzzle);aim[n]={h=m.restYaw or 0,p=0,wantH=m.restYaw or 0,wantP=0,untilFrame=0,token=0};cursor[n]=m.initialMuzzleCursor or 1;nextCursor[n]=1;if m.indexedSpin then local a=m.indexedSpin.initialAngle or 0;spin[n]={from=a,target=a,started=0}end;for _,e in ipairs(m.extraMuzzles or EMPTY)do e.piece=piece(e.name)end end
 if d.factory then SetUnitValue(COB.YARD_OPEN,1);SetUnitValue(COB.BUGGER_OFF,1)end
 if d.builder or d.factory then Spring.SetUnitNanoPieces(unitID,{piece(d.nano or'unit_aim')});SetUnitValue(COB.INBUILDSTANCE,d.factory and 1 or 0)end
 StartThread(loop)
end
function script.StartMoving()moving=true end
function script.StopMoving()moving=false end
function script.AimFromWeapon(n)local m=d.mounts[n];return m and m.aimPiece or root end
function script.QueryWeapon(n)local m=d.mounts[n];if not m then return root end;return m.muzzles and piece(m.muzzles[cursor[n]])or m.muzzlePiece end
function script.AimWeapon(n,h,p)
 local m=d.mounts[n];if dead or not m then return false end
 if m.sharedAim then local a=aim[m.sharedAim];return not dead and math.abs(delta(a.h,h or 0))<.025 and math.abs(a.p-(p or 0))<.025 end
 local a=aim[n];a.token=a.token+1;local token=a.token;local yaw=m.yawLimit or math.pi;local low,high=m.minPitch or math.rad(-40),m.maxPitch or math.rad(70)
 a.wantH=math.max(m.minYaw or -yaw,math.min(m.maxYaw or yaw,h or 0));a.wantP=math.max(low,math.min(high,p or 0));a.untilFrame=Spring.GetGameFrame()+150
 if math.abs(a.wantH-(h or 0))>.01 or math.abs(a.wantP-(p or 0))>.01 then return false end
 while not dead and token==a.token and(math.abs(delta(a.h,a.wantH))>.025 or math.abs(a.p-a.wantP)>.025)do Sleep(33)end
 return not dead and token==a.token
end
local lastGroupFire={}
function script.BlockShot(n)
 local m=d.mounts[n];if not m or not m.fireGroup then return false end
 local last=lastGroupFire[m.fireGroup]
 return last~=nil and Spring.GetGameFrame()-last<math.ceil(m.fireGroupGap*Game.gameSpeed)
end
function script.FireWeapon(n)
 local m=d.mounts[n];if not m then return end
 local frame=Spring.GetGameFrame()
 if m.fireGroup then lastGroupFire[m.fireGroup]=frame end
 -- FireWeapon starts one native emission; Shot may run every continuous-beam tick.
 if m.cycleOnFire and m.muzzles then cursor[n]=nextCursor[n];nextCursor[n]=cursor[n]%#m.muzzles+1 end
 if m.fireOncePerBurst then shot[n]=frame end
 local state=spin[n]
 if state then state.from=state.target;state.target=state.target+m.indexedSpin.stepAngle;state.started=frame end
end
function script.Shot(n)
 local m=d.mounts[n];if not m then return end
 if not m.fireOncePerBurst then shot[n]=Spring.GetGameFrame()end
 if m.muzzles and not m.cycleOnFire then cursor[n]=cursor[n]%#m.muzzles+1 end
end
function script.StartBuilding(h,p)if d.wholeBodyAim then Turn(root,2,h or 0,d.yawRate);WaitForTurn(root,2)end;SetUnitValue(COB.INBUILDSTANCE,1)end
function script.StopBuilding()if not d.factory then SetUnitValue(COB.INBUILDSTANCE,0)end end
function script.QueryNanoPiece()return piece(d.nano or'unit_aim')end
function script.QueryBuildInfo()return root end
function script.Activate()if d.factory then SetUnitValue(COB.YARD_OPEN,1);SetUnitValue(COB.INBUILDSTANCE,1);SetUnitValue(COB.BUGGER_OFF,1)end;return 1 end
function script.Deactivate()if d.factory then SetUnitValue(COB.YARD_OPEN,0);SetUnitValue(COB.BUGGER_OFF,0)end;return 0 end
function script.BeginTransport() SetUnitValue(COB.BUSY,0) end
function script.QueryTransport() return 0 end
function script.TransportPickup(id) Spring.UnitScript.AttachUnit(0,id);SetUnitValue(COB.BUSY,0) end
function script.TransportDrop(id) Spring.UnitScript.DropUnit(id);SetUnitValue(COB.BUSY,0) end
function script.EndTransport() SetUnitValue(COB.BUSY,0) end
function script.Killed()dead=true;return 1 end
end
