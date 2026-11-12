-- One AA Kan, one native mover and one pose writer. Proper Codex body/legs,
-- native independent weapon targeting, four queried Gunship Big Shoota muzzles.
local data=include('bar40k/animation_data.lua')('bar40k/ork_aa_kan_animation.lua')
local meta=include('bar40k/animation_data.lua')(data.sourceHierarchy)
local source=include('bar40k/source_local_pose.lua')(meta)
local bones,arms,muzzles={},{},{}
for i,name in ipairs(data.bones)do bones[i]=piece(name)end
for i,name in ipairs(data.armBones)do arms[i]=piece(name)end
for i,name in ipairs(data.muzzles)do muzzles[i]=piece(name)end
local aim=piece('aakan_aim')
local moving,dead=false,false
local created=Spring.GetGameFrame();local lastFrame=created;local oldX,oldZ
local travel=0;local mode='idle';local transition,transitionStart,lastSource
local aimUntil,targetHeading,targetPitch=0,0,0
local torsoYaw=0;local armYaw={0,0};local armPitch={0,0}
local cursor=1;local queried;local recoil={-1000,-1000};local previous={}
local fps=Game.gameSpeed;local tau=2*math.pi
local torsoRate,armYawRate,armPitchRate=math.rad(156),math.rad(208),math.rad(130)
local waist={meta.bind[29][4]+data.referenceOrigin[1],meta.bind[29][8]+data.referenceOrigin[2],meta.bind[29][12]+data.referenceOrigin[3]}
local function delta(a,b)return(b-a+math.pi)%tau-math.pi end
local function approach(a,b,step)return a+math.max(-step,math.min(step,b-a))end
local function point(m,p)return{m[1]*p[1]+m[2]*p[2]+m[3]*p[3]+m[4],m[5]*p[1]+m[6]*p[2]+m[7]*p[3]+m[8],m[9]*p[1]+m[10]*p[2]+m[11]*p[3]+m[12]}end
local function identity()return{1,0,0,0,0,1,0,0,0,0,1,0}end
local function rotateAbout(p,x,y,z)
 local m=source.matrix({0,0,0,x,y,z});local q=point(m,p)
 m[4],m[8],m[12]=p[1]-q[1],p[2]-q[2],p[3]-q[3]
 return m
end
local function write(handle,row,dt)
 local old=previous[handle]
 if old then
  local a={row[4],row[5],row[6]};local b={math.pi-row[4],row[5]+math.pi,row[6]+math.pi};local ca,cb=0,0
  for k=1,3 do a[k]=old[k+3]+delta(old[k+3],a[k]);b[k]=old[k+3]+delta(old[k+3],b[k]);ca=ca+(a[k]-old[k+3])^2;cb=cb+(b[k]-old[k+3])^2 end
  local r=ca<=cb and a or b;for k=1,3 do row[k+3]=r[k]end
 end
 local stored=old or{}
 for axis=1,3 do
  if not old or math.abs(row[axis]-old[axis])>.0001 then Move(handle,axis,row[axis],old and math.abs(row[axis]-old[axis])/dt or nil);stored[axis]=row[axis]end
  if not old or math.abs(row[axis+3]-old[axis+3])>.0001 then Turn(handle,axis,row[axis+3],old and math.abs(row[axis+3]-old[axis+3])/dt or nil);stored[axis+3]=row[axis+3]end
 end
 previous[handle]=stored
end
local function nativeDirection()
 local _,_,_,x,y,z=Spring.GetUnitWeaponVectors(unitID,1)
 if not x then return math.sin(targetHeading)*math.cos(targetPitch),math.sin(targetPitch),math.cos(targetHeading)*math.cos(targetPitch)end
 local length=math.sqrt(x*x+y*y+z*z);if length<1e-9 then return 0,0,1 end
 x,y,z=x/length,y/length,z/length
 local front,up,right
 if Spring.GetUnitVectors then front,up,right=Spring.GetUnitVectors(unitID)end
 if front then return-(x*right[1]+y*right[2]+z*right[3]),x*up[1]+y*up[2]+z*up[3],x*front[1]+y*front[2]+z*front[3]end
 local heading=Spring.GetUnitHeading(unitID)*math.pi/32768;local c,s=math.cos(heading),math.sin(heading)
 return c*x-s*z,y,s*x+c*z
end
local function pose(frame,dt)
 local px,_,pz=Spring.GetUnitPosition(unitID)
 local distance=oldX and math.sqrt((px-oldX)^2+(pz-oldZ)^2)or 0;oldX,oldZ=px,pz
 if moving and distance<8 then travel=travel+distance end
 local chosen=dead and 'die' or moving and 'walk' or 'idle'
 if chosen~=mode then transition=lastSource;transitionStart=frame;mode=chosen end
 local clip=data.clips[chosen];local t=dead and(frame-created)/fps or moving and travel/data.stride*clip.duration or(frame-created)/fps
 local row=source.sample(clip,t,not dead)
 if transition then local blend=math.min(1,(frame-transitionStart)/12);row=source.blend(transition,row,blend);if blend==1 then transition=nil end end
 lastSource=row
 local body=source.matrix(row[29]);local p=point(body,waist)
 local dx,dy,dz=0,0,1;local active=not dead and frame<aimUntil
 if active then dx,dy,dz=nativeDirection()end
 local wanted=0
 if active and dx*dx+dz*dz>1e-8 then wanted=delta(math.atan2(body[3],body[11]),math.atan2(dx,dz))end
 torsoYaw=torsoYaw+math.max(-dt*torsoRate,math.min(dt*torsoRate,delta(torsoYaw,wanted)))
 local yaw=rotateAbout(p,0,torsoYaw,0);local aimed={}
 for i,r in ipairs(row)do aimed[i]=i>=29 and source.row(source.multiply(yaw,source.matrix(r)))or r end
 for i,handle in ipairs(bones)do write(handle,{unpack(aimed[i])},dt)end
 body=source.matrix(aimed[29])
 for side,handle in ipairs(arms)do
  -- Directions, unlike positions, multiply by the transpose rotation.
  local lx=body[1]*dx+body[5]*dy+body[9]*dz
  local ly=body[2]*dx+body[6]*dy+body[10]*dz
  local lz=body[3]*dx+body[7]*dy+body[11]*dz
  local h=active and math.atan2(lx,lz)or 0;local pitch=active and math.asin(math.max(-1,math.min(1,ly)))or math.rad(45)
  pitch=math.max(math.rad(-20),math.min(math.rad(89.5),pitch))
  -- The torso performs normal horizontal tracking. The side weapons may
  -- overlap inward at steep elevation, clearing the head and upper hull.
  local inward=side==1 and h<0 or side==2 and h>0
  local limit=inward and pitch<math.rad(70)and math.rad(20)or math.pi
  h=math.max(-limit,math.min(limit,h))
  armYaw[side]=armYaw[side]+math.max(-dt*armYawRate,math.min(dt*armYawRate,delta(armYaw[side],h)))
  armPitch[side]=approach(armPitch[side],pitch,dt*armPitchRate)
  local pivot=data.armPivots[side];local inner=rotateAbout(pivot,-armPitch[side],armYaw[side],0);local m=source.multiply(body,inner)
  local age=(frame-recoil[side])/fps;local kick=age>=0 and age<.1 and .12*(1-age/.1)or 0
  m[4],m[8],m[12]=m[4]-m[3]*kick,m[8]-m[7]*kick,m[12]-m[11]*kick
  write(handle,source.row(m),dt)
  for b=1,2 do local index=(side-1)*2+b;local q=point(m,data.muzzlePoints[index]);local r=source.row(m);r[1],r[2],r[3]=q[1],q[2],q[3];write(muzzles[index],r,dt)end
 end
 local q=point(body,{data.referenceOrigin[1],data.armPivots[1][2],data.referenceOrigin[3]});write(aim,{q[1],q[2],q[3],0,0,0},dt)
end
local function animate()
 while true do local f=Spring.GetGameFrame();local dt=math.max(1,f-lastFrame)/fps;lastFrame=f;pose(f,dt);Sleep(1000/fps)end
end
local function aligned()
 local muzzle=muzzles[cursor];local _,_,_,x,y,z=Spring.GetUnitPiecePosDir(unitID,muzzle);local _,_,_,tx,ty,tz=Spring.GetUnitWeaponVectors(unitID,1)
 if not(x and tx)then return false end
 local a=x*x+y*y+z*z;local b=tx*tx+ty*ty+tz*tz
 return a>1e-12 and b>1e-12 and(x*tx+y*ty+z*tz)/math.sqrt(a*b)>math.cos(math.rad(4))
end
function script.Create()StartThread(animate)end
function script.StartMoving()moving=true end
function script.StopMoving()moving=false end
function script.AimFromWeapon(n)return aim end
function script.QueryWeapon(n)queried=queried or cursor;return muzzles[queried]end
function script.AimWeapon(n,h,p)
 if n~=1 or dead then return false end
 targetHeading,targetPitch=h or 0,p or 0;aimUntil=Spring.GetGameFrame()+90
 local deadline=Spring.GetGameFrame()+90
 while not aligned()do if dead or Spring.GetGameFrame()>=deadline then return false end;Sleep(1000/fps)end
 return true
end
function script.BlockShot(n)
 if dead or n~=1 then return true end
 local kind,_,target=Spring.GetUnitWeaponTarget(unitID,1)
 if kind~=1 or not target or not Spring.ValidUnitID(target)or Spring.GetUnitIsDead(target)then return true end
 local definition=UnitDefs[Spring.GetUnitDefID(target)]
 return not(definition and definition.canFly)or not aligned()
end
function script.FireWeapon(n)end
function script.Shot(n)
 if n~=1 then return end
 -- Native per-projectile order is Shot -> QueryWeapon -> projectile creation.
 -- Select the next barrel here, then keep that selection through every query.
 local which=cursor;queried=which;recoil[which<=2 and 1 or 2]=Spring.GetGameFrame()
 EmitSfx(muzzles[which],1024);cursor=which%4+1
end
function script.Activate()return 1 end
function script.Deactivate()return 0 end
function script.Killed(recent,max)
 dead=true;created=Spring.GetGameFrame();transition=lastSource;transitionStart=created;mode='die'
 Sleep(data.clips.die.duration*1000)
 return recent/max>.5 and 2 or 1
end
