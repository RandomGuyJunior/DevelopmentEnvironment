-- Client-only pose planning; no Spring/UnitScript/gl calls or simulation state writes.
local M={}
M.SourceActions={death_1='die_1',death_2='die_2',death_3='die_3'}
local function finite(v)return type(v)=='number' and v==v and math.abs(v)<math.huge end
-- Caller provides a copied display snapshot after native UnitDestroyed, not a live actor.
-- No random variant selection: stable actor ID selects among proven available clips.
function M.Begin(data,snapshot,nativeDestroyed)
 if nativeDestroyed~=true or type(snapshot)~='table' or snapshot.visible~=true or type(data)~='table' or type(data.clips)~='table' or type(snapshot)~='table'
  or not finite(snapshot.unitID) or snapshot.unitID%1~=0 or snapshot.unitID<0
  or not finite(snapshot.destroyedFrame) or snapshot.destroyedFrame<0
  or not finite(snapshot.x) or not finite(snapshot.y) or not finite(snapshot.z) or not finite(snapshot.heading)
  or not finite(snapshot.teamID) or snapshot.teamID<0 or snapshot.teamID%1~=0 then return nil end
 local labels={}
 for _,label in ipairs({'death_1','death_2','death_3'})do
  local c=data.clips[label]
  if c and c.source==M.SourceActions[label] and type(c.frames)=='table' and #c.frames>0
   and finite(c.source_fps) and c.source_fps>0 and finite(c.duration) and c.duration>0 then labels[#labels+1]=label end
 end
 if #labels==0 then return nil end
 local label=labels[snapshot.unitID%#labels+1];local c=data.clips[label]
 -- Frame array and source fps are the same clock contract used by source-pose runtime.
 local seconds=#c.frames/c.source_fps
 return {label=label,clip=c,frames=c.frames,fps=c.source_fps,seconds=seconds,
  snapshot={unitID=snapshot.unitID,teamID=snapshot.teamID,destroyedFrame=snapshot.destroyedFrame,
   x=snapshot.x,y=snapshot.y,z=snapshot.z,heading=snapshot.heading},presentationOnly=true}
end
-- Absolute render frame can include the engine's fractional render offset.
-- Returns only immutable exported row and captured display transform. No death delays.
function M.Sample(plan,renderFrame)
 if type(plan)~='table' or plan.presentationOnly~=true or not finite(renderFrame) then return nil end
 local age=(renderFrame-plan.snapshot.destroyedFrame)/30
 if age<0 or age>=plan.seconds then return nil end
 local index=math.min(#plan.frames,math.floor(age*plan.fps)+1)
 return plan.frames[index],plan.snapshot,index
end
return M
