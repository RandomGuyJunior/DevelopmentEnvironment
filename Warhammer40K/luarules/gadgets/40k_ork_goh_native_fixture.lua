function gadget:GetInfo()return{name='40K exact GOH native diagnostic',desc='Default-off scoped motion mobile muzzles and one wreck; no economy acceptance',author='Local project',layer=160,enabled=true}end
local options=Spring.GetModOptions()or{}
local bounds=options.prototype_source_bounds_capture
if bounds==true or bounds==1 or bounds=='1'then return false end
local enabled=options.prototype_ork_goh_native_fixture==true or options.prototype_ork_goh_native_fixture==1 or options.prototype_ork_goh_native_fixture=='1'
if not enabled or(options.prototype_ork_goh_native_actor~='warbike'and options.prototype_ork_goh_native_actor~='morkanaut')then return false end
local action='fortyk_ork_goh_native_done'
if not gadgetHandler:IsSyncedCode()then
 local closeAt
 function gadget:Initialize()gadgetHandler:AddSyncAction(action,function()closeAt=Spring.GetGameFrame()+60 end)end
 function gadget:GameFrame(frame)if closeAt and frame>=closeAt then closeAt=nil;Spring.SendCommands('quitforce')end end
 function gadget:Shutdown()gadgetHandler:RemoveSyncAction(action)end
 return
end
local controller,terminal
local function log(event,...)
 local a={...};for i,v in ipairs(a)do a[i]=tostring(v)end
 Spring.Echo('40K_GOH_NATIVE '..event..' '..table.concat(a,' '))
end
function gadget:Initialize()
 controller=VFS.Include('40k_configs/ork_goh_native_fixture.lua').New(Spring,UnitDefs,UnitDefNames,WeaponDefs,FeatureDefs,GG,Script,Game,CMD,options,log)
end
function gadget:GameFrame(frame)
 if terminal then return end
 local result=controller.Step(frame)
 if result then terminal=result;controller.Close();SendToUnsynced(action,result)end
end
function gadget:ProjectileCreated(...)if controller then controller.Projectile(...)end end
function gadget:UnitDamaged(id,def,team,damage,paralyzer,wid,pid,attacker)if controller then controller.Damaged(id,damage,paralyzer,wid,pid,attacker)end end
function gadget:Shutdown()if controller then controller.Close()end end
