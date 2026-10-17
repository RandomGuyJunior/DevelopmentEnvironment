-- Explicit review paths. Normal gameplay has no approved paid phase prerequisite.
local M={Version=1}
local function yes(v)return v==true or v==1 or v=='1'end
function M.Mode(o)
 o=o or{}
 if not yes(o.prototype_source_progression)then return end
 if yes(o.prototype_wraith_squad_phase_review)then
  if yes(o.prototype_wraith_review)then return end -- never mix legacy and squad owners
  if yes(o.prototype_development_playtest)and yes(o.prototype_necron_wraith_squad)
   and(o.prototype_diagnostic==nil or o.prototype_diagnostic=='normal')then return'squad'end
  return
 end
 if yes(o.prototype_wraith_review)and o.prototype_diagnostic=='expandedproduction'then return'legacy'end
end
function M.FundedFixture(o)
 return M.Mode(o)=='squad'and yes(o.prototype_wraith_phase_funded_fixture)
end
function M.ScriptEnabled(source,cp,o)
 if source~='nec_wraith'or not cp or not yes(cp.necron_wraith_review)then return false end
 local mode=M.Mode(o)
 if mode=='squad'then return tostring(cp.prototype40k_squad_profile_id)=='17'end
 return mode=='legacy'
end
return M
