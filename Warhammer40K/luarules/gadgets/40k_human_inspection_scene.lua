function gadget:GetInfo()return{name='40K six-unit human inspection',desc='One initial direct-spawn scene; then human owns all orders and closure',author='Local project',layer=180,enabled=true}end
local options=Spring.GetModOptions()or{}
local M=VFS.Include('40k_configs/human_inspection_scene.lua')
if not M.Enabled(options)then return false end
local bounds=options.prototype_source_bounds_capture
if bounds==true or bounds==1 or bounds=='1'then return false end
local action='fortyk_human_inspection_ready'
if not gadgetHandler:IsSyncedCode()then
 local used=false
 local function ready(_,cx,y,cz,...)
  if used or Spring.GetMyTeamID()~=0 or Spring.GetSpectatingState()then return end;used=true
  local ids={...};if #ids~=6 then return end
  for _,id in ipairs(ids)do if Spring.GetUnitTeam(id)~=0 then return end end
  Spring.SetCameraTarget(cx,y,cz,0);Spring.SelectUnitArray(ids)
  Spring.Echo('Development inspection: six directly spawned units; orders and window now belong to you. This is not ordinary production acceptance.')
 end
 function gadget:Initialize()gadgetHandler:AddSyncAction(action,ready)end
 function gadget:Shutdown()gadgetHandler:RemoveSyncAction(action)end
 return
end
local attempted=false
function gadget:GameFrame(frame)
 if attempted or frame==0 then return end;attempted=true
 assert(frame==1 and Game.gameSpeed==30,'Fresh inspection scene requires frame1 normal clock')
 assert(Spring.GetTeamInfo(0)~=nil,'Human team0 required')
 local ids=M.Validate(UnitDefs,UnitDefNames);local sites,cx,y,cz=M.Site(Spring,UnitDefs,ids,Game)
 assert(sites,'No safe flat six-unit inspection site; no units spawned')
 local made={}
 for i,key in ipairs(M.Actors)do
  local p=sites[i];local id=Spring.CreateUnit(key,p[1],p[2],p[3],0,0)
  assert(id and Spring.GetUnitDefID(id)==ids[key]and Spring.GetUnitTeam(id)==0,'Exact direct-spawn birth refused: '..key)
  local hp,_,_,_,built=Spring.GetUnitHealth(id);assert(hp and hp>0 and built==1,'Completed inspection actor required: '..key)
  made[i]=id;Spring.Echo('40K_HUMAN_INSPECTION actor='..key..' id='..id..' frame='..frame..' direct_spawn=true ordinary_accepted=false x='..p[1]..' y='..p[2]..' z='..p[3])
 end
 SendToUnsynced(action,cx,y,cz,unpack(made))
 Spring.Echo('40K_HUMAN_INSPECTION READY count=6 auto_orders=false auto_shutdown=false human_owned=true')
end
