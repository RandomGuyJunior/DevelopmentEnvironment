-- Presentation-only phase clock. Call exclusively from actual native FireWeapon.
-- It cannot create shots, alter reloads, or authorize a melee contact.
local M={}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function integer(v)return finite(v)and v>=0 and v==math.floor(v)end
function M.New(clip,options)
 options=options or{}
 if options.kind~='ranged'or type(clip)~='table'or clip.contact_frame~=nil then return nil,'verified_ranged_clip_required'end
 local count=type(clip.frames)=='table'and #clip.frames or 0
 local fps=clip.source_fps;local simulation=options.simulation_fps or 30
 if count<2 or not finite(fps)or fps<=0 or not finite(simulation)or simulation<=0 then return nil,'invalid_source_clock'end
 if not finite(clip.duration)or math.abs(clip.duration-count/fps)>1e-4 then return nil,'incomplete_source_cycle'end
 local interval=options.native_fire_interval_frames
 if not integer(interval)or interval<1 then return nil,'actual_native_interval_required'end
 local hold=options.source_hold_frame or 1
 if not integer(hold)or hold<1 or hold>count then return nil,'invalid_source_hold_frame'end
 local state={blocked=false,lastInput=-1}
 local clock={}
 function clock.OnFireWeapon(frame,currentInterval)
  local actual=currentInterval or interval
  if not integer(frame)or frame<state.lastInput or not integer(actual)or actual<1 or state.blocked then return false end
  if not state.start or frame>=state.finish then state.start=frame end
  -- Bridge the real weapon's next due callback, then finish that entire source
  -- cycle even when no further callbacks arrive. Never synthesize a callback.
  local bridge=math.min(actual,count*simulation/fps)
  local needed=(frame-state.start+bridge)*fps/simulation
  local cycles=math.max(1,math.ceil(needed/count))
  state.finish=state.start+math.ceil(cycles*count*simulation/fps)
  state.last=frame;state.interval=actual;state.lastInput=frame
  return true
 end
 function clock.SetInterrupted(frame,blocked)
  if not integer(frame)or frame<state.lastInput or type(blocked)~='boolean'then return false end
  state.blocked=blocked;state.lastInput=frame
  if blocked then state.start=nil;state.finish=nil;state.last=nil end
  return true
 end
 function clock.Sample(frame,wantsHold)
  if not integer(frame)or frame<state.lastInput then return nil,nil,'invalid_frame'end
  if state.blocked then return nil,nil,'interrupted'end
  if not state.start or frame>=state.finish then
   if wantsHold then return clip.frames[hold],hold,'hold'end
   return nil,nil,'idle'
  end
  local index=math.floor((frame-state.start)*fps/simulation)%count+1
  local mode=frame<=state.last+state.interval and 'sustained'or 'recovery'
  return clip.frames[index],index,mode
 end
 function clock.State()
  return {start=state.start,finish=state.finish,last=state.last,interval=state.interval,blocked=state.blocked}
 end
 return clock
end
return M
