-- Read-only actual-native ability receipt contract. No commands, HP or resource writes.
local M={}
function M.New(enemy)
 local A={incoming={},refusals={},verified=0,late=0,mode='before',regen=0,damagedDuring=0}
 local function finite(x)return type(x)=='number'and x==x and math.abs(x)<math.huge end
 function A.Pre(frame,damage,weapon,projectile,attacker,hp,max,xp)
  if attacker~=enemy or not finite(damage)or damage<=0 or not finite(hp)or hp<=0 or not finite(max)or not finite(xp)then return false,'not_real_hostile_hit'end
  A.incoming={frame=frame,damage=damage,weapon=weapon,projectile=projectile,attacker=attacker,hp=hp,max=max,xp=xp};return true
 end
 function A.Damaged(frame,damage,weapon,projectile,attacker,hp,max,xp)
  local t=A.incoming;A.incoming={}
  if A.mode=='immune'then A.damagedDuring=A.damagedDuring+1;return false,'positive_damage_during_immunity'end
  if not t.frame or t.frame~=frame or t.weapon~=weapon or t.projectile~=projectile or t.attacker~=attacker or damage<=0 or attacker~=enemy then return false,'unmatched_native_damage'end
  if math.abs(hp-(t.hp-damage))>.02 or math.abs(max-t.max)>.01 or xp~=t.xp then return false,'native_health_subtraction_mismatch'end
  A[A.mode]=true;return true
 end
 function A.Refused(frame,damage,weapon,projectile,attacker,hp,max,xp)
  if A.mode~='immune'or attacker~=enemy or not finite(damage)or damage<=0 or not finite(hp)or hp<=0 or not finite(max)or not finite(xp)then return false,'refusal_not_actual_hostile_immunity'end
  A.late=frame;A.refused=(A.refused or 0)+1
  if A.verified==0 and #A.refusals<64 then A.refusals[#A.refusals+1]={frame=frame,hp=hp,max=max,xp=xp,regen=0,weapon=weapon,projectile=projectile,attacker=attacker}end
  return true
 end
 function A.Regenerated(frame,before,max,xp,after,newMax,newXP,requested)
  if not finite(frame)or not finite(before)or not finite(after)or not finite(max)or not finite(xp)or not finite(requested)or requested<0 or max~=newMax or xp~=newXP or math.abs(after-math.min(max,before+requested))>.01 then return false,'invalid_actual_regen_readback'end
  A.regen=A.regen+(after-before)
  for _,t in ipairs(A.refusals)do if t.frame<=frame then t.regen=t.regen+after-before end end
  return true
 end
 function A.Verify(frame,hp,max,xp)
  for i=#A.refusals,1,-1 do local t=A.refusals[i]
   if frame>t.frame then
    if math.abs(hp-(t.hp+t.regen))>.02 or math.abs(max-t.max)>.01 or xp~=t.xp then return false,'refused_hit_native_health_changed'end
    A.verified=A.verified+1;table.remove(A.refusals,i)
   end
  end
  return true
 end
 return A
end
return M
