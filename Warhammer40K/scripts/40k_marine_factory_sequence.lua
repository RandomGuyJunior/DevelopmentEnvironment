-- Source clip sequence only. Caller owns native poses/stance and genuine paid
-- completion evidence; no health/resources/orders or fabricated births here.
local M={}
local order={hq={'production_open','production_rise','production_drop','production_recess','production_close'},barracks={'production','production_drop','production_recess','production_close'}}
function M.New(clips,kind)
 local labels=assert(order[kind],'Unknown genuine Marine factory')
 local hold=kind=='hq' and 2 or 1
 for _,label in ipairs(labels)do local c=assert(clips[label],'Missing source stage '..label);assert(c.frames and #c.frames>0 and c.source_fps and c.source_fps>0)end
 local state={stage=0,start=0,ready=false,building=false,finished=false,closing=false}
 local function span(i)local c=clips[labels[i]];return #c.frames/c.source_fps*30 end
 local function enter(i,f)state.stage=i;state.start=f;state.ready=false end
 local api={}
 function api.Activate(f)
  -- A real native yard activation supersedes a previous idle close, including
  -- one received during queued opening. Keep the current genuine clip/clock.
  state.closing=false
  if state.stage==0 then enter(1,f)end
 end
 function api.StartBuilding(f)
  if not state.ready or state.building then return false end
  state.building=true;state.finished=false;state.closing=false;return true
 end
 -- Must be called ONLY from actual owned native product-finished evidence.
 -- StopBuilding alone also covers cancellation and is not completion proof.
 function api.ProductFinished(f)
  if not state.building or state.finished then return false end
  state.finished=true;state.building=false;enter(hold+1,f);return true
 end
 function api.StopBuilding(f)
  if state.building then state.building=false;state.finished=false;enter(hold+2,f)end
 end
 function api.Deactivate(f)
  state.closing=true
  if state.ready then enter(hold+2,f)end
 end
 function api.Tick(f)
  local i=state.stage
  if i==0 then return nil,0,false end
  local age=f-state.start
  -- Preserve elapsed native time across stage boundaries; never loop/truncate.
  while age>=span(i)do
   local nextStage=i+1
   if i==hold then
    state.ready=not state.closing
    if not state.closing then return clips[labels[i]],span(i)/30,state.ready end
    nextStage=hold+2 -- early deactivation must never invent a completed drop
   elseif i==#labels then
    state.stage=0;state.ready=false;return clips[labels[i]],span(i)/30,false
   end
   state.start=state.start+span(i);i=nextStage;state.stage=i;age=f-state.start
  end
  return clips[labels[i]],age/30,state.ready
 end
 function api.State()return state.stage,state.ready,state.building,state.finished end
 return api
end
return M
