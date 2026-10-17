-- Read-only health hit receipts. This module never sets damage, health or projectiles.
-- A caller binds native pre/post call-ins; native shields/abilities may alter raw damage.
local M={Version=1}
local function finite(x)return type(x)=='number'and x==x and math.abs(x)<math.huge end
function M.New(S,emit)
 local R={pending={},rows={},failures={},hits=0};emit=emit or function()end
 local function fail(reason,id)R.failures[#R.failures+1]={reason=reason,unit=id};return false end
 function R.Pre(id,damage,paralyzer,weapon,projectile,attacker)
  if paralyzer or not finite(damage)or damage<=0 then return end
  local hp,max=S.GetUnitHealth(id);if not finite(hp)or not finite(max)then return fail('pre_health_unreadable',id)end
  if R.pending[id]then fail('unmatched_previous_hit',id)end
  R.pending[id]={before=hp,max=max,incoming=damage,weapon=weapon,projectile=projectile,attacker=attacker}
 end
 function R.Damaged(id,damage,paralyzer,weapon,projectile,attacker)
  if paralyzer then return end
  local p=R.pending[id];R.pending[id]=nil
  if not p and damage==0 then return true end
  if not p or p.weapon~=weapon or p.projectile~=projectile or p.attacker~=attacker then return fail('unmatched_native_receipt',id)end
  local hp,max=S.GetUnitHealth(id)
  if not finite(damage)or damage<0 or not finite(hp)or not finite(max)then return fail('post_health_unreadable',id)end
  local loss=p.before-hp;local tolerance=math.max(1,math.abs(p.before),math.abs(hp))*.000005
  local okay=math.abs(loss-damage)<=tolerance and max==p.max
  local row={unit=id,attacker=attacker,weapon=weapon,projectile=projectile,incoming=p.incoming,nativeDamage=damage,healthBefore=p.before,healthAfter=hp,healthLoss=loss,maxHealth=max,pass=okay}
  R.rows[#R.rows+1]=row;R.hits=R.hits+1;emit('native_hit',row)
  if not okay then return fail('native_health_accounting_mismatch',id)end
  return true
 end
 function R.Remove(id)R.pending[id]=nil end
 function R.Pass()return R.hits>0 and #R.failures==0 and next(R.pending)==nil end
 return R
end
return M
