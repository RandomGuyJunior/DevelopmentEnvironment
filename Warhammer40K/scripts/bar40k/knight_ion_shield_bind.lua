-- Call after the ordinary Knight actor. Shield slots never index gun banks.
return function()
 local slot
 for n,w in ipairs(UnitDefs[unitDefID].weapons)do
  if WeaponDefs[w.weaponDef].type=='Shield'then slot=n;break end
 end
 if not slot then return end
 local emitter=piece('ion_shield_center')
 local originalQuery,originalAimFrom,originalAim,originalBlock,originalFire,originalShot=
  script.QueryWeapon,script.AimFromWeapon,script.AimWeapon,script.BlockShot,script.FireWeapon,script.Shot
 function script.QueryWeapon(n)if n==slot then return emitter end;return originalQuery(n)end
 function script.AimFromWeapon(n)if n==slot then return emitter end;return originalAimFrom(n)end
 function script.AimWeapon(n,...)if n==slot then return true end;return originalAim(n,...)end
 function script.BlockShot(n,...)if n==slot then return false end;if originalBlock then return originalBlock(n,...)end;return false end
 function script.FireWeapon(n,...)if n~=slot and originalFire then return originalFire(n,...)end end
 function script.Shot(n,...)if n~=slot and originalShot then return originalShot(n,...)end end
end
