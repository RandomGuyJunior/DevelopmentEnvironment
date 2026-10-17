function gadget:GetInfo()return{name='40K bounded real-shot hull observer',desc='Default-off funded diagnostic telemetry only',author='Local project',layer=170,enabled=true}end
local o=Spring.GetModOptions()or{}
local function yes(v)return v==true or v==1 or v=='1'end
local retainedDakka=VFS.Include('40k_configs/stompa_weapon_fixture.lua').Enabled(o)
if not(yes(o.prototype_development_playtest)or retainedDakka)or not yes(o.prototype_mount_burst_observer)then return false end
if not gadgetHandler:IsSyncedCode()then return false end
local M=VFS.Include('40k_configs/walker_burst_observer.lua');local observer;local watches={}
local function json(x)
 local t=type(x);if t=='string'then return '"'..x:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n')..'"'end
 if t=='boolean'then return x and 'true'or 'false'end
 if t=='number'then assert(x==x and math.abs(x)<math.huge,'Nonfinite telemetry');return string.format('%.17g',x)end
 assert(t=='table');local keys={};for k in pairs(x)do keys[#keys+1]=k end;table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
 local array=#x>0 and #keys==#x;local parts={}
 if array then for i=1,#x do parts[i]=json(x[i])end;return '['..table.concat(parts,',')..']'end
 for _,k in ipairs(keys)do parts[#parts+1]=json(tostring(k))..':'..json(x[k])end;return '{'..table.concat(parts,',')..'}'
end
local function register(id)
 if not observer.Register(id)then return end
 for _,w in ipairs(UnitDefs[Spring.GetUnitDefID(id)].weapons)do
  if watches[w.weaponDef]==nil then watches[w.weaponDef]=Script.GetWatchProjectile(w.weaponDef);Script.SetWatchProjectile(w.weaponDef,true)end
 end
end
function gadget:Initialize()
 if GG.Recoil40KWalkerBurstWitness then error('Existing burst witness owner; refuse overwrite')end
 local scope=yes(o.prototype_ork_ranged_weapon_fixture)and{rangedOnly=true,weaponDefs=WeaponDefs}or nil
 observer=M.New(Spring,UnitDefs,function(row)local payload=json(row);if scope then assert(#payload<=15360,'Ranged observer payload exceeds15360; refuse truncated telemetry')end;Spring.Echo('40K_BURST_OBSERVER '..payload)end,128,scope)
 GG.Recoil40KWalkerBurstWitness=observer
 for _,id in ipairs(Spring.GetAllUnits())do register(id)end
end
function gadget:UnitCreated(id)register(id)end
function gadget:ProjectileCreated(pid,owner,wd)observer.Projectile(pid,owner,wd)end
function gadget:Shutdown()
 if GG.Recoil40KWalkerBurstWitness==observer then GG.Recoil40KWalkerBurstWitness=nil end
 -- Watches remain enabled: another diagnostic may have acquired them since Init.
 -- This changes only event subscription, never projectile simulation.
end
