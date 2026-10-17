function gadget:GetInfo()
 return{name='40K paid Nob corpse acceptance fixture',desc='Default-off earned INF2 Nob3 then separately funded hostile blast and ordinary reclaim',author='Local project',layer=152,enabled=true}
end
local options=Spring.GetModOptions()or{}
local enabled=VFS.Include('40k_configs/development_playtest.lua').OptionEnabled
if not enabled(options.prototype_nob_corpse_fixture)then return false end
if not gadgetHandler:IsSyncedCode()then
 local closeAt
 local function done(_,result)Spring.Echo('40K_NOB_REMAINS owned_fixture_autoclose '..tostring(result));closeAt=Spring.GetGameFrame()+90 end
 function gadget:Initialize()gadgetHandler:AddSyncAction('fortyk_nob_remains_done',done)end
 function gadget:GameFrame(frame)if closeAt and frame>=closeAt then closeAt=nil;Spring.SendCommands('quitforce')end end
 function gadget:Shutdown()gadgetHandler:RemoveSyncAction('fortyk_nob_remains_done')end
 return
end
local S=Spring;local phase='ladder';local driver,plan,profiles,nobTest
local function emit(event,...)
 local a={...};for i=1,#a do a[i]=tostring(a[i])end;S.Echo('40K_NOB_REMAINS '..event..' '..table.concat(a,' '))
end
local function finish(reason)
 if phase=='done'then return end;phase='done';if nobTest then nobTest.Close()end
 emit('COMPLETE',reason,'paid_automated_egress=true visual_occlusion_acceptance=false stock_hud_acceptance=false')
 SendToUnsynced('fortyk_nob_remains_done',reason)
end
function gadget:Initialize()
 local ok,result=pcall(function()
  assert(options.prototype_diagnostic=='normal'and(options.prototype_test_speed==1 or options.prototype_test_speed=='1')
   and enabled(options.prototype_development_playtest)and enabled(options.prototype_source_progression)
   and enabled(options.prototype_nob_remains_pilot)and enabled(options.prototype_ork_nob_squad)
   and not enabled(options.prototype_scale085_pilot),'explicit_unscaled_native_speed_Nob3_source_route_required')
  for key,value in pairs(options)do
   if enabled(value)and(key:match('fixture$')or key:match('driver$')or key=='prototype_mount_burst_observer'or key=='prototype_mixed_force')
    and key~='prototype_nob_corpse_fixture'then error('competing_native_diagnostic_owner_'..key)end
  end
  profiles=VFS.Include('40k_configs/active_squad_profiles.lua')
  for _,path in ipairs({'objects3d/ork_nob.glb','scripts/generated/ork_nob_anim.lua','scripts/40k_roster.lua'})do assert(VFS.FileExists(path),'genuine_asset_absent_'..path)end
  return VFS.Include('40k_configs/ork_paid_infantry_ladder.lua').Plan(UnitDefs,UnitDefNames,profiles,'ork_nob',1)
 end)
 if not ok then finish('REFUSAL '..tostring(result));return end;plan=result
end
local physical=VFS.Include('40k_configs/guard_factory_egress_geometry.lua')
local site=VFS.Include('40k_configs/ordinary_paid_construction_site.lua')
local endpoint=VFS.Include('40k_configs/paid_factory_egress_review.lua')
function gadget:UnitCreated(...)if driver and phase=='ladder'then driver.Created(...)end end
function gadget:UnitFinished(...)if driver and phase=='ladder'then driver.Finished(...)end end
function gadget:UnitFromFactory(...)if driver and phase=='ladder'then driver.Released(...)end end
function gadget:UnitDestroyed(id)if driver and phase=='ladder'then driver.Retired(id)end end
function gadget:UnitTaken(id)if driver and phase=='ladder'then driver.Retired(id)end end
function gadget:UnitGiven(id)if driver and phase=='ladder'then driver.Retired(id)end end
function gadget:GameFrame(frame)
 if phase=='done'or frame<1 then return end
 if phase=='remains'then local result=nobTest.Step(frame);if result then finish(result)end;return end
 if not driver then
  if not plan or not GG.Recoil40KSquads then finish('REFUSAL actual_squad_owner_required');return end
  local placement={Version=1,Choose=function(def,builder,metal)return site.Choose(S,UnitDefs,GG,Game,def,builder,metal,emit)end,
   Rally=function(def,factory)local task=driver.tasks[driver.step];return task and task.birth and endpoint.Plan(S,UnitDefs,task.birth,factory,Game.mapSizeX,Game.mapSizeZ)end}
  driver=VFS.Include('40k_configs/ork_paid_infantry_driver.lua').New(S,UnitDefs,UnitDefNames,profiles,GG.Recoil40KSquads,physical,placement,plan,emit)
 end
 local result=driver.Step(frame)
 if not result then return end
 if result:sub(1,9)~='PREPARED 'then finish(result);return end
 -- No funded resource/creation API belongs to the production ladder. The retained
 -- hostile projectile diagnostic is deliberately separate from this earned route.
 nobTest=VFS.Include('40k_configs/nob_paid_remains_fixture.lua').New(S,UnitDefs,FeatureDefs,WeaponDefs,GG,
  driver.units.cohort1,driver.units.builder,driver.units.infantry2,driver.team,frame,emit)
 if nobTest.result then finish(nobTest.result);return end
 phase='remains';emit('NOB_PAID_ROUTE_COMPLETE','INF1_corck_INF2=true one_paid_product_three_real_bodies=true','funded_hostile_blast_next=true')
end
function gadget:UnitDamaged(id,def,t,damage,para,wd,pid)if nobTest then nobTest.Damaged(id,damage,para,wd,pid)end end
function gadget:Explosion(...)if nobTest then return nobTest.Explosion(...)end;return false end
function gadget:AllowFeatureBuildStep(...)if nobTest then return nobTest.BuildStep(...)end;return true end
function gadget:FeatureDestroyed(fid)if nobTest then nobTest.FeatureDestroyed(fid)end end
function gadget:Shutdown()if nobTest then nobTest.Close()end end
