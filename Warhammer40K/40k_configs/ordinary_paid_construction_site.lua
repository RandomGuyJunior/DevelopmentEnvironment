-- Exact ordinary Immortal stock spot/snapped construction placement, shared read-only.
local M={Version=1}
function M.Choose(S,UnitDefs,GG,Game,def,builder,metal,emit,accept)
 local cx,_,cz=S.GetUnitPosition(builder);local d=UnitDefs[def]
 if metal then
  local api=GG.resource_spot_finder
  if not api then return end -- Never bypass stock spot admission with a guessed pixel.
  if not api.isMetalMap then
   if type(api.metalSpotsList)~='table'or type(api.GetBuildingPositions)~='function'or type(api.IsMexPositionValid)~='function'then return end
   local candidates={}
   for _,spot in ipairs(api.metalSpotsList)do for _,p in ipairs(api.GetBuildingPositions(spot,def,0,true)or{})do
    local distance=(p.x-cx)^2+(p.z-cz)^2
    if distance<=2048^2 then candidates[#candidates+1]={spot=spot,x=p.x,z=p.z,distance=distance}end
   end end
   table.sort(candidates,function(a,b)if a.distance~=b.distance then return a.distance<b.distance end;if a.x~=b.x then return a.x<b.x end;return a.z<b.z end)
   for _,c in ipairs(candidates)do
    local x,y,z=S.Pos2BuildPos(def,c.x,0,c.z,0);y=S.GetGroundHeight(x,z)
    local status,feature=S.TestBuildOrder(def,x,y,z,0)
    if x>d.xsize*4+32 and z>d.zsize*4+32 and x<Game.mapSizeX-d.xsize*4-32 and z<Game.mapSizeZ-d.zsize*4-32
     and status==2 and not feature and api.IsMexPositionValid(c.spot,x,z)
     and #(S.GetUnitsInRectangle(x-d.xsize*4-32,z-d.zsize*4-32,x+d.xsize*4+32,z+d.zsize*4+32)or{})==0 then
     local free=true
     for _,id in ipairs(S.GetUnitsInCylinder(c.spot.x,c.spot.z,Game.extractorRadius or 96)or{})do
      local existing=UnitDefs[S.GetUnitDefID(id)]
      if existing and(existing.extractsMetal or 0)>0 and S.GetUnitIsDead(id)==false then free=false;break end
     end
     if free and(not accept or accept(x,y,z,0))then emit('STOCK_MEX_SITE','x='..x,'z='..z,'full_yield_provider=true','final_snapped_valid=true');return{x,y,z,0}end
    end
   end
   return
  end
 end
 for ring=6,64 do for angle=0,15 do
  local a=angle*math.pi/8;local x,y,z=S.Pos2BuildPos(def,cx+ring*32*math.cos(a),0,cz+ring*32*math.sin(a),0)
  if x>d.xsize*4+32 and z>d.zsize*4+32 and x<Game.mapSizeX-d.xsize*4-32 and z<Game.mapSizeZ-d.zsize*4-32 then
   y=S.GetGroundHeight(x,z);local status,feature=S.TestBuildOrder(def,x,y,z,0)
   if status==2 and not feature and #(S.GetUnitsInRectangle(x-d.xsize*4-32,z-d.zsize*4-32,x+d.xsize*4+32,z+d.zsize*4+32)or{})==0
    and(not metal or(select(3,S.GetGroundInfo(x,z))or 0)>0)and(not accept or accept(x,y,z,0))then return{x,y,z,0}end
  end
 end end
end

return M
