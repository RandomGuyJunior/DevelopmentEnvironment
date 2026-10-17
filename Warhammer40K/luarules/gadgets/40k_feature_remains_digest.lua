function gadget:GetInfo()return{name='40K feature remains digest supplement',desc='Default-off read-only bounded common frames',author='Local project',layer=181,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return false end
local o=Spring.GetModOptions()or{}
if o.prototype_feature_remains_digest~=true and o.prototype_feature_remains_digest~=1 and o.prototype_feature_remains_digest~='1'then return false end
local observer
local function receipt(r)
 if r.status=='sample'then local h={};for i=1,#r.payload do h[i]=string.format('%02x',r.payload:byte(i))end;Spring.Echo('40K_FEATURE_DIGEST SAMPLE '..r.frame..' '..r.checksum..' '..table.concat(h))
 elseif r.status=='complete'then Spring.Echo('40K_FEATURE_DIGEST COMPLETE '..r.frame..' '..r.samples)
 else Spring.Echo('40K_FEATURE_DIGEST REFUSED '..r.frame..' '..tostring(r.reason))end
end
function gadget:Initialize()
 local ok,result=pcall(function()
  assert(o.prototype_diagnostic=='normal','ordinary_diagnostic_required')
  assert(o.prototype_squad_state_digest==true or o.prototype_squad_state_digest==1 or o.prototype_squad_state_digest=='1','paired_body_digest_required')
  return VFS.Include('40k_configs/feature_remains_digest.lua').New(Spring,GG,{source=o.prototype_squad_state_digest_source,engine=Engine and Engine.version,engineFull=Engine and Engine.versionFull,gameChecksum=Game.modChecksum,mapChecksum=Game.mapChecksum},o.prototype_squad_state_digest_frames,receipt,VFS.Include('40k_configs/squad_state_digest.lua'))
 end)
 if not ok then Spring.Echo('40K_FEATURE_DIGEST REFUSED 0 '..tostring(result));gadgetHandler:RemoveGadget(self);return end;observer=result
end
function gadget:GameFrame(frame)observer.Frame(frame)end
