-- One ordinary native unit, one pose writer. Native BAR owns commands, damage,
-- movement and ballistics. The extra crew are parts of this single model.
local data=include('bar40k/animation_data.lua')('bar40k/gladius_mek_gun_crew_animation.lua')
local cp=UnitDefs[unitDefID].customParams
local mainSlot=tonumber(cp.mek_gun_weapon_slot)or 1
local bones={};for i,name in ipairs(data.bones)do bones[i]=piece(name)end
local muzzle=piece(data.muzzle);local fps=Game.gameSpeed
local moving,dead=false,false;local last=Spring.GetGameFrame();local oldX,oldZ
local travel,shotFrame,crewFireStart,crewFireUntil=0,-10000,-10000,-10000
local wantedYaw,wantedPitch,aimUntil=0,0,-1
local gunYaw,gunPitch;local previous,basePrevious;local lastModes,transitions,transitionAt={},{},{}
local function angle(v)return(v+math.pi)%(2*math.pi)-math.pi end
local function mix(a,b,t)return a+angle(b-a)*t end
local function approach(a,b,step)return a+math.max(-step,math.min(step,angle(b-a)))end
local function rotation(r)
 local x,y,z=r[4],r[5],r[6];local cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
 return{cy*cz+sy*sx*sz,-cy*sz+sy*sx*cz,sy*cx,cx*sz,cx*cz,-sx,-sy*cz+cy*sx*sz,sy*sz+cy*sx*cz,cy*cx}
end
local function point(r,p)return{r[1]*p[1]+r[2]*p[2]+r[3]*p[3],r[4]*p[1]+r[5]*p[2]+r[6]*p[3],r[7]*p[1]+r[8]*p[2]+r[9]*p[3]}end
local function mul(a,b)local c={};for r=0,2 do for j=1,3 do c[r*3+j]=a[r*3+1]*b[j]+a[r*3+2]*b[3+j]+a[r*3+3]*b[6+j]end end;return c end
local function transpose(r)return{r[1],r[4],r[7],r[2],r[5],r[8],r[3],r[6],r[9]}end
local function euler(r)
 local x=math.asin(math.max(-1,math.min(1,-r[6])))
 if math.abs(math.cos(x))<1e-6 then return x,math.atan2(-r[7],r[1]),0 end
 return x,math.atan2(r[3],r[9]),math.atan2(r[4],r[5])
end
local function sample(clip,time,loop)
 time=loop and time%clip.duration or math.max(0,math.min(time,clip.duration))
 local phase=math.min(#clip.frames-1,time*clip.fps);local a=math.floor(phase)+1;local b=math.min(a+1,#clip.frames);local t=phase-math.floor(phase);local out={}
 for i,r in ipairs(clip.frames[a])do local q=clip.frames[b][i];local row={};for k=1,6 do row[k]=k<=3 and r[k]+(q[k]-r[k])*t or mix(r[k],q[k],t)end;out[i]=row end
 return out
end
local function blend(a,b,t)
 if not a or t>=1 then return b end;t=t*t*(3-2*t);local out={}
 for i,r in ipairs(b)do local q=a[i]or r;local row={};for k=1,6 do row[k]=k<=3 and q[k]+(r[k]-q[k])*t or mix(q[k],r[k],t)end;out[i]=row end
 return out
end
local function gunShot(age)
 local clip=data.gunClips.fire;local cue=data.sourceShotCue
 if age<=.65 then return sample(clip,cue+age,false)end
 return blend(sample(clip,cue+.65,false),sample(clip,cue,false),math.min(1,(age-.65)/.35))
end
local function aim(row,seconds,frame)
 local cfg=data.aim;local mr=row[cfg.muzzleRow];local current=rotation(mr);local originalYaw=math.atan2(current[3],current[9]);local originalPitch=math.asin(math.max(-1,math.min(1,current[6])))
 local h,p=originalYaw,originalPitch;if frame<aimUntil then h,p=wantedYaw,wantedPitch end
 gunYaw=approach(gunYaw or originalYaw,h,math.rad(cfg.yawRate)*seconds);gunPitch=approach(gunPitch or originalPitch,p,math.rad(cfg.pitchRate)*seconds)
 local transform=mul(rotation({0,0,0,-gunPitch,gunYaw,mr[6]}),transpose(current));local body=row[cfg.pivotRow];local pivot=point(rotation(body),cfg.pivot);for k=1,3 do pivot[k]=pivot[k]+body[k]end
 for _,i in ipairs(cfg.indices)do local r=row[i];local q=point(transform,{r[1]-pivot[1],r[2]-pivot[2],r[3]-pivot[3]});local x,y,z=euler(mul(transform,rotation(r)));row[i]={q[1]+pivot[1],q[2]+pivot[2],q[3]+pivot[3],x,y,z}end
 return row
end
local function write(row,seconds)
 for i,bone in ipairs(bones)do local r=row[i];local old=previous and previous[i]
  for axis=1,3 do
   if not old or math.abs(r[axis]-old[axis])>1e-6 then Move(bone,axis,r[axis])end
   local value=old and old[axis+3]+angle(r[axis+3]-old[axis+3])or r[axis+3]
   if not old or math.abs(value-old[axis+3])>1e-6 then Turn(bone,axis,value)end;r[axis+3]=value
  end
 end
 previous=row
end
local function animate()
 while not dead do
  local frame=Spring.GetGameFrame();local seconds=math.max(1,frame-last)/fps;last=frame
  local x,_,z=Spring.GetUnitPosition(unitID);local distance=oldX and math.sqrt((x-oldX)^2+(z-oldZ)^2)or 0;oldX,oldZ=x,z
  if distance<8 then travel=travel+distance end
  local walking=moving or distance>.01;local age=(frame-shotFrame)/fps;local firing=age>=0 and age<data.shotDuration
  local gm=firing and'fire'or walking and'walk'or'idle';local gun=firing and gunShot(age)or walking and sample(data.gunClips.walk,travel/data.gunStride*data.gunClips.walk.duration,true)or sample(data.gunClips.idle,frame/fps,true)
  local crewTime=(frame-crewFireStart)/fps;local busy=frame<crewFireUntil
  local pm=busy and'fire'or'idle';local platform=sample(data.crewClips[pm],busy and crewTime or frame/fps+.27,true)
  local fm=walking and'walk'or busy and'fire'or'idle';local following=sample(data.crewClips[fm],walking and travel/data.groundStride*data.crewClips.walk.duration or busy and crewTime+.13 or frame/fps+.91,true)
  local tracks={gun,platform,following};local modes={gm,pm,fm};local row={};local offset=0
  for t,pose in ipairs(tracks)do
   if lastModes[t]~=modes[t]then transitions[t]=basePrevious and basePrevious[t];transitionAt[t]=frame;lastModes[t]=modes[t]end
   pose=blend(transitions[t],pose,(frame-(transitionAt[t]or frame))/6);basePrevious=basePrevious or{};basePrevious[t]=pose
   for _,r in ipairs(pose)do offset=offset+1;row[offset]=r end
  end
  write(aim(row,seconds,frame),seconds);Sleep(1000/fps)
 end
end
local function boreReady()
 local _,_,_,x,y,z=Spring.GetUnitPiecePosDir(unitID,muzzle);local _,_,_,a,b,c=Spring.GetUnitWeaponVectors(unitID,mainSlot)
 if not(x and y and z and a and b and c)then return false end
 local aa=x*x+y*y+z*z;local bb=a*a+b*b+c*c
 if bb<=1e-12 then return false end
 local front,up,right=Spring.GetUnitVectors(unitID)
 local h=math.atan2(a*right[1]+b*right[2]+c*right[3],a*front[1]+b*front[2]+c*front[3]);local p=math.asin(math.max(-1,math.min(1,(a*up[1]+b*up[2]+c*up[3])/math.sqrt(bb))))
 if math.abs(h)>math.rad(data.aim.maxYaw)or p<math.rad(data.aim.minPitch)or p>math.rad(data.aim.maxPitch)then return false end
 return aa>1e-12 and bb>1e-12 and(x*a+y*b+z*c)/math.sqrt(aa*bb)>=math.cos(math.rad(data.aim.boreDegrees))
end
function script.Create()
 local row={};for _,r in ipairs(data.gunClips.idle.frames[1])do row[#row+1]={unpack(r)}end
 for i=1,2 do for _,r in ipairs(data.crewClips.idle.frames[1])do row[#row+1]={unpack(r)}end end
 write(row,1/fps);local x,_,z=Spring.GetUnitPosition(unitID);oldX,oldZ=x,z;StartThread(animate)
end
function script.StartMoving()moving=true end
function script.StopMoving()moving=false end
function script.AimFromWeapon()return muzzle end
function script.QueryWeapon()return muzzle end
function script.AimWeapon(n,h,p)
 if n~=mainSlot then return false end
 h,p=h or 0,p or 0
 if h~=h or p~=p or math.abs(h)>math.rad(data.aim.maxYaw)or p<math.rad(data.aim.minPitch)or p>math.rad(data.aim.maxPitch)then return false end
 wantedYaw,wantedPitch,aimUntil=h,p,Spring.GetGameFrame()+90
 return boreReady()
end
function script.BlockShot(n)return n~=mainSlot or Spring.GetGameFrame()>=aimUntil or not boreReady()end
function script.FireWeapon()end
function script.Shot(n)
 if n~=mainSlot then return end
 local f=Spring.GetGameFrame();shotFrame=f
 if f>=crewFireUntil then crewFireStart=f end
 crewFireUntil=f+data.crewClips.fire.duration*fps
 EmitSfx(muzzle,1024)
end
function script.Activate()return 1 end
function script.Deactivate()return 0 end
function script.Killed()dead=true;return 1 end

local nativeFacing=include('bar40k/native_ground_facing.lua')(3,1)
local createBeforeFacing=script.Create
function script.Create()createBeforeFacing();StartThread(nativeFacing.Run)end
