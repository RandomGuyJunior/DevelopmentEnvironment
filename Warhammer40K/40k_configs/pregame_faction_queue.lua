-- Explicit pregame role equivalence, bounded by the chosen commander's real menu.
-- Changes unit IDs only; native queue placement/facing/MOVE semantics remain stock.
local M={}
local roles={
 {'imp_mex','imp_marine_mex','ork_listening_post','nec_mex'},
 {'imp_generator','imp_marine_generator','ork_generator','nec_generator'},
 {'imp_barracks','imp_marine_barracks','ork_boyz_hut','nec_hq'},
 {'imp_tank_factory','imp_walker_factory','ork_mek_shop','nec_vehicle_factory'},
 {'imp_comms_array','imp_marine_comms_array'},
}
local roleByName={};for index,list in ipairs(roles)do for _,name in ipairs(list)do roleByName[name]=index end end
local factions={['Imperial Guard']=true,['Space Marines']=true,Orks=true,Necrons=true}
local function flag(value)return value==true or value==1 or value=='1'end
function M.IsCommander(id,defs)
 local d=type(id)=='number'and defs[id];local c=d and d.customParams or{}
 return d~=nil and flag(c.prototype40k_four_faction)and flag(c.iscommander)and factions[c.faction]==true
end
local function options(id,defs)
 local d=defs[id];local c=d.customParams or{};local allowed,byRole={},{}
 for _,target in ipairs(d.buildOptions or{})do
  local td=defs[target];local tc=td and td.customParams or{}
  if td and tc.faction==c.faction then
   allowed[target]=true
   local role=roleByName[td.name]
   if role then byRole[role]=byRole[role]==nil and target or false end -- ambiguity fails closed
  end
 end
 return allowed,byRole
end
local function resolve(id,defs,allowed,byRole)
 if allowed[id]then return id end
 local d=type(id)=='number'and defs[id];local role=d and roleByName[d.name]
 return role and byRole[role]or nil
end
function M.CanCompleteQueue(queue,id,defs,move)
 if not M.IsCommander(id,defs)then return false end
 local allowed=options(id,defs)
 for _,row in ipairs(queue)do if type(row)~='table'or not(allowed[row[1]]or row[1]==-move)then return false end end
 return true
end
function M.Reconcile(queue,selected,id,defs,move,previous)
 if not M.IsCommander(id,defs)then
  local d=type(id)=='number'and defs[id]
  if d and d.name=='dummycom'and M.IsCommander(previous,defs)then
   return{deferred=true,selected=nil,selectionChanged=selected~=nil,changed=false}
  end
  return nil
 end
 local allowed,byRole=options(id,defs)
 local result={converted=0,removed=0,selected=resolve(selected,defs,allowed,byRole)}
 local names,counts={},{}
 local write=1
 for _,row in ipairs(queue)do
  local old=type(row)=='table'and row[1]or nil
  local target=old==-move and old or resolve(old,defs,allowed,byRole)
  if target then
   if old~=target then result.converted=result.converted+1;row[1]=target end
   queue[write]=row;write=write+1
  else
   result.removed=result.removed+1
   local d=type(old)=='number'and defs[old];local label=d and(d.translatedHumanName or d.humanName or d.name)or'unknown entry'
   if not counts[label]then names[#names+1]=label;counts[label]=0 end;counts[label]=counts[label]+1
  end
 end
 for index=#queue,write,-1 do queue[index]=nil end
 result.selectionChanged=result.selected~=selected
 result.changed=result.converted>0 or result.removed>0
 if result.changed then
  local text='[Pregame Queue] Converted '..result.converted..' build(s) for '..defs[id].customParams.faction..'.'
  if result.removed>0 then
   local removed={};for index=1,math.min(#names,5)do local name=names[index];removed[#removed+1]=name..(counts[name]>1 and' ('..counts[name]..')'or'')end
   text=text..' Removed '..result.removed..' unsupported order(s): '..table.concat(removed,', ')..(#names>5 and', ...'or'')..'.'
  end
  result.notice=text
 elseif selected and not result.selected then
  result.notice='[Pregame Queue] Cleared selected building: unavailable to this commander.'
 end
 return result
end
return M
