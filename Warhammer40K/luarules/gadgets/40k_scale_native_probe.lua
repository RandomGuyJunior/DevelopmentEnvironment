function gadget:GetInfo()
 return{name='40K read-only native scale geometry probe',desc='Default-off bounded existing actor geometry telemetry',author='Local project',layer=154,enabled=true}
end
local M=VFS.Include('40k_configs/scale_native_probe.lua')
if not M.Enabled(Spring.GetModOptions()or{})or not gadgetHandler:IsSyncedCode()then return false end
GG.Prototype40kAnimationCache=GG.Prototype40kAnimationCache or{}
local P=M.New(Spring,UnitDefs,VFS,Spring.Echo,GG.Prototype40kAnimationCache,GG)
function gadget:Initialize()GG.Recoil40KNativeGaitObserve=P.GaitFrame end
function gadget:Shutdown()if GG.Recoil40KNativeGaitObserve==P.GaitFrame then GG.Recoil40KNativeGaitObserve=nil end end
local initial=false
function gadget:UnitCreated(id,def)P.Created(id,def,Spring.GetGameFrame())end
function gadget:UnitFinished(id,def)P.Finished(id,def,Spring.GetGameFrame())end
function gadget:UnitDestroyed(id)P.Destroyed(id)end
function gadget:GameFrame(frame)
 if not initial then P.Initial(frame);initial=true end
 P.Frame(frame)
 P.GaitFrame(frame)
end
