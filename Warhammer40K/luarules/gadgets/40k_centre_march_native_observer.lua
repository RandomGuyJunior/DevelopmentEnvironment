function gadget:GetInfo()return{name='40K ordinary Guard CentreMarch native observer',desc='Default-off read-only paid AI squad/research/repair evidence',author='Local project',layer=152,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return false end
local S=Spring;local options=S.GetModOptions()or{}
local dev=VFS.Include('40k_configs/development_playtest.lua')
if not dev.Enabled(options)or not dev.OptionEnabled(options.prototype_centre_march_native_observer)then return false end
local O,started
function gadget:Initialize()
 local function emit(key,...)local a={...};for i=1,#a do a[i]=tostring(a[i])end;S.Echo('40K_CENTREMARCH_NATIVE '..key..' frame='..S.GetGameFrame()..' '..table.concat(a,' '))end
 if not dev.OptionEnabled(options.prototype_source_progression)or not dev.OptionEnabled(options.prototype_guard_squad_flamer)or options.prototype_diagnostic~='normal'then emit('REFUSED','ordinary_current_guard_source_route_required');return end
 for key,value in pairs(options)do if key:match('^prototype_.*fixture$')and dev.OptionEnabled(value)then emit('REFUSED','competing_fixture='..key);return end end
 if dev.OptionEnabled(options.prototype_mixed_force)then emit('REFUSED','mixed_force_disables_actual_ai');return end
 local profiles=VFS.Include('40k_configs/active_squad_profiles.lua')
 local ready=VFS.Include('40k_configs/centre_march_squad_research.lua').New(S,UnitDefs,profiles)
 local probe=VFS.Include('40k_configs/centre_march_guard_research_probe.lua').New(S,UnitDefs,ready,function()return GG.Recoil40KResearch end,function(r)
  emit('RESEARCH_DISPATCH_PREREQUISITES','team='..r.team,'budgetReady='..tostring(r.budgetReady),'budgetReason='..r.budgetReason,'producers='..r.producers,'finished='..r.finished,'idle='..r.idle,'requirement='..r.requirement,'enabledDescriptor='..r.enabledDescriptor,'targetLocalNecessaryGatesReady='..tostring(r.targetLocalNecessaryGatesReady),'AIVisitedTargetProven=false nativeOrdersIssued=false paidResearchAccepted=false')
 end)
 O=VFS.Include('40k_configs/centre_march_native_observer.lua').New(S,UnitDefs,profiles.profiles.guard_line,function()return GG.Recoil40KResearch end,ready,emit,probe)
end
function gadget:GameFrame(frame)
 if not O then return end
 if not started then started=true;if frame<0 or frame>1 then S.Echo('40K_CENTREMARCH_NATIVE REFUSED fresh_first_simulation_frame_required');O=nil;return end;if not O.Initialize()then return end end
 if frame%30==0 then O.Frame(frame,GG.Recoil40KSquads)end
end
function gadget:UnitCreated(id,def,team,builder)if O then O.Birth(id,def,team,builder)end end
function gadget:UnitDestroyed(id,def,team)if O then O.Destroyed(id,def,team,GG.Recoil40KSquads)end end
function gadget:AllowCommand(id,def,team,cmd,params,opts,tag,player,synced,lua,insert)
 if O then O.Command('ADMISSION_PROPOSAL',id,def,team,cmd,params,opts,tag,player,synced,lua,insert)end;return true
end
function gadget:UnitCommand(id,def,team,cmd,params,opts,tag,player,synced,lua)
 if O then O.Command('NATIVE_ACCEPTED_COMMAND',id,def,team,cmd,params,opts,tag,player,synced,lua,nil)end
end
