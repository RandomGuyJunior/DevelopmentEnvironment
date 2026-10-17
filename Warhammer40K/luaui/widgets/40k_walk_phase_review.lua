function widget:GetInfo()return {name='40K opted native walking phase readback',desc='Same-frame after-simulation limb matrices paired with exact source phase',author='Local project',layer=1005,enabled=true}end
local options=Spring.GetModOptions()
if tostring(options.prototype_walk_sampling_review or '0')~='1'
 or tostring(options.prototype_animation_interpolation or '0')~='1'
 or tostring(options.prototype_fractional_walk_sampling or '0')~='1' then return end
local seen,counts={},{}
local function names(id)
 local map=Spring.GetUnitPieceMap(id) or {};local selected={}
 for name in pairs(map)do
  local lower=name:lower()
  if lower:find('pelvis',1,true) or lower:find('hip',1,true) or lower:find('thigh',1,true)
   or lower:find('calf',1,true) or lower:find('knee',1,true) or lower:find('foot',1,true) then
   local parent=name;local visited={}
   while parent and map[parent] and not visited[parent] do
    visited[parent]=true;selected[parent]=map[parent]
    local info=Spring.GetUnitPieceInfo(id,map[parent]);parent=info and info.parent
   end
  end
 end
 local sorted={};for name in pairs(selected)do sorted[#sorted+1]=name end;table.sort(sorted)
 return sorted,selected
end
function widget:Update()
 local f=Spring.GetGameFrame()
 for _,id in ipairs(Spring.GetAllUnits())do
  local sampled=Spring.GetUnitRulesParam(id,'40k_walk_review_frame')
  if sampled==f and seen[id]~=f and (counts[id] or 0)<120 then
   seen[id]=f;counts[id]=(counts[id] or 0)+1
   local def=Spring.GetUnitDefID(id);local ud=def and UnitDefs[def]
   local source=ud and ud.customParams and ud.customParams.animsource
   if source then
    local ordered,pieces=names(id);local count=0
    for _,name in ipairs(ordered)do
     local values={Spring.GetUnitPieceMatrix(id,pieces[name])}
     if #values==16 then
      count=count+1;local formatted={}
      for i,value in ipairs(values)do formatted[i]=string.format('%.17g',value)end
      Spring.Echo('40K WALK NATIVE',source,id,f,name,unpack(formatted))
     end
    end
    local vx,vy,vz=Spring.GetUnitVelocity(id);local x,y,z=Spring.GetUnitPosition(id)
    Spring.Echo('40K WALK AFTER SIM',source,id,f,count,x or 0,y or 0,z or 0,vx or 0,vy or 0,vz or 0)
   end
  end
 end
end
