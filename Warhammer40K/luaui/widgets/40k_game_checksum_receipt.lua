-- One unsynced diagnostic receipt for the external two-pass archive gate.
-- Reads only native metadata; installs no model, gameplay or UI hooks.
function widget:GetInfo()
 return {name='40K complete game checksum receipt',desc='Explicit demand review only',author='Local Recoil Project',layer=-100000,enabled=true}
end
local opts=Spring.GetModOptions() or {}
if tonumber(opts.prototype_demand_model_review)~=1 then return false end
local gate=VFS.Include('40k_configs/complete_checksum_handshake.lua')
local function quoted(v)
 if v==nil then return 'null' end
 return '"'..tostring(v):gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r'):gsub('\t','\\t')..'"'
end
local once=false
function widget:Initialize()
 if once then return end
 once=true
 gate.Check(Game,Engine,opts.prototype_lazy_metadata_game_checksum,function(r)
  Spring.Echo('[40K_GAME_CHECKSUM] {"schema":1,"context":"unsynced_widget","game_name":'..quoted(r.game_name)..',"game_version":'..quoted(r.game_version)..',"engine_full_version":'..quoted(r.engine_full_version)..',"actual_checksum":'..quoted(r.actual_checksum)..',"status":'..quoted(r.status)..'}')
 end)
 widgetHandler:RemoveWidget(self)
end
