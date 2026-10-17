function widget:GetInfo()return{name='40K stock squad controls observer',desc='Default-off read-only selection/groups/proposals',author='Local project',layer=10001,enabled=true}end
local S=Spring;local options=S.GetModOptions()or{}
local development=VFS.Include('40k_configs/development_playtest.lua')
if not development.Enabled(options)or not development.OptionEnabled(options.prototype_squad_controls_observer)then return false end
for _,name in ipairs({'Echo','GetGameFrame','GetSelectedUnits','GetGroupList','GetGroupUnits','GetUnitGroup','GetUnitRulesParam'})do
 if type(S[name])~='function'then if S.Echo then S.Echo('40K_CONTROL_OBSERVER UI_REFUSED missing_api='..name)end;return false end
end
local elapsed=0;local previous;local lastFrame=-1;local proposals=0
local function values(v)local out={};for _,n in ipairs(v or{})do out[#out+1]=tostring(n)end;return table.concat(out,',')end
local function emit(event,body)S.Echo('40K_CONTROL_OBSERVER '..event..' frame='..S.GetGameFrame()..' '..body)end
local function selection()
 local selected=S.GetSelectedUnits();local groups=S.GetGroupList()
 if type(selected)~='table'or #selected>64 or type(groups)~='table'then emit('UI_REFUSED','selection_or_groups_unreadable_or_selection_cap=64');return end
 table.sort(selected);local groupIDs={};for id in pairs(groups)do if type(id)~='number'then emit('UI_REFUSED','group_id_unreadable=true');return end;groupIDs[#groupIDs+1]=id end
 if #groupIDs>32 then emit('UI_REFUSED','groups_cap=32');return end;table.sort(groupIDs)
 local rows={'selected='..values(selected)}
 for _,id in ipairs(selected)do local group,squad,leader=S.GetUnitGroup(id),S.GetUnitRulesParam(id,'40k_squad_id'),S.GetUnitRulesParam(id,'40k_squad_leader');rows[#rows+1]='selected_unit='..id..':group='..tostring(group)..':squad='..tostring(squad)..':leader='..tostring(leader)end
 for _,group in ipairs(groupIDs)do local units=S.GetGroupUnits(group);if type(units)~='table'or #units>64 then emit('UI_REFUSED','group='..group..' unreadable_or_member_cap=64');return end;table.sort(units);rows[#rows+1]='group='..group..':members='..values(units)end
 local signature=table.concat(rows,' ')
 if signature~=previous then previous=signature;emit('UI_SELECTION_GROUPS',signature..' actual_readback=true observer_read_only=true')end
end
local function proposal(event,id,cmd,params,opts)
 local frame=S.GetGameFrame();if frame~=lastFrame then lastFrame=frame;proposals=0 end;proposals=proposals+1
 if proposals==129 then emit('UI_REFUSED','proposals_per_frame_cap=128')end
 if proposals>128 then return end
 emit(event,'unit='..tostring(id)..' cmd='..tostring(cmd)..' coded='..tostring(opts and opts.coded)..' params='..values(params)..' proposal_only=true observer_handles_command=false')
 selection()
end
function widget:CommandNotify(cmd,params,opts)proposal('UI_COMMAND_PROPOSAL',nil,cmd,params,opts);return false end
function widget:UnitCommandNotify(id,cmd,params,opts)proposal('UI_UNIT_COMMAND_PROPOSAL',id,cmd,params,opts);return false end
function widget:Update(dt)elapsed=elapsed+dt;if elapsed>=.2 then elapsed=0;selection()end end
function widget:Initialize()emit('UI_READY','stock_selection_groups_readback=true orders=false selection_mutation=false')end
