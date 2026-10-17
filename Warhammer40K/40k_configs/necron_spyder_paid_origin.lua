-- Scoped corpse-currency birth composed with the actual common controller.
local M={}
function M.Attach(C,S,U,Names,policy)
 assert(C and type(C.CanBuild)=='function'and type(C.Register)=='function')
 local P={paid={},births={},lethal={},outputs={}};local active;local ledger;local oldBuild,oldRegister=C.CanBuild,C.Register
 local spyder=Names.nec_spyder and Names.nec_spyder.id
 -- Only an explicitly supplied current factory policy broadens historical origin.
 if policy then assert(policy.factory=='nec_advanced_factory'and policy.source=='nec_hq','Unknown Spyder paid factory policy')end
 local function currentFactory(d,row)
  if not policy or not d or not d.isFactory or not row or row.name~=policy.factory then return false end
  local cp=d.customParams or{}
  if cp.animsource~=policy.source or cp.faction~='Necrons'then return false end
  for _,def in ipairs(d.buildOptions or{})do if def==spyder then return true end end
  return false
 end
 local targets={};for _,name in ipairs({'nec_warrior','nec_flayed','nec_immortal'})do if Names[name]then targets[Names[name].id]=true end end
 local function live(id,team)
  if not id or not S.ValidUnitID(id)or S.GetUnitIsDead(id)or S.GetUnitTeam(id)~=team then return false end
  local hp,_,_,_,built=S.GetUnitHealth(id);local row=C.units[id]
  return hp and hp>0 and built==1 and row and row.team==team and row.finished and true or false
 end
 function P.IsPaidSpyder(id,team)
  local proof=P.paid[id];return proof and proof.team==team and S.GetUnitDefID(id)==spyder and live(id,team)and oldBuild(team,spyder,proof.factory,false)==true or false
 end
 function P.Birth(id,def,team,builder)
  if active then
   local t=active
   if def==t.def and team==t.team and builder==t.producer then t.births[#t.births+1]=id end
   if t.preflight and not t.created and def==t.def and team==t.team and builder==t.producer then t.created=id;t.witness=true
   else t.invalid=true end
  end
  local factoryDef=builder and U[S.GetUnitDefID(builder)];local factoryRow=builder and C.units[builder]
  local genuineHQ=factoryDef and factoryDef.isFactory and (factoryDef.customParams or{}).animsource=='nec_hq'and factoryRow and factoryRow.name=='nec_hq'
  if def==spyder and(genuineHQ or currentFactory(factoryDef,factoryRow))and live(builder,team)and oldBuild(team,def,builder,false)==true then
   local cmd=(S.GetFactoryCommands(builder,1)or{})[1]
   local hp,_,_,_,built=S.GetUnitHealth(id)
   if cmd and cmd.id==-def and type(cmd.tag)=='number'and cmd.tag>=0 and hp and hp>0 and built<1 then P.births[id]={team=team,factory=builder,tag=cmd.tag}end
  end
 end
 function P.Factory(id,def,team,factory)
  local t=P.births[id];if not t or def~=spyder or t.team~=team or t.factory~=factory or not live(id,team)then return false end
  local work,metal,energy=S.GetUnitCosts(id);local d=U[def]
  if work~=d.buildTime or metal~=d.metalCost or energy~=d.energyCost then return false end
  P.paid[id]=t;P.births[id]=nil;return true
 end
 function P.Remove(id)P.paid[id]=nil;P.births[id]=nil;P.lethal[id]=nil;P.outputs[id]=nil end
 function P.Damaged(id,damage,paralyzer,attacker)
  P.lethal[id]=nil
  if damage<=0 or paralyzer or not attacker then return end
  -- Capture native completion while the lethal callback still exposes the unit.
  -- An unfinished construction must not mint a full source-body transaction.
  local hp,_,_,_,built=S.GetUnitHealth(id)
  if hp and hp<=0 and built==1 then
   local work,metal,energy;if S.GetUnitCosts then work,metal,energy=S.GetUnitCosts(id)end
   P.lethal[id]={frame=S.GetGameFrame(),team=S.GetUnitTeam(id),def=S.GetUnitDefID(id),attacker=attacker,completed=true,cost={work=work,metal=metal,energy=energy}}
  end
 end
 function P.DeathEligible(id,def,team)
  local t=P.lethal[id];P.lethal[id]=nil
  local ok=t and t.completed and t.frame==S.GetGameFrame()and t.team==team and t.def==def
  return ok and true or false,ok and t or nil
 end
 function P.OutputReady(id,row,team)
  local d=Names[row.entity];local cp=d and U[d.id]and U[d.id].customParams or{}
  -- Defense in depth at the creation permit, not only the outer adapter Ready.
  if cp.prototype40k_squad_product or tonumber(cp.prototype40k_squad_internal or 0)==1 then return false end
  return d and targets[d.id]and P.IsPaidSpyder(id,team)and oldBuild(team,d.id,id,false)==true or false
 end
 function C.CanBuild(team,def,builder,initial)
  if active then local t=active
   if not t.preflight and not t.invalid and t.team==team and t.def==def and builder==t.producer and not initial and P.IsPaidSpyder(builder,team)then t.preflight=true;return true end
   t.invalid=true;return false
  end
  return oldBuild(team,def,builder,initial)
 end
 function C.Register(id,def,team,finished)
  if active then
   local t=active
   if not t.invalid and t.preflight and t.witness and t.created==id and t.def==def and t.team==team and finished==true then t.registered=true
   else t.invalid=true end
  end
  return oldRegister(id,def,team,finished)
 end
 function P.BindLedger(A)assert(not ledger and A and type(A.ClaimBodyBirth)=='function');ledger=A end
 function P.WithBodyProductionPermit(producer,entity,team,fn)
  local d=Names[entity];if active or type(fn)~='function'or not d or not targets[d.id]or not P.OutputReady(producer,{entity=entity},team)or not ledger or ledger.ClaimBodyBirth(producer,entity,team)~=true then return end
  local token={producer=producer,def=d.id,team=team,births={}};active=token
  -- Native Lua CreateUnit does not invoke AllowUnitCreation: preflight the same
  -- common CanBuild hook explicitly, then demand real synchronous birth/Register.
  local allowed=C.CanBuild(team,d.id,producer,false)
  local ok,id;if allowed then ok,id=pcall(fn)end
  active=nil
  if not ok or not id or token.invalid or token.created~=id or not token.witness or not token.registered or not live(id,team)then
   local removed={}
   for _,unit in ipairs(token.births)do if S.ValidUnitID(unit)then S.DestroyUnit(unit,false,true);removed[unit]=true end end
   if type(id)=='number'and not removed[id]and S.ValidUnitID(id)then S.DestroyUnit(id,false,true)end;return
  end
  P.outputs[id]={team=team,producer=producer,def=d.id,frame=S.GetGameFrame(),currency='source_bodies'};return id
 end
 return P
end
return M
