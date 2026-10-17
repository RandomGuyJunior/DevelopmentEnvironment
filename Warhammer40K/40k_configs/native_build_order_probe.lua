-- Owned diagnostic only. Reads native state; never sends or repairs commands.
local M={}
local function vector(x,y,z)if x==nil or y==nil or z==nil then return nil end;return{x,y,z}end
function M.New(S,defs,actor,def,pos,ordered,orderReturn)
 assert(type(ordered)=='number'and actor and defs[def],'invalid owned build observation')
 local target={};for i=1,math.min(#(pos or{}),4)do target[i]=pos[i]end
 local last;local emitted=0;local closed=false
 local function observe(frame,birth)
  if closed or frame<ordered or frame==last then return nil,false end
  if birth then closed=true;return nil,false end
  local elapsed=frame-ordered;local expired=elapsed>=1800
  if elapsed~=0 and elapsed~=1 and elapsed%90~=0 and not expired then return nil,false end
  if emitted>=22 then closed=true;return nil,expired end
  emitted=emitted+1;last=frame
  local bd=defs[S.GetUnitDefID(actor)]or{};local td=defs[def]
  local x,y,z=S.GetUnitPosition(actor);local vx,vy,vz=S.GetUnitVelocity(actor)
  local site={};for i,v in ipairs(target)do site[i]=v end
  local row={frame=frame,elapsed=elapsed,actor=actor,target=def,orderReturn=orderReturn,team=S.GetUnitTeam(actor),dead=S.GetUnitIsDead(actor),position=vector(x,y,z),velocity=vector(vx,vy,vz),site=site,buildDistance=bd.buildDistance,buildSpeed=bd.buildSpeed,isBuilder=bd.isBuilder,isFactory=bd.isFactory,queue={},metalCost=td.metalCost,energyCost=td.energyCost,buildTime=td.buildTime}
  local readQueue=bd.isFactory and S.GetFactoryCommands or S.GetUnitCommands
  row.queueKind=bd.isFactory and'native_factory_production'or'native_unit_commands'
  for i,c in ipairs(readQueue(actor,3)or{})do
   if i>3 then break end;local params={};for j=1,math.min(#(c.params or{}),4)do params[j]=c.params[j]end
   row.queue[i]={id=c.id,tag=c.tag,params=params,options=type(c.options)=='table'and{coded=c.options.coded,shift=c.options.shift,ctrl=c.options.ctrl,alt=c.options.alt}or c.options}
  end
  row.building=S.GetUnitIsBuilding(actor)
  if #target>=3 then
   row.status,row.feature=S.TestBuildOrder(def,target[1],target[2],target[3],target[4]or 0)
   if x and y and z then row.distance=math.sqrt((x-target[1])^2+(y-target[2])^2+(z-target[3])^2);row.inBuildRange=bd.buildDistance and row.distance<=bd.buildDistance or false end
   row.groundMetal=select(3,S.GetGroundInfo(target[1],target[3]))
  end
  if type(row.team)=='number'then
   local m,ms,_,mi,me=S.GetTeamResources(row.team,'metal');local e,es,_,ei,ee=S.GetTeamResources(row.team,'energy')
   row.resources={metal=m,metalStorage=ms,metalIncome=mi,metalExpense=me,energy=e,energyStorage=es,energyIncome=ei,energyExpense=ee,netDeltaIsBill=false}
  end
  if expired then closed=true end
  return row,expired
 end
 return{Observe=observe}
end
return M
