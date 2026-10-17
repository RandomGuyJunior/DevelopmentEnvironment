function gadget:GetInfo()return{name='40K funded full4 Burna Flame diagnostic',desc='Default-off actual native projectile/HP observer; no economy acceptance',author='Local project',layer=159,enabled=true}end
local options=Spring.GetModOptions()or{}
local function on(v)return v==true or v==1 or v=='1'end
if not on(options.prototype_burna_flame_combat)then return false end
assert(options.prototype_burna_flame_actor=='ork_burna','Exact genuine Burna actor selector required')
assert(VFS.Include('40k_configs/four_faction_playtest.lua').Enabled(options)and on(options.prototype_ork_burna_squad),'Full4 source profile18 required')
assert(options.prototype_test_speed==nil or options.prototype_test_speed==1 or options.prototype_test_speed=='1','Exact normal speed1 required')
local allowed={prototype_burna_flame_combat=true,prototype_burna_flame_actor=true,prototype_ork_burna_squad=true,prototype_development_playtest=true,prototype_source_progression=true,prototype_test_speed=true,prototype_demand_model_review=true,prototype_demand_model_normal_review=true,prototype_ork_tankbusta_squad=true,prototype_ork_loota_squad=true,prototype_ork_nob_squad=true,prototype_ork_meganob_squad=true,prototype_ork_slugga_squad=true}

-- Exact ordinary data context: these select existing definitions, not fixtures.
local normalProfiles={'prototype_ork_tankbusta_squad','prototype_ork_loota_squad','prototype_ork_nob_squad','prototype_ork_meganob_squad','prototype_ork_slugga_squad'}
for _,key in ipairs(normalProfiles)do assert(on(options[key]),'Exact current-normal data profile required '..key)end
for key,value in pairs(options)do
 if type(key)=='string'and key:match('^prototype_')and on(value)and not allowed[key]then error('Competing enabled diagnostic option '..key)end
end
if not gadgetHandler:IsSyncedCode()then
 local closeAt
 local function done(_,result)Spring.Echo('40K_BURNA_FLAME owned_autoclose '..tostring(result));closeAt=Spring.GetGameFrame()+90 end
 function gadget:Initialize()gadgetHandler:AddSyncAction('fortyk_burna_flame_done',done)end
 function gadget:GameFrame(f)if closeAt and f>=closeAt then closeAt=nil;Spring.SendCommands('quitforce')end end
 function gadget:Shutdown()gadgetHandler:RemoveSyncAction('fortyk_burna_flame_done')end
 return
end
local C;local reported=false
local function emit(e,...)
 local args={...};for i=1,#args do args[i]=tostring(args[i])end
 Spring.Echo('40K_BURNA_FLAME '..e..' frame='..Spring.GetGameFrame()..' '..table.concat(args,' '))
end
local function complete()
 if C and C.result and not reported then reported=true;SendToUnsynced('fortyk_burna_flame_done',C.result)end
end
function gadget:GameFrame(f)
 if reported then return end
 if not C then
  if f==0 then return end
  if f~=1 then emit('COMPLETE','INCONCLUSIVE fresh_frame1_required','funded_non_economy=true');reported=true;SendToUnsynced('fortyk_burna_flame_done','INCONCLUSIVE fresh_frame1_required');return end
  C=VFS.Include('40k_configs/burna_flame_combat_fixture.lua').New(Spring,UnitDefs,UnitDefNames,WeaponDefs,GG,Script,Game,emit)
 end
 if not reported then C.Frame(f);complete()end
end
function gadget:UnitCreated(...)if C and not reported then C.Created(...);complete()end end
function gadget:UnitFinished(...)if C and not reported then C.Finished(...);complete()end end
function gadget:UnitFromFactory(...)if C and not reported then C.Released(...);complete()end end
function gadget:ProjectileCreated(...)if C and not reported then C.Projectile(...);complete()end end
function gadget:UnitDamaged(id,def,team,damage,paralyzer,weapon,pid,attacker)if C and not reported then C.Damaged(id,damage,paralyzer,weapon,pid,attacker);complete()end end
function gadget:UnitDestroyed(id)if C and not reported then C.Destroyed(id);complete()end end
function gadget:Shutdown()if C then C.Close()end end
