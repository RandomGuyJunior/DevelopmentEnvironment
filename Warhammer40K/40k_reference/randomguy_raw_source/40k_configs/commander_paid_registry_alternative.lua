-- Additional exact Force presentation only; original Commissar guard remains.
local M={}
local function on(v)return v==true or v==1 or v=='1'or v=='true'end
local function positive(v)return type(v)=='number'and v==v and v>0 and v<math.huge end
function M.Force(d,id,names,defs)
 if not d or not names or not names.armcom or names.armcom.id~=id or d.name~='armcom'or d.id~=id then return false end
 local c=d.customParams or{}
 if c.faction~='Imperium'or tostring(c.prototype40k)~='1'or c.prototype40k_vital~='commander'or not on(c.iscommander)or not on(c.commander_presentation_adaptation)then return false end
 if c.prototype40k_donor~='imp_force_commander_candidate'or c.animsource~='imp_force_commander_candidate'or c.source_entity~='force_commander_sp'or c.source_whm_sha256~='bae55403be5bca7161afd12ee3096f28a2a28d93fc62e0fbbe4890a402e51e21'or c.source_glb_sha256~='47df0f59cc4b0e21401ff54e9307fa21c1930db37791c227b75b625af7cecb62'then return false end
 if d.isBuilder~=true or d.canMove~=true or not positive(d.buildSpeed)or not positive(d.buildDistance)or not positive(d.metalCost)or not positive(d.energyCost)or not positive(d.buildTime)then return false end
 local hq=names.imp_hq;local target=hq and defs and defs[hq.id]
 if not target or target.name~='imp_hq'or not positive(target.metalCost)or not positive(target.energyCost)or not positive(target.buildTime)then return false end
 for _,b in ipairs(d.buildOptions or{})do if b==hq.id then return true end end
 return false
end
return M
