function gadget:GetInfo()return{name='40K Wraith native witness',desc='Bounded actual native births/phase/damage/cloak/ownership journal; no fixture grants or acceptance',author='Local project',layer=67,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return end
local o=Spring.GetModOptions()or{}
if not VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(o.prototype_source_progression)or tostring(o.prototype_wraith_review)~='1'or tostring(o.prototype_wraith_witness)~='1'or o.prototype_diagnostic~='expandedproduction'then return end
local count=0;local wraith;local observed={}
local function journal(event,id,...)
 if count>=128 then return end;count=count+1
 local hp,max,_,_,built=Spring.GetUnitHealth(id)
 Spring.Echo('40K WRAITH NATIVE WITNESS',Spring.GetGameFrame(),event,id,Spring.GetUnitDefID(id)or -1,Spring.GetUnitTeam(id)or -1,hp or 'nil',max or 'nil',built or 'nil',...)
end
local function isWraith(id)return id and wraith and Spring.GetUnitDefID(id)==wraith.id end
local function callback(event,id,...)if isWraith(id)then journal(event,id,...)end end
function gadget:Initialize()
 wraith=UnitDefNames.nec_wraith;if not wraith then gadgetHandler:RemoveGadget(self);return end
 GG.Recoil40KWraithWitness=callback
 for _,id in ipairs(Spring.GetAllUnits()or{})do if isWraith(id)then observed[id]=true;journal('EXISTING_NOT_PAID_BIRTH',id)end end
end
function gadget:UnitCreated(id,def,team,builder)
 if def~=wraith.id then return end;observed[id]=true
 local hq=UnitDefNames.nec_hq;local head
 if builder and hq and Spring.GetUnitDefID(builder)==hq.id then head=(Spring.GetFactoryCommands(builder,1)or{})[1]end
 journal('ACTUAL_BIRTH',id,builder or -1,head and head.id or -1,head and head.tag or -1)
end
function gadget:UnitFinished(id,def)if def==wraith.id then journal('ACTUAL_FINISHED',id)end end
function gadget:UnitPreDamaged(id,def,team,damage,paralyzer,weapon,projectile,attacker)
 if def==wraith.id or isWraith(attacker)then journal('INCOMING_CALLBACK',id,damage,paralyzer,weapon or -1,projectile or -1,attacker or -1)end
end
function gadget:UnitDamaged(id,def,team,damage,paralyzer,weapon,projectile,attacker)
 if def==wraith.id or isWraith(attacker)then journal('APPLIED_CALLBACK',id,damage,paralyzer,weapon or -1,projectile or -1,attacker or -1)end
end
function gadget:GameFrame(f)
 if f%30~=0 then return end
 local A=GG.Recoil40KWraithReview
 for id in pairs(observed)do if isWraith(id)then
  local mode=A and A.IsActive(id,f)and 'phase' or 'ordinary'
  if observed[id]~=mode then observed[id]=mode;journal('ACTUAL_MODE',id,mode,Spring.GetUnitIsCloaked(id))
   for _,ally in ipairs(Spring.GetAllyTeamList()or{})do local los=Spring.GetUnitLosState(id,ally,true);journal('ACTUAL_VISIBILITY_READ',id,ally,los or -1,Spring.GetUnitIsCloaked(id))end
  end
 end end
end
function gadget:UnitTaken(id)if observed[id]then journal('OWNER_TAKEN',id)end end
function gadget:UnitGiven(id)if observed[id]then journal('OWNER_GIVEN',id)end end
function gadget:UnitDestroyed(id,def,team)if def==wraith.id then journal('DESTROYED',id,def,team);observed[id]=nil end end
function gadget:Shutdown()if GG.Recoil40KWraithWitness==callback then GG.Recoil40KWraithWitness=nil end end
