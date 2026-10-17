function widget:GetInfo()
 return {name='40K mixed render intervals',desc='Read-only observed pacing, not GPU timing or acceptance',author='Local project',layer=1005,enabled=true}
end
local o=Spring.GetModOptions()
if o.prototype_diagnostic~='mixedperf2' or tostring(o.prototype_mixed_v2)~='1' then return end
local cfg=VFS.Include('40k_configs/mixed_v2.lua')
local window=VFS.Include('40k_configs/mixed_profile_window.lua').New(Spring,cfg)
local function drawCounter()
 if type(Spring.GetDrawFrame)~='function' then return nil end
 local low,high=Spring.GetDrawFrame()
 local function half(v)return type(v)=='number'and v==v and v%1==0 and v>=0 and v<=65535 end
 if not half(low)or not half(high)then return nil end
 return low+65536*high
end
local state,lastTimer,lastDraw,lastCheck,lastFrame,stopped
local function invalid(reason) state.invalid[reason]=true end
local function emit(reason)
 if not state or state.emitted then return end
 state.emitted=true
 local values={};for i,v in ipairs(state.intervals) do values[i]=v end;table.sort(values)
 local function percentile(p) return #values>0 and string.format('%.9f',values[math.max(1,math.ceil(#values*p))]*1000) or 'null' end
 local failures={};for k in pairs(state.invalid) do failures[#failures+1]='"'..k..'"' end;table.sort(failures)
 local complete=reason=='window_complete' and state.lastAge>=cfg.settleWall+cfg.measureWall
 if not complete then failures[#failures+1]='"incomplete_window"' end
 if #values==0 then failures[#failures+1]='"no_intervals"' end
 Spring.Echo('40K_MIXED_FRAME_BUDGET '..string.format('{"event":"window","schedule":"movement_first_then_combat","population_scope":"%s","serial":%d,"stage":%d,"phase":"%s","target":%d,"reason":"%s","complete":%s,"intervals":%d,"p50_ms":%s,"p95_ms":%s,"p99_ms":%s,"within120":%d,"within144":%d,"budget120_ms":8.333333333,"budget144_ms":6.944444444,"duplicate_updates":%d,"missing_draw_frames":%d,"paused_checks":%d,"catchup_checks":%d,"slow_sim_checks":%d,"sim_frames":%d,"wall_seconds":%.9f,"population_checks":%d,"invalid":[%s],"acceptance":false,"gpu_timing":null,"draw_counter_encoding":"low16+65536*high16"}',state.phase=='movement' and 'fixed_population' or 'battle_population_history',state.serial,state.stage,state.phase,state.target,reason,tostring(complete),#values,percentile(.5),percentile(.95),percentile(.99),state.within120,state.within144,state.duplicates,state.missing,state.paused,state.catchup,state.slow,state.sim,state.wall,state.populationChecks,table.concat(failures,',')))
end
local function new(v)
 state={serial=v.serial,stage=v.stage,phase=v.phase,target=v.target,intervals={},invalid={},within120=0,within144=0,duplicates=0,missing=0,paused=0,catchup=0,slow=0,sim=0,wall=0,populationChecks=0,lastAge=0}
 lastTimer,lastDraw,lastCheck,lastFrame=nil,nil,nil,nil
end
local function population()
 local all=Spring.GetAllUnits();local seeds=0
 if type(all)~='table' then invalid('population_unavailable');return end
 for _,id in ipairs(all) do if Spring.GetUnitRulesParam(id,'40k_mixed_v2_seed')==state.serial then seeds=seeds+1 end end
 state.populationChecks=state.populationChecks+1
 if seeds~=state.target then invalid('population_mismatch') end
end
function widget:Update()
 if stopped then return end
 local now=Spring.GetTimer();local v=window(now)
 if state and state.serial~=v.serial then emit('serial_changed');state=nil end
 if v.done then emit('fixture_done');stopped=true;return end
 if not v.valid then return end
 if not state then new(v) end
 state.lastAge=v.age
 if v.ended then emit('window_complete');return end
 if not v.active then lastTimer,lastDraw,lastCheck,lastFrame=nil,nil,nil,nil;return end
 local frame=Spring.GetGameFrame()
 local wanted,actual,paused=Spring.GetGameSpeed()
 if paused then invalid('paused') end
 if wanted~=1 then invalid('desired_speed_not_one') end
 local draw=drawCounter()
 if type(draw)~='number' then invalid('draw_counter_unavailable') end
 if lastTimer then
  local dt=Spring.DiffTimers(now,lastTimer)
  local delta=draw and lastDraw and draw-lastDraw
  if not delta then invalid('draw_counter_unavailable')
  elseif delta==0 then state.duplicates=state.duplicates+1
  elseif delta~=1 then invalid('draw_counter_gap');state.missing=state.missing+math.max(0,delta-1)
  elseif dt>0 and dt<math.huge then
   if #state.intervals>=100000 then invalid('interval_limit');return end
   state.intervals[#state.intervals+1]=dt
   if dt<=1/120 then state.within120=state.within120+1 end
   if dt<=1/144 then state.within144=state.within144+1 end
  else invalid('invalid_interval') end
 end
 -- Duplicate Updates do not reset the timer for an actual draw interval.
 if draw~=lastDraw or not lastTimer then lastTimer,lastDraw=now,draw end
 if not lastCheck then lastCheck,lastFrame=now,frame;population() end
 local elapsed=Spring.DiffTimers(now,lastCheck)
 if elapsed>=1 then
  if paused then state.paused=state.paused+1;invalid('paused') end
  if wanted~=1 then invalid('desired_speed_not_one') end
  local ratio=(frame-lastFrame)/(Game.gameSpeed*elapsed)
  if ratio>1.05 then state.catchup=state.catchup+1 end
  if ratio<.95 then state.slow=state.slow+1;invalid('slow_simulation') end
  state.sim=state.sim+frame-lastFrame;state.wall=state.wall+elapsed
  population();lastCheck,lastFrame=now,frame
 end
end
function widget:Shutdown() emit('shutdown') end
