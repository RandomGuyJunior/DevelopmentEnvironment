function widget:GetInfo()return{name='40K opt-in runtime image/audio review',desc='Actual native image captures and explicit low-volume codec inputs',author='Local project',layer=1005,enabled=true}end
local opts=Spring.GetModOptions()or{}
if opts.prototype_diagnostic~='six'or tostring(opts.prototype_runtime_library_review)~='1'then return end
local plans={[600]='imp_guardsman',[1000]='imp_marine',[1400]='imp_russ',[1800]='ork_boy'}
local original,pending
local elapsed,renderSerial=0,0
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function log(...)Spring.Echo('40K RUNTIME LIBRARY REVIEW',...)end
function widget:Initialize()original=Spring.GetCameraState();log('START','image_and_audio_unaccepted')end
function widget:Shutdown()if original then Spring.SetCameraState(original,0)end end
function widget:GameFrame(f)
 local name=plans[f]
 if name then
  local found=false
  for _,id in ipairs(Spring.GetTeamUnits(Spring.GetMyTeamID()))do
   local d=UnitDefs[Spring.GetUnitDefID(id)]
   if d and d.name==name and Spring.GetUnitRulesParam(id,'40k_diagnostic_slot')then
    found=true
    local x,y,z=Spring.GetUnitPosition(id)
    if not(finite(x)and finite(y)and finite(z))then log('NATIVE_SCREENSHOT_REFUSED',name,id,f,'actor_position_unreadable');break end
    local radius=Spring.GetUnitRadius(id);if not finite(radius)or radius<=0 then radius=40 end
    local dist=math.max(110,radius*2.6)
    local camera={name='free',mode=4,px=x+dist*.78,py=y+dist*.88,pz=z+dist,rx=-.612,ry=-2.48,rz=0,vx=0,vy=0,vz=0,avx=0,avy=0,avz=0}
    if pending then log('NATIVE_SCREENSHOT_REFUSED',pending.name,pending.id,'superseded_plan')end
    Spring.SetCameraState(camera,0)
    Spring.SelectUnitArray({id});pending={frame=f,name=name,id=id,camera=camera,start=elapsed,stableRenders=0};log('NATIVE_IMAGE_PLAN',name,id,f);break
   end
  end
  if not found then log('NATIVE_SCREENSHOT_REFUSED',name,-1,f,'requested_diagnostic_actor_missing')end
 end
 if tostring(opts.prototype_runtime_library_audio)=='1'and f>=600 and f<=2400 and f%180==0 then
  local i=math.floor((f-600)/180)%3+1;local file='sounds/40k_runtime_review/'..i..'.ogg'
  local isolated=true
  for _,key in ipairs({'snd_volbattle','snd_volgeneral','snd_volunitreply','snd_volmusic'})do
   local value=Spring.GetConfigInt(key,-1);log('NATIVE_AUDIO_CHANNEL',f,key,value);if value~=0 then isolated=false end
  end
  local master=Spring.GetConfigInt('snd_volmaster',-1);log('NATIVE_AUDIO_CHANNEL',f,'snd_volmaster',master)
  if master<=0 or master>5 then isolated=false end
  if not isolated then log('ISOLATION_REFUSED',f,file)
  elseif VFS.FileExists(file)then log('NATIVE_OGG_REQUEST_ONLY',f,file,tostring(Spring.PlaySoundFile(file,.8,'ui')))
  else log('MISSING_PRIVATE_AUDIO',f,file)end
 end
end

-- Observe presentation on real rendered frames, not the next simulation frame.
local function evidence(p)
 local d=UnitDefs[Spring.GetUnitDefID(p.id)]
 if not d or d.name~=p.name or not Spring.GetUnitRulesParam(p.id,'40k_diagnostic_slot')then return nil,'requested_actor_changed'end
 for _,api in ipairs({'GetSelectedUnits','IsUnitInView','GetCameraState','GetCameraPosition','WorldToScreenCoords','GetViewGeometry'})do
  if type(Spring[api])~='function'then return nil,'readback_api_missing_'..api end
 end
 local selected=Spring.GetSelectedUnits()
 if type(selected)~='table'or #selected~=1 or selected[1]~=p.id then return nil,'selection_not_requested_actor'end
 local camera=Spring.GetCameraState()
 if type(camera)~='table'or camera.name~='free'or camera.mode~=4 then return nil,'camera_controller_changed'end
 for _,key in ipairs({'px','py','pz','rx','ry','rz'})do
  if not finite(camera[key])or math.abs(camera[key]-p.camera[key])>(key:sub(1,1)=='p'and .25 or .001)then return nil,'camera_not_settled_'..key end
 end
 local cx,cy,cz=Spring.GetCameraPosition()
 if not(finite(cx)and finite(cy)and finite(cz))then return nil,'render_camera_unreadable'end
 if math.abs(cx-p.camera.px)>.25 or math.abs(cy-p.camera.py)>.25 or math.abs(cz-p.camera.pz)>.25 then return nil,'render_camera_not_settled'end
 if Spring.IsUnitInView(p.id)~=true then return nil,'requested_actor_not_in_view'end
 local x,y,z=Spring.GetUnitPosition(p.id)
 if not(finite(x)and finite(y)and finite(z))then return nil,'actor_position_unreadable'end
 local sx,sy,sz=Spring.WorldToScreenCoords(x,y,z);local width,height=Spring.GetViewGeometry()
 if not(finite(sx)and finite(sy)and finite(sz)and finite(width)and finite(height))then return nil,'projection_unreadable'end
 if sx<16 or sy<16 or sx>width-16 or sy>height-16 or sz<0 or sz>1 then return nil,'requested_actor_projection_outside_view'end
 return {camera=camera,render_camera={cx,cy,cz},screen={sx,sy,sz},view={width,height},selected=selected[1]}
end
function widget:DrawScreen()
 renderSerial=renderSerial+1
 if not pending then return end
 local okay,row,why=pcall(evidence,pending)
 if not okay then row=nil;why='readback_exception'end
 if row then
  pending.stableRenders=pending.stableRenders+1;pending.observed=row
  pending.stableSince=pending.stableSince or elapsed;pending.observedSerial=renderSerial
 else pending.stableRenders=0;pending.stableSince=nil;pending.observed=nil;pending.reason=why end
end
function widget:Update(dt)
 if finite(dt)and dt>0 then elapsed=elapsed+dt end
 if not pending then return end
 local f=Spring.GetGameFrame();local p=pending
 if elapsed-p.start>8 or f-p.frame>180 then
  log('NATIVE_SCREENSHOT_REFUSED',p.name,p.id,f,p.reason or 'render_settling_timeout',p.stableRenders,elapsed-p.start);pending=nil;return
 end
 if not p.observed or p.stableRenders<3 or elapsed-(p.stableSince or elapsed)<.5 or f-p.frame<10 then return end
 -- Recheck just before requesting; DrawScreen data alone can become stale.
 local okay,row,why=pcall(evidence,p)
 if not okay or not row then p.stableRenders=0;p.stableSince=nil;p.observed=nil;p.reason=why or 'readback_exception';return end
 local c=row.camera;local screen=row.screen
 log('NATIVE_IMAGE_READBACK',p.name,p.id,f,'selected',row.selected,'visible',true,'screen',screen[1],screen[2],screen[3],
  'view',row.view[1],row.view[2],'camera',c.name,c.mode,c.px,c.py,c.pz,c.rx,c.ry,c.rz,'renderCamera',row.render_camera[1],row.render_camera[2],row.render_camera[3],'stableRenders',p.stableRenders,'settleSeconds',elapsed-p.stableSince)
 Spring.SendCommands('screenshot png');log('NATIVE_SCREENSHOT_REQUEST',p.name,p.id,f);pending=nil
end
