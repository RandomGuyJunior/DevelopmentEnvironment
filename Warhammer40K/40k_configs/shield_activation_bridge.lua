-- A payment predicate only; all shield damage/coverage arithmetic stays native.
local M={}
function M.Allowed(id)
 local policy=GG and GG.Recoil40KCommanderShieldAllowed
 return not policy or policy(id)~=false
end
function M.Coverage(coverage)
 if not coverage then return nil end
 local rejected=false
 for id in pairs(coverage)do if not M.Allowed(id)then rejected=true;break end end
 if not rejected then return coverage end
 local out={}
 for id,value in pairs(coverage)do if M.Allowed(id)then out[id]=value end end
 return next(out)and out or nil
end
local function once(s,a,b)
 local _,count=s:gsub(a:gsub('([^%w])','%%%1'),'')
 assert(count==1,'Pinned shield bridge anchor changed')
 local start,finish=s:find(a,1,true);return s:sub(1,start-1)..b..s:sub(finish+1)
end
function M.Patch(s)
 s=once(s,'local function shieldNegatesDamageCheck(unitID, unitTeam, attackerID, attackerTeam)',
  "local commanderShieldActivation=VFS.Include('40k_configs/shield_activation_bridge.lua')\nlocal function shieldNegatesDamageCheck(unitID, unitTeam, attackerID, attackerTeam)")
 s=once(s,'local unitShields = unitCoverages[unitID]','local unitShields = commanderShieldActivation.Coverage(unitCoverages[unitID])')
 s=once(s,'local attackerShields = unitCoverages[attackerID]','local attackerShields = commanderShieldActivation.Coverage(unitCoverages[attackerID])')
 s=once(s,'if unitCoverage[areaCoverage[i]] then','if unitCoverage[areaCoverage[i]] and commanderShieldActivation.Allowed(areaCoverage[i]) then')
 s=once(s,'\tlocal weaponDefID\n\tlocal shieldData = shieldUnitsData[shieldUnitID]',
  '\tif not commanderShieldActivation.Allowed(shieldUnitID) then return true end\n\tlocal weaponDefID\n\tlocal shieldData = shieldUnitsData[shieldUnitID]')
 s=once(s,'if unitData and unitData.shieldEnabled then','if unitData and unitData.shieldEnabled and commanderShieldActivation.Allowed(shieldUnitID) then')
 local start=assert(s:find('local function getShieldUnitsInSphere(',1,true))
 local head,tail=s:sub(1,start-1),s:sub(start)
 local count;tail,count=tail:gsub('if unitData%.shieldEnabled','if unitData.shieldEnabled and commanderShieldActivation.Allowed(unitID)')
 assert(count==6,'Pinned native shield query guards changed')
 return head..tail
end
return M
