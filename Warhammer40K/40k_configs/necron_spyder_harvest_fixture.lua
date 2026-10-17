-- Read-only native evidence plus a paid prefix reused from Necron acceptance.
local M={PickupCommand=34581,OutputCommand=34582,MaxSeconds=2400,
 BodySource='attrib/ebps/environment/gameplay/necron_basic_warrior_body.lua',
 Steps={{kind='build',name='nec_mex'},{kind='build',name='nec_mex'},{kind='build',name='nec_hq'},
 {kind='build',name='nec_generator'},{kind='build',name='nec_generator'},{kind='build',name='nec_generator'},{kind='build',name='nec_generator'},
 {kind='build',name='nec_core'},{kind='research',name='nec_awakening_1',producer='nec_hq'},
 {kind='build',name='nec_greater_core'},{kind='factory',name='nec_spyder',producer='nec_hq'}}}
function M.New(Q)
 local A={bodies={},history={},births={},consumed=0,expired=0,outputs={},hits={},destroyed={}};local expected;local pending;local locked=false
 local function fail(reason)A.failed=A.failed or reason;return false,reason end
 function A.ExpectVictim(id)expected=id end
 function A.Pre(id,frame,hp,damage,weapon,projectile,attacker)
  if id~=expected or attacker~=Q.enemy or damage<=0 then return end
  if not hp or hp<=0 then return fail('invalid_pre_damage_health')end
  pending={id=id,frame=frame,hp=hp,damage=damage,weapon=weapon,projectile=projectile,attacker=attacker}
 end
 function A.Damaged(id,frame,hp,damage,weapon,projectile,attacker)
  if id~=expected or attacker~=Q.enemy or damage<=0 then return end
  local p=pending;pending=nil
  if type(hp)~='number'then return fail('missing_actual_health_readback')end
  if not p or p.id~=id or p.frame~=frame or p.weapon~=weapon or p.projectile~=projectile or math.abs((p.hp-damage)-hp)>.05 then return fail('unmatched_native_health_damage')end
  if hp<=0 then A.hits[id]={frame=frame,attacker=attacker,health=hp,damage=damage}end
 end
 function A.Destroyed(id,frame)
  local hit=A.hits[id];if id==expected and hit and hit.frame==frame then A.destroyed[id]=frame;return true end
 end
 function A.Body(feature,id,team,source,frame,live)
  local old=A.bodies[feature]
  if id~=expected or team~=Q.team or source~=M.BodySource or not live or old and not(old.consumed or old.expired)or not A.hits[id]or A.destroyed[id]~=frame then return fail('body_without_genuine_lethal_death')end
  if old then A.history[#A.history+1]=old end
  A.bodies[feature]={id=id,born=frame};expected=nil;return true
 end
 function A.Pickup(actor,feature,frame,balance)
  local b=A.bodies[feature];if actor~=Q.spyder or not b or b.started or b.consumed or b.expired then return fail('invalid_actual_pickup_start')end
  b.started=frame;b.balance=balance;return true
 end
 function A.Frame(frame,validFeature,balance,near)
  for feature,b in pairs(A.bodies)do if b.started and not b.consumed then
   if frame>=b.started and frame<=b.started+3*Q.fps and not near(feature)then return fail('continuous_native_pickup_range_lost')end
   if frame==b.started+3*Q.fps-1 then
    if not validFeature(feature)or balance~=b.balance then return fail('pickup_before_exact_90frame_boundary')end;b.at89=true
   end
  end end
  return true
 end
 function A.Consumed(actor,feature,balance,frame,live)
  local b=A.bodies[feature]
  if actor~=Q.spyder or not b or not b.at89 or b.consumed or live or frame~=b.started+3*Q.fps or balance~=b.balance+1 then return fail('missing_exact_native_pickup_receipt')end
  b.consumed=frame;A.consumed=A.consumed+1;return true
 end
 function A.Expired(feature,frame,live)
  local b=A.bodies[feature]
  if not b or b.started or b.consumed or frame~=b.born+180*Q.fps or live then return fail('invalid_genuine_body_expiry')end
  b.expired=frame;A.expired=A.expired+1;return true
 end
 function A.NativeOutput(id,def,team,builder)
  if not locked or def~=Q.warriorDef or team~=Q.team or builder~=Q.spyder or A.outputs[id]then return fail('unaccounted_native_body_output')end
  A.outputs[id]=true;return true
 end
 function A.BeginOutput(balance)
  if A.failed or A.consumed~=5 or A.expired~=1 or balance~=5 or locked then return fail('five_genuine_body_payments_required')end
  locked=true;return true
 end
 function A.OutputPaid(actor,slot,cost,count,balance,receipt)
  local n=0;for id in pairs(A.outputs)do n=n+1;if receipt(id)~=true then return fail('actual_common_paid_birth_receipt_missing')end end
  if not locked or actor~=Q.spyder or slot~=1 or cost~=5 or count~=3 or balance~=0 or n~=3 then return fail('exact_three_warrior_output_missing')end
  A.outputPaid=true;return true
 end
 function A.Accept()
  return not A.failed and A.outputPaid==true and A.consumed==5 and A.expired==1
 end
 return A
end
return M
