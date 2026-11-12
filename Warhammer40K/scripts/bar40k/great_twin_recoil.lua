-- Native order is Shot -> QueryWeapon -> projectile Fire. Pick the actual
-- post-Shot muzzle once, then flash/recoil exactly that tube. The original
-- actor still owns shoulder cadence, yaw, elevation and its cursor.
return function(data,sfx)
 local oldShot=script.Shot
 local function recoil(side,letter)
  local channel=(side=='left'and 0 or 2)+(letter=='a'and 0 or 1)
  local mask=2^(10+channel);Signal(mask);SetSignalMask(mask)
  local handle=piece('rapid_shoulder_'..side..'_recoil_'..letter)
  Move(handle,3,-3,75);Sleep(66);Move(handle,3,0,12)
 end
 function script.Shot(n)
  oldShot(n)
  if n~=4 and n~=5 then return end
  local muzzle=script.QueryWeapon(n)
  local side=n==4 and'left'or'right'
  local letter=muzzle==piece(data.weaponMounts[n].muzzles[1])and'a'or'b'
  if sfx[n]then EmitSfx(muzzle,1023+sfx[n])end
  StartThread(recoil,side,letter)
 end
end
