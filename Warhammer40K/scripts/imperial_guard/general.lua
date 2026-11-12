-- Source-authored General poses. Native Cortex commander owns all gameplay.
local data=include('bar40k/animation_data.lua')('imperial_guard/general_animation.lua')
local source=include('bar40k/source_local_pose.lua')(include(data.hierarchy))
local bones={};for i,name in ipairs(data.bones)do bones[i]=piece(name)end
local root,muzzle,nano=piece('unit_aim','general_muzzle','general_nano')
local moving,building,dead=false,false,false
local aimUntil,shot,walkTime=0,-100000,0
local previous={};local lastFrame=Spring.GetGameFrame()
local function delta(a,b)return(b-a+math.pi)%(2*math.pi)-math.pi end
local function point(m,p)return{m[1]*p[1]+m[2]*p[2]+m[3]*p[3]+m[4],m[5]*p[1]+m[6]*p[2]+m[7]*p[3]+m[8],m[9]*p[1]+m[10]*p[2]+m[11]*p[3]+m[12]}end
local function direction(m,p)return{m[1]*p[1]+m[2]*p[2]+m[3]*p[3],m[5]*p[1]+m[6]*p[2]+m[7]*p[3],m[9]*p[1]+m[10]*p[2]+m[11]*p[3]}end
local function write(handle,row,dt)
 local old=previous[handle];local saved={}
 for a=1,3 do
  local p=row[a];local r=old and old[a+3]+delta(old[a+3],row[a+3])or row[a+3]
  if not old or math.abs(p-old[a])>1e-5 then Move(handle,a,p,old and math.abs(p-old[a])/dt or nil)end
  if not old or math.abs(r-old[a+3])>1e-5 then Turn(handle,a,r,old and math.abs(r-old[a+3])/dt or nil)end
  saved[a],saved[a+3]=p,r
 end
 previous[handle]=saved
end
local function animate()
 local prior,transition,from
 while not dead do
  local f=Spring.GetGameFrame();local dt=math.max(1,f-lastFrame)/Game.gameSpeed;lastFrame=f
  local vx,_,vz=Spring.GetUnitVelocity(unitID);local speed=math.sqrt((vx or 0)^2+(vz or 0)^2)*Game.gameSpeed
  local mode=building and'build'or(moving and speed>.05 and'walk'or(f<aimUntil and'fire'or'idle'))
  if mode=='walk'then walkTime=walkTime+speed*dt/math.max(.01,data.stride)*data.clips.walk.duration end
  local time=mode=='walk'and walkTime or f/Game.gameSpeed
  if mode=='fire'then time=f>=shot and math.min((f-shot)/Game.gameSpeed,data.clips.fire.duration)or 0 end
  local rows=source.sample(data.clips[mode],time,mode~='fire')
  if prior~=mode then prior,transition,from=mode,f,from or rows end
  if from and(f-transition)/Game.gameSpeed<.15 then rows=source.blend(from,rows,(f-transition)/Game.gameSpeed/.15)end
  for i,row in ipairs(rows)do write(bones[i],row,dt)end
  for name,handle in pairs({muzzle=muzzle,nano=nano})do
   local cfg=data.markers[name];local m=source.matrix(rows[cfg.parent]);local p=point(m,cfg.point);local d=direction(m,cfg.forward)
   local h=math.atan2(d[1],d[3]);local elevation=math.atan2(d[2],math.sqrt(d[1]^2+d[3]^2));write(handle,{p[1],p[2],p[3],-elevation,h,0},dt)
  end
  from=rows
  if not building and f>=aimUntil then Turn(root,2,0,math.rad(150))end
  Sleep(1000/Game.gameSpeed)
 end
end
function script.Create()
 Spring.SetUnitNanoPieces(unitID,{nano});SetUnitValue(COB.INBUILDSTANCE,0);StartThread(animate)
end
function script.StartMoving()moving=true end
function script.StopMoving()moving=false end
function script.StartBuilding(heading,pitch)
 building=true;Turn(root,2,heading or 0,math.rad(150));WaitForTurn(root,2);SetUnitValue(COB.INBUILDSTANCE,1)
end
function script.StopBuilding()building=false;SetUnitValue(COB.INBUILDSTANCE,0)end
function script.QueryNanoPiece()return nano end
function script.QueryBuildInfo()return root end
function script.AimFromWeapon()return muzzle end
function script.QueryWeapon()return muzzle end
function script.AimWeapon(n,heading,pitch)
 if dead or building then return false end
 aimUntil=Spring.GetGameFrame()+Game.gameSpeed*5
 Turn(root,2,heading or 0,math.rad(150));WaitForTurn(root,2)
 return not dead and not building
end
function script.FireWeapon()end
function script.Shot()shot=Spring.GetGameFrame()end
function script.Activate()return 1 end
function script.Deactivate()return 0 end
function script.Killed()dead=true;return 1 end
