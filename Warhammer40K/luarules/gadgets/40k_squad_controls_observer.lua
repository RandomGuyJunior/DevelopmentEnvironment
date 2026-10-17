function gadget:GetInfo()return{name='40K native squad controls observer',desc='Default-off read-only queue and command-origin evidence',author='Local project',layer=39,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return false end
local S=Spring;local options=S.GetModOptions()or{}
local development=VFS.Include('40k_configs/development_playtest.lua')
if not development.Enabled(options)or not development.OptionEnabled(options.prototype_squad_controls_observer)then return false end
for _,name in ipairs({'Echo','GetGameFrame','GetAllUnits','GetUnitRulesParam','GetUnitDefID','GetUnitTeam','GetUnitPosition','GetUnitCommandCount','GetUnitCommands'})do
 if type(S[name])~='function'then if S.Echo then S.Echo('40K_CONTROL_OBSERVER REFUSED missing_api='..name)end;return false end
end
local tracked={};local trackedCount=0;local eventFrame=-1;local eventCount=0;local lastSnapshot
local fields={'id','slot','leader','living','capacity','generation','profile','owner'}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function emit(event,body)S.Echo('40K_CONTROL_OBSERVER '..event..' frame='..S.GetGameFrame()..' '..body)end
local function params(values)local out={};for _,v in ipairs(values or{})do out[#out+1]=tostring(v)end;return table.concat(out,',')end
local function remember(id)
 if not tracked[id]then
  if trackedCount>=64 then emit('REFUSED','tracked_units_cap=64 id='..id);return false end
  tracked[id]=true;trackedCount=trackedCount+1
 end
 return true
end
local function limited()
 local frame=S.GetGameFrame();if frame~=eventFrame then eventFrame=frame;eventCount=0 end
 eventCount=eventCount+1
 if eventCount==129 then emit('REFUSED','command_events_per_frame_cap=128')end
 return eventCount<=128
end
local function command(event,id,def,team,cmd,values,opts,tag,player,synced,lua,insert)
 if not limited()or not remember(id)then return end
 emit(event,'id='..id..' def='..def..' team='..team..' cmd='..tostring(cmd)..' tag='..tostring(tag)..' coded='..tostring(opts and opts.coded)
  ..' params='..params(values)..' player='..tostring(player)..' fromSynced='..tostring(synced)..' fromLua='..tostring(lua)
  ..' fromInsert='..tostring(insert~=nil)..' insert_coded='..tostring(insert and insert.coded)..' raw_origin_only=true observer_read_only=true')
end
function gadget:AllowCommand(id,def,team,cmd,values,opts,tag,player,synced,lua,insert)
 command('ADMISSION',id,def,team,cmd,values,opts,tag,player,synced,lua,insert);return true
end
function gadget:UnitCommand(id,def,team,cmd,values,opts,tag,player,synced,lua)
 command('NATIVE_COMMAND_EVENT',id,def,team,cmd,values,opts,tag,player,synced,lua,nil)
end
function gadget:GameFrame(frame)
 if frame%15~=0 then return end
 local all=S.GetAllUnits();if type(all)~='table'or #all>256 then emit('REFUSED','all_units_unreadable_or_over_cap=256');return end
 table.sort(all);local ids={}
 for _,id in ipairs(all)do local seed=S.GetUnitRulesParam(id,'40k_squad_id');if tracked[id]or(seed and seed>0)then ids[#ids+1]=id end end
 if #ids>64 then emit('REFUSED','snapshot_units_cap=64');return end
 local rows={}
 for _,id in ipairs(ids)do
  local count=S.GetUnitCommandCount(id)
  if type(count)~='number'or count<0 or count>32 then emit('REFUSED','id='..id..' queue_count='..tostring(count)..' queue_cap=32');return end
  local q=S.GetUnitCommands(id,-1);if type(q)~='table'or #q~=count then emit('REFUSED','id='..id..' queue_unreadable_or_count_changed=true');return end
  local x,y,z=S.GetUnitPosition(id);if not finite(x)or not finite(y)or not finite(z)then emit('REFUSED','id='..id..' position_unavailable=true');return end
  local def,team=S.GetUnitDefID(id),S.GetUnitTeam(id)
  if type(def)~='number'or type(team)~='number'then emit('REFUSED','id='..id..' identity_unavailable=true');return end
  local parts={'id='..id,'def='..def,'team='..team,'position='..params({x,y,z}),'queue_count='..count}
  for _,field in ipairs(fields)do local value=S.GetUnitRulesParam(id,'40k_squad_'..field);parts[#parts+1]='squad_'..field..'='..tostring(value)end
  for i,row in ipairs(q)do
   if type(row)~='table'or not finite(row.id)or not finite(row.tag)or type(row.options)~='table'or not finite(row.options.coded)or type(row.params)~='table'then emit('REFUSED','id='..id..' queue_fields_unavailable=true');return end
   for _,value in ipairs(row.params)do if not finite(value)then emit('REFUSED','id='..id..' queue_params_unavailable=true');return end end
   parts[#parts+1]='q'..i..'='..row.id..':'..row.tag..':'..row.options.coded..':'..params(row.params)
  end
  rows[#rows+1]=table.concat(parts,' ')
 end
 local signature=table.concat(rows,'\n')
 if signature~=lastSnapshot or frame%300==0 then
  lastSnapshot=signature;emit('SNAPSHOT_BEGIN','units='..#rows..' complete=true')
  for _,row in ipairs(rows)do emit('BODY_QUEUE',row)end
  emit('SNAPSHOT_END','units='..#rows..' observer_read_only=true native_acceptance_not_automatic=true')
 end
end
function gadget:Initialize()emit('READY','synced=true max_units=64 max_queue=32 sampling_frames=15 grants=false orders=false')end
