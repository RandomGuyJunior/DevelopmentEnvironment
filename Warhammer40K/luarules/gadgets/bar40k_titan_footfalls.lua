function gadget:GetInfo()
 return {name='Titan footfalls',desc='Source animation footstep audio and Warlord local crushing',author='BAR 40K',layer=0,enabled=true}
end
local action='bar40k_titan_footfall'
if gadgetHandler:IsSyncedCode()then
 local last={}
 local function footfall(id,foot,x,y,z,sound,volume,radius)
  local udid=Spring.GetUnitDefID(id);if not udid then return end
  local frame=Spring.GetGameFrame();last[id]=last[id]or{}
  if frame-(last[id][foot]or-1000)<8 then return end;last[id][foot]=frame
  local ground=Spring.GetGroundHeight(x,z)
  SendToUnsynced(action,x,ground+2,z,sound,volume)
  if not radius or UnitDefs[udid].name~='impwarlord'then return end
  -- Deliberate friendly crushing. Only small mobile ground units under THIS foot.
  for _,target in ipairs(Spring.GetUnitsInCylinder(x,z,radius))do
   if target~=id then
    local tid=Spring.GetUnitDefID(target);local ud=tid and UnitDefs[tid]
    if ud and not ud.canFly and not ud.isBuilding and(Spring.GetUnitRadius(target)or math.huge)<=24 and(Spring.GetUnitHeight(target)or math.huge)<=40 then
     local _,ty=Spring.GetUnitPosition(target)
     if ty and ty>=ground-12 and ty<=ground+20 then Spring.AddUnitDamage(target,10000000,0,id,-1)end
    end
   end
  end
 end
 function gadget:Initialize()GG.bar40kTitanFootfall=footfall end
 function gadget:UnitDestroyed(id)last[id]=nil end
 function gadget:Shutdown()if GG.bar40kTitanFootfall==footfall then GG.bar40kTitanFootfall=nil end end
else
 local function hear(_,x,y,z,sound,volume)
  local _,full=Spring.GetSpectatingState()
  if full or Spring.IsPosInLos(x,y,z)then Spring.PlaySoundFile(sound,volume,x,y,z,'sfx')end
 end
 function gadget:Initialize()gadgetHandler:AddSyncAction(action,hear)end
 function gadget:Shutdown()gadgetHandler:RemoveSyncAction(action)end
end
