function gadget:GetInfo()return{name='40K Wraith source review',desc='Explicit review only: Phase Shift and base ranged defense; boost/infiltration closed',author='Local project',layer=66,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return end
local o=Spring.GetModOptions()or{}
local Gate=VFS.Include('40k_configs/wraith_phase_review_gate.lua');local mode=Gate.Mode(o)
if not mode then return end
local M=VFS.Include('40k_configs/necron_wraith_mechanics.lua');local A,wraith
local paired=mode=='squad';local funded=Gate.FundedFixture(o)
local function recognized(id)
 if not wraith then return false end
 local def=Spring.GetUnitDefID(id);local cp=UnitDefs[def]and UnitDefs[def].customParams or{}
 if not paired then return def==wraith.id end
 local member=UnitDefNames.nec_wraith_member
 return (def==wraith.id or member and def==member.id)and cp.animsource=='nec_wraith'
  and tostring(cp.prototype40k_squad_profile_id)=='17'and tostring(cp.necron_wraith_review)=='1'
  and cp.source_entity==M.ActorSource
end

local function ready()
 local r=GG.Recoil40KResearch;local d=wraith and UnitDefs[wraith.id];local cp=d and d.customParams
 return r and type(r.HasResearch)=='function'and cp and cp.source_entity==M.ActorSource
 and VFS.FileExists('objects3d/nec_wraith.glb')and VFS.FileExists('scripts/generated/nec_wraith_anim.lua')and true or false
end
local function hasHQ(team)
 local hq=UnitDefNames.nec_hq;if not hq then return false end
 for _,id in ipairs(Spring.GetTeamUnits(team)or{})do if Spring.GetUnitDefID(id)==hq.id then local hp,_,_,_,built=Spring.GetUnitHealth(id);if hp and hp>0 and built==1 then return true end end end
 return false
end
local function weaponKind(id)
 local w=id and WeaponDefs[id];if not w then return end
 local cp=w.customParams or{}
 if w.type=='Melee'or w.weapontype=='Melee'or cp.source_melee=='1'or cp.source_melee==1 then return 'melee'end
 -- Root must supply explicit audited classification; native projectile class does
 -- not prove an authored melee-contact weapon is ranged.
 if cp.source_damage_kind=='ranged'then return 'ranged'end
end
local function desc(id)
 if not recognized(id)then return end
 local ok=A.CanActivate(id,Spring.GetGameFrame());local row={id=M.Command,type=CMDTYPE.ICON,name='Phase Shift',action='40kwraithphase',tooltip=paired and(funded and'Funded non-economy phase fixture: 10 seconds unable to attack and immune to health damage; 45-second recharge.'or'Phase review disabled: ordinary paid ability prerequisite unresolved.')or'Source review: 10 seconds immune to health damage and unable to attack; 45-second recharge. Requires paid Awakening I and live HQ.',disabled=not ok}
 local i=Spring.FindUnitCmdDesc(id,M.Command);if i then Spring.EditUnitCmdDesc(id,i,row)else Spring.InsertUnitCmdDesc(id,row)end
end
function gadget:Initialize()
 wraith=UnitDefNames.nec_wraith;if not wraith then gadgetHandler:RemoveGadget(self);return end
 gadgetHandler:RegisterCMDID(M.Command)
 local q={wraithDef=wraith.id,fps=Game.gameSpeed or 30,Ready=ready,HasHQ=hasHQ,WeaponKind=weaponKind,
 HasResearch=function(team,key)return GG.Recoil40KResearch and GG.Recoil40KResearch.HasResearch(team,key)==true end}
 if paired then
  q.Base=M;q.IsWraith=recognized;q.Squads=function()return GG.Recoil40KSquads end
  -- Explicit non-economy fixture only; no Awakening/HQ restoration or fabricated paid receipt.
  q.Ready=function()return ready()and funded end
  q.HasHQ=function()return funded end;q.HasResearch=function()return funded end
  if funded then Spring.Echo('40K Wraith phase: FUNDED NON-ECONOMY REVIEW FIXTURE; paid prerequisite acceptance unavailable')end
  A=VFS.Include('40k_configs/wraith_squad_phase_adapter.lua').New(Spring,q)
 else A=M.New(Spring,q)end
 GG.Recoil40KWraithReview=A
 for _,id in ipairs(Spring.GetAllUnits()or{})do if recognized(id)then A.Restore(id);desc(id)end end
end
function gadget:GameFrame(f)if f%30==0 then for _,id in ipairs(Spring.GetAllUnits()or{})do if recognized(id)then desc(id)end end end end
function gadget:UnitFinished(id,def)if recognized(id)then desc(id)end end
function gadget:AllowCommand(id,def,team,cmd,params)
 if cmd~=M.Command then return true end
 if not recognized(id)or team~=Spring.GetUnitTeam(id)or params and #params>0 then return false end
 local ok,reason=A.Activate(id,Spring.GetGameFrame());desc(id)
 if type(GG.Recoil40KWraithWitness)=='function'then GG.Recoil40KWraithWitness('PHASE_REQUEST',id,ok,reason)end
 return false
end
function gadget:UnitPreDamaged(id,def,team,damage,paralyzer,weapon,projectile,attacker)
 local returned,impulse,reason=A.Damage(id,damage,paralyzer,weapon,attacker,Spring.GetGameFrame())
 if reason~='unchanged'and type(GG.Recoil40KWraithWitness)=='function'then
  if reason=='phase_outgoing_refused'then GG.Recoil40KWraithWitness('OUTGOING_RETURN',attacker,damage,returned,reason,weapon,projectile,id)
  else GG.Recoil40KWraithWitness('DAMAGE_RETURN',id,damage,returned,reason,weapon,projectile,attacker)end
 end
 if returned~=damage then return returned,impulse end
end
function gadget:UnitTaken(id)A.Cancel(id)end
function gadget:UnitGiven(id)A.Cancel(id)end
function gadget:UnitDestroyed(id)A.UnitDestroyed(id)end
function gadget:Shutdown()if GG.Recoil40KWraithReview==A then GG.Recoil40KWraithReview=nil end end
