-- Read-only deterministic candidate placement. Caller creates reviewed neutral objective.
local M={AcceptedMaps={['Ravaged Remake v1.2']=true,['Ashen Bastion 0.1']=true},Clearance=150}
function M.Find(S,G,def)
 if not M.AcceptedMaps[G.mapName]then return nil,'map_not_selected' end
 local r=M.Clearance
 local stats={tested=0,bounds=0,dry_height=0,units=0,features=0,native=0,native_samples={}}
 -- Fixed integer-grid rings, no random calls, actor mutation or resource grants.
 for ring=0,12 do for a=0,7 do
  local dx,dz=math.cos(a*math.pi/4)*ring*192,math.sin(a*math.pi/4)*ring*192
  local x,z=math.floor((G.mapSizeX/2+dx)/16)*16,math.floor((G.mapSizeZ/2+dz)/16)*16
  if x>r and z>r and x<G.mapSizeX-r and z<G.mapSizeZ-r then
   stats.tested=stats.tested+1
   local y=S.GetGroundHeight(x,z);local clear=y and y>0
   for _,v in ipairs({{r,0},{-r,0},{0,r},{0,-r}})do
    local h=S.GetGroundHeight(x+v[1],z+v[2]);if not h or h<=0 or math.abs(h-y)>8 then clear=false end
   end
   if not clear then stats.dry_height=stats.dry_height+1
   elseif #(S.GetUnitsInRectangle(x-r,z-r,x+r,z+r)or{})~=0 then stats.units=stats.units+1
   elseif #(S.GetFeaturesInRectangle(x-r,z-r,x+r,z+r)or{})~=0 then stats.features=stats.features+1
   else
    local status,feature=S.TestBuildOrder(def,x,y,z,0)
    if status==2 and feature==nil then return{x=x,y=y,z=z,map=G.mapName,clearance=r,def=def},nil,stats end
    stats.native=stats.native+1
    if #stats.native_samples<8 then stats.native_samples[#stats.native_samples+1]={x=x,y=y,z=z,status=status,feature=feature}end
   end
  else stats.bounds=stats.bounds+1 end
 end end
 return nil,'no_clear_dry_native_site',stats
end
return M
