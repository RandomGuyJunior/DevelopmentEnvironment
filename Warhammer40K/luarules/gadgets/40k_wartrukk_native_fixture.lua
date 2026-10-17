function gadget:GetInfo()return{name='40K exact ground Wartrukk full8 diagnostic',desc='Default-off spawned setup, native paid products and repeated real-body transport',author='Local project',layer=161,enabled=true}end
local options=Spring.GetModOptions()or{}
local bounds=options.prototype_source_bounds_capture
if bounds==true or bounds==1 or bounds=='1'then return false end
local v=options.prototype_wartrukk_native_fixture
if v~=true and v~=1 and v~='1'then return false end
local action='fortyk_wartrukk_native_done'
if not gadgetHandler:IsSyncedCode()then
 local finishAt
 function gadget:Initialize()gadgetHandler:AddSyncAction(action,function()finishAt=Spring.GetGameFrame()+60 end)end
 function gadget:GameFrame(frame)if finishAt and frame>=finishAt then finishAt=nil;Spring.SendCommands('quitforce')end end
 function gadget:Shutdown()gadgetHandler:RemoveSyncAction(action)end
 return
end
local controller,terminal
local function log(event,...)local t={...};for i,v in ipairs(t)do t[i]=tostring(v)end;Spring.Echo('40K_WARTRUKK_NATIVE '..event..' '..table.concat(t,' '))end
function gadget:Initialize()controller=VFS.Include('40k_configs/wartrukk_native_fixture.lua').New(Spring,UnitDefs,UnitDefNames,FeatureDefs,GG,Game,CMD,VFS.Include('40k_configs/guard_factory_egress_geometry.lua'),options,log)end
function gadget:GameFrame(frame)if terminal then return end;local why=controller.Step(frame);if why then terminal=why;controller.Close();SendToUnsynced(action,why)end end
function gadget:UnitCreated(...)if controller and controller.ids then controller.Created(...)end end
function gadget:UnitFinished(...)if controller then controller.Finished(...)end end
function gadget:UnitFromFactory(...)if controller then controller.Released(...)end end
function gadget:UnitLoaded(...)if controller then controller.Loaded(...)end end
function gadget:UnitUnloaded(...)if controller then controller.Unloaded(...)end end
function gadget:Shutdown()if controller then controller.Close()end end
