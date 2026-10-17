-- Default-off ordinary paid Tankbusta3 two-cohort preparation. No combat acceptance.
function gadget:GetInfo()return{name='40K paid Tankbusta3 cohorts',desc='Native finish/release and all-body egress',author='Local project',layer=156,enabled=true}end
local o=Spring.GetModOptions()or{};local function yes(v)return v==true or v==1 or v=='1'end
if not yes(o.prototype_ork_tankbusta_native_fixture)then return false end
if not gadgetHandler:IsSyncedCode()then return false end
local S=Spring;local driver,plan,profiles;local closed=false
local function emit(event,...)local out={...};for i=1,#out do out[i]=tostring(out[i])end;S.Echo('40K_TANKBUSTA_PAID '..event..' '..table.concat(out,' '))end
local function close(why)if not closed then closed=true;emit('COMPLETE',why,'nativeAccepted=false paidEconomyAccepted=false combatAccepted=false')end end
local function makePlan()
 assert(o.prototype_diagnostic=='normal'and(o.prototype_test_speed==1 or o.prototype_test_speed=='1')and yes(o.prototype_development_playtest)and yes(o.prototype_source_progression)and yes(o.prototype_ork_tankbusta_squad)and not yes(o.prototype_scale085_pilot),'explicit_unscaled_source_Tankbusta3_route_required')
 for key,value in pairs(o)do if yes(value)and(key:match('fixture$')or key:match('driver$')or key=='prototype_mount_burst_observer'or key=='prototype_mixed_force')and key~='prototype_ork_tankbusta_native_fixture'then error('competing_native_diagnostic_owner_'..key)end end
 profiles=VFS.Include('40k_configs/active_squad_profiles.lua');local p=assert(profiles.profiles.ork_tankbusta);assert(p.id==10 and p.capacity==3 and p.product=='ork_tankbusta'and p.member=='ork_tankbusta_member','actual_fixed_profile_required')
 for _,path in ipairs({'objects3d/ork_tankbusta.glb','scripts/generated/ork_tankbusta_anim.lua','scripts/40k_roster.lua'})do assert(VFS.FileExists(path),'genuine_asset_absent_'..path)end
 return VFS.Include('40k_configs/ork_paid_infantry_ladder.lua').Plan(UnitDefs,UnitDefNames,profiles,'ork_tankbusta',2)
end
function gadget:Initialize()local ok,value=pcall(makePlan);if not ok then close('REFUSAL '..tostring(value));return end;plan=value end
local physical=VFS.Include('40k_configs/guard_factory_egress_geometry.lua');local site=VFS.Include('40k_configs/ordinary_paid_construction_site.lua');local endpoint=VFS.Include('40k_configs/paid_factory_egress_review.lua')
function gadget:UnitCreated(...)if driver and not closed then driver.Created(...)end end
function gadget:UnitFinished(...)if driver and not closed then driver.Finished(...)end end
function gadget:UnitFromFactory(...)if driver and not closed then driver.Released(...)end end
function gadget:UnitDestroyed(id)if driver and not closed then driver.Retired(id)end end
function gadget:UnitTaken(id)if driver and not closed then driver.Retired(id)end end
function gadget:UnitGiven(id)if driver and not closed then driver.Retired(id)end end
function gadget:GameFrame(frame)
 if closed or frame<1 then return end
 if not driver then
  if not plan or not GG.Recoil40KSquads then close('REFUSAL actual_squad_owner_required');return end
  local placement={Version=1,Choose=function(def,builder,metal)return site.Choose(S,UnitDefs,GG,Game,def,builder,metal,emit)end,
   Rally=function(def,factory)local task=driver.tasks[driver.step];return task and task.birth and endpoint.Plan(S,UnitDefs,task.birth,factory,Game.mapSizeX,Game.mapSizeZ)end}
  driver=VFS.Include('40k_configs/ork_tankbusta_paid_driver.lua').New(S,UnitDefs,UnitDefNames,profiles,GG.Recoil40KSquads,physical,placement,plan,emit)
 end
 if driver.result then close(driver.result);return end
 local why=driver.Step(frame);if why then close(why)end
end
