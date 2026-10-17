-- Read-only, explicitly opted ordinary SourcePaidMatch observations.
function widget:GetInfo()
 return{name='40K paid match performance observer',desc='Actual wall windows/population history; no acceptance or mutations',author='Local Recoil Project',layer=1007,enabled=true}
end
local o=Spring.GetModOptions()
if tostring(o.prototype_paid_match_performance)~='1'or tostring(o.prototype_source_paid_match)~='1'or o.prototype_diagnostic~='expandedproduction'or not VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(o.prototype_source_progression)or tonumber(o.prototype_test_speed)~=1 then return end
local NULL={};local ARRAY={};local function array(t)return setmetatable(t or{},ARRAY)end
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function quote(s)return '"'..tostring(s):gsub('[%z\1-\31\\"]',function(c)return string.format('\\u%04x',c:byte())end)..'"'end
local function json(v)
 if v==NULL or v==nil then return'null'end
 local k=type(v);if k=='number'then return finite(v)and string.format('%.12g',v)or'null'elseif k=='boolean'then return tostring(v)elseif k=='string'then return quote(v)elseif k~='table'then return'null'end
 local out={};if getmetatable(v)==ARRAY or #v>0 then for i=1,#v do out[#out+1]=json(v[i])end;return'['..table.concat(out,',')..']'end
 local keys={};for key in pairs(v)do keys[#keys+1]=key end;table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
 for _,key in ipairs(keys)do out[#out+1]=quote(key)..':'..json(v[key])end;return'{'..table.concat(out,',')..'}'
end
local function emit(row)Spring.Echo('40K_PAID_MATCH_PERF '..json(row))end
local function read(name,...)
 if type(Spring[name])~='function'then return NULL end
 local okay,a,b,c,d,e,f,g,h=pcall(Spring[name],...);if not okay or a==nil then return NULL end
 if b~=nil then return array{a,b,c,d,e,f,g,h}end;return a
end
local function geometry(name)
 local v=read(name);if type(v)~='table'or not finite(v[1])or not finite(v[2])or v[1]<=0 or v[2]<=0 then return NULL end;return v
end
local function config(name,float)
 local v=read(float and'GetConfigFloat'or'GetConfigInt',name,-987654321);return finite(v)and v~=-987654321 and v or NULL
end
local function policy()
 return{config_VSync=config('VSync'),actual_driver_swap_interval=NULL,effective_external_fps_cap=NULL,effective_idle_throttle=NULL,
  config_MinDrawFPS=config('MinDrawFPS'),config_MinSimDrawBalance=config('MinSimDrawBalance',true),config_MaxFPS_unproven_key=config('MaxFPS'),config_IdleFPS_unproven_key=config('IdleFPS'),
  fullscreen_config=config('Fullscreen'),window_borderless_config=config('WindowBorderless'),requested_window_width=config('XResolutionWindowed'),requested_window_height=config('YResolutionWindowed'),
  master_config=config('snd_volmaster'),music_config=config('snd_volmusic'),gui_hidden=read('IsGUIHidden'),
  scope='Config knobs and native geometry only; external cap/focus/idle effect/driver swap unavailable, never inferred'}
end
-- Native API returns low16 and high16; do not infer modulo wraps/resets.
local function drawCounter()
 if type(Spring.GetDrawFrame)~='function'then return nil end
 local low,high=Spring.GetDrawFrame()
 if not finite(low)or not finite(high)or low%1~=0 or high%1~=0 or low<0 or low>65535 or high<0 or high>65535 then return nil end
 return low+high*65536
end
local epoch,state,lastTimer,lastDraw,lastCensusTimer,lastCensusFrame,stopped,serial
local damaged={};local damageCount=0;local damageSum=0;local paralyzeCount=0;local lastObservedFrame
local function invalid(reason)if state then state.invalid[reason]=true end end
local function create(now,frame,draw)
 serial=(serial or 0)+1
 state={serial=serial,startTimer=now,startFrame=frame,startDraw=draw,intervals={},invalid={},samples=0,fpsSum=0,fpsMin=nil,fpsMax=nil,duplicates=0,missing=0,within120=0,within144=0,catchup=0,slow=0,
  mobileMin=nil,mobileMax=nil,aliveMin=nil,aliveMax=nil,movingMax=0,combatMax=0,damageStart=damageCount,damageSumStart=damageSum,paralyzeStart=paralyzeCount,cameraChanges=0,viewportChanges=0,policyChanges=0,nativeWindowChanges=0}
 lastTimer,lastDraw,lastCensusTimer,lastCensusFrame=now,draw,now,frame
 emit{event='window_start',serial=serial,window_seconds=60,settle_seconds=10,frame=frame,draw=draw,wall_elapsed_since_observer=Spring.DiffTimers(now,epoch),paid_provenance='SourcePaidMatch option; payment/admission receipts are separate',fixed_population_claim=false,acceptance=false}
end
local function quantile(values,p)return #values>0 and values[math.max(1,math.ceil(#values*p))]*1000 or NULL end
local function finish(now,frame,draw,reason)
 if not state then return end
 local wall=Spring.DiffTimers(now,state.startTimer);local values={};for i,v in ipairs(state.intervals)do values[i]=v end;table.sort(values)
 local problems=array();for k in pairs(state.invalid)do problems[#problems+1]=k end;table.sort(problems)
 if reason~='wall_window_complete'or wall<60 then problems[#problems+1]='incomplete_window'end
 if #values==0 then problems[#problems+1]='no_counted_draw_intervals'end
 emit{event='window',serial=state.serial,reason=reason,complete=reason=='wall_window_complete'and wall>=60,observation_valid=#problems==0,invalid=problems,
  start_frame=state.startFrame,end_frame=frame,sim_frame_delta=frame-state.startFrame,draw_counter_encoding='GetDrawFrame low16+65536*high16',start_draw=state.startDraw,end_draw=draw,wall_seconds=wall,wall_elapsed_since_observer=Spring.DiffTimers(now,epoch),observed_draw_delta=draw-state.startDraw,observed_draw_rate=wall>0 and(draw-state.startDraw)/wall or NULL,sim_ratio=(frame-state.startFrame)/((Game.gameSpeed or 30)*wall),
  intervals=#values,p50_ms=quantile(values,.5),p95_ms=quantile(values,.95),p99_ms=quantile(values,.99),within120=state.within120,within144=state.within144,budget120_ms=1000/120,budget144_ms=1000/144,
  native_fps_samples=state.samples,native_fps_mean=state.samples>0 and state.fpsSum/state.samples or NULL,native_fps_min=state.fpsMin or NULL,native_fps_max=state.fpsMax or NULL,
  population_scope='actual_observed_paid_match_history',alive_min=state.aliveMin or NULL,alive_max=state.aliveMax or NULL,mobile_min=state.mobileMin or NULL,mobile_max=state.mobileMax or NULL,moving_max=state.movingMax,combat_damage_actor_max=state.combatMax,
  unit_damaged_callbacks=damageCount-state.damageStart,observed_native_damage=damageSum-state.damageSumStart,paralyze_damage_callbacks=paralyzeCount-state.paralyzeStart,duplicate_updates=state.duplicates,missing_draw_frames=state.missing,catchup_checks=state.catchup,slow_sim_checks=state.slow,
  camera_changes=state.cameraChanges,viewport_changes=state.viewportChanges,policy_changes=state.policyChanges,native_window_changes=state.nativeWindowChanges,fair_fixed_view_comparison=state.cameraChanges==0 and state.viewportChanges==0 and state.policyChanges==0 and state.nativeWindowChanges==0 and #problems==0,
  acceptance=false,gpu_timing=NULL,input_to_display_latency=NULL,fixed_population_claim=false}
end
local function census(frame)
 local all=read('GetAllUnits');local rows={};local out={alive=0,mobile=0,structures=0,moving=0,combat=0,unfinished=0,production=0,unreadable=0,by_team={},by_faction={},by_definition={},by_role={}}
 if all==NULL then invalid('population_unavailable');return out end
 local productionReadable=type(Spring.GetUnitIsBuilding)=='function';if not productionReadable then out.production=NULL;invalid('production_api_unavailable')end
 for _,id in ipairs(all)do
  local def=read('GetUnitDefID',id);local team=read('GetUnitTeam',id);local ud=def~=NULL and UnitDefs[def];local health=read('GetUnitHealth',id)
  if not ud or team==NULL or health==NULL or type(health)~='table'or not finite(health[1])then out.unreadable=out.unreadable+1
  elseif health[1]>0 then
   local cp=ud.customParams or{};local faction=cp.faction or cp.prototype40k_faction or'unknown';local name=ud.name or tostring(def);local role=cp.rosterrole or'unknown';local mobile=ud.canMove==true and finite(ud.speed)and ud.speed>0
   out.alive=out.alive+1;if mobile then out.mobile=out.mobile+1 else out.structures=out.structures+1 end
   out.by_team[tostring(team)]=(out.by_team[tostring(team)]or 0)+1;out.by_faction[faction]=(out.by_faction[faction]or 0)+1;out.by_definition[name]=(out.by_definition[name]or 0)+1;out.by_role[role]=(out.by_role[role]or 0)+1
   if finite(health[5])and health[5]<1 then out.unfinished=out.unfinished+1 end
   local velocity=read('GetUnitVelocity',id);if velocity~=NULL and type(velocity)=='table'and finite(velocity[1])and finite(velocity[2])and finite(velocity[3])then if velocity[1]*velocity[1]+velocity[2]*velocity[2]+velocity[3]*velocity[3]>1e-12 then out.moving=out.moving+1 end else invalid('velocity_unavailable')end
   if damaged[id]and frame-damaged[id]<=150 then out.combat=out.combat+1 end
   if productionReadable then local product=read('GetUnitIsBuilding',id);if product~=NULL then out.production=out.production+1 end end
  end
 end
 if out.unreadable>0 then invalid('population_partly_unreadable')end
 for id,when in pairs(damaged)do if frame-when>150 then damaged[id]=nil end end
 return out
end
local function sample(now,frame,draw,wanted,actual,paused)
 local elapsed=Spring.DiffTimers(now,lastCensusTimer);local delta=frame-lastCensusFrame;local ratio=elapsed>0 and delta/((Game.gameSpeed or 30)*elapsed)or NULL
 local pop=census(frame);local camera=read('GetCameraState');local view=geometry('GetViewGeometry');local win=geometry('GetWindowGeometry');local settings=policy();local spectating=read('GetSpectatingState');local fps=read('GetFPS')
 if view==NULL or win==NULL then invalid('render_geometry_unavailable')end
 if spectating==NULL or type(spectating)~='table'or spectating[2]~=true then invalid('population_not_proven_full_view')end
 if not finite(fps)then invalid('native_fps_unavailable')else state.samples=state.samples+1;state.fpsSum=state.fpsSum+fps;state.fpsMin=math.min(state.fpsMin or fps,fps);state.fpsMax=math.max(state.fpsMax or fps,fps)end
 if finite(ratio)and ratio<.95 then state.slow=state.slow+1 end;if finite(ratio)and ratio>1.05 then state.catchup=state.catchup+1 end
 if camera==NULL then invalid('camera_unavailable')end
 for label,value in pairs{camera=camera,viewport=view,policy=settings,nativeWindow=win}do local key=json(value);if state[label]and state[label]~=key then local counter=label=='camera'and'cameraChanges'or label=='viewport'and'viewportChanges'or label=='nativeWindow'and'nativeWindowChanges'or'policyChanges';state[counter]=state[counter]+1 end;state[label]=key end
 state.aliveMin=math.min(state.aliveMin or pop.alive,pop.alive);state.aliveMax=math.max(state.aliveMax or pop.alive,pop.alive);state.mobileMin=math.min(state.mobileMin or pop.mobile,pop.mobile);state.mobileMax=math.max(state.mobileMax or pop.mobile,pop.mobile);state.movingMax=math.max(state.movingMax,pop.moving);state.combatMax=math.max(state.combatMax,pop.combat)
 emit{event='sample',serial=serial,frame=frame,draw=draw,window_age=Spring.DiffTimers(now,state.startTimer),wall_delta=elapsed,sim_frame_delta=delta,sim_ratio=ratio,native_fps=fps,desired_speed=wanted,actual_speed=actual,paused=paused,
  population=pop,camera=camera,viewport=view,native_window=win,policy=settings,mouse_state=read('GetMouseState'),spectating=spectating,population_visibility='native GetAllUnits under observed spectator/full-view state',combat_scope='live actors with observed positive UnitDamaged callback in last150simframes; none observed is not no-combat proof',acceptance=false}
 lastCensusTimer,lastCensusFrame=now,frame
end
function widget:Update()
 if stopped then return end
 if not(Spring.GetTimer and Spring.DiffTimers and Spring.GetGameFrame and Spring.GetDrawFrame and Spring.GetGameSpeed)then emit{event='refused',reason='required_native_clock_api_missing',acceptance=false};stopped=true;return end
 local now=Spring.GetTimer();local frame=Spring.GetGameFrame();local draw=drawCounter();local wanted,actual,paused=Spring.GetGameSpeed()
 if not finite(frame)or not finite(draw)then emit{event='refused',reason='native_counters_or_draw_halves_unavailable',acceptance=false};stopped=true;return end
 if frame<=0 then return end
 if not epoch then epoch=now;emit{event='observer',window_seconds=60,settle_seconds=10,draw_counter_encoding='GetDrawFrame low16+65536*high16; no modulo32/reset inference',clock='actual wall timers; sample first Update crossing1s/window60s; no interpolation of missing timestamps',option='prototype_paid_match_performance=1',profile_callbacks=tostring(o.prototype_profile or'0'),widget_profile_callbacks=tostring(o.prototype_profile_widgets or'0'),acceptance=false}end
 if Spring.DiffTimers(now,epoch)<10 then return end
 if not state then create(now,frame,draw);sample(now,frame,draw,wanted,actual,paused);lastObservedFrame=frame;if paused then invalid('paused')end;if wanted~=1 then invalid('desired_speed_not_one')end;return end
 if lastObservedFrame and frame<lastObservedFrame then invalid('simulation_counter_reversed')end;lastObservedFrame=frame
 if paused then invalid('paused')end;if wanted~=1 then invalid('desired_speed_not_one')end
 if tostring(o.prototype_profile or'0')=='1'or tostring(o.prototype_profile_widgets or'0')=='1'then invalid('profiling_callbacks_enabled')end
 local dt=Spring.DiffTimers(now,lastTimer);local dd=draw-lastDraw
 if dd==0 then state.duplicates=state.duplicates+1
 elseif dd~=1 then invalid(dd<0 and'draw_counter_reversed'or'draw_counter_gap');state.missing=state.missing+math.max(0,dd-1)
 elseif dt>0 and finite(dt)then if #state.intervals<100000 then state.intervals[#state.intervals+1]=dt;if dt<=1/120 then state.within120=state.within120+1 end;if dt<=1/144 then state.within144=state.within144+1 end else invalid('interval_limit')end
 else invalid('invalid_draw_interval')end
 if dd~=0 then lastTimer,lastDraw=now,draw end
 if Spring.DiffTimers(now,lastCensusTimer)>=1 then sample(now,frame,draw,wanted,actual,paused)end
 if Spring.DiffTimers(now,state.startTimer)>=60 then if Spring.DiffTimers(now,lastCensusTimer)>0 then sample(now,frame,draw,wanted,actual,paused)end;finish(now,frame,draw,'wall_window_complete');create(now,frame,draw);sample(now,frame,draw,wanted,actual,paused)end
end
function widget:UnitDamaged(id,def,team,damage,paralyzer,weapon,projectile,attacker)
 if type(Spring.GetGameFrame)~='function'then return end
 if finite(damage)and damage>0 then local frame=Spring.GetGameFrame();if not finite(frame)then return end;if paralyzer then paralyzeCount=paralyzeCount+1 end;damaged[id]=frame;if attacker then damaged[attacker]=frame end;damageCount=damageCount+1;damageSum=damageSum+damage end
end
function widget:Shutdown()if state then local draw=drawCounter();if draw==nil then invalid('draw_counter_halves_unavailable');draw=lastDraw end;finish(Spring.GetTimer(),Spring.GetGameFrame(),draw,'shutdown')end;stopped=true end
