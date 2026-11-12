-- Original banked source idle/flight/bomb-bay animation, one pose writer.
-- Native Lich flight, target selection, bomb physics and damage are unchanged.
local data=include('bar40k/animation_data.lua')('bar40k/ork_nuke_bomba_anim.lua')
local bones={};for i,name in ipairs(data.bones)do bones[i]=piece(name)end
local muzzle=piece('fb_fx_bomb_bay');local moving=false;local dead=false
local shot=-100000;local previous={};local priorFrame=Spring.GetGameFrame()
local function angle(a,b,t)return a+((b-a+math.pi)%(2*math.pi)-math.pi)*t end
local function sample(c,time,loop)
 local f=(loop and time%c.duration or math.min(time,c.duration))*c.fps
 local a=math.min(#c.frames,math.floor(f)+1);local b=math.min(#c.frames,a+1);local t=f-math.floor(f);local out={}
 for i,x in ipairs(c.frames[a])do local y=c.frames[b][i];local r={};for k=1,6 do r[k]=k<=3 and x[k]+(y[k]-x[k])*t or angle(x[k],y[k],t)end;out[i]=r end
 return out
end
local function animate()
 while not dead do
  local f=Spring.GetGameFrame();local dt=math.max(1,f-priorFrame)/Game.gameSpeed;priorFrame=f
  local rows=sample(moving and data.clips.move_1 or data.clips.idle,f/Game.gameSpeed,true)
  local age=(f-shot)/Game.gameSpeed
  if age>=0 and age<data.clips.bomb_fire.duration then rows=sample(data.clips.bomb_fire,age,false)end
  for i,row in ipairs(rows)do
   local old=previous[i];local store={}
   for a=1,3 do
    local position=row[a];local rotation=old and angle(old[a+3],row[a+3],1)or row[a+3]
    if not old or math.abs(position-old[a])>1e-5 then Move(bones[i],a,position,old and math.abs(position-old[a])/dt or nil)end
    if not old or math.abs(rotation-old[a+3])>1e-5 then Turn(bones[i],a,rotation,old and math.abs(rotation-old[a+3])/dt or nil)end
    store[a],store[a+3]=position,rotation
   end
   previous[i]=store
  end
  Sleep(1000/Game.gameSpeed)
 end
end
function script.Create()StartThread(animate)end
function script.StartMoving()moving=true end
function script.StopMoving()moving=false end
function script.AimFromWeapon()return muzzle end
function script.QueryWeapon()return muzzle end
function script.AimWeapon()return true end
function script.FireWeapon()end
function script.Shot()shot=Spring.GetGameFrame()end
function script.Killed()dead=true;return 0 end
