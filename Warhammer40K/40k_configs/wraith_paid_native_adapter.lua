-- Read-only proof adapter. Native commands are owned by its dedicated fixture.
local M={}
function M.New(S,Q)
 local A={before=false,after=false,incomingZero=0,outgoingZero=0,projectiles=0,incomingProjectiles=0,nativeOutgoingHits=0,requests={},pending={},failure=nil}
 local fps=Q.fps;local actor,enemy,team,hq,started,deadline,recharge,baselineShot
 local function fail(reason)A.failure=A.failure or reason;return false,reason end
 local function live(id)return id and S.ValidUnitID(id)and not S.GetUnitIsDead(id)end
 local function snapshot()return Q.Controller().Snapshot(actor)end
 local function emit(event,row)Q.Journal(event,row or{})end
 function A.Begin(id,opponent,owner,producer,paid)
  if not live(id)or not live(opponent)or not live(producer)or S.GetUnitTeam(id)~=owner or S.GetUnitTeam(producer)~=owner or S.AreTeamsAllied(owner,S.GetUnitTeam(opponent))~=false then return fail('live_paid_actors_missing')end
  local _,_,_,_,built=S.GetUnitHealth(id);local hp,_,_,_,hqBuilt=S.GetUnitHealth(producer)
  if built~=1 or not hp or hp<=0 or hqBuilt~=1 or S.GetUnitDefID(producer)~=Q.hqDef then return fail('finished_live_hq_or_actor_missing')end
  if not paid or paid.builder~=producer or paid.finished~=true or paid.egress~=true or paid.queueDef~=-Q.wraithDef or not paid.queueTag or not paid.researchPaid then return fail('paid_birth_finish_egress_and_research_missing')end
  actor,enemy,team,hq=id,opponent,owner,producer;A.mode='before';emit('PAID_ACTOR_READY',{actor=id,enemy=opponent,hq=producer});return true
 end
 function A.Projectile(id,owner,weapon,frame)
  if owner==enemy then A.incomingProjectiles=A.incomingProjectiles+1;emit('NATIVE_INCOMING_PROJECTILE',{id=id,owner=owner,weapon=weapon,frame=frame});return end
  if owner~=actor then return end
  A.projectiles=A.projectiles+1;emit('NATIVE_PROJECTILE',{id=id,owner=owner,weapon=weapon,frame=frame})
  if A.mode=='phase'and frame>=started and frame<deadline then fail('new_projectile_during_phase')end
 end
 function A.Witness(event,id,...)
  if id~=actor then return end
  local v={...};local f=S.GetGameFrame()
  if event=='SCRIPT_ATTACK_BOUNDARY'then
   local boundary,mount,observedFrame,pendingStart,currentPending,currentMelee,preparingStart=v[1],v[2],v[3],v[4],v[5],v[6],v[7]
   if observedFrame~=f or type(mount)~='number'then fail('native_script_boundary_identity_missing');return end
   emit('NATIVE_SCRIPT_ATTACK_BOUNDARY',{boundary=boundary,mount=mount,frame=f,pendingStart=pendingStart,currentPending=currentPending,currentMelee=currentMelee,preparingStart=preparingStart})
   if boundary=='pending_melee'and A.mode=='before'and A.before and A.nativeOutgoingHits>0 then
    if type(pendingStart)~='number'or pendingStart~=currentPending or currentMelee~=true then fail('actual_pending_melee_state_missing');return end
    A.observedPending={mount=mount,start=pendingStart,frame=f};A.Start(f)
   elseif boundary=='phase_cancel_before'and A.mode=='phase'then
    local p=A.observedPending
    if not p or mount~=p.mount or pendingStart~=p.start or currentPending~=p.start or currentMelee~=true then fail('phase_cancellation_not_original_pending');return end
    A.cancelBefore=f
   elseif boundary=='phase_cancel_after'and A.mode=='phase'then
    local p=A.observedPending
    if not p or mount~=p.mount or pendingStart~=p.start or A.cancelBefore~=f or currentPending~=nil or currentMelee~=false then fail('actual_post_cancel_state_missing');return end
    A.cancelAfter=f
   end
   return
  end
  if event=='PHASE_REQUEST'then A.requests[#A.requests+1]={frame=f,ok=v[1],reason=v[2]};emit('NATIVE_PHASE_REQUEST',{frame=f,ok=v[1],reason=v[2]});return end
  if event~='DAMAGE_RETURN'and event~='OUTGOING_RETURN'then return end
  local raw,returned,reason,weapon,projectile,other=v[1],v[2],v[3],v[4],v[5],v[6]
  if not(raw and raw>0)or type(projectile)~='number'then fail('native_positive_damage_callback_required');return end
  -- Preserve native sentinel -1 for non-projectile melee; never invent a projectile ID.
  local hp,max,_,_,built=S.GetUnitHealth(event=='DAMAGE_RETURN'and actor or other)
  if not hp or not max or built~=1 then fail('native_damage_health_unreadable');return end
  local row={frame=f,raw=raw,returned=returned,reason=reason,weapon=weapon,projectile=projectile,other=other,hp=hp,max=max}
  emit('NATIVE_DAMAGE_RETURN',row)
  if event=='DAMAGE_RETURN'and other==enemy then
   if reason=='base_ranged_defense'and Q.Ranged(weapon)then
    if returned~=raw*.75 then fail('base_ranged_factor_not_exact');return end
    A.pending[projectile]={row=row,mode=A.mode,victim=actor,attacker=enemy}
   elseif A.mode=='phase'and reason=='phase_incoming_refused'and returned==0 then
    A.incomingZero=A.incomingZero+1;A.firstZero=A.firstZero or f;A.lastZero=f;A.pending[projectile]={row=row,zero=true,victim=actor,attacker=enemy}
   end
  elseif event=='OUTGOING_RETURN'and other==enemy and A.mode=='phase'and reason=='phase_outgoing_refused'and returned==0 then
   A.outgoingZero=A.outgoingZero+1;A.pending[projectile]={row=row,zero=true,victim=enemy,attacker=actor}
  end
 end
 function A.Damaged(victim,damage,paralyzer,weapon,projectile,attacker,frame)
  if victim~=actor and attacker~=actor then return end
  if A.mode=='before'and attacker==actor and victim==enemy and damage>0 and not paralyzer then A.nativeOutgoingHits=A.nativeOutgoingHits+1 end
  if A.mode=='phase'and frame<deadline and not paralyzer and damage>0 then return fail('positive_health_damage_during_phase')end
  local t=A.pending[projectile]
  if not t or t.victim~=victim or t.attacker~=attacker or t.row.weapon~=weapon or t.row.frame~=frame then
   if damage>0 and victim==actor then return fail('unmatched_native_health_damage')end;return true
  end
  local hp,max=S.GetUnitHealth(victim)
  if not hp or math.abs(hp-(t.row.hp-damage))>.02 or max~=t.row.max then return fail('native_applied_health_subtraction_mismatch')end
  if t.zero then if damage~=0 then return fail('returned_zero_applied_positive')end
  elseif not paralyzer and damage>0 and(t.mode=='before'or t.mode=='after')then A[t.mode]=true end
  emit('NATIVE_APPLIED_DAMAGE',{frame=frame,damage=damage,victim=victim,projectile=projectile,mode=t.mode});A.pending[projectile]=nil;return true
 end
 function A.Start(frame)
  if not A.before or not actor or not Q.PaidResearch(team)or not live(hq)then return fail('native_base_before_or_paid_live_hq_missing')end
  local shot=S.GetUnitRulesParam(actor,'40k_last_shot_1')
  if type(shot)~='number'or shot>frame or A.nativeOutgoingHits<1 or A.incomingProjectiles<1 then return fail('real_attack_before_cancellation_missing')end
  if not A.observedPending or A.observedPending.frame~=frame then return fail('genuine_pending_windup_required')end
  baselineShot=shot;started=frame;deadline=frame+10*fps;recharge=frame+45*fps
  Q.Order(actor,34578,{},{});local t=snapshot()
  if not t or t.active~=deadline or t.ready~=recharge or t.team~=team then return fail('native_phase_command_timer_missing')end
  A.mode='phase';emit('PHASE_STARTED',{frame=frame,deadline=deadline,recharge=recharge,priorShot=shot});return true
 end
 function A.Frame(frame)
  if A.failure or not actor then return end
  if not live(actor)or not live(enemy)or not live(hq)or S.GetUnitTeam(actor)~=team or not Q.PaidResearch(team)then fail('live_paid_prerequisite_lost');return end
  local hp,_,_,_,built=S.GetUnitHealth(hq);if S.GetUnitTeam(hq)~=team or not hp or hp<=0 or built~=1 or S.AreTeamsAllied(team,S.GetUnitTeam(enemy))~=false then fail('hq_or_hostility_prerequisite_changed');return end
  local C=Q.Controller();if not C then fail('review_controller_lost');return end
  for projectile,t in pairs(A.pending)do if t.zero and frame>t.row.frame then
   local hp,max=S.GetUnitHealth(t.victim)
   if not hp or math.abs(hp-t.row.hp)>.02 or max~=t.row.max then fail('refused_hit_health_changed_unattributed');return end
   emit('NATIVE_ZERO_HEALTH_VERIFIED',{frame=frame,projectile=projectile,victim=t.victim});A.pending[projectile]=nil
  end end
  if A.mode=='phase'then
   if frame<deadline then
    if not C.IsActive(actor,frame)or C.CanAttack(actor,frame)~=false then fail('phase_window_or_attack_gate_missing');return end
    if S.GetUnitRulesParam(actor,'40k_last_shot_1')~=baselineShot then fail('native_shot_during_phase');return end
    if A.cancelAfter and frame>A.cancelAfter and not A.pendingCancelled then
     if not S.GetUnitWeaponState then fail('native_weapon_state_getter_missing');return end
     -- Pinned native getter has no named aimReady key. No-key value1 is angleGood,
     -- the identical field written by the BAR wrapper's aimReady setter.
     local angleGood,reloaded,reloadFrame,salvoLeft,stockpiled=S.GetUnitWeaponState(actor,A.observedPending.mount)
     if type(angleGood)~='boolean'or type(reloaded)~='boolean'or type(reloadFrame)~='number'or type(salvoLeft)~='number'or type(stockpiled)~='number'then fail('native_weapon_state_tuple_unreadable');return end
     if angleGood~=false then fail('native_wrapped_angle_good_not_false');return end
     A.pendingCancelled=true;emit('NATIVE_PENDING_CANCEL_AND_ANGLEGOOD_VERIFIED',{frame=frame,mount=A.observedPending.mount,pendingStart=A.observedPending.start,cancelFrame=A.cancelAfter,angleGood=angleGood,reloaded=reloaded,reloadFrame=reloadFrame,salvoLeft=salvoLeft,stockpiled=stockpiled})
    end
   else
    if C.IsActive(actor,frame)or not C.CanAttack(actor,frame)then fail('ten_second_boundary_missing');return end
    if not A.firstZero or A.firstZero>started+fps or not A.lastZero or A.lastZero<deadline-fps then fail('incoming_zero_whole_window_evidence_missing');return end
    local ok,reason=C.CanActivate(actor,frame);if ok or reason~='cooldown'then fail('cooldown_refusal_missing');return end
    Q.Order(actor,34578,{},{});local t=snapshot();if t.active~=deadline or t.ready~=recharge then fail('cooldown_refusal_changed_timers');return end
    A.mode='after';emit('TEN_SECOND_END_AND_COOLDOWN_REFUSAL',{frame=frame});Q.Order(actor,CMD.STOP,{},{});Q.Order(actor,CMD.FIRE_STATE,{0},{})
   end
  elseif A.mode=='after'and A.after then
   Q.Order(enemy,CMD.STOP,{},{});Q.Order(enemy,CMD.FIRE_STATE,{0},{});A.mode='cooldown';emit('BASE_RANGED_AFTER_VERIFIED')
  elseif A.mode=='cooldown'then
   local ok,reason=C.CanActivate(actor,frame)
   if frame<recharge then if ok or reason~='cooldown'then fail('early_recharge_eligible');return end
    if frame==recharge-1 then Q.Order(actor,34578,{},{});if snapshot().ready~=recharge then fail('last_frame_cooldown_reset');return end end
   else
    if frame~=recharge or not ok then fail('exact_45_second_recharge_missing');return end
    Q.Order(actor,34578,{},{});local t=snapshot();if t.active~=frame+10*fps or t.ready~=frame+45*fps then fail('native_reactivation_missing');return end
    A.mode='done';emit('COOLDOWN_AND_CANCELLATION_VERIFIED',{frame=frame,incomingZero=A.incomingZero,outgoingZero=A.outgoingZero})
   end
  end
 end
 function A.Result()
  local missing={};if A.failure then missing[#missing+1]=A.failure end
  if A.mode~='done'then missing[#missing+1]='bounded_native_sequence_incomplete'end
  if A.outgoingZero<1 then missing[#missing+1]='actual_outgoing_zero_damage_callback_missing'end
  if not A.pendingCancelled then missing[#missing+1]='native_pending_windup_cancellation_receipt_missing'end
  return #missing==0,missing
 end
 return A
end
return M
