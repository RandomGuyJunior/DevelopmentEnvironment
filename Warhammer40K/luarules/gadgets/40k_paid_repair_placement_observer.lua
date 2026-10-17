function gadget:GetInfo()return{name='40K paid Guard repair placement observer',desc='Default-off read-only bounded placement probes',author='Local project',layer=182,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return false end
local o=Spring.GetModOptions()or{}
if o.prototype_paid_repair_placement_observer~=true and o.prototype_paid_repair_placement_observer~=1 and o.prototype_paid_repair_placement_observer~='1'then return false end
local observer
local function receipt(r)
 if r.status=='sample'then local h={};for i=1,#r.payload do h[i]=string.format('%02x',r.payload:byte(i))end;Spring.Echo('40K_PAID_REPAIR_PLACEMENT SAMPLE '..r.frame..' '..r.checksum..' '..table.concat(h))
 elseif r.status=='complete'then Spring.Echo('40K_PAID_REPAIR_PLACEMENT COMPLETE '..r.frame..' '..r.samples)
 else Spring.Echo('40K_PAID_REPAIR_PLACEMENT REFUSED '..r.frame..' '..tostring(r.reason))end
end
function gadget:Initialize()
 local ok,value=pcall(function()
  assert(o.prototype_guard_squad_paid_research_fixture==true or o.prototype_guard_squad_paid_research_fixture==1 or o.prototype_guard_squad_paid_research_fixture=='1','ordinary_Guard_paid_fixture_required')
  return VFS.Include('40k_configs/paid_repair_placement_observer.lua').New(Spring,GG,UnitDefs,UnitDefNames,VFS.Include('40k_configs/active_squad_profiles.lua'),VFS.Include('40k_configs/squad_state_digest.lua'),o.prototype_paid_repair_placement_frames,
   {source=o.prototype_squad_state_digest_source,engine=Engine.versionFull,game=Game.modChecksum,map=Game.mapChecksum},receipt)
 end)
 if not ok then receipt{status='refused',frame=Spring.GetGameFrame(),reason=value};gadgetHandler:RemoveGadget(self);return end;observer=value
end
function gadget:GameFrame(frame)observer.Frame(frame)end
function gadget:UnitCreated(id,def,team,builder)if observer then observer.Created(id,def,team,builder)end end
function gadget:UnitDestroyed(id)if observer then observer.Destroyed(id)end end
