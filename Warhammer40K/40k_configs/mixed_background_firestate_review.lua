-- Explicit diagnostic movement baseline; ordinary FIRE_STATE only, never damage masks.
local M={Name='initial_commanders_movement_holdfire_v1'}
function M.New(S,CMD,defs,options,emit)
 local active=options.prototype_diagnostic=='mixedperf2' and tostring(options.prototype_mixed_v2)=='1' and tostring(options.prototype_mixed_background_holdfire)=='1'
 local births,records,invalid={},{},nil
 local expected={[0]='imp_field_commander',[1]='ork_big_mek_commander',[2]='ork_big_mek_commander'}
 local function exact(r)return S.ValidUnitID(r.id) and not S.GetUnitIsDead(r.id) and S.GetUnitDefID(r.id)==r.def end
 local function journal(event,r,reason,actual)emit({actualFireState=actual,event=event,policy=M.Name,id=r and r.id,team=r and r.team,definition=r and r.def,originalFireState=r and r.fire,reason=reason,newBaselineRequired=true})end
 local function restore(reason)
  local ok=true
  for _,r in pairs(records)do if r.held then
   -- Cleanup restores saved fire state across a capture of this same actor;
   -- it never enrolls the new owner or issues any other order.
   local actual
   if exact(r)then
    S.GiveOrderToUnit(r.id,CMD.FIRE_STATE,{r.fire},{})
    local state=S.GetUnitStates(r.id);actual=state and state.firestate
    if actual==r.fire then r.held=false else ok=false end
   else r.held=false end -- dead/replaced IDs cannot be restored or commanded
   journal(actual==r.fire and 'background_firestate_restore' or 'background_firestate_restore_unproved',r,reason,actual)
  end end
  return ok,ok and nil or 'background_firestate_restore_readback_failed'
 end
 local P={}
 function P.Birth(id,def,team,builder,frame)
  if not active or builder~=nil or frame>0 then return end
  local name=expected[team];local d=name and defs[name]
  if not d or d.id~=def then return end
  if births[team] then invalid='duplicate_initial_commander';return end
  if S.GetTeamRulesParam(team,'startUnit')~=def then invalid='native_start_unit_rule_mismatch';return end
  births[team]={id=id,def=def,team=team}
 end
 function P.Window(phase)
  if not active then return true end
  if invalid then restore(invalid);return false,invalid end
  if not next(records)then
   for team=0,2 do
    local r=births[team]
    if not r or not exact(r)or S.GetUnitTeam(r.id)~=team then invalid='initial_commander_birth_missing_or_changed';return false,invalid end
    local state=S.GetUnitStates(r.id)
    if not state or type(state.firestate)~='number' or state.firestate<0 or state.firestate>2 or state.firestate%1~=0 then invalid='native_firestate_unknown';return false,invalid end
    records[team]={id=r.id,def=r.def,team=team,fire=state.firestate,held=false}
   end
  end
  for _,r in pairs(records)do if not exact(r)or S.GetUnitTeam(r.id)~=r.team then invalid='initial_commander_identity_changed';restore(invalid);return false,invalid end end
  if phase=='movement'then
   for _,r in pairs(records)do if not r.held then
    r.held=true -- retain rollback obligation even if native command/readback fails
    S.GiveOrderToUnit(r.id,CMD.FIRE_STATE,{0},{})
    local state=S.GetUnitStates(r.id);local actual=state and state.firestate
    journal(actual==0 and 'background_firestate_hold' or 'background_firestate_hold_unproved',r,'movement',actual)
    if actual~=0 then invalid='background_firestate_hold_readback_failed';restore(invalid);return false,invalid end
   end end
  else return restore('before_combat')end
  return true
 end
 function P.Check()
  if not active then return true end
  for _,r in pairs(records)do if not exact(r)or S.GetUnitTeam(r.id)~=r.team then invalid='initial_commander_capture_or_death';restore(invalid);return false,invalid end end
  return true
 end
 function P.Restore(reason)if active then return restore(reason)end;return true end
 function P.SaveAbort()if not active then return true end;invalid='save_resume_not_supported';restore(invalid);return false,invalid end
 return P
end
return M
