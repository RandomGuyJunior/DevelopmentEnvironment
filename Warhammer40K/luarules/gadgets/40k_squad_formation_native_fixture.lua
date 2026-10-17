function gadget:GetInfo()return{name='40K controlled shared formation diagnostic',desc='Real8 native queued product then obstacle/orders/succession observations',author='Local project',layer=180,enabled=true}end
local options=Spring.GetModOptions()or{}
if not(options.prototype_squad_formation_native_fixture==true or options.prototype_squad_formation_native_fixture==1 or options.prototype_squad_formation_native_fixture=='1')then return false end
local action='fortyk_shared_formation_done'
if not gadgetHandler:IsSyncedCode()then
 local closeAt
 local function done(_,result)Spring.Echo('40K_FORMATION_NATIVE owned_fixture_autoclose '..tostring(result));closeAt=Spring.GetGameFrame()+30 end
 function gadget:Initialize()gadgetHandler:AddSyncAction(action,done)end
 function gadget:GameFrame(frame)if closeAt and frame>=closeAt then closeAt=nil;Spring.SendCommands('quitforce')end end
 function gadget:Shutdown()gadgetHandler:RemoveSyncAction(action)end
 return
end
local C;local closed=false
local function emit(event,...)
 local row={...};for i=1,#row do row[i]=tostring(row[i])end
 -- Distinct explanatory namespace: never an extra acceptance event.
 if event:sub(1,7)=='TRIAGE_'then Spring.Echo('40K_FORMATION_TRIAGE '..event:sub(8)..' '..table.concat(row,' '))
 else Spring.Echo('40K_FORMATION_NATIVE '..event..' '..table.concat(row,' '))end
end
function gadget:GameFrame(frame)
 if closed or frame<2 then return end
 if not C then C=VFS.Include('40k_configs/formation_native_fixture.lua').New(Spring,UnitDefs,UnitDefNames,VFS.Include('40k_configs/active_squad_profiles.lua'),GG.Recoil40KSquads,GG.Recoil40KSquadFormation,GG,Game,options,VFS.Include('40k_configs/guard_factory_egress_geometry.lua'),emit)end
 local result=C.result or C.Step and C.Step(frame)
 if result then closed=true;emit('CLOSED_RESULT',result,'nativeAccepted=false paidEconomyAccepted=false exactDebitAccepted=false renderAccepted=false');SendToUnsynced(action,result)end
end
function gadget:UnitCreated(...)if C and C.Created then C.Created(...)end end
function gadget:UnitFinished(...)if C and C.Finished then C.Finished(...)end end
function gadget:UnitFromFactory(...)if C and C.Released then C.Released(...)end end
function gadget:UnitDestroyed(...)if C and C.Destroyed then C.Destroyed(...)end end
-- Exact explicit diagnostic self-closes after30frames. Native process ownership
-- remains coordinator-only; fast externally forced closure is separately recorded.
