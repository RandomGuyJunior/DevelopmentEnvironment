-- Project-owned wrapper; the exact native provider is copied privately at
-- assembly. This Spring proxy belongs only to this gadget environment.
local env=getfenv(1)
local guard=VFS.Include('40k_configs/native_hat_piece_guard.lua')
env.Spring=guard.Proxy(Spring,UnitDefs)
local ok,result=pcall(VFS.Include,'40k_reference/unit_intergrated_hats.lua',env)
if not ok then error('40K Integrated Hats requires the pinned private provider: '..tostring(result))end
return result
