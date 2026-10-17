-- Diagnostic route policy only. Read-only destination tests, not path proof.
local M={Name='cardinal320_E_W_S_N_v1'}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
function M.Plan(S,D,id,origin,mapX,mapZ)
 local receipt={policy=M.Name,id=id,attempts={}}
 if type(origin)~='table'or not finite(origin[1])or not finite(origin[2])or not finite(mapX)or not finite(mapZ)or mapX<=256 or mapZ<=256 then return nil,receipt,'invalid_origin_or_map'end
 if origin[1]<=128 or origin[2]<=128 or origin[1]>=mapX-128 or origin[2]>=mapZ-128 then return nil,receipt,'origin_outside_map_margin'end
 for _,name in ipairs({'GetUnitDefID','GetUnitPosition','GetGroundHeight','TestMoveOrder'})do if type(S[name])~='function'then return nil,receipt,'missing_'..name end end
 local def=S.GetUnitDefID(id);local d=def and D[def];if not d then return nil,receipt,'missing_native_definition'end
 local x,y,z=S.GetUnitPosition(id);if not finite(x)or not finite(y)or not finite(z)then return nil,receipt,'missing_native_position'end
 receipt.definition=def;receipt.unitName=d.name;receipt.spawn={x=origin[1],z=origin[2]};receipt.actual={x=x,y=y,z=z};receipt.originalGoal={x=origin[1]+320,z=origin[2]}
 local md=d.moveDef;receipt.moveDef=md and {name=md.name,xsize=md.xsize,zsize=md.zsize,maxSlope=md.maxSlope,depth=md.depth}or'UNKNOWN'
 for _,direction in ipairs({{'E',320,0},{'W',-320,0},{'S',0,320},{'N',0,-320}})do
  local g={direction=direction[1],x=origin[1]+direction[2],z=origin[2]+direction[3]};receipt.attempts[#receipt.attempts+1]=g
  if g.x<=128 or g.z<=128 or g.x>=mapX-128 or g.z>=mapZ-128 then g.result='map_margin_refused'
  else
   g.y=S.GetGroundHeight(g.x,g.z)
   if not finite(g.y)then g.result='ground_height_unknown'
   else
    local valid=S.TestMoveOrder(def,g.x,g.y,g.z,0,0,0,true,false,false)
    g.nativeTerrain=valid==true;g.result=valid==true and 'native_destination_pass' or 'native_destination_refused_or_unknown'
    if valid==true then receipt.selected=direction[1];receipt.originalRefused=direction[1]~='E';return g,receipt end
   end
  end
 end
 return nil,receipt,'all_cardinal320_destinations_refused'
end
return M
