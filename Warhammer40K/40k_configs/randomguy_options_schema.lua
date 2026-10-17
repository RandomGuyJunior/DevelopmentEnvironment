-- Generated release schema: exact normal-game custom defaults, no metadata grants.
local options={}
options[#options+1]={key='prototype_development_playtest',name='40K development roster',desc='Intermediate paid four-faction playtest; experimental roles, not final release acceptance.',type='bool',def=true}
options[#options+1]={key='prototype_source_progression',name='40K paid source progression',desc='Ordinary paid faction construction and research.',type='bool',def=true}
options[#options+1]={key='prototype_stompa_weapon_fixture',name='Unpaid Stompa weapon fixture',type='bool',def=false}
options[#options+1]={key='prototype_stompa_multigun_review',name='Four visible Stompa guns review',type='bool',def=false}
options[#options+1]={key='prototype_hellfire_fixture',name='Unpaid Hellfire/Basilisk native review',type='bool',def=false}
options[#options+1]={key='prototype_corpse_reclaim_review',name='Five Necron corpses: reclaim review',type='bool',def=false}
options[#options+1]={key='prototype_generator_scrap_review',name='Generator machinery salvage review',type='bool',def=false}
options[#options+1]={key='prototype_normal_native_observer',name='Passive native HWT/radar observer',type='bool',def=false}
options[#options+1]={key='prototype_squad_fixture',name='Funded native squad diagnostic',type='bool',def=false}
options[#options+1]={key='prototype_squad_paid_fixture',name='Owned ordinary-resource squad diagnostic',type='bool',def=false}
options[#options+1]={key='prototype_terminator_scale085_pair_pilot',name='Complete paired Terminator scale pilot; native pending',type='bool',def=false}
options[#options+1]={key='prototype_scale085_pilot',name='Paired smaller infantry geometry pilot',type='bool',def=false}
options[#options+1]={key='prototype_scale_native_probe',name='Read-only native infantry geometry diagnostic',type='bool',def=false}
options[#options+1]={key='prototype_animation_interpolation',name='Owned infantry renderer interpolation pilot',type='bool',def=false}
options[#options+1]={key='prototype_fractional_walk_sampling',name='Owned fractional infantry walk sampling pilot',type='bool',def=false}
options[#options+1]={key='prototype_squad_order_tags_fixture',name='Owned paid Tactical native order tags',type='bool',def=false}
options[#options+1]={key='prototype_gait_movement_fixture',name='Owned paid infantry movement and phase diagnostic',type='bool',def=false}
options[#options+1]={key='prototype_guard_metal_lamp_isolation_pilot',name='Guard metal panel UV isolation pilot',desc='Default-off matched model/materials for fixed three Guard metal tiers; native rendering pending.',type='bool',def=false}
options[#options+1]={key='prototype_guard_energy_blue_pilot',name='Guard blue energy detail pilot',desc='Exact isolated existing thermoglow palette candidate; native brightness pending.',type='bool',def=false}
options[#options+1]={key='prototype_extractor_fixed_tier_pilot',name='Owned fixed extractor tier pilot',type='bool',def=false}
options[#options+1]={key='prototype_extractor_paid_fixture',name='Owned paid extractor placement and refund diagnostic',type='bool',def=false}
options[#options+1]={key='prototype_extractor_paid_faction',name='Owned extractor diagnostic faction',type='list',def='guard',items={{key='guard',name='Imperial Guard'},{key='marine',name='Space Marines'},{key='ork',name='Orks'},{key='necron',name='Necrons'}}}
options[#options+1]={key='prototype_russ_wreck_paid_fixture',name='Owned paid Guard Russ wreck and reclaim diagnostic',type='bool',def=false}
options[#options+1]={key='prototype_russ_wreck_pilot',name='Native Leman Russ source death-state wreck pilot',type='bool',def=false}
options[#options+1]={key='prototype_heavy_corpse_contact_pilot',name='Heavy Marine corpse ground-contact pilot',type='bool',def=false}
options[#options+1]={key='prototype_corpse_blast_fixture',name='Owned unpaid native corpse blast diagnostic',type='bool',def=false}
options[#options+1]={key='prototype_squad_egress_fixture',name='Owned paid consecutive-squad egress diagnostic',type='bool',def=false}
options[#options+1]={key='prototype_ork_squad_paid_research_fixture',name='Owned paid Ork specialist research diagnostic',type='bool',def=false}
options[#options+1]={key='prototype_ork_paid_squad_transport',name='Owned paid Ork squad transport follow-on',desc='Default-off ordinary paid real Rhino repeat native pickup/unload; requires paid Ork research fixture',type='bool',def=false}
options[#options+1]={key='prototype_ork_paid_transport_casualty_probe',name='Owned paid transport casualty state probe',desc='Optional scripted native damage to two already paid bodies; not weapon/combat acceptance',type='bool',def=false}
options[#options+1]={key='prototype_stock_transport_reference',name='Owned stock transport physical reference',desc='Default-off unmodified BAR one-body transport observer; funded non-economy reference only',type='bool',def=false}
options[#options+1]={key='prototype_stock_transport_reference_mode',name='Owned stock transport reference scope',desc='Whole eight is refused for pinned one-slot donors; sequential observes eight individual actors twice',type='list',def='whole8',items={{key='whole8',name='Strict whole-eight preflight'},{key='sequential',name='Eight sequential single-body references'}}}
options[#options+1]={key='prototype_squad_paid_research_fixture',name='Owned paid Marine squad specialist research diagnostic',type='bool',def=false}
options[#options+1]={key='prototype_squad_save_first_tick_fixture',name='Owned separate first-tick saved-state diagnostic',type='bool',def=false}
options[#options+1]={key='prototype_squad_save_checkpoint_fixture',name='Owned native save during paid Marine repair',type='bool',def=false}
options[#options+1]={key='prototype_squad_save_checkpoint_name',name='Owned unique native save checkpoint name',type='string',def=''}
options[#options+1]={key='prototype_ork_paid_air_fixture',name='Owned paid Ork aircraft production and flight diagnostic',type='bool',def=false}
options[#options+1]={key='prototype_adapted_air_paid_fixture',name='Owned paid native light bomber combat diagnostic',desc='Ordinary own resources; funded enemy target only.',type='bool',def=false}
options[#options+1]={key='prototype_fighta_paid_landing_fixture',name='Owned paid Fighta native physical landing diagnostic',desc='After ordinary production/primary combat; source landing pose and death/reclaim unaccepted.',type='bool',def=false}
options[#options+1]={key='prototype_ork_paid_air_combat',name='Owned paid Fighta primary combat follow-on',desc='Requires paid aircraft fixture and hostile team; enemy target unpaid.',type='bool',def=false}
options[#options+1]={key='prototype_water_combat_paid_fixture',name='Owned paid native torpedo combat and salvage diagnostic',desc='Ordinary own production; funded hostile ship combat/salvage is non-economy.',type='bool',def=false}
options[#options+1]={key='prototype_cruiser_weapons_fixture',name='Owned funded native cruiser weapon diagnostic',desc='Funded non-economy own/enemy setup; native beam and depthcharge witnesses. No paid production acceptance.',type='bool',def=false}
options[#options+1]={key='prototype_hydra_fighta_aa_fixture',name='Owned funded Hydra versus Fighta AA flight diagnostic',desc='Funded setup; real normal flight, native autocannon projectiles and health loss. No paid production acceptance.',type='bool',def=false}
options[#options+1]={key='prototype_naval_repeat_paid_fixture',name='Owned ordinary paid two-patrol naval yard diagnostic',type='bool',def=false}
options[#options+1]={key='prototype_paid_patrol_combat_fixture',name='Paid patrol surface missile funded-hostile follow-on (requires naval repeat)',type='bool',def=false}
options[#options+1]={key='prototype_water_paid_fixture',name='Owned paid naval constructor and tidal income diagnostic',type='bool',def=false}
options[#options+1]={key='prototype_corpse_native_reclaim_fixture',name='Owned native reclaim after corpse blast diagnostic',type='bool',def=false}
options[#options+1]={key='prototype_squad_egress_faction',name='Owned egress diagnostic faction',type='list',def='marine',items={{key='marine',name='Space Marines'},{key='guard',name='Imperial Guard'},{key='ork',name='Orks'},{key='necron',name='Necrons'}}}
options[#options+1]={key='prototype_squad_paid_faction',name='Owned squad diagnostic faction',type='list',def='marine',items={{key='marine',name='Space Marines'},{key='guard',name='Imperial Guard'},{key='ork',name='Orks'},{key='necron',name='Necrons'}}}
options[#options+1]={key='prototype_ork_paid_air_ladder_fixture',name='Owned paid Ork aircraft constructor ladder diagnostic',type='bool',def=false}
options[#options+1]={key='prototype_mount_clearance_review',name='Owned mount clearance review pilot',desc='Default-off conservative side-weapon sectors; geometry and native acceptance pending.',type='bool',def=false}
options[#options+1]={key='prototype_ork_ranged_weapon_fixture',name='Owned unpaid four Ork walker weapons diagnostic',type='bool',def=false}
options[#options+1]={key='prototype_ork_ranged_flat_scene',name='Owned funded ranged-walker flat scene on Martyr gate',type='bool',def=false}
options[#options+1]={key='prototype_guard_squad_flamer',name='Owned genuine Guard squad flamer pilot',type='bool',def=false}
options[#options+1]={key='prototype_guard_squad_paid_research_fixture',name='Owned paid Guard genuine flamer research diagnostic',type='bool',def=false}
options[#options+1]={key='prototype_guard_paid_flamer_combat',name='Owned paid Guard flamer combat follow-on',desc='Requires paid Guard research fixture; hostile target unpaid; actual combat only.',type='bool',def=false}
options[#options+1]={key='prototype_guard_kasrkin_squad',name='Owned fixed paid Kasrkin squad pilot',type='bool',def=false}
options[#options+1]={key='prototype_guard_ogryn_squad',name='Owned fixed paid Ogryn squad pilot',type='bool',def=false}
options[#options+1]={key='prototype_marine_scout_squad',name='Owned fixed paid Scout Marine squad pilot',type='bool',def=false}
options[#options+1]={key='prototype_marine_heavy_squad',name='Owned fixed paid Devastator squad pilot',type='bool',def=false}
options[#options+1]={key='prototype_necron_immortal_squad',name='Owned fixed paid Immortal phalanx pilot',type='bool',def=false}
options[#options+1]={key='prototype_ork_tankbusta_squad',name='Tankbusta squads',desc='One paid factory order produces 3 real Tankbustas. Builders restore casualties for resources.',type='bool',def=true}
options[#options+1]={key='prototype_ork_loota_squad',name='Loota squads',desc='One paid factory order produces 3 real Lootas. Builders restore casualties for resources.',type='bool',def=true}
options[#options+1]={key='prototype_ork_nob_squad',name='Nob squads',desc='One paid factory order produces 3 real Nobz. Builders restore casualties for resources.',type='bool',def=true}
options[#options+1]={key='prototype_ork_meganob_squad',name='Meganob squads',desc='One paid factory order produces 3 real Meganobz. Builders restore casualties for resources.',type='bool',def=true}
options[#options+1]={key='prototype_marine_terminator_squad',name='Owned fixed paid Terminator squad pilot',type='bool',def=false}
options[#options+1]={key='prototype_necron_flayed_squad',name='Owned fixed paid Flayed One pack pilot',type='bool',def=false}
options[#options+1]={key='prototype_necron_wraith_squad',name='Owned fixed paid Wraith pack pilot',type='bool',def=false}
options[#options+1]={key='prototype_wraith_squad_phase_review',name='Owned Wraith squad phase compatibility pilot',type='bool',def=false}
options[#options+1]={key='prototype_wraith_phase_funded_fixture',name='Owned FUNDED NON-ECONOMY Wraith phase fixture',type='bool',def=false}
options[#options+1]={key='prototype_squad_transport_pilot',name='Owned native fixed-squad Looted Rhino pilot',type='bool',def=false}
options[#options+1]={key='prototype_squad_controls_observer',name='Owned read-only native squad controls observer',type='bool',def=false}
options[#options+1]={key='prototype_guard_sentinel_weapon_fixture',name='Owned paid Sentinel native weapon follow-on; funded hostile target only',type='bool',def=false}
options[#options+1]={key='prototype_marine_assault_squad',name='Owned fixed paid Assault squad pilot; requires shared jump adapter',type='bool',def=false}
options[#options+1]={key='prototype_nob_remains_pilot',name='Owned genuine Nob corpse pilot; native pose pending',type='bool',def=false}
options[#options+1]={key='prototype_necron_remains_pilot',name='Owned genuine Immortal/Flayed remains pilot; native pose pending',type='bool',def=false}
options[#options+1]={key='prototype_squad_state_digest',name='Owned bounded squad state digest observer',desc='Read-only exact common-frame diagnostic; default off; replay acceptance external.',type='bool',def=false}
options[#options+1]={key='prototype_squad_state_digest_frames',name='Owned digest explicit common frames',desc='One to eight ascending unique frames, 1..36000, comma separated. No automatic sampling.',type='string',def=''}
options[#options+1]={key='prototype_squad_state_digest_source',name='Owned digest exact source commit',desc='Coordinator-verified source commit for matching external binary/journal receipts.',type='string',def=''}
options[#options+1]={key='prototype_body_benchmark',name='Owned matched actual-body pacing observer',type='bool',def=false}
options[#options+1]={key='prototype_body_benchmark_source',name='Owned body observer source commit',type='string',def=''}
options[#options+1]={key='prototype_body_benchmark_counts',name='Owned exact native definition counts',desc='Explicit native definitionID:bodyCount pairs; all bodies must fit fixed camera model view.',type='string',def=''}
options[#options+1]={key='prototype_body_benchmark_intervals',name='Owned body observer counted intervals',type='number',def=120,min=30,max=600,step=1}
options[#options+1]={key='prototype_body_benchmark_start_frame',name='Owned body observer exact initial frame',type='number',def=600,min=1,max=36000,step=1}
options[#options+1]={key='prototype_multisquad_corpse_fixture',name='Owned FUNDED NON-ECONOMY two-cohort corpse diagnostic',type='bool',def=false}
options[#options+1]={key='prototype_multisquad_corpse_case',name='Owned corpse terrain case',type='list',def='flat',items={{key='flat',name='Flat'},{key='edge',name='Map edge'},{key='slope',name='Slope'},{key='water',name='Water'},{key='obstruction',name='Solid obstruction'}}}
options[#options+1]={key='prototype_multisquad_corpse_run_id',name='Owned fresh native corpse run identity',type='string',def=''}
options[#options+1]={key='prototype_mount_burst_observer',name='Owned real-shot hull observer',desc='Default-off funded diagnostics; no firing/physics changes.',type='bool',def=false}
options[#options+1]={key='prototype_nob_corpse_fixture',name='Owned paid Nob3 native remains diagnostic; funded hostile blast only',type='bool',def=false}
options[#options+1]={key='prototype_squad_save_pending_research_fixture',name='Owned genuinely pending paid Guard equipment save witness',type='bool',def=false}
options[#options+1]={key='prototype_squad_save_pending_first_tick_fixture',name='Owned pending research serialized pre-controller firstTick witness',type='bool',def=false}
options[#options+1]={key='prototype_necron_native_factory_pilot',name='Owned Necron native vehicle factory pilot',type='bool',def=false}
options[#options+1]={key='prototype_necron_factory_paid_fixture',name='Owned ordinary paid Necron vehicle factory egress witness',type='bool',def=false}
options[#options+1]={key='prototype_feature_remains_digest',name='Owned bounded native feature/remains digest supplement',desc='Default-off read-only supplement at existing body digest common frames; native reclaim/network acceptance external.',type='bool',def=false}
options[#options+1]={key='prototype_squad_cancel_fixture',name='Owned ordinary Tactical native cancel and retry',type='bool',def=false}
options[#options+1]={key='prototype_ork_air_factory_repeat_fixture',name='Owned ordinary-paid Ork native air factory repeat witness',type='bool',def=false}
options[#options+1]={key='prototype_immortal_emitter_fixture',name='Owned paid Immortal3 native two-emitter diagnostic; funded enemy only',type='bool',def=false}
options[#options+1]={key='prototype_immortal_paid_driver',name='Owned ordinary paid Immortal factory ladder driver',type='bool',def=false}
options[#options+1]={key='prototype_centre_march_native_observer',name='Owned read-only ordinary Guard CentreMarch witness',type='bool',def=false}
options[#options+1]={key='prototype_terminator_native_observer',name='Owned read-only full-three paired Terminator native geometry/gait/remains observer',type='bool',def=false}
options[#options+1]={key='prototype_terminator_paid_driver',name='Owned ordinary paid Marine native Terminator3 factory ladder',type='bool',def=false}
options[#options+1]={key='prototype_ork_extractor_armed_fixture',name='Owned FUNDED NON-ECONOMY Ork three-tier native armed extractor witness',desc='Default off; ordinary paid replacement lifecycle remains separate.',type='bool',def=false}
options[#options+1]={key='prototype_paid_repair_placement_observer',name='Owned paid Guard replacement placement observer',type='bool',def=false}
options[#options+1]={key='prototype_paid_repair_placement_frames',name='Explicit paid repair placement sample frames',type='string',def=''}
options[#options+1]={key='prototype_basilica_paid_driver',name='Owned Basilica ordinary paid Guard wall/reclaim driver',type='bool',def=false}
options[#options+1]={key='prototype_basilica_wall_observer',name='Owned Basilica read-only wall lifecycle observer',type='bool',def=false}
options[#options+1]={key='prototype_necron_remains_native_fixture',name='Owned Necron ordinary paid remains diagnostic context',type='bool',def=false}
options[#options+1]={key='prototype_necron_remains_paid_driver',name='Owned ordinary paid Necron remains production driver',type='bool',def=false}
options[#options+1]={key='prototype_necron_immortal_remains_native_fixture',name='Owned paid Immortal3 natural hostile remains route',type='bool',def=false}
options[#options+1]={key='prototype_necron_flayed_remains_native_fixture',name='Owned paid Flayed4 natural hostile remains route',type='bool',def=false}
options[#options+1]={key='prototype_necron_remains_native_actor',name='Owned exact Necron remains actor',type='list',def='immortal',items={{key='immortal',name='Immortal3'},{key='flayed',name='Flayed4'}}}
options[#options+1]={key='prototype_necron_remains_run_id',name='Owned unique Necron remains native run identity',type='string',def=''}
options[#options+1]={key='prototype_scout_paid_driver',name='Owned ordinary paid Scout repeated factory driver',type='bool',def=false}
options[#options+1]={key='prototype_guard_ogryn_paid_driver',name='Owned ordinary paid Ogryn T2 factory driver',type='bool',def=false}
options[#options+1]={key='prototype_corpse_save_checkpoint_fixture',name='Owned Heavy corpse SSF checkpoint',type='bool',def=false,section='prototype'}
options[#options+1]={key='prototype_corpse_save_first_tick_fixture',name='Heavy SSF firsttick only',type='bool',def=false,section='prototype'}
options[#options+1]={key='prototype_corpse_save_checkpoint_name',name='Unique owned Heavy SSF name',type='string',def='',section='prototype'}
options[#options+1]={key='prototype_corpse_save_run_id',name='Fresh owned Heavy run identity',type='string',def='',section='prototype'}
options[#options+1]={key='prototype_ork_tankbusta_native_fixture',name='Owned ordinary paid Tankbusta repeated factory preparation',type='bool',def=false}
options[#options+1]={key='prototype_russ_four_mount_fixture',name='Owned funded Russ four native mounts diagnostic',type='bool',def=false}
options[#options+1]={key='prototype_guard_research_capture_fixture',name='Owned Guard research capture observer',desc='Default-off read-only ordinary two-owner native capture scene; no setup orders',type='bool',def=false}
options[#options+1]={key='prototype_guard_factory_geometry_receipt',name='Owned read-only Guard proof-time native geometry receipt',type='bool',def=false}
options[#options+1]={key='prototype_marine_vehicle_factory_paid_fixture',name='Owned ordinary Marine native vehicle factory repeat witness',type='bool',def=false}
options[#options+1]={key='prototype_fighta_secondary_fixture',name='Owned funded genuine Fighta secondary mounts',desc='Unpaid own aircraft and hostile Russ; secondary2/3/4 native hits only, no economy acceptance',type='bool',def=false}
options[#options+1]={key='prototype_guard_capture_order_assistant',name='Owned ordinary Guard two-owner capture order assistance',type='bool',def=false,section='prototype'}
options[#options+1]={key='prototype_guard_kasrkin_native_fixture',name='Owned ordinary paid Kasrkin5 repeated production',desc='Two full5 Kasrkin products through existing Guard T2; no grants, native finish/release/egress only',type='bool',def=false}
options[#options+1]={key='prototype_predator_paid_combat_fixture',name='Owned ordinary paid Predator three-mount combat follow-on',desc='Preserves paid two-product factory route; hostile Russ only unpaid, non-economy combat',type='bool',def=false}
options[#options+1]={key='prototype_centre_march_research_repair_probe',name='40K AI Guard paid research repair probe',desc='Default-off ordinary AI decisions and explicitly scripted casualty; no grants.',type='bool',def=false,section='40kprototype'}
options[#options+1]={key='prototype_ork_meganob_native_fixture',name='Paid Meganob3 Warcamp native fixture',desc='Default-off earned INF1/corck/INF2/corack/Warcamp ladder and one full3 product; no combat/economy acceptance',type='bool',def=false,section='prototype'}
options[#options+1]={key='prototype_ork_loota_native_fixture',name='Paid Loota3 repeat native fixture',desc='Default-off earned INF1/corck/INF2/corack/Warcamp ladder and two full3 products; no combat/economy acceptance',type='bool',def=false,section='prototype'}
options[#options+1]={key='prototype_scout_remains_pilot',name='Owned authored static Scout remains pilot',desc='Default-off private paid-body quarter reclaim through existing owner; native presentation pending',type='bool',def=false}
options[#options+1]={key='prototype_guard_kasrkin_remains_pilot',name='Owned genuine Kasrkin terminal corpse pilot',desc='Default-off closed source derivative; native visual/reclaim acceptance pending',type='bool',def=false}
options[#options+1]={key='prototype_ogryn_remains_pilot',name='Owned genuine Ogryn terminal corpse pilot',desc='Default-off closed source derivative; native visual/reclaim acceptance pending',type='bool',def=false}
options[#options+1]={key='prototype_ork_burna_squad',name='Burna Boyz squads',desc='One paid factory order produces 4 real Burna Boyz. Builders restore casualties for resources.',type='bool',def=true}
options[#options+1]={key='prototype_corpse_presentation_fixture',name='Private corpse presentation diagnostic',desc='Zero-currency Scout/Kasrkin/Ogryn compiled native features; screenshot requests only.',type='bool',def=false}
options[#options+1]={key='prototype_ork_slugga_squad',name='Slugga Boyz squads',desc='One paid factory order produces 8 real Slugga Boyz. Builders restore casualties for resources.',type='bool',def=true}
options[#options+1]={key='prototype_elite_corpse_reclaim_fixture',name='Private funded elite corpse reclaim diagnostic',type='bool',def=false}
options[#options+1]={key='prototype_elite_corpse_reclaim_team',name='Owned elite reclaim fixture team',type='number',def=0,min=0,max=255,step=1}
options[#options+1]={key='prototype_ork_burna_native_fixture',name='Burna4 ordinary paid production diagnostic',desc='Default-off earned INF1/corck/INF2 ladder, two paid full4 products, native releases and all-body egress; no grants or combat acceptance',type='bool',def=false,section='prototype'}
options[#options+1]={key='prototype_ork_slugga_native_fixture',name='Slugga8 ordinary paid production diagnostic',desc='Default-off two paid full8 native finishes, factory releases and all-body egress; native melee pending; no grants',type='bool',def=false,section='prototype'}
options[#options+1]={key='prototype_burna_flame_combat',name='Funded full4 Burna Flame native witness',desc='Default-off non-economy own factory/product/hostile scene; original physics and weapons.',type='bool',def=false}
options[#options+1]={key='prototype_burna_flame_actor',name='Exact funded Burna actor selector',desc='Empty unless the exclusive funded scene is selected; exact ork_burna only.',type='string',def=''}
options[#options+1]={key='prototype_flayed_terminal_remains_pilot',name='Private genuine Flayed terminal129 remains',type='bool',def=false}
options[#options+1]={key='prototype_burna_remains_pilot',name='Owned genuine Burna terminal corpse pilot',desc='Default-off closed source derivative through existing sole owner; native visual/reclaim acceptance pending',type='bool',def=false}
options[#options+1]={key='prototype_slugga_remains_pilot',name='Owned genuine Slugga terminal corpse pilot',desc='Default-off closed source derivative through existing sole owner; native visual/reclaim acceptance pending',type='bool',def=false}
options[#options+1]={key='prototype_corpse_presentation_actors',name='Exact owned corpse presentation actor family',desc='Empty preserves Scout/Kasrkin/Ogryn; exact ork selects two zero-currency source features only.',type='string',def=''}
options[#options+1]={key='prototype_stock_music_observer',name='Owned stock music playback observer',desc='Default-off bounded readonly stream/settings evidence; no audio control or audible acceptance.',type='bool',def=false}
options[#options+1]={key='prototype_marine_research_capture_fixture',name='Private ordinary Marine research capture observer',type='bool',def=false}
options[#options+1]={key='prototype_marine_capture_order_assistant',name='Owned ordinary Marine capture order assistant; disclosed fromLua orders',type='bool',def=false}
options[#options+1]={key='prototype_ork_advanced_air_development',name='Ork advanced air development',desc='Enable implemented T2/T3 Ork aircraft production for controlled development; normal playtest defaults off.',type='bool',def=false,section='prototype'}
options[#options+1]={key='prototype_generator_native_fixture',name='Isolated generator appearance/paid-neighbor observation',type='bool',def=false}
options[#options+1]={key='prototype_generator_native_mode',name='Explicit generator native diagnostic mode',type='string',def=''}
options[#options+1]={key='prototype_generator_native_key',name='Exact bound generator native diagnostic key',type='string',def=''}
options[#options+1]={key='prototype_squad_formation_native_fixture',name='Shared infantry movement diagnostic',desc='Controlled unpaid factory/wall/builder scene; one native full8 product, raw formation travel, obstacles, queues, leader succession, paid slot1 restore and STOP. No economy acceptance.',type='bool',def=false,section='prototype'}
options[#options+1]={key='prototype_ork_gunship_native_fixture',name='Owned approved Gunship native/human diagnostic',desc='Explicit direct-spawn thirteen-owner model/weapon check or human preview; NOT ordinary economy or progression acceptance.',type='bool',def=false}
options[#options+1]={key='prototype_ork_gunship_native_mode',name='Owned approved Gunship diagnostic mode',desc='Explicit native13 or human; empty in normal play.',type='string',def=''}
options[#options+1]={key='prototype_ork_goh_native_fixture',name='Owned exact GOH motion and ranged mount diagnostic',desc='Directly spawned actor/target, native movement/HP and one wreck only. No ordinary production, visual or reclaim acceptance.',type='bool',def=false}
options[#options+1]={key='prototype_ork_goh_native_actor',name='Exact owned GOH diagnostic actor',desc='Empty normally; warbike or morkanaut only with the exclusive fixture.',type='string',def=''}
options[#options+1]={key='prototype_corpse_pile_native_fixture',name='Isolated synthetic native pile M/E reclaim/passage check',type='bool',def=false}
options[#options+1]={key='prototype_ork_mek_kopta_source_review',name='Owned genuine smertolet presentation review',desc='Default-off root-scheduled isolated art/rotor/nano/flight/build review using unchanged native constructor gameplay. No normal final-art acceptance.',type='bool',def=false,section='prototype'}
options[#options+1]={key='prototype_ork_big_mek_kopta_source_review',name='Owned tandem smertolet presentation review',desc='Default-off root-scheduled authored tandem art/rotor/nano/flight/build review; unchanged native T2 constructor gameplay. No normal final-art acceptance.',type='bool',def=false,section='prototype'}
options[#options+1]={key='prototype_dakka_reference_review',name='Unpaid Dakka Juggernaut scale diagnostic',desc='Default-off exact paired model/bank/wreck review; ordinary production and final readiness remain held.',type='bool',def=false}
options[#options+1]={key='prototype_wartrukk_transport_pilot',name='Owned full8 genuine Wartrukk transport candidate',desc='Default-off actual eight-body reservation/hidden cargo/native wreck candidate; ordinary and native acceptance pending.',type='bool',def=false}
options[#options+1]={key='prototype_wartrukk_native_fixture',name='Owned exact native ground Wartrukk full8 check',desc='Spawned production setup, paid native queues and two real-body ground load/unload cycles; no ordinary progression or visual acceptance.',type='bool',def=false}
options[#options+1]={key='prototype_human_inspection_scene',name='Six-unit human inspection scene',desc='Direct-spawn development inspection only; no ordinary production or acceptance claim. No automatic orders or shutdown.',type='bool',def=false}
options[#options+1]={key='prototype_diagnostic',name='40K ordinary game mode',type='string',def='normal'}
return options
