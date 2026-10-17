-- Unpaid diagnostic ledger. Sole damage authority remains native weapons.
local M={Slots={4,1,3,2,5,6,7}}
function M.Enabled(o)
 o=o or{};local enabled=VFS.Include('40k_configs/development_playtest.lua').OptionEnabled
 return enabled(o.prototype_stompa_weapon_fixture) and enabled(o.prototype_stompa_multigun_review) and o.prototype_diagnostic=='stompaweapons' and not enabled(o.prototype_source_progression) and not enabled(o.prototype_source_paid_match) and not enabled(o.prototype_development_playtest) and (o.prototype_source_acceptance==nil or o.prototype_source_acceptance=='')
end
function M.New(api,actor,team,mounts,emit)
 local R={stage=0,rows={},failed=nil,closed=false,projectiles={}}
 local function fail(why)R.failed=R.failed or why;emit('FAIL '..why)end
 local function valid()return not R.closed and api.GetUnitTeam(actor)==team and not api.GetUnitIsDead(actor)end
 function R.Begin(slot,target,targetTeam,frame,ground)
  if not valid()then fail('actor_lifecycle');return false end
  local m=mounts[slot];if not m then fail('mount_missing');return false end
  if not ground and(api.GetUnitTeam(target)~=targetTeam or api.GetUnitIsDead(target))then fail('target_lifecycle');return false end
  R.stage=slot;R.target=target;R.targetTeam=targetTeam;R.ground=ground;R.start=frame;R.row={queries=0,shots=0,cycles=0,projectiles=0,damage=0,healthLoss=0,terrain=0,hitCycles={},cycleEvidence={}};R.rows[#R.rows+1]=R.row
  R.hp=not ground and api.GetUnitHealth(target)or nil;R.lastShot=nil;R.cycle=nil;return true
 end
 function R.Query(id,n,piece)
  if id~=actor or R.closed then return end
  if not valid()then fail('actor_lifecycle');return end
  if n~=R.stage then return end
  local expected=mounts[n].piece;if piece~=expected then fail('query_wrong_piece');return end
  local x,y,z=api.GetUnitPiecePosDir(id,piece);if not x or not y or not z then fail('native_piece_unknown');return end
  R.row.queries=R.row.queries+1;emit('QUERY slot='..n..' piece='..piece..' xyz='..x..','..y..','..z)
 end
 function R.Shot(id,n,frame)
  if id~=actor or R.closed then return end
  if not valid()then fail('actor_lifecycle');return end
  if n~=R.stage then fail('nonselected_native_shot');return end
  local m=mounts[n];local subframes=m.beam and math.max(1,math.floor(m.beamtime*30))or 0
  if not R.lastShot or frame-R.lastShot>subframes then
   if R.cycle and frame-R.cycle<math.floor(m.reload*30)-1 then fail('reload_too_fast')end
   R.cycle=frame;R.row.cycles=R.row.cycles+1
  end
  R.lastShot=frame;R.row.shots=R.row.shots+1;emit('SHOT slot='..n..' frame='..frame..' cycle='..R.row.cycles)
 end
 function R.Projectile(pid,owner,wd)
  if R.closed or owner~=actor or not mounts[R.stage]or wd~=mounts[R.stage].weapon then return end
  local x,y,z=api.GetProjectilePosition(pid);if not x then fail('projectile_position_unknown');return end
  R.projectiles[pid]={row=R.row,slot=R.stage,weapon=wd,cycle=R.row.cycles};R.row.projectiles=R.row.projectiles+1
  local mx,my,mz=api.GetUnitWeaponVectors(actor,R.stage)
  if mx then emit('PROJECTILE slot='..R.stage..' id='..pid..' xyz='..x..','..y..','..z..' muzzle='..mx..','..my..','..mz)else fail('native_vectors_unknown')end
 end
 function R.Damaged(id,damage,paralyzer,wd,attacker,pid)
  if R.closed or attacker~=actor or not mounts[R.stage]then return end
  if wd~=mounts[R.stage].weapon then fail('nonselected_native_damage');return end
  if R.ground or id~=R.target then emit('COLLATERAL id='..id..' damage='..damage);return end
  if api.GetUnitTeam(id)~=R.targetTeam then fail('target_capture');return end
  local tracked=R.projectiles[pid];local cycle
  if tracked and tracked.row==R.row then cycle=tracked.cycle
  elseif mounts[R.stage].beam and api.GetGameFrame()==R.lastShot then
   cycle=R.row.cycles;emit('BEAM_DAMAGE native_authority=true projectile_callback=UNKNOWN')
  else fail('damage_projectile_receipt_unknown');return end
  local hp=api.GetUnitHealth(id);if not hp then fail('native_health_unknown');return end
  local loss=math.max(0,(R.hp or hp)-hp);R.hp=hp
  R.row.hitCycles[cycle]=true
  local evidence=R.row.cycleEvidence[cycle]or{damage=0,healthLoss=0};R.row.cycleEvidence[cycle]=evidence
  evidence.damage=evidence.damage+damage;evidence.healthLoss=evidence.healthLoss+loss
  R.row.damage=R.row.damage+damage;R.row.healthLoss=R.row.healthLoss+loss
  emit('DAMAGE slot='..R.stage..' amount='..damage..' hp='..hp..' cycle='..cycle..' observed_hp_loss='..loss..' paralyzer='..tostring(paralyzer))
 end
 function R.Explosion(wd,x,y,z,owner,pid)
  if R.closed or owner~=actor or not R.ground or not mounts[R.stage]or wd~=mounts[R.stage].weapon then return end
  local tracked=R.projectiles[pid];if not tracked or tracked.row~=R.row then return end
  local ground=api.GetGroundHeight(x,z)
  if math.abs(y-ground)<=12 then R.row.terrain=R.row.terrain+1;emit('TERRAIN slot='..R.stage..' xyz='..x..','..y..','..z)end
 end
 function R.Ready()
  if R.failed or not valid()or not R.row then return false end
  local r=R.row
  local beam=mounts[R.stage].beam
  local first,second=r.cycleEvidence[1],r.cycleEvidence[2]
  local each=first and second and first.damage>0 and first.healthLoss>0 and second.damage>0 and second.healthLoss>0
  local ready=r.queries>0 and r.shots>0 and(beam or r.projectiles>0)and(R.ground and(beam or r.terrain>0)or not R.ground and r.cycles>=2 and each)
  if ready and beam and not r.beamNotice then r.beamNotice=true;emit('BEAM_CALLBACKS projectiles='..(r.projectiles>0 and'OBSERVED'or'UNKNOWN')..' terrain='..(r.terrain>0 and'OBSERVED'or'UNKNOWN')..' native_damage_authority=Shot_Query_UnitDamaged_HP')end
  return ready
 end
 function R.Deleted(pid)
  local row=R.projectiles[pid];if row then emit('PROJECTILE_DELETED slot='..row.slot..' id='..pid);R.projectiles[pid]=nil end
 end
 function R.Close(reason)R.closed=true;emit('END reason='..reason..' unpaid_diagnostic=true native_visual_review_pending=true')end
 return R
end
return M
