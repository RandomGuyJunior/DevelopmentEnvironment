-- Bounded source-derived recoil on each actual native arm Shot, also moving.
-- One real physical arm, no extra damage/projectiles, clocks or script threads.
local M={Policy='dakka_human_weapons_r3_v1'}
function M.New(source,cp,data)
 if not cp.source_dakka_weapon_policy then return nil end
 assert(source=='ork_dakka_stompa'and cp.source_dakka_weapon_policy==M.Policy
  and cp.source_dakka_gait_policy=='dakka_distance_locked_boots_v1'
  and cp.source_native_glb_sha256=='184bb884ba03f5ceef1dda85cdbb4648527a5f9e89f1b45928cb4f7538f50748','Unknown exact Dakka recoil actor')
 local clip=assert(data.clips.fire_dakka_arm);local i
 for n,name in ipairs(data.bones)do if name=='dakka_arm_bone'then i=n end end
 assert(i and #clip.frames==21 and clip.source_fps==30 and clip.source=='fire_dakka_arm','Actual retained arm recoil required')
 local rest=clip.frames[1][i][3];local minimum=0
 for _,row in ipairs(clip.frames)do minimum=math.min(minimum,row[i][3]-rest)end
 assert(minimum<0 and math.abs(clip.frames[#clip.frames][i][3]-rest)<1e-6,'Bounded genuine recoil endpoints required')
 local shots={};local outputs={{},{}};local recoilRows={{},{}};local outputIndex=0
 local api={}
 function api.Shot(slot,frame)
  if slot~=2 and slot~=5 and slot~=6 and slot~=7 then return false end
  assert(type(frame)=='number'and frame>=0 and frame<math.huge and frame==math.floor(frame),'Actual native frame required')
  -- Four native muzzles may shoot together. Every Shot supplies an impulse;
  -- cap their sum at the real source travel instead of stacking through hull.
  shots[#shots+1]=frame
  return true
 end
 function api.Overlay(row,frame)
  local amount=0;local kept={}
  for _,f in ipairs(shots)do
   local age=frame-f
   if age>=0 and age<#clip.frames-1 then
    local a=math.floor(age);local t=age-a
    local z=clip.frames[a+1][i][3]*(1-t)+clip.frames[a+2][i][3]*t-rest
    amount=amount+z;kept[#kept+1]=f
   end
  end
  shots=kept
  if amount==0 then return row end
  outputIndex=outputIndex%2+1;local out=outputs[outputIndex]
  for n,v in ipairs(row)do out[n]=v end
  local v=row[i];local recoil=recoilRows[outputIndex]
  for a=1,6 do recoil[a]=v[a]end
  recoil[3]=recoil[3]+math.max(minimum,math.min(0,amount));out[i]=recoil
  return out
 end
 return api
end
return M
