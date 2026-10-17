function gadget:GetInfo()return{name='40K bounded synced state digest',desc='Default-off read-only common-frame observer; native replay acceptance external',author='Local project',layer=180,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return false end
local options=Spring.GetModOptions()or{}
if options.prototype_squad_state_digest~=true and options.prototype_squad_state_digest~=1 and options.prototype_squad_state_digest~='1'then return false end
local observer
local function hex(text)local out={};for i=1,#text do out[i]=string.format('%02x',text:byte(i))end;return table.concat(out)end
local function receipt(r)
 if r.status=='sample'then Spring.Echo('40K_STATE_DIGEST SAMPLE '..r.frame..' '..r.checksum..' '..hex(r.payload))
 elseif r.status=='complete'then Spring.Echo('40K_STATE_DIGEST COMPLETE '..r.frame..' '..r.samples)
 else Spring.Echo('40K_STATE_DIGEST REFUSED '..r.frame..' '..tostring(r.reason))end
end
function gadget:Initialize()
 local ok,result=pcall(function()
  assert(options.prototype_diagnostic=='normal','ordinary_diagnostic_required')
  return VFS.Include('40k_configs/squad_state_digest.lua').New(Spring,GG,{source=options.prototype_squad_state_digest_source,
   engine=Engine and Engine.version,engineFull=Engine and Engine.versionFull,gameChecksum=Game.modChecksum,mapChecksum=Game.mapChecksum},options.prototype_squad_state_digest_frames,receipt)
 end)
 if not ok then Spring.Echo('40K_STATE_DIGEST REFUSED 0 '..tostring(result));gadgetHandler:RemoveGadget(self);return end
 observer=result
end
function gadget:GameFrame(frame)observer.Frame(frame)end
