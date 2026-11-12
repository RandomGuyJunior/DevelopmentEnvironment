-- Events from the existing animation phase; never owns movement or pose.
return function()
 local profiles=include('bar40k/animation_data.lua')('bar40k/titan_footfall_data.lua')
 local profile=profiles[UnitDefs[unitDefID].name]
 if not profile then return function()end end
 local last={};local old
 local handles={};for n,e in ipairs(profile.events)do handles[n]=piece(e.piece)end
 return function(phase,walking)
  if not walking then old=nil;return end
  phase=phase%1
  if old then
   local frame=Spring.GetGameFrame()
   for n,e in ipairs(profile.events)do
    local crossed=phase>=old and e.phase>old and e.phase<=phase or phase<old and(e.phase>old or e.phase<=phase)
    if crossed and frame-(last[n]or-1000)>=8 then
     last[n]=frame
     local x,y,z=Spring.GetUnitPiecePosDir(unitID,handles[n])
     if x and GG.bar40kTitanFootfall then GG.bar40kTitanFootfall(unitID,n,x,y,z,profile.sound,profile.volume,profile.crushRadius)end
    end
   end
  end
  old=phase
 end
end
