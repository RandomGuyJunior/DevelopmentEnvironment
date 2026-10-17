-- Read-only receipt arithmetic. No native health/XP/config writes.
-- Observe PreDamaged, then layer110 UnitDamaged AFTER leech layer60,
-- then next-frame native XP health rescaling independently.
local M={}
local tolerance=.01
local function finite(x)return type(x)=='number'and x==x and math.abs(x)<math.huge end
function M.New(baseHealth,healthScale)
 assert(finite(baseHealth)and baseHealth>0 and finite(healthScale)and healthScale>=0)
 local last={};local api={}
 local function continuation(receipt,hp,max,exp)
  if exp<receipt.exp then return false,'experience_regressed'end
  local expectedMax=math.max(.1,baseHealth*(1+exp/(exp+1)*healthScale))
  if math.abs(max-expectedMax)>tolerance then return false,'native_xp_max_formula_mismatch',expectedMax end
  local expected=receipt.hp*(max/receipt.max)
  if math.abs(hp-expected)>tolerance then return false,'unaccounted_health_transition',expected end
  return true
 end
 function api.Pre(frame,hp,max,exp,victim,cap)
  assert(finite(hp)and hp>0 and finite(max)and max>0 and finite(exp)and exp>=0 and finite(victim)and finite(cap)and cap>=0)
  local okay,reason
  if last[frame]then okay,reason=continuation(last[frame],hp,max,exp)end
  return {frame=frame,hp=hp,max=max,exp=exp,victim=math.max(0,victim),cap=cap,invalidReason=okay==false and reason or nil}
 end
 function api.Damaged(token,damage,hp,max,exp)
  if not token or token.consumed or not finite(damage)or damage<=0 or not finite(hp)or not finite(max)or not finite(exp)then return false,'invalid_hit_receipt'end
  if token.invalidReason then return false,token.invalidReason end
  local heal=math.min(damage,token.victim,token.cap)
  local expected=math.min(token.max,token.hp+heal)
  -- Native AddExperience occurs after the entire UnitDamaged callin list.
  if math.abs(max-token.max)>tolerance or math.abs(exp-token.exp)>1e-7 then return false,'unexpected_pre_xp_state_change'end
  if math.abs(hp-expected)>tolerance then return false,'immediate_source_leech_mismatch',expected,heal end
  token.consumed=true
  local old=last[token.frame]
  last[token.frame]={hp=hp,max=max,exp=exp,hits=(old and old.hits or 0)+1,sourceHeal=(old and old.sourceHeal or 0)+heal,incomingHits=old and old.incomingHits or 0,incomingDamage=old and old.incomingDamage or 0}
  return true,expected,heal
 end
 -- Incoming Pre is read BEFORE actual victim damage; outgoing attacker XP
 -- may already have rescaled the form. Validate that transition, not an inferred
 -- damage difference. Incoming Done uses final native UnitDamaged damage.
 function api.IncomingPre(frame,hp,max,exp)
  if not finite(frame)or not finite(hp)or hp<=0 or not finite(max)or max<=0 or not finite(exp)or exp<0 then return nil,'invalid_incoming_pre_receipt'end
  local pending
  for f in pairs(last)do
   if f<=frame then
    if pending then return nil,'ambiguous_pending_leech_receipts'end
    pending=f
   end
  end
  if pending then
   local okay,reason,expected=continuation(last[pending],hp,max,exp)
   if not okay then return nil,reason,expected end
  end
  return {frame=frame,hp=hp,max=max,exp=exp,pending=pending}
 end
 function api.Incoming(token,damage,hp,max,exp,paralyzer)
  if not token or token.consumed or not finite(damage)or damage<=0 or not finite(hp)or not finite(max)or not finite(exp)then return false,'invalid_incoming_hit_receipt'end
  if math.abs(max-token.max)>tolerance or math.abs(exp-token.exp)>1e-7 then return false,'incoming_callback_state_change'end
  local expected=paralyzer and token.hp or token.hp-damage
  if math.abs(hp-expected)>tolerance then return false,'native_incoming_health_subtraction_mismatch',expected end
  if token.pending then
   local receipt=last[token.pending]
   if not receipt then return false,'incoming_pending_receipt_lost'end
   receipt.hp=hp;receipt.max=max;receipt.exp=exp
   receipt.incomingHits=(receipt.incomingHits or 0)+1
   receipt.incomingDamage=(receipt.incomingDamage or 0)+(paralyzer and 0 or damage)
  end
  token.consumed=true
  return true,expected,token.pending
 end
 -- Only an actual observed setter/readback journal may account for regeneration.
 function api.Regenerated(frame,hp,max,exp,after,newMax,newExp,requested)
  if not finite(frame)or not finite(hp)or not finite(max)or max<=0 or not finite(exp)or not finite(after)or not finite(newMax)or not finite(newExp)or not finite(requested)or requested<0 then return false,'invalid_regeneration_journal'end
  if newMax~=max or newExp~=exp or math.abs(after-math.min(max,hp+requested))>tolerance then return false,'regeneration_native_readback_mismatch'end
  local pending
  for f in pairs(last)do if f<=frame then if pending then return false,'ambiguous_pending_regeneration'end;pending=f end end
  if pending then
   local okay,reason,expected=continuation(last[pending],hp,max,exp)
   if not okay then return false,reason,expected end
   local receipt=last[pending];receipt.hp=after;receipt.max=newMax;receipt.exp=newExp
   receipt.regeneration=(receipt.regeneration or 0)+(after-hp)
  end
  return true,after-hp,pending
 end
 function api.Finish(frame,hp,max,exp)
  local receipt=last[frame];if not receipt then return false,'missing_verified_immediate_receipt'end
  if not finite(hp)or not finite(max)or not finite(exp)or exp<receipt.exp then return false,'invalid_post_xp_receipt'end
  local expectedMax=math.max(.1,baseHealth*(1+exp/(exp+1)*healthScale))
  if math.abs(max-expectedMax)>tolerance then return false,'native_xp_max_formula_mismatch',expectedMax end
  local expected=receipt.hp*(max/receipt.max)
  if math.abs(hp-expected)>tolerance then return false,'post_xp_health_ratio_mismatch',expected end
  last[frame]=nil
  return true,expected,receipt.hits,receipt.sourceHeal,receipt.incomingHits or 0,receipt.incomingDamage or 0
 end
 return api
end
return M
