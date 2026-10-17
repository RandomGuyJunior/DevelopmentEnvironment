-- Observe actual two native Immortal BeamLaser mounts; no weapon/damage edits.
local M={Option='prototype_immortal_emitter_fixture',Capacity=3,ProfileID=9}
local function yes(v)return v==true or v==1 or v=='1'end
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local markers={' marker_gauss_muzzle01_ext',' marker_gauss_muzzle02_ext'}
function M.Enabled(o)
 o=o or{}
 return yes(o[M.Option])and yes(o.prototype_development_playtest)and yes(o.prototype_source_paid_match)
  and yes(o.prototype_source_progression)and yes(o.prototype_necron_immortal_squad)and o.prototype_diagnostic=='normal'
  and not yes(o.prototype_scale085_pilot)
end
function M.New(S,D,W,R,origin,emit,physical)
 local C={phase='site',start=S.GetGameFrame(),bodies={},shots={},projectiles={},seen={},target=nil}
 local function fail(why)C.result=C.result or('FAIL '..why);return C.result end
 function C.Close()C.closed=true end
 for _,api in ipairs({'GetUnitCosts','GetUnitHealth','GetUnitDefID','GetUnitTeam','GetUnitTransporter','GetUnitRulesParam','GetUnitPieceMap','GetUnitPiecePosDir','GetUnitWeaponState','GetUnitPosition','GetUnitLosState','GetUnitAllyTeam','GetUnitWeaponTestRange','IsPosInLos','TestMoveOrder','GetGroundHeight','GetUnitsInRectangle','GetFeaturesInRectangle','GetUnitIsBuilding','GetUnitCommands','AreTeamsAllied','GetTeamList','GetGaiaTeamID','CreateUnit','GiveOrderToUnit'})do
  if type(S[api])~='function'then fail('missing_native_API_'..api);return C end
 end
 if not R or type(R.Get)~='function'or type(R.Members)~='function'or type(origin)~='table'or not finite(origin.created)or not finite(origin.released)or origin.released<origin.created
  or origin.createdWork~=2550 or origin.createdMetal~=255 or origin.createdEnergy~=1320 or not origin.finished then fail('observed_paid_factory_origin_required');return C end
 local product,factory,team=origin.product,origin.factory,origin.team
 local squad=R.Get(product);local fd=D[S.GetUnitDefID(factory)]
 if not squad or squad.profile~='necron_immortal'or squad.leader~=product or squad.team~=team or not squad.generations or not squad.slots or #R.Members(product)~=3
  or S.GetUnitDefID(product)~=origin.productDefinition or not fd or fd.name~='nec_advanced_factory'or S.GetUnitTeam(factory)~=team or S.GetUnitIsBuilding(factory)==product then fail('released_paid_Immortal3_current_factory_required');return C end
 local buildable=false;for _,def in pairs(fd.buildOptions or{})do if def==origin.productDefinition then buildable=true end end
 if not buildable then fail('current_native_factory_menu_required');return C end
 C.team=team;C.product=product;C.factory=factory;C.seed=squad.id
 local seen={}
 for slot=1,3 do
  local id=squad.slots[slot];local def=id and S.GetUnitDefID(id);local d=def and D[def];local cp=d and d.customParams or{}
  local finished=id and origin.finished[id];local work,metal,energy
  if id then work,metal,energy=S.GetUnitCosts(id)end
  local hp,max,_,_,built;if id then hp,max,_,_,built=S.GetUnitHealth(id)end
  local generation=squad.generations[slot]
  if not id or seen[id]or not d or cp.animsource~='nec_immortal'or not tostring(d.scriptName):lower():match('40k_roster%.lua$')
   or S.GetUnitTeam(id)~=team or not hp or hp<=0 or built~=1 or work~=850 or metal~=85 or energy~=440
   or not finished or finished.def~=def or finished.team~=team or not finite(generation)or generation%1~=0 or generation<1
   or S.GetUnitRulesParam(id,'40k_squad_schema')~=2 or S.GetUnitRulesParam(id,'40k_squad_id')~=C.seed
   or S.GetUnitRulesParam(id,'40k_squad_slot')~=slot or S.GetUnitRulesParam(id,'40k_squad_generation')~=generation
   or S.GetUnitRulesParam(id,'40k_squad_investment_metal')~=85 or S.GetUnitRulesParam(id,'40k_squad_investment_energy')~=440
   or S.GetUnitRulesParam(id,'40k_squad_investment_work')~=850 or S.GetUnitTransporter(id)then fail('paid_body_finish_identity_or_bill_required');return C end
  if type(physical)~='table'or physical.Outside(S,D,factory,id)~=true then fail('actual_native_collider_and_yard_release_required');return C end
  seen[id]=true;local map=S.GetUnitPieceMap(id)or{}
  local row={slot=slot,def=def,generation=generation,mounts={}}
  if not d.weapons or #d.weapons~=2 then fail('actual_two_native_Immortal_mounts_required');return C end
  local wids={}
  for n=1,2 do
   local entry=d.weapons[n];local wd=entry and W[entry.weaponDef];local p=wd and wd.customParams or{}
   if not wd or wids[entry.weaponDef]or wd.type~='BeamLaser'or wd.range~=340 or p.source_muzzle~=markers[n]
    or p.source_fireclip~='fire'or p.source_muzzle_pair or not map[markers[n]]or map[markers[1]]==map[markers[2]]then fail('true_WeaponDef_and_exact_native_emitter_mapping_required');return C end
   wids[entry.weaponDef]=true;row.mounts[n]={weapon=entry.weaponDef,piece=map[markers[n]],cycles=0,hits=0}
  end
  C.bodies[id]=row
 end
 for slot in pairs(squad.slots)do if type(slot)=='number'and(slot<1 or slot>3)then fail('extra_cohort_slot');return C end end
 for _,enemy in ipairs(S.GetTeamList())do if enemy~=S.GetGaiaTeamID()and not S.AreTeamsAllied(team,enemy)then C.enemy=enemy;break end end
 if not C.enemy then C.result='INCONCLUSIVE hostile_team_required';return C end
 local target=UnitDefNames.imp_russ;local td=target and D[target.id]
 if not td or td.canFly or not finite(td.xsize)or not finite(td.zsize)or td.xsize<=0 or td.zsize<=0 then fail('genuine_native_ground_target_required');return C end
 C.targetDefinition=target.id
 function C.Telemetry(row)
  if C.closed or C.result or C.phase~='fire'or not C.bodies[row.owner]then return end
  local body=C.bodies[row.owner];local mount=body.mounts[row.mount]
  if not mount then fail('foreign_native_mount');return end
  if row.kind=='SHOT'then
   local los=S.GetUnitLosState(C.target,S.GetUnitAllyTeam(row.owner),false)or{}
   local hp,_,_,_,built=S.GetUnitHealth(C.target)
   if los.los~=true or S.GetUnitTeam(C.target)~=C.enemy or not hp or hp<=0 or built~=1 then fail('naturally_visible_finished_hostile_target_required');return end
   local burst=S.GetUnitWeaponState(row.owner,row.mount,'burst');local delay=S.GetUnitWeaponState(row.owner,row.mount,'burstRate');local reload=S.GetUnitWeaponState(row.owner,row.mount,'reloadTimeXP')
   if burst~=1 or delay~=0 or not finite(reload)or reload<=0 or S.GetUnitWeaponState(row.owner,row.mount,'salvoLeft')~=0
    or row.ambiguous or not row.snapshot or row.snapshot.muzzle_piece~=mount.piece or not row.native_target or row.native_target[1]~=1 or row.native_target[3]~=C.target then fail('actual_native_Immortal_shot_clock_query_target_required');return end
   if mount.last and row.frame-mount.last<math.floor(reload*Game.gameSpeed)-1 then fail('native_XP_reload_clock_too_fast');return end
   mount.last=row.frame;mount.cycles=mount.cycles+1
   C.shots[row.serial]={owner=row.owner,mount=row.mount,frame=row.frame}
   emit('IMMORTAL_NATIVE_SHOT','body='..row.owner,'mount='..row.mount,'frame='..row.frame,'reloadXP='..reload,'source_cosmetic_flash_only_not_render_acceptance=true')
  elseif row.kind=='PROJECTILE'then
   local shot=C.shots[row.shot_serial];local q=row.actual_query;local pos=row.position;local query=q and q.snapshot and q.snapshot.muzzle_position
   if C.seen[row.projectile]or row.duplicate_pid or row.association~='unique_same_frame_unconsumed_shot'or not shot or shot.owner~=row.owner or shot.mount~=row.mount
    or shot.frame~=row.frame or row.weapondef~=mount.weapon or not q or q.piece~=mount.piece or not pos or not query then fail('native_PID_WD_actual_QueryShot_association_required');return end
   for i=1,3 do if not finite(pos[i])or not finite(query[i])then fail('nonfinite_native_origin');return end end
   if(pos[1]-query[1])^2+(pos[2]-query[2])^2+(pos[3]-query[3])^2>16 then fail('native_beam_birth_not_actual_emitter');return end
   C.seen[row.projectile]=true;C.projectiles[row.projectile]={owner=row.owner,mount=row.mount,weapon=row.weapondef,frame=row.frame}
   emit('IMMORTAL_NATIVE_BEAM','pid='..row.projectile,'body='..row.owner,'mount='..row.mount,'weaponDef='..row.weapondef,'actual_Query_piece='..q.piece,
    'shot_serial='..row.shot_serial,'native_frame='..row.frame,'native_birth_xyz='..table.concat(pos,','),'actual_Query_xyz='..table.concat(query,','))
  end
 end
 function C.Damaged(id,damage,paralyzer,wd,pid,attacker)
  if C.closed or C.result or C.phase~='fire'or id~=C.target then return end
  local hp=S.GetUnitHealth(id);local loss=hp and C.lastHP and C.lastHP-hp;C.lastHP=hp
  local p=C.projectiles[pid]
  if not p or p.hit or p.owner~=attacker or p.weapon~=wd or paralyzer or not finite(damage)or damage<=0 or not loss or loss<=0 then fail('owned_native_beam_damage_and_HP_loss_required');return end
  p.hit=true;local mount=C.bodies[attacker].mounts[p.mount];mount.hits=mount.hits+1
  emit('IMMORTAL_NATIVE_HIT','pid='..pid,'body='..attacker,'mount='..p.mount,'damage='..damage,'HP='..hp,'native_damage_owner=true')
 end
 local function intact()
  local current=R.Get(product)
  if not current or current.id~=C.seed or current.team~=team or current.leader~=product or #R.Members(product)~=3 then return false end
  for id,b in pairs(C.bodies)do
   local hp,_,_,_,built=S.GetUnitHealth(id)
   if current.slots[b.slot]~=id or current.generations[b.slot]~=b.generation or S.GetUnitDefID(id)~=b.def or S.GetUnitTeam(id)~=team or not hp or hp<=0 or built~=1 or S.GetUnitTransporter(id)then return false end
  end
  return true
 end
 local function site()
  local x,y,z=S.GetUnitPosition(product);local hx,hz=td.xsize*4+16,td.zsize*4+16
  if not finite(x)or not finite(z)then return end
  for j=0,15 do local angle=j*math.pi/8;local tx,tz=x+180*math.cos(angle),z+180*math.sin(angle);local ty=S.GetGroundHeight(tx,tz)
   if finite(ty)and ty>=0 and tx-hx>32 and tz-hz>32 and tx+hx<Game.mapSizeX-32 and tz+hz<Game.mapSizeZ-32
    and S.TestMoveOrder(target.id,tx,ty,tz,0,0,0,true,true,false)==true
    and #(S.GetUnitsInRectangle(tx-hx,tz-hz,tx+hx,tz+hz)or{})==0 and #(S.GetFeaturesInRectangle(tx-hx,tz-hz,tx+hx,tz+hz)or{})==0 then
    local legal=true
    for id in pairs(C.bodies)do for n=1,2 do
     local ally=S.GetUnitAllyTeam(id)
     if not S.IsPosInLos(tx,ty,tz,ally)or S.GetUnitWeaponTestRange(id,n,tx,ty,tz)~=true then legal=false end
    end end
    if legal then return tx,ty,tz end
   end
  end
 end
 function C.Step(frame)
  if C.closed or C.result then return C.result end
  if not intact()then return fail('paid_cohort_lost_transported_captured_or_repaired_during_fixture')end
  if C.phase=='site'and frame>C.start and frame%15==0 then
   local x,y,z=site()
   if x then
    C.target=S.CreateUnit('imp_russ',x,y,z,0,C.enemy)
    if not C.target then return fail('disclosed_funded_enemy_target_birth_failed')end
    S.GiveOrderToUnit(C.target,CMD.FIRE_STATE,{0},0);S.GiveOrderToUnit(C.target,CMD.MOVE_STATE,{0},0)
    C.phase='settle';C.stage=frame
    emit('IMMORTAL_TARGET','id='..C.target,'funded_hostile_target_only=true own_cohort_factory_paid=true paid_economy_acceptance=false')
   end
  elseif C.phase=='settle'and frame>C.stage then
   local hp,_,_,_,built=S.GetUnitHealth(C.target);local seen=true
   for id in pairs(C.bodies)do local los=S.GetUnitLosState(C.target,S.GetUnitAllyTeam(id),false)or{};if los.los~=true then seen=false end end
   if hp and hp>0 and built==1 and seen and S.GetUnitTeam(C.target)==C.enemy then
    C.lastHP=hp;C.phase='fire';C.stage=frame
    -- One ordinary leader ATTACK; existing unified squad controller owns dispatch.
    S.GiveOrderToUnit(product,CMD.ATTACK,{C.target},0)
   end
  elseif C.phase=='fire'then
   if S.GetUnitTeam(C.target)~=C.enemy then return fail('funded_hostile_target_transferred')end
   local ready=true;for _,body in pairs(C.bodies)do for _,mount in pairs(body.mounts)do if mount.cycles<2 or mount.hits<2 then ready=false end end end
   if ready then C.result='PASS paid_origin_full3_each_actual_native_mount_two_hit_cycles visual_geometry_and_economy_acceptance=false';return C.result end
  end
  if frame-C.start>=900 then C.result='INCONCLUSIVE bounded_native_Immortal_emitter_evidence_timeout';return C.result end
 end
 return C
end
return M
