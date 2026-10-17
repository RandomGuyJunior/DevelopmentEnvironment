function widget:GetInfo()return {name='40K opt-in factory production pose review',desc='Read-only actual production screenshots and native piece matrices',author='Local project',layer=1005,enabled=true}end
local opts=Spring.GetModOptions()
if opts.prototype_diagnostic~='expandedproduction' or tostring(opts.prototype_factory_pose_review)~='1' then return end
local plans={imp_marine_hq={12,42,72,102,132,192,252},imp_marine_barracks={12,42,72,102,132,192,252},imp_barracks={12,42,72,102},imp_tank_factory={12,42,72,102},imp_walker_factory={12,72,132,192,252}}
local keys={imp_marine_hq={'door01','door02','pod_landing','marker_door_front'},imp_marine_barracks={'door_left','door_right','landing_pad','marker_barracks_doors_front'},imp_barracks={'bunker','bone_flag_03'},imp_tank_factory={'bunker_base','bone_01_banner_01'},imp_walker_factory={'piekeystone','wedge04','tower'}}
local function sourceName(ud)
 if plans[ud.name] then return ud.name end
 local cp=ud.customParams or {}
 local source=cp.animsource or cp.prototype40k_donor
 if ud.isFactory and cp.prototype40k and plans[source] then return source end
end
local sources={imp_marine_hq='genuine_full_native_production_sequence',imp_marine_barracks='genuine_full_native_production_sequence',imp_barracks='flag_idle',imp_tank_factory='flag_idle',imp_walker_factory='production_1'}
local captureFree=tostring(opts.prototype_factory_pose_capture_free)=='1'
local records={};local savedCamera;local speedReported=false
local cameraID,cameraFrame
local cadence,observedWindows,validWindows= nil,0,0
local cadenceStopped=false
local discontinuities=0
local observationStart
local function log(...)Spring.Echo('40K FACTORY POSE',...)end
function widget:Initialize()if not captureFree then savedCamera=Spring.GetCameraState()end end
function widget:Shutdown()if savedCamera then Spring.SetCameraState(savedCamera,0)end end
local function readback(id,name,f)
 if not Spring.GetUnitPieceMatrix then log('UNKNOWN','native_piece_matrix_missing',name,id,f);return end
 local map=Spring.GetUnitPieceMap(id) or {}
 for _,bone in ipairs(keys[name]) do
  local p=map[bone]
  if p then
   local info=Spring.GetUnitPieceInfo(id,p);local parent=info and info.parent
   local m={Spring.GetUnitPieceMatrix(id,p)}
   if #m==16 then log('NATIVE_MATRIX',name,id,f,bone,unpack(m))end
   if parent and map[parent] then
    local pm={Spring.GetUnitPieceMatrix(id,map[parent])}
    if #pm==16 then log('NATIVE_PARENT_MATRIX',name,id,f,bone,parent,unpack(pm))end
   end
  else log('UNKNOWN','source_key_piece_missing',name,id,f,bone)end
 end
end
local function finite(v)return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function observeCadence(f,user,speed,paused)
 if cadenceStopped then return end
 if not Spring.GetTimer or not Spring.DiffTimers then
  log('CADENCE_UNKNOWN','wall_timer_unavailable');cadenceStopped=true;return
 end
 local now=Spring.GetTimer()
 observationStart=observationStart or now
 local total=Spring.DiffTimers(now,observationStart)
 if not finite(total) or total<0 then observationStart=now end
 if finite(total) and total>=1800 or observedWindows>=1200 then
  log('CADENCE_STOP','observation_limit',observedWindows,validWindows);cadenceStopped=true;return
 end
 if paused then
  if cadence then log('CADENCE_RESET','paused','screenshot_affected',cadence.screenshot or false) end
  cadence=nil;return
 end
 if not cadence then cadence={timer=now,frame=f};return end
 local wall=Spring.DiffTimers(now,cadence.timer)
 if not finite(wall) or wall<0 or f<cadence.frame or wall>10 then
  log('CADENCE_RESET','frame_or_time_discontinuity',f,cadence.frame,wall,'screenshot_affected',cadence.screenshot or false)
  discontinuities=discontinuities+1
  if discontinuities>=32 then log('CADENCE_STOP','discontinuity_limit',observedWindows,validWindows);cadenceStopped=true;cadence=nil;return end
  cadence={timer=now,frame=f};return
 end
 if wall<1 then return end
 local frames=f-cadence.frame
 local ratio=frames/(wall*(Game and Game.gameSpeed or 30))
 local configured=finite(speed) and math.abs(speed-1)<=.05
 local affected=cadence.screenshot or false
 local valid=configured and not affected and finite(ratio)
 observedWindows=observedWindows+1
 if valid then validWindows=validWindows+1 end
 log('CADENCE_WINDOW',f,'wall_seconds',wall,'sim_frames',frames,'achieved_ratio',ratio,
  'configured_speed',speed or -1,'wanted_speed',user or -1,'configured_1x',configured,
  'screenshot_affected',affected,'valid_window',valid,'window',observedWindows,'valid_windows',validWindows)
 cadence={timer=now,frame=f}
end
local function prepareCamera(id,name,f)
 if captureFree then return true end
 local x,y,z=Spring.GetUnitPosition(id);if not x then log('UNKNOWN','position_missing',name,id,f);return false end
 local radius=Spring.GetUnitRadius(id) or 60;local height=Spring.GetUnitHeight(id) or 50
 local d=math.max(110,radius*2.6,height*2)
 Spring.SetCameraState({name='free',mode=4,px=x+d*.78,py=y+d*.88,pz=z+d,rx=-.612,ry=-2.48,rz=0,vx=0,vy=0,vz=0,avx=0,avy=0,avz=0},0)
 Spring.SelectUnitArray({id});cameraID,cameraFrame=id,f
 log('CAMERA_PREP',name,id,f,x,y,z,d)
 return true
end
function widget:Update()
 local user,speed,paused=Spring.GetGameSpeed()
 local f=Spring.GetGameFrame()
 observeCadence(f,user,speed,paused)
 if paused then return end
 if not finite(speed) or math.abs(speed-1)>.05 then
  if not speedReported then log('UNKNOWN','visual_review_requires_configured_1x',user or -1,speed or -1);speedReported=true end
  return
 end
 local candidates={}
 for _,id in ipairs(Spring.GetAllUnits())do
  local def=Spring.GetUnitDefID(id);local ud=def and UnitDefs[def];local name=ud and sourceName(ud)
  if plans[name] and Spring.GetUnitRulesParam(id,'40k_factory_pose_tracked')==1 then
   local product=Spring.GetUnitRulesParam(id,'40k_factory_pose_product')
   local actual=Spring.GetUnitIsBuilding(id)
   local finished=Spring.GetUnitRulesParam(id,'40k_factory_pose_finished_product')
   local finishFrame=Spring.GetUnitRulesParam(id,'40k_factory_pose_finished_frame')
   local closing=(name=='imp_marine_hq'or name=='imp_marine_barracks')and finished and type(finishFrame)=='number'and f-finishFrame>=0 and f-finishFrame<180
   if product and(actual==product or closing and finished==product)then
    local r=records[id]
    if not r or r.product~=product then r={start=f,seen={},product=product};records[id]=r;log('NATIVE_BUILDING',name,id,product,f,sources[name],ud.name);prepareCamera(id,name,f)end
    if closing then
     for _,age in ipairs({12,30,60,90,120,150})do
      local key='finished'..age
      if f-finishFrame>=age and not r.seen[key]then
       if f-finishFrame>age+5 then r.seen[key]=true;log('MISSED_CLOSURE',name,id,age,f-finishFrame)
       else candidates[#candidates+1]={id=id,name=name,product=product,r=r,age=key,closureAge=age,finish=finishFrame}end
      end
     end
    end
    for _,age in ipairs(plans[name])do
     if f-r.start>=age and not r.seen[age]then
      if f-r.start>age+5 then r.seen[age]=true;log('MISSED',name,id,age,f-r.start)
      else candidates[#candidates+1]={id=id,name=name,product=product,r=r,age=age}end
     end
    end
   end
  end
 end
 table.sort(candidates,function(a,b)return a.id<b.id end)
 local c=candidates[1];if not c then return end
 if not captureFree and cameraID~=c.id then prepareCamera(c.id,c.name,f);return end
 if not captureFree and (not cameraFrame or f-cameraFrame<1) then return end
 c.r.seen[c.age]=true
 if not captureFree and c.age==plans[c.name][1] and f-cameraFrame<12 then
  log('UNKNOWN','first_capture_camera_lead_under_12_frames',c.name,c.id,f,cameraFrame or -1);return
 end
 readback(c.id,c.name,f)
 if c.closureAge then log('NATIVE_CLOSURE_STAGE',c.name,c.id,c.product,f,c.finish,c.closureAge,Spring.GetUnitRulesParam(c.id,'40k_source_factory_stage'))end
 if captureFree then
  log('POSE_SAMPLE',c.name,c.id,c.product,f,c.r.start,c.age,sources[c.name],'capture_free')
 else
  Spring.SendCommands('screenshot png')
  if cadence then cadence.screenshot=true end
  log('CAPTURE',c.name,c.id,c.product,f,c.r.start,c.age,sources[c.name],'camera_prepared_frame',cameraFrame)
 end
end
-- Cadence is separate evidence. Screenshots perturb wall timing; no pose/FPS/
-- cadence acceptance is combined and no simulation/production state is changed.
