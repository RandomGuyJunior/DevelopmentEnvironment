function widget:GetInfo()
 return {name='40K opted widget profiler',desc='Diagnostic inclusive callback elapsed time',author='Local project',layer=1007,enabled=true,handler=true}
end
local options=Spring.GetModOptions()
local mode=options.prototype_diagnostic
if tostring(options.prototype_profile_widgets)~='1' or tostring(options.prototype_profile)~='1' or (mode~='benchmark' and mode~='combatbenchmark' and mode~='mixedperf2') then return end
local key=mode=='benchmark' and '40k_benchmark_' or '40k_combat_benchmark_'
local mixedWindow
if mode=='mixedperf2' then
 if tostring(options.prototype_mixed_v2)~='1' then return end
 mixedWindow=VFS.Include('40k_configs/mixed_profile_window.lua').New(Spring,VFS.Include('40k_configs/mixed_v2.lua'))
 key='40k_mixed_v2_'
end
local mappedSerial=0
local function mixedSample(now)
 local v=mixedWindow(now)
 if v.valid and v.serial~=mappedSerial then
  mappedSerial=v.serial
  Spring.Echo('40K_WIDGET_PROFILE '..string.format('{"event":"mixed_window","stage":%d,"serial":%d,"population_stage":%d,"phase":"%s","target":%d}',v.serial,v.serial,v.stage,v.phase,v.target))
 end
 return v
end
local callbacks={'DrawScreen','DrawScreenEffects','DrawScreenPost'}
local records,stopped,stage,active={},false,0,false
local window,frame,draw
local function quote(s)
 return '"'..s:gsub('[%z\1-\31\\"]',function(c)return string.format('\\u%04x',c:byte())end)..'"'
end
local function emit(s) Spring.Echo('40K_WIDGET_PROFILE '..s) end
local function restore(r)
 if r.owner[r.callin]==r.wrapper then r.owner[r.callin]=r.original end
end
local function stop(reason)
 if stopped then return end
 stopped=true;active=false
 for _,r in ipairs(records) do restore(r) end
 records={}
 emit('{"event":"terminated","reason":'..quote(reason)..'}')
end
local function wrap(owner,callin)
 local original=owner[callin]
 local r={owner=owner,callin=callin,original=original,name=tostring(owner.whInfo and owner.whInfo.name or '<unnamed>'),seconds=0,calls=0}
 -- One helper per wrapped callback, avoiding per-draw closure allocation.
 local function finish(started,...)
  r.seconds=r.seconds+Spring.DiffTimers(Spring.GetTimer(),started)
  r.calls=r.calls+1
  return ...
 end
 r.wrapper=function(...)
  if not active or stopped then return original(...) end
  local started=Spring.GetTimer()
  -- Tail forwarding preserves nil-containing multiple returns. No pcall:
  -- callback errors retain the pinned handler's existing error policy.
  return finish(started,original(...))
 end
 owner[callin]=r.wrapper
 return r
end
local function sync()
 local present={};for _,w in ipairs(widgetHandler.widgets) do present[w]=true end
 local retained={}
 for _,r in ipairs(records) do
  if present[r.owner] and r.owner[r.callin]==r.wrapper then retained[#retained+1]=r
  else
   restore(r)
   emit('{"event":"detached","name":'..quote(r.name)..',"callin":'..quote(r.callin)..'}')
  end
 end
 records=retained
 local known={};for _,r in ipairs(records) do known[r.owner]=known[r.owner] or {};known[r.owner][r.callin]=true end
 for _,w in ipairs(widgetHandler.widgets) do
  if w~=widget then
   for _,callin in ipairs(callbacks) do
    if type(w[callin])=='function' and not (known[w] and known[w][callin]) then
     if #records>=256 then stop('callback_limit');return end
     records[#records+1]=wrap(w,callin)
     emit('{"event":"attached","name":'..quote(records[#records].name)..',"callin":'..quote(callin)..'}')
    end
   end
  end
 end
end
function widget:Initialize()
 if type(widgetHandler.widgets)~='table' or not Spring.GetTimer or not Spring.DiffTimers then stop('api_unavailable');return end
 sync()
end
function widget:Update()
 if stopped then return end
 if Spring.GetGameRulesParam(key..'done')==1 then stop('fixture_terminated');return end
 local now=Spring.GetTimer()
 local f=Spring.GetGameFrame()
 local d=Spring.GetDrawFrame and Spring.GetDrawFrame() or nil
 local mv=mixedWindow and mixedSample(now)
 local nextStage=mv and mv.serial or Spring.GetGameRulesParam(key..'stage') or 0
 local started=Spring.GetGameRulesParam(key..'started')
 if nextStage~=stage then
  stage=nextStage;window=nil
  for _,r in ipairs(records) do r.seconds=0;r.calls=0 end
 end
 active=(mv and mv.active) or (not mv and stage>0 and started~=nil and f-started>=150)
 if not active then window=nil;for _,r in ipairs(records) do r.seconds=0;r.calls=0 end;return end
 if not window then window,frame,draw=now,f,d;sync();return end
 local elapsed=Spring.DiffTimers(now,window)
 if elapsed<1 then return end
 for _,r in ipairs(records) do
  emit(string.format('{"event":"callback","stage":%d,"name":%s,"callin":%s,"elapsed_ms":%.6f,"calls":%d,"wall_seconds":%.6f,"sim_frames":%d,"draw_frames":%s,"elapsed_wall_fraction":%.6f}',stage,quote(r.name),quote(r.callin),r.seconds*1000,r.calls,elapsed,f-frame,d and draw and tostring(d-draw) or 'null',r.seconds/elapsed))
  r.seconds=0;r.calls=0
 end
 window,frame,draw=now,f,d
 sync()
end
function widget:Shutdown() stop('shutdown') end
