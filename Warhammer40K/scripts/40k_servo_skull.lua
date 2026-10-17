-- Decorative source skeleton only. Native builders own work, targets and spray.
-- Invoke only through the narrow Create/Tick/Query hooks; no extra thread/entity.
local M={}
function M.New(unit,cp,map,lookup,api,bank)
 if tostring(cp.source_servoskull or'')~='attached_v1'then return nil end
 assert(cp.source_nanopiece=='servo_skull_nano','Servo emitter contract differs')
 assert(api.SetUnitNanoPieces and api.Move and api.Turn,'Servo native presentation API missing')
 assert(bank and bank.clips and bank.clips.idle,'Genuine servo idle bank missing')
 local modelPiece=assert(map.servo_skull_nano,'Servo model emitter missing')
 local query=assert(lookup('servo_skull_nano'),'Servo script emitter missing')
 assert(map.servo_skull_mount and lookup('servo_skull_mount'),'Servo parent mount missing')
 local handles={}
 for i,n in ipairs(bank.bones)do
  assert(n:sub(1,6)=='servo_','Servo bank attempted body ownership')
  handles[i]=assert(lookup(n),'Servo source bone missing: '..n)
 end
 local idle=bank.clips.idle
 assert(#handles==6 and #idle.frames>0 and idle.source_fps>0,'Invalid genuine servo idle')
 local created=false;local previous={};local lastFrame
 local c={}
 function c.Create()
  if created then return end
  -- Model-piece indices are Lua one-based; replace rather than append cached body emitters.
  api.SetUnitNanoPieces(unit,{modelPiece});created=true
 end
 function c.Query()return query end
 function c.Tick(frame)
  if not created or lastFrame==frame then return end
  lastFrame=frame
  -- Frame clock only: no RNG, camera input, work commands or economic state.
  local row=idle.frames[math.floor(math.max(0,frame)*idle.source_fps/30)%#idle.frames+1]
  for i,p in ipairs(handles)do
   local values=row[i];assert(values and #values==6,'Invalid servo pose row')
   local last=previous[i]or{};previous[i]=last
   for axis=1,3 do
    if last[axis]~=values[axis]then api.Move(p,axis,values[axis]);last[axis]=values[axis]end
    if last[axis+3]~=values[axis+3]then api.Turn(p,axis,values[axis+3]);last[axis+3]=values[axis+3]end
   end
  end
 end
 return c
end
return M
