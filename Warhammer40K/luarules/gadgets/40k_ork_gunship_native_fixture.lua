function gadget:GetInfo()return{name='40K approved Gunship model diagnostic',desc='Default-off user-controlled seven-turret volley preview with real passive ground/air targets; no economy acceptance',author='Local project',layer=159,enabled=true}end
local o=Spring.GetModOptions()or{};local v=o.prototype_ork_gunship_native_fixture
if not(v==true or v==1 or v=='1')then return false end
local action='fortyk_ork_gunship_native_done'
if not gadgetHandler:IsSyncedCode()then
 local closeAt
 function gadget:Initialize()gadgetHandler:AddSyncAction(action,function(_,reason)Spring.Echo('40K_GUNSHIP_NATIVE owned_autoclose '..reason);closeAt=Spring.GetGameFrame()+90 end)end
 function gadget:GameFrame(frame)if closeAt and frame>=closeAt then closeAt=nil;Spring.SendCommands('quitforce')end end
 function gadget:Shutdown()gadgetHandler:RemoveSyncAction(action)end
 return
end
local C,terminal
local function log(event,...)local a={...};for i,v in ipairs(a)do a[i]=tostring(v)end;Spring.Echo('40K_GUNSHIP_NATIVE '..event..' '..table.concat(a,' '))end
function gadget:Initialize()C=VFS.Include('40k_configs/ork_gunship_loadout_fixture.lua').New(Spring,UnitDefs,UnitDefNames,WeaponDefs,GG,Script,Game,CMD,o,nil,log)end
function gadget:GameFrame(frame)if terminal then return end;local r=C.Step(frame);if r then terminal=r;C.Close();if o.prototype_ork_gunship_native_mode~='human'then SendToUnsynced(action,r)end end end
function gadget:UnitCreated(...)if C then C.Created(...)end end
function gadget:UnitFinished(...)if C then C.Finished(...)end end
function gadget:UnitFromFactory(...)if C then C.Released(...)end end
function gadget:ProjectileCreated(...)if C then C.Projectile(...)end end
function gadget:UnitDamaged(id,def,team,damage,para,weapon,pid,attacker)if C then C.Damaged(id,damage,para,weapon,pid,attacker)end end
function gadget:Explosion(...)if C then return C.Explosion(...)end;return false end
function gadget:Shutdown()if C then C.Close()end end
