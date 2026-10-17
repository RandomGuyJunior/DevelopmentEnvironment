function widget:GetInfo()return{name='40K squad stock-control adapter',desc='Whole-squad selection and native command routing',author='Local project',layer=100,enabled=true}end
local S=Spring;local previous={}
local profiles=VFS.Include('40k_configs/active_squad_profiles.lua')
local function seed(id)return S.GetUnitRulesParam(id,'40k_squad_id')end
function widget:SelectionChanged(selected,subselection)
 local wanted={};local squads={};local bySquad;local excluded={};local raw={}
 for _,id in ipairs(selected)do raw[id]=true end
 local _,ctrl=S.GetModKeyState()
 -- The pinned native Ctrl-click removes one selected body. Remove its whole
 -- tactical object; deaths/control-group recalls must still expand survivors.
 if ctrl and subselection then
  for id in pairs(previous)do if not raw[id]and S.ValidUnitID(id)and not S.GetUnitIsDead(id)then
   local s=seed(id);if s and s>0 then excluded[s]=true end
  end end
 end
 for _,id in ipairs(selected)do
  local s=seed(id);if not excluded[s]then wanted[id]=true end
  if s and s>0 and not excluded[s]and not squads[s]then
   if not bySquad then bySquad={};for _,member in ipairs(S.GetTeamUnits(S.GetMyTeamID())or{})do local k=seed(member);if k and S.ValidUnitID(member)and not S.GetUnitIsDead(member)then bySquad[k]=bySquad[k]or{};bySquad[k][#bySquad[k]+1]=member end end end
   squads[s]=true;for _,member in ipairs(bySquad[s]or{})do wanted[member]=true end
  end
 end
 local list={};for id in pairs(wanted)do list[#list+1]=id end;table.sort(list)
 previous=wanted
 if #list~=#selected then return list end
 for _,id in ipairs(selected)do if not wanted[id]then return list end end
end
function widget:CommandNotify(cmd,params,opts)
 local targets,seen={},{};local any=false
 for _,id in ipairs(S.GetSelectedUnits())do
  local s=seed(id);local target=id
  if s and s>0 then target=S.GetUnitRulesParam(id,'40k_squad_leader')or id;any=true end
  if not seen[target]then targets[#targets+1]=target;seen[target]=true end
 end
 if not any then return false end
 -- One user command per squad identity; synced native owner handles its bodies.
 S.GiveOrderToUnitArray(targets,cmd,params,opts);return true
end
function widget:DefaultCommand(kind,id)
 if kind~='unit'or not id then return end
 local n=S.GetUnitRulesParam(id,'40k_squad_living');if not n then return end
 local capacity=S.GetUnitRulesParam(id,'40k_squad_capacity')or n
 local h=S.GetUnitRulesParam(id,'40k_squad_health')or 0;local max=S.GetUnitRulesParam(id,'40k_squad_maxhealth')or h
 if n>=capacity and h>=max-.01 then return end
 if not S.AreTeamsAllied(S.GetMyTeamID(),S.GetUnitTeam(id))then return end
 for _,builder in ipairs(S.GetSelectedUnits())do local d=UnitDefs[S.GetUnitDefID(builder)];if d.isBuilder and not d.isFactory and d.canMove and(d.speed or 0)>0 and S.AreTeamsAllied(S.GetMyTeamID(),S.GetUnitTeam(builder))then return CMD.REPAIR end end
end
function widget:WorldTooltip(kind,id)
 if kind~='unit'or not id then return end
 local n=S.GetUnitRulesParam(id,'40k_squad_living');if not n then return end
 local key=profiles.byID[S.GetUnitRulesParam(id,'40k_squad_profile')];local p=key and profiles.profiles[key]
 local text=(p and p.name or'Infantry squad')..' '..n..'/'..(S.GetUnitRulesParam(id,'40k_squad_capacity')or n)..'\nBuilders heal survivors and restore missing members for resources.'
 if p and p.shortRole then text=text..'\n'..p.shortRole end
 if p and p.research then
  local label=p.researchRow and p.researchRow.name or 'Squad specialist'
  text=text..'\n'..((S.GetUnitRulesParam(id,'40k_squad_special')or 0)==1 and 'Researched: ' or 'Optional research: ')..label
 end
 return text
end
