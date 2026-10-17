function gadget:GetInfo()return{name='40K AI Guard ordinary research repair probe',desc='Default-off natural AI decisions plus disclosed casualty',author='Local project',layer=153,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return false end
local S=Spring;local o=S.GetModOptions()or{};local dev=VFS.Include('40k_configs/development_playtest.lua')
if not dev.OptionEnabled(o.prototype_centre_march_research_repair_probe)then return false end
local O,started
local function emit(key,message)S.Echo('40K_AI_GUARD_REPAIR '..key..' frame='..S.GetGameFrame()..' '..message)end
function gadget:Initialize()
 local allowed={prototype_development_playtest=true,prototype_source_progression=true,prototype_guard_squad_flamer=true,prototype_centre_march_native_observer=true,prototype_centre_march_research_repair_probe=true}
 if not dev.Enabled(o)or not dev.OptionEnabled(o.prototype_source_progression)or not dev.OptionEnabled(o.prototype_guard_squad_flamer)or not dev.OptionEnabled(o.prototype_centre_march_native_observer)or o.prototype_diagnostic~='normal'or tonumber(o.prototype_test_speed)~=1 then emit('REFUSED','exclusive_normal_speed1_observed_guard_route_required');return end
 for key,value in pairs(o)do if key:match('^prototype_')and dev.OptionEnabled(value)and not allowed[key]and key~='prototype_test_speed'then emit('REFUSED','competing_option='..key);return end end
 O=VFS.Include('40k_configs/ai_guard_research_repair.lua').New(S,UnitDefs,VFS.Include('40k_configs/active_squad_profiles.lua').profiles.guard_line,function()return GG.Recoil40KResearch end,function()return GG.Recoil40KSquads end,emit)
end
function gadget:GameFrame(frame)
 if not O then return end
 if not started then
  started=true;if frame~=1 then emit('REFUSED','fresh_frame1_required');O=nil;return end
  local team
  for _,t in ipairs(S.GetTeamList())do if S.GetTeamLuaAI(t)=='40K Test AI - Centre March'then if team~=nil then emit('REFUSED','exactly_one_AI_required');O=nil;return end;team=t end end
  if team==nil then emit('REFUSED','AI_required');O=nil;return end
  local ids=S.GetTeamUnits(team)
  if type(ids)~='table'or #ids~=1 or not UnitDefs[S.GetUnitDefID(ids[1])]or UnitDefs[S.GetUnitDefID(ids[1])].name~='imp_field_commander'then emit('REFUSED','natural_guard_commander_required');O=nil;return end
  if not O.Initialize(team)then return end
 end
 if frame>=54000 and O.phase~='PASS'and not O.failed then emit('INCONCLUSIVE','natural_AI_decision_or_repair_timing_pending_phase='..O.phase);O=nil;return end
 O.Frame(frame)
end
function gadget:UnitCommand(id,def,team,cmd,params,opts,tag,player,synced,lua)if O then O.Command(id,def,team,cmd,params,tag,lua)end end
