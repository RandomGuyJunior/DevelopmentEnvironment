function gadget:GetInfo() return {name='40K opt-in actual paired barrel proof',desc='Read-only native projectile/Shot flash origin correlation',author='Local project',layer=107,enabled=true} end
local opts=Spring.GetModOptions()
if not gadgetHandler:IsSyncedCode() or tostring(opts.prototype_barrel_review)~='1' or (opts.prototype_diagnostic~='roster' and opts.prototype_diagnostic~='six') then return end
local watched,counts,barrels={},{},{}
local limit=8
local tolerance=.01 -- native position float tolerance, in unchanged game units
local function finite(v)return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function emit(...)Spring.Echo('40K BARREL NATIVE',...)end
local function words(s)
 local out={}
 for name in tostring(s or ''):gmatch('[^,;]+') do out[#out+1]=name:match('^%s*(.-)%s*$') end
 return out
end
function gadget:Initialize()
 if not Script.SetWatchProjectile or not Spring.GetProjectilePosition then emit('UNKNOWN','native_projectile_api_missing');return end
 for id,wd in pairs(WeaponDefs) do
  local pair=words((wd.customParams or {}).source_muzzle_pair)
  if #pair>=2 then watched[id]=pair;Script.SetWatchProjectile(id,true) end
 end
end
function gadget:ProjectileCreated(projectile,owner,weapon)
 -- Some engine callbacks omit a valid def; fallback reads this actual projectile.
 if (not weapon or weapon<0) and Spring.GetProjectileDefID then weapon=Spring.GetProjectileDefID(projectile) end
 local pair=weapon and watched[weapon];if not pair then return end
 local key=tostring(owner)..':'..weapon
 local count=counts[key] or 0;if count>=limit then return end
 counts[key]=count+1
 local f=Spring.GetGameFrame()
 local def=Spring.GetUnitDefID(owner);local ud=def and UnitDefs[def]
 local mount,matches=nil,0
 for n,w in ipairs(ud and ud.weapons or {}) do
  if (w.weaponDef or w.weaponDefID)==weapon then mount=n;matches=matches+1 end
 end
 if matches~=1 then emit('UNKNOWN','ambiguous_or_missing_mount',projectile,owner,weapon,f,matches);return end
 local shot=Spring.GetUnitRulesParam(owner,'40k_last_shot_'..mount)
 local piece=Spring.GetUnitRulesParam(owner,'40k_last_muzzle_'..mount)
 local fx=Spring.GetUnitRulesParam(owner,'40k_last_flash_x_'..mount)
 local fy=Spring.GetUnitRulesParam(owner,'40k_last_flash_y_'..mount)
 local fz=Spring.GetUnitRulesParam(owner,'40k_last_flash_z_'..mount)
 local x,y,z=Spring.GetProjectilePosition(projectile)
 if shot~=f then emit('UNKNOWN','stale_or_missing_same_frame_shot',projectile,owner,weapon,mount,f,shot or -1);return end
 if not (finite(x) and finite(y) and finite(z) and finite(fx) and finite(fy) and finite(fz) and finite(piece)) then
  emit('UNKNOWN','missing_or_nonfinite_positions',projectile,owner,weapon,mount,f,piece or -1,x or 'nil',y or 'nil',z or 'nil',fx or 'nil',fy or 'nil',fz or 'nil');return
 end
 local map=Spring.GetUnitPieceMap(owner) or {};local pairMember=false
 for _,name in ipairs(pair) do if map[name]==piece then pairMember=true;break end end
 local distance=math.sqrt((x-fx)^2+(y-fy)^2+(z-fz)^2)
 barrels[key]=barrels[key] or {};barrels[key][piece]=true
 local distinct=0;for _ in pairs(barrels[key]) do distinct=distinct+1 end
 local status=pairMember and distance<=tolerance and 'PASS' or 'MISMATCH'
 emit(status,projectile,owner,weapon,mount,f,'piece',piece,'projectile',x,y,z,'flash',fx,fy,fz,'distance',distance,'paired_piece',pairMember,'distinct_barrels',distinct,'sample',count+1)
end
-- No projectile spawning/modification, script callbacks, orders or damage changes.
-- Do not disable watch flags on shutdown: another diagnostic may share them.
