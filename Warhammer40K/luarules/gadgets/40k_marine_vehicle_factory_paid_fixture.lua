function gadget:GetInfo()return{name='40K Marine native vehicle factory paid repeat witness',desc='Default-off existing ordinary paid Predator two-cycle proof',author='Local project',layer=153,enabled=true}end
local o=Spring.GetModOptions()or{}
local policy=VFS.Include('40k_configs/development_playtest.lua')
local own='prototype_marine_vehicle_factory_paid_fixture'
local foreignGates={
 ['prototype_adapted_air_paid_fixture']=true,
 ['prototype_animation_interpolation']=true,
 ['prototype_basilica_paid_driver']=true,
 ['prototype_basilica_wall_observer']=true,
 ['prototype_body_benchmark']=true,
 ['prototype_centre_march_native_observer']=true,
 ['prototype_corpse_blast_fixture']=true,
 ['prototype_corpse_native_reclaim_fixture']=true,
 ['prototype_corpse_reclaim_review']=true,
 ['prototype_corpse_save_checkpoint_fixture']=true,
 ['prototype_corpse_save_first_tick_fixture']=true,
 ['prototype_cruiser_weapons_fixture']=true,
 ['prototype_extractor_fixed_tier_pilot']=true,
 ['prototype_extractor_paid_fixture']=true,
 ['prototype_feature_remains_digest']=true,
 ['prototype_fighta_paid_landing_fixture']=true,
 ['prototype_fractional_walk_sampling']=true,
 ['prototype_gait_movement_fixture']=true,
 ['prototype_generator_scrap_review']=true,
 ['prototype_guard_energy_blue_pilot']=true,
 ['prototype_guard_factory_geometry_receipt']=true,
 ['prototype_guard_kasrkin_squad']=true,
 ['prototype_guard_metal_lamp_isolation_pilot']=true,
 ['prototype_guard_ogryn_paid_driver']=true,
 ['prototype_guard_ogryn_squad']=true,
 ['prototype_guard_paid_flamer_combat']=true,
 ['prototype_guard_research_capture_fixture']=true,
 ['prototype_guard_sentinel_weapon_fixture']=true,
 ['prototype_guard_squad_flamer']=true,
 ['prototype_guard_squad_paid_research_fixture']=true,
 ['prototype_heavy_corpse_contact_pilot']=true,
 ['prototype_hellfire_fixture']=true,
 ['prototype_hydra_fighta_aa_fixture']=true,
 ['prototype_immortal_emitter_fixture']=true,
 ['prototype_immortal_paid_driver']=true,
 ['prototype_marine_assault_squad']=true,
 ['prototype_marine_heavy_squad']=true,
 ['prototype_marine_scout_squad']=true,
 ['prototype_marine_terminator_squad']=true,
 ['prototype_mount_burst_observer']=true,
 ['prototype_mount_clearance_review']=true,
 ['prototype_multisquad_corpse_fixture']=true,
 ['prototype_naval_repeat_paid_fixture']=true,
 ['prototype_necron_factory_paid_fixture']=true,
 ['prototype_necron_flayed_remains_native_fixture']=true,
 ['prototype_necron_flayed_squad']=true,
 ['prototype_necron_immortal_remains_native_fixture']=true,
 ['prototype_necron_immortal_squad']=true,
 ['prototype_necron_native_factory_pilot']=true,
 ['prototype_necron_remains_native_fixture']=true,
 ['prototype_necron_remains_paid_driver']=true,
 ['prototype_necron_remains_pilot']=true,
 ['prototype_necron_wraith_squad']=true,
 ['prototype_nob_corpse_fixture']=true,
 ['prototype_nob_remains_pilot']=true,
 ['prototype_normal_native_observer']=true,
 ['prototype_ork_air_factory_repeat_fixture']=true,
 ['prototype_ork_extractor_armed_fixture']=true,
 ['prototype_ork_loota_squad']=true,
 ['prototype_ork_meganob_squad']=true,
 ['prototype_ork_nob_squad']=true,
 ['prototype_ork_paid_air_combat']=true,
 ['prototype_ork_paid_air_fixture']=true,
 ['prototype_ork_paid_air_ladder_fixture']=true,
 ['prototype_ork_paid_squad_transport']=true,
 ['prototype_ork_paid_transport_casualty_probe']=true,
 ['prototype_ork_ranged_flat_scene']=true,
 ['prototype_ork_ranged_weapon_fixture']=true,
 ['prototype_ork_squad_paid_research_fixture']=true,
 ['prototype_ork_tankbusta_native_fixture']=true,
 ['prototype_ork_tankbusta_squad']=true,
 ['prototype_paid_patrol_combat_fixture']=true,
 ['prototype_paid_repair_placement_observer']=true,
 ['prototype_russ_four_mount_fixture']=true,
 ['prototype_russ_wreck_paid_fixture']=true,
 ['prototype_russ_wreck_pilot']=true,
 ['prototype_scale085_pilot']=true,
 ['prototype_scale_native_probe']=true,
 ['prototype_scout_paid_driver']=true,
 ['prototype_squad_cancel_fixture']=true,
 ['prototype_squad_controls_observer']=true,
 ['prototype_squad_egress_fixture']=true,
 ['prototype_squad_fixture']=true,
 ['prototype_squad_order_tags_fixture']=true,
 ['prototype_squad_paid_fixture']=true,
 ['prototype_squad_paid_research_fixture']=true,
 ['prototype_squad_save_checkpoint_fixture']=true,
 ['prototype_squad_save_first_tick_fixture']=true,
 ['prototype_squad_save_pending_first_tick_fixture']=true,
 ['prototype_squad_save_pending_research_fixture']=true,
 ['prototype_squad_state_digest']=true,
 ['prototype_squad_transport_pilot']=true,
 ['prototype_stock_transport_reference']=true,
 ['prototype_stompa_multigun_review']=true,
 ['prototype_stompa_weapon_fixture']=true,
 ['prototype_terminator_native_observer']=true,
 ['prototype_terminator_paid_driver']=true,
 ['prototype_terminator_scale085_pair_pilot']=true,
 ['prototype_water_combat_paid_fixture']=true,
 ['prototype_water_paid_fixture']=true,
 ['prototype_wraith_phase_funded_fixture']=true,
 ['prototype_wraith_squad_phase_review']=true,
}
if not policy.OptionEnabled(o[own])then return false end
if not gadgetHandler:IsSyncedCode()then
 local closeAt
 function gadget:Initialize()gadgetHandler:AddSyncAction('fortyk_marine_vehicle_factory_done',function(_,result)Spring.Echo('40K_MARINE_VEHICLE_FACTORY owned_autoclose '..tostring(result));closeAt=Spring.GetGameFrame()+90 end)end
 function gadget:GameFrame(n)if closeAt and n>=closeAt then closeAt=nil;Spring.SendCommands('quitforce')end end
 function gadget:Shutdown()gadgetHandler:RemoveSyncAction('fortyk_marine_vehicle_factory_done')end
 return
end
local driver=VFS.Include('40k_configs/marine_vehicle_factory_paid.lua')
local physical=VFS.Include('40k_configs/guard_factory_egress_geometry.lua')
local placement=VFS.Include('40k_configs/ordinary_paid_construction_site.lua')
local C,reported,combat
local follow=policy.OptionEnabled(o.prototype_predator_paid_combat_fixture)
local paidPass='PASS two_ordinary_paid_Predators_native_finish_release_geometry30travel_rally_idle_reopen_prior_preserved'
local function emit(event,...)
 local a={...};for i,v in ipairs(a)do a[i]=tostring(v)end
 Spring.Echo('40K_MARINE_VEHICLE_FACTORY '..event..' frame='..Spring.GetGameFrame()..' '..table.concat(a,' '))
end
local function complete(result)
 if result and not reported then
  if follow and result==paidPass then
   if not combat then
    local m=VFS.Include('40k_configs/predator_paid_combat_fixture.lua')
    combat=m.New(Spring,UnitDefs,UnitDefNames,WeaponDefs,GG,Script,Game,C,Spring.GetGameFrame(),emit)
   end
   if not combat.result then return end
   result=combat.result
  end
  reported=true;SendToUnsynced('fortyk_marine_vehicle_factory_done',result)
 end
end
function gadget:Initialize()
 local n=Spring.GetGameFrame()
 if type(n)~='number'or n~=0 then emit('COMPLETE','INCONCLUSIVE fresh_initialize_frame0_required');complete('INCONCLUSIVE fresh_initialize_frame0_required');return end
 if o.prototype_diagnostic~='normal'or tonumber(o.prototype_test_speed or 1)~=1 or not policy.OptionEnabled(o.prototype_source_progression)then emit('COMPLETE','FAIL ordinary_normal_source_speed_required');complete('FAIL ordinary_normal_source_speed_required');return end
 for key,v in pairs(o)do
  local active=v~=nil and v~=false and v~=0 and v~='0'and v~=''and v~='none'and v~='off'and v~='normal'
  -- Native options include dormant numeric benchmark metadata, not just gates.
  -- Exempt only the genuine defaults; the benchmark enable flag still refuses.
  if key=='prototype_body_benchmark_intervals'and tonumber(v)==120
   or key=='prototype_body_benchmark_start_frame'and tonumber(v)==600 then active=false end
  if key~=own and key~='prototype_predator_paid_combat_fixture'and type(key)=='string'and(foreignGates[key]or key:match('fixture')or key:match('benchmark')or key:match('probe')or key:match('_driver$')or key:match('_observer$'))and active then emit('COMPLETE','FAIL conflicting_diagnostic_'..key);complete('FAIL conflicting_diagnostic_'..key);return end
 end
 local context={mapSizeX=Game.mapSizeX,mapSizeZ=Game.mapSizeZ,extractorRadius=Game.extractorRadius,GG=GG}
 C=driver.New(Spring,UnitDefs,UnitDefNames,context,placement,physical,emit);complete(C.result)
end
function gadget:GameFrame(n)if C and not reported then if combat then combat.Frame(n)else C.Frame(n)end;complete(C.result)end end
function gadget:UnitCreated(...)if C then C.Created(...);complete(C.result)end end
function gadget:UnitFinished(...)if C then C.Finished(...);complete(C.result)end end
function gadget:UnitFromFactory(...)if C then C.Released(...);complete(C.result)end end

function gadget:ProjectileCreated(pid,owner,weapon)if combat and not reported then combat.Projectile(pid,owner,weapon);complete(C.result)end end
function gadget:UnitDamaged(id,def,team,damage,paralyzer,weapon,pid,attacker)if combat and not reported then combat.Damaged(id,damage,paralyzer,weapon,pid,attacker);complete(C.result)end end
function gadget:UnitDestroyed(id)if combat and not reported then combat.Destroyed(id);complete(C.result)end end
function gadget:Shutdown()if combat then combat.Close()end end
