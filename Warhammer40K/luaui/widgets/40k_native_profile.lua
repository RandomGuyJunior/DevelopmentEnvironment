function widget:GetInfo()
 return {name='40K opted native profiler',desc='Separate diagnosis only; nested elapsed CPU scopes, not GPU timing',author='Local project',layer=1006,enabled=true}
end
local options=Spring.GetModOptions()
local mode=options.prototype_diagnostic
if tostring(options.prototype_profile)~='1' or (mode~='benchmark' and mode~='combatbenchmark' and mode~='mixedperf2') then return end
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
  Spring.Echo('40K_NATIVE_PROFILE '..string.format('{"event":"mixed_window","stage":%d,"serial":%d,"population_stage":%d,"phase":"%s","target":%d}',v.serial,v.serial,v.stage,v.phase,v.target))
 end
 return v
end
local names={'Sim','Sim::GameFrame','Sim::Script','CUnitScriptEngine::Tick',
 'Sim::Unit::MoveType','Sim::Unit::Weapon','Sim::Unit::UpdateWeaponVectors','Sim::Unit::UpdatePostAnimation',
 'Misc::SwapBuffers','Draw::Screen','Draw::Screen::DrawScreen','Draw::Screen::InputReceivers',
 'Draw::DrawGenesis','Draw::World::UpdateReflTex','Draw::World::UpdateSpecTex',
 'Draw::World::UpdateSkyTex','Draw::World::UpdateShadingTex','Draw','Update','Update::WorldDrawer','CUnitDrawerBase::Update','Draw::World',
 'Draw::World::Models::Opaque','Draw::World::CreateShadows','Draw::World::Particles'}
local owned,stopped=false,false
local stage,timer,frame,draw,zeroWindows=0,nil,nil,nil,0
local previous={}
local selected,inventoryStage={},0
local scopeLimit,inventoryLimit=64,256
local function emit(value) Spring.Echo('40K_NATIVE_PROFILE '..value) end
local function quote(value)
 return '"'..value:gsub('[%z\1-\31\\"]',function(c)return string.format('\\u%04x',c:byte())end)..'"'
end
local function array(values)
 local out={};for i,value in ipairs(values) do out[i]=quote(value) end
 return '['..table.concat(out,',')..']'
end
local function inventory(available)
 local all,present={},{}
 for _,name in ipairs(available) do
  if type(name)=='string' and not present[name] then all[#all+1]=name;present[name]=true end
 end
 table.sort(all)
 local excluded,seen={},{}
 selected={}
 local function select(name)
  if not present[name] or seen[name] then return end
  seen[name]=true
  if #selected<scopeLimit then selected[#selected+1]=name else excluded[#excluded+1]=name end
 end
 -- Explicit screen/IBL/swap scopes have priority; then every available Draw*.
 for _,name in ipairs(names) do select(name) end
 for _,name in ipairs(all) do if name:sub(1,4)=='Draw' then select(name) end end
 local visible,omitted={},{}
 for i,name in ipairs(all) do if i<=inventoryLimit then visible[#visible+1]=name else omitted[#omitted+1]=name end end
 emit(string.format('{"event":"inventory","stage":%d,"native_available_count":%d,"inventory_limit":%d,"scope_limit":%d,"native_names":%s,"selected_names":%s,"excluded_scope_names":%s,"omitted_inventory_names":%s}',stage,#all,inventoryLimit,scopeLimit,array(visible),array(selected),array(excluded),array(omitted)))
end
local function stop(reason)
 if stopped then return end
 stopped=true
 if owned then Spring.SendCommands('debug 0 0');owned=false end
 emit(string.format('{"event":"terminated","reason":"%s"}',reason))
end
function widget:Initialize()
 if not Spring.GetProfilerRecordNames or not Spring.GetProfilerTimeRecord then stop('native_api_unavailable');return end
 -- The prior collection state has no audited getter. Explicit opt-in owns the
 -- profiler state: collection on/overlay off now, collection/overlay off later.
 Spring.SendCommands('debug 1 0');owned=true
 emit('{"event":"started","diagnosis_only":true,"frame_data":false,"debug_policy":"explicit ownership: on without overlay, off on shutdown; prior state unknown"}')
end
function widget:Update()
 if stopped then return end
 if Spring.GetGameRulesParam(key..'done')==1 then stop('fixture_terminated');return end
 local now=Spring.GetTimer()
 local mv=mixedWindow and mixedSample(now)
 local current=mv and mv.serial or Spring.GetGameRulesParam(key..'stage') or 0
 local f=Spring.GetGameFrame()
 local started=Spring.GetGameRulesParam(key..'started')
 if (mv and not mv.active) or (not mv and (current==0 or not started or f-started<150)) then timer=nil;previous={};return end
 local d=Spring.GetDrawFrame and Spring.GetDrawFrame() or nil
 if not timer or stage~=current then stage=current;timer=now;frame=f;draw=d;previous={};zeroWindows=0;return end
 local elapsed=Spring.DiffTimers(now,timer)
 if elapsed<1 then return end
 local ok,available=pcall(Spring.GetProfilerRecordNames)
 if not ok or type(available)~='table' then stop('native_names_unavailable');return end
 if inventoryStage~=stage then inventory(available);inventoryStage=stage end
 local present={};for _,name in ipairs(available) do present[name]=true end
 local positive=0
 for _,name in ipairs(selected) do
  if present[name] then
   local valid,total=pcall(Spring.GetProfilerTimeRecord,name,false)
   if valid and type(total)=='number' and total>=0 and total<math.huge then
    local old=previous[name];previous[name]=total
    if old and total>=old then
     local delta=total-old
     if delta>0 then positive=positive+1 end
     local simFrames=f-frame;local drawFrames=d and draw and d-draw or nil
     emit(string.format('{"event":"scope","stage":%d,"frame":%d,"name":%s,"delta_ms":%.6f,"wall_seconds":%.6f,"sim_frames":%d,"draw_frames":%s,"ms_per_sim_frame":%s,"ms_per_draw_frame":%s,"elapsed_wall_fraction":%.6f}',stage,f,quote(name),delta,elapsed,simFrames,drawFrames and tostring(drawFrames) or 'null',simFrames>0 and tostring(delta/simFrames) or 'null',drawFrames and drawFrames>0 and tostring(delta/drawFrames) or 'null',delta/(1000*elapsed)))
    elseif old then
     emit(string.format('{"event":"counter_reset","stage":%d,"name":%s}',stage,quote(name)))
    end
   else
    previous[name]=nil
    emit(string.format('{"event":"scope_unavailable","stage":%d,"name":%s}',stage,quote(name)))
   end
  else previous[name]=nil end
 end
 zeroWindows=positive==0 and zeroWindows+1 or 0
 timer,frame,draw=now,f,d
 if zeroWindows>=5 then stop('no_positive_native_counters') end
end
function widget:Shutdown() stop('shutdown') end
