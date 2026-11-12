-- Called only by the two opted-in Great Gargants. Native engine owns the
-- existing death explosion; the synced gadget owns one wreck entitlement.
return function()
 local original=script.Killed
 function script.Killed(recent,maximum)
  local level=original(recent,maximum)
  if level>0 and GG and GG.Bar40KGreatDeath and GG.Bar40KGreatDeath.Begin(unitID,level)then
   -- Native CUnit creates a corpse for every nonnegative wreckLevel.
   -- Zero still reaches CreateWreck(-1), which leaves the first full corpse.
   -- Our breakup owns the single salvage entitlement, so suppress it with -1.
   for _,piece in pairs(Spring.GetUnitPieceMap(unitID)or{})do Hide(piece)end
   return -1
  end
  return level
 end
end
