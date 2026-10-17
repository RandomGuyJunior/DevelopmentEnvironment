-- Source-review HQ visibility/construction. Native factory/economy own simulation.
local M={}
function M.New(meta,data,api)
 assert(type(meta.meshPieces)=='table'and type(meta.clip_visibility)=='table','Genuine fullmesh metadata required')
 local handles={};local count=0
 for name,pieces in pairs(meta.meshPieces)do
  handles[name]={};count=count+1
  for _,pieceName in ipairs(pieces)do handles[name][#handles[name]+1]=assert(api.resolve(pieceName),'Missing genuine HQ mesh piece '..pieceName)end
 end
 assert(count==18,'All source meshes required')
 for _,label in ipairs({'construction_1','construction_2','placement','upgrade_base','upgrade_fort'})do assert(data.clips[label]and meta.clip_visibility[label],'Missing genuine HQ action '..label)end
 local R={created=api.frame(),current=nil,phase=nil,isFactory=true}
 local function visibility(name,map)
  if R.current==name then return end
  for mesh,pieces in pairs(handles)do assert(type(map[mesh])=='boolean','Incomplete source visibility map '..mesh)
   for _,handle in ipairs(pieces)do if map[mesh]then api.show(handle)else api.hide(handle)end end
  end
  R.current=name
 end
 local function duration(clip)return tonumber(clip.duration)or(#clip.frames/math.max(1,tonumber(clip.fps)or 30))end
 function R.Tick(frame)
  local progress=api.progress()
  if type(progress)~='number'or progress<0 or progress>1 then return nil,nil,nil,'unreadable_build_progress' end
  if progress<1 then
   local label,age
   if progress<.2 then label='construction_1';age=math.max(0,(frame-R.created)/30)
   else label='construction_2';age=duration(data.clips[label])*math.max(0,math.min(1,(progress-.2)/.8))end
   visibility(label,meta.clip_visibility[label]);R.phase=label
   return data.clips[label],math.min(age,duration(data.clips[label])),nil,label
  end
  local level=api.level()or 0;assert(level==0 or level==1,'No invented HQ tier')
  local label=level==1 and'upgrade_fort'or'upgrade_base'
  local map=meta.levels[level]or meta.levels[tostring(level)];assert(map,'Missing genuine completed HQ tier')
  visibility('completed'..level,map);R.phase='completed'..level
  return nil,nil,data.clips[label],R.phase
 end
 function R.Create()visibility('placement',meta.clip_visibility.placement)end
 return R
end
return M
