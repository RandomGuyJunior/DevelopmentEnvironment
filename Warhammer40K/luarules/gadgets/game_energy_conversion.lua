-- Project-owned wrapper. The copied pinned dependency remains private/ignored.
-- Gadget-local Spring proxy: no global API replacement and no economy rewrite.
local env=getfenv(1)
local native=Spring
local bridge=VFS.Include('40k_configs/converter_script_bridge.lua')
env.Spring=bridge.Proxy(native,UnitDefs)
local ok,result=pcall(VFS.Include,'40k_reference/game_energy_conversion.lua',env)
if not ok then error('40K converter requires the pinned private gadget: '..tostring(result)) end
return result
