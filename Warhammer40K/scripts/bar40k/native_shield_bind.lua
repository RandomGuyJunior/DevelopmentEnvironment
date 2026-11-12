-- Native full plasma sphere adapter. Shield slot never indexes gun banks.
return function(centerPiece)
 local slot
 for n,w in ipairs(UnitDefs[unitDefID].weapons)do
  if WeaponDefs[w.weaponDef].type=='Shield'then slot=n;break end
 end
 if not slot then return end
 local emitter=piece(centerPiece or 'titan_shield_center')
 local originalQuery,originalAimFrom,originalAim,originalBlock,originalFire,originalShot=
  script.QueryWeapon,script.AimFromWeapon,script.AimWeapon,script.BlockShot,script.FireWeapon,script.Shot
 function script.QueryWeapon(n)if n==slot then return emitter end;return originalQuery(n)end
 function script.AimFromWeapon(n)if n==slot then return emitter end;return originalAimFrom(n)end
 local originalAimShield=script.AimShield
 function script.AimShield(n,...)
  if n~=slot then return originalAimShield and originalAimShield(n,...) or false end
  if not Spring.GetUnitIsActive(unitID)then return false end
  -- The standard shield gadget owns downtime/overkill recovery; native LUS
  -- requires this separate callin to re-enable its suspended shield afterward.
  if GG.Shields and GG.Shields.GetUnitShieldState then
   local state=GG.Shields.GetUnitShieldState(unitID)
   -- Rework API returns numeric0/1; bounce mode exposes native boolean state.
   if type(state)=='number'then return state==1 end
  end
  return true
 end
 function script.AimWeapon(n,...)if n==slot then return true end;return originalAim(n,...)end
 function script.BlockShot(n,...)if n==slot then return false end;if originalBlock then return originalBlock(n,...)end;return false end
 function script.FireWeapon(n,...)if n~=slot and originalFire then return originalFire(n,...)end end
 function script.Shot(n,...)if n~=slot and originalShot then return originalShot(n,...)end end
end
