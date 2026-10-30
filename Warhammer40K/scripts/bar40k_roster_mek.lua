-- Scoped to the Gladius Mek: one pose writer, native builder/EMP semantics.
local data=include('bar40k/animation_data.lua')('bar40k/roster_mek_animation.lua')
local bones={};for i,n in ipairs(data.bones)do bones[i]=piece(n)end
local muzzle,nano=piece('mek_muzzle'),piece('mek_nano')
local dt=1/Game.gameSpeed
local moving,building,dead=false,false,false
local mode,phase,lastFrame='idle',0,Spring.GetGameFrame()
local aimingUntil,readyFrame,aligned=0,0,false
local pose,previous,transition={}, {}, nil
local blendStart=0
local function delta(a,b)return(b-a+math.pi)%(2*math.pi)-math.pi end
local function interpolate(a,b,t,k)return k<=3 and a+(b-a)*t or a+delta(a,b)*t end
local function sample(clip,time,i)
 local f=(time%clip.duration)/clip.duration*(#clip.frames-1)
 local a=math.floor(f)+1;local t=f-math.floor(f);local row={}
 for k=1,6 do row[k]=interpolate(clip.frames[a][i][k],clip.frames[math.min(a+1,#clip.frames)][i][k],t,k)end
 return row
end
local function apply(rows,instant)
 for i,bone in ipairs(bones)do
  local row,old=rows[i],previous[i]or{}
  for axis=1,3 do
   if instant or old[axis]==nil or math.abs(row[axis]-old[axis])>1e-5 then Move(bone,axis,row[axis],not instant and old[axis]and math.abs(row[axis]-old[axis])/dt or nil)end
   local k=axis+3;local value=old[k]and old[k]+delta(old[k],row[k])or row[k]
   if instant or old[k]==nil or math.abs(value-old[k])>1e-5 then Turn(bone,axis,value,not instant and old[k]and math.abs(value-old[k])/dt or nil)end
   old[axis],old[k]=row[axis],value
  end
  previous[i]=old
 end
end
local function animate()
 while not dead do
  local f=Spring.GetGameFrame();local elapsed=math.max(0,f-lastFrame)*dt;lastFrame=f
  local chosen=building and 'build' or (f<aimingUntil and not moving)and'ready' or moving and'walk'or'idle'
  if chosen~=mode then
   transition={};for i,row in ipairs(pose)do transition[i]={unpack(row)}end
   blendStart=f;mode,phase=chosen,0
  end
  local speed=1
  if chosen=='walk'then local _,_,_,v=Spring.GetUnitVelocity(unitID);speed=math.max(0,(v or 0)*Game.gameSpeed/data.walkspeed)end
  local clip=data.clips[chosen];phase=(phase+elapsed*speed)%clip.duration
  local blend=math.min(1,(f-blendStart)/6);blend=blend*blend*(3-2*blend)
  for i in ipairs(bones)do
   local row=sample(clip,phase,i)
   if transition and transition[i]then for k=1,6 do row[k]=interpolate(transition[i][k],row[k],blend,k)end end
   pose[i]=row
  end
  if blend>=1 then transition=nil end
  apply(pose,false);Sleep(33)
 end
end
function script.Create()
 for i in ipairs(bones)do pose[i]={unpack(data.clips.idle.frames[1][i])}end
 apply(pose,true);Spring.SetUnitNanoPieces(unitID,{nano});StartThread(animate)
end
function script.StartMoving()moving=true;aligned=false end
function script.StopMoving()moving=false end
function script.StartBuilding()building=true;aligned=false;SetUnitValue(COB.INBUILDSTANCE,1)end
function script.StopBuilding()building=false;SetUnitValue(COB.INBUILDSTANCE,0)end
function script.QueryNanoPiece()return nano end
function script.QueryBuildInfo()return nano end
function script.AimFromWeapon()return muzzle end
function script.QueryWeapon()return muzzle end
function script.AimWeapon(n,heading,pitch)
 local f=Spring.GetGameFrame()
 aligned=not building and not moving and math.abs(heading or 0)<=math.rad(10)and math.abs(pitch or 0)<=math.rad(20)
 if not aligned then return false end
 if f>=aimingUntil then readyFrame=f+6 end
 aimingUntil=f+60
 return f>=readyFrame
end
function script.BlockShot()return dead or building or moving or not aligned or Spring.GetGameFrame()<readyFrame end
function script.FireWeapon()aimingUntil=Spring.GetGameFrame()+60 end
function script.Shot()EmitSfx(muzzle,1024)end
function script.Activate()return 1 end
function script.Deactivate()return 0 end
function script.Killed()
 dead=true;local clip=data.clips.die
 for i,rows in ipairs(clip.frames)do apply(rows,true);Sleep(math.max(1,math.floor(1000/clip.fps+.5)))end
 return 1
end
