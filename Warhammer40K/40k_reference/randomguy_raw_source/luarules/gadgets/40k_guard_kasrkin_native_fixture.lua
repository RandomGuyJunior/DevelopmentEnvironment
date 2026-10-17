-- Default-off ordinary paid Kasrkin5 two-cohort preparation. No combat acceptance.
function gadget:GetInfo()return{name='40K paid Kasrkin5 cohorts',desc='Native finish/release and all-body egress',author='Local project',layer=156,enabled=true}end
local o=Spring.GetModOptions()or{};local function yes(v)return v==true or v==1 or v=='1'end
if not yes(o.prototype_guard_kasrkin_native_fixture)then return false end
if not gadgetHandler:IsSyncedCode()then return false end
local S=Spring;local driver,plan,profiles;local closed=false
local function emit(event,...)local out={...};for i=1,#out do out[i]=tostring(out[i])end;S.Echo('40K_KASRKIN_PAID '..event..' '..table.concat(out,' '))end
local function close(why)if not closed then closed=true;emit('COMPLETE',why,'nativeAccepted=false paidEconomyAccepted=false combatAccepted=false')end end
local function makePlan()
 assert(o.prototype_diagnostic=='normal'and yes(o.prototype_development_playtest)and yes(o.prototype_source_progression)and yes(o.prototype_guard_kasrkin_squad)and not yes(o.prototype_scale085_pilot),'explicit_unscaled_source_Kasrkin5_route_required')
 for key,value in pairs(o)do if yes(value)and(key:match('fixture$')or key:match('driver$')or key=='prototype_mount_burst_observer'or key=='prototype_mixed_force')and key~='prototype_guard_kasrkin_native_fixture'then error('competing_native_diagnostic_owner_'..key)end end
 profiles=VFS.Include('40k_configs/active_squad_profiles.lua');local p=assert(profiles.profiles.guard_kasrkin);assert(p.id==5 and p.capacity==5 and p.product=='imp_kasrkin'and p.member=='imp_kasrkin_member','actual_fixed_profile_required')
 local body=assert(UnitDefNames[p.member]);local full=assert(UnitDefNames[p.product]);local builder=assert(UnitDefNames.armck)
 assert(builder.metalCost==110 and builder.energyCost==1600 and builder.buildTime==3450,'actual_native_Guard_constructor_bill_required')
 local advanced=assert(UnitDefNames.armalab)
 assert(advanced.metalCost==2600 and advanced.energyCost==15000 and advanced.buildTime==25000 and advanced.isFactory,'actual_native_T2_MekLab_bill_required')
 assert(body.metalCost==55 and body.energyCost==280 and body.buildTime==520 and full.metalCost==275 and full.energyCost==1400 and full.buildTime==2600,'actual_native_full5_bill_required')
 for _,path in ipairs({'objects3d/imp_kasrkin.glb','scripts/generated/imp_kasrkin_anim.lua','scripts/40k_roster.lua'})do assert(VFS.FileExists(path),'genuine_asset_absent_'..path)end
 return{actor=p.product,profile='guard_kasrkin',capacity=5,id=p.id,cohorts=2,builder='armck',builderFactory='imp_barracks',metal=body.metalCost,energy=body.energyCost,work=body.buildTime,
 productBill={metal=full.metalCost,energy=full.energyCost,work=full.buildTime},builderBill={metal=builder.metalCost,energy=builder.energyCost,work=builder.buildTime},
 advancedBill={metal=advanced.metalCost,energy=advanced.energyCost,work=advanced.buildTime}}
end
function gadget:Initialize()local ok,value=pcall(makePlan);if not ok then close('REFUSAL '..tostring(value));return end;plan=value end
local physical=VFS.Include('40k_configs/guard_factory_egress_geometry.lua');local site=VFS.Include('40k_configs/ordinary_paid_construction_site.lua');local endpoint=VFS.Include('40k_configs/paid_factory_egress_review.lua')
function gadget:UnitCreated(...)if driver and not closed then driver.Created(...)end end
function gadget:UnitFinished(...)if driver and not closed then driver.Finished(...)end end
function gadget:UnitFromFactory(...)if driver and not closed then driver.Released(...)end end
function gadget:GameFrame(frame)
 if closed or frame<1 then return end
 if not driver then
  if not plan or not GG.Recoil40KSquads then close('REFUSAL actual_squad_owner_required');return end
  local placement={Version=1,Choose=function(def,builder,metal)return site.Choose(S,UnitDefs,GG,Game,def,builder,metal,emit)end,
   Rally=function(def,factory)local task=driver.tasks[driver.step];return task and task.birth and endpoint.Plan(S,UnitDefs,task.birth,factory,Game.mapSizeX,Game.mapSizeZ)end}
  driver=VFS.Include('40k_configs/guard_kasrkin_paid_driver.lua').New(S,UnitDefs,UnitDefNames,profiles,GG.Recoil40KSquads,physical,placement,plan,emit)
 end
 if driver.result then close(driver.result);return end
 local why=driver.Step(frame);if why then close(why)end
end
