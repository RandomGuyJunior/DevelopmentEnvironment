function gadget:GetInfo()return{name='40K passive normal native observer',desc='Opt-in HWT projectile and allied radar-only receipts',author='Local project',layer=108,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return end
local options=Spring.GetModOptions()or{}
local function enabled(v)return v==true or v==1 or v=='1'end
-- Refuse before loading observer code; absent option is the ordinary default.
if not enabled(options.prototype_normal_native_observer)then return end
local M=VFS.Include('40k_configs/normal_native_observer.lua')
if not M.Enabled(options)then return end
local O=M.New(Spring,UnitDefs,WeaponDefs,UnitDefNames,Script,VFS.Include('40k_configs/wraith_paid_native_json.lua'))
function gadget:Initialize()O.Initialize()end
function gadget:GameFrame(f)O.Frame(f)end
function gadget:GameFramePost(f)O.PostFrame(f)end
function gadget:UnitCreated(id)O.Register(id)end
function gadget:UnitFinished(id)O.Register(id)end
function gadget:UnitDestroyed(id)O.Remove(id)end
function gadget:UnitTaken(id)O.Remove(id)end
function gadget:UnitGiven(id)O.Register(id)end
function gadget:ProjectileCreated(id,owner,weapon)O.Projectile(id,owner,weapon)end
function gadget:UnitEnteredRadar(...)O.Contact(...)end
function gadget:UnitLeftRadar(...)O.Contact(...)end
function gadget:UnitEnteredLos(...)O.Contact(...)end
function gadget:UnitLeftLos(...)O.Contact(...)end
-- Projectile watch registration is shared with other passive probes; never unset it.
