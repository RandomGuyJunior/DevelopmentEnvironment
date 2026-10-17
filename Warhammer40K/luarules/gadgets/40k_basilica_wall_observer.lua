function gadget:GetInfo()return{name='40K Basilica wall read-only observer',desc='No setup/orders/paid acceptance',author='Local project',layer=182,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return false end
local o=Spring.GetModOptions()or{}
if o.prototype_basilica_wall_observer~=true and o.prototype_basilica_wall_observer~=1 and o.prototype_basilica_wall_observer~='1'then return false end
local A
local function log(r)
 if r.status=='sample'then local h={};for i=1,#r.payload do h[i]=string.format('%02x',r.payload:byte(i))end;Spring.Echo('40K_BASILICA_WALL SAMPLE '..r.frame..' '..r.checksum..' '..table.concat(h))
 elseif r.status=='complete'then Spring.Echo('40K_BASILICA_WALL COMPLETE '..r.frame..' '..r.samples)
 else Spring.Echo('40K_BASILICA_WALL REFUSED '..r.frame..' '..tostring(r.reason))end
end
function gadget:Initialize()
 local ok,result=pcall(function()
  assert(o.prototype_diagnostic=='normal','ordinary_diagnostic_required')
  local function on(v)return v==true or v==1 or v=='1'end
  assert(on(o.prototype_squad_state_digest)and on(o.prototype_feature_remains_digest),'paired_body_feature_observers_required')
  return VFS.Include('40k_configs/basilica_wall_observer.lua').New(Spring,FeatureDefs,Game,o.prototype_squad_state_digest_source,o.prototype_squad_state_digest_frames,log,VFS.Include('40k_configs/squad_state_digest.lua'))
 end)
 if not ok then Spring.Echo('40K_BASILICA_WALL REFUSED 0 '..tostring(result));gadgetHandler:RemoveGadget(self);return end;A=result
end
function gadget:GameFrame(f)A.Frame(f)end
function gadget:FeatureCreated(...)A.FeatureCreated(...)end
function gadget:FeatureDamaged(...)A.FeatureDamaged(...)end
function gadget:FeatureDestroyed(...)A.FeatureDestroyed(...)end
