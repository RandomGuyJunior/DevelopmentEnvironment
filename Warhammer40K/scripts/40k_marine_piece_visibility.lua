-- levels are genuine generated vis_default/vis_upgrade_1/vis_upgrade_2 sets.
-- meshPieces is the instrumented WHM mesh -> retained native piece-name map.
-- Call only within UnitScript, after verified paid HQ-local addon evidence.
local M={}
function M.New(meshPieces,levels,resolve,show,hide)
 assert(levels[0] and levels[1] and levels[2],'Genuine visibility levels required')
 local refs={};for mesh,names in pairs(meshPieces)do refs[mesh]={};for _,name in ipairs(names)do local p=resolve(name);assert(p~=nil,'Native source piece missing '..name);refs[mesh][#refs[mesh]+1]=p end end
 local api={}
 function api.Apply(level)
  local visible=assert(levels[level],'Invalid genuine HQ visibility level')
  for mesh,pieces in pairs(refs)do
   assert(visible[mesh]~=nil,'Unspecified source mesh visibility '..mesh)
   for _,p in ipairs(pieces)do if visible[mesh]then show(p)else hide(p)end end
  end
 end
 return api
end
return M
