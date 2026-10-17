-- Flat native UnitRulesParams survive LuaRules reload and engine save restoration.
-- No loadstring/deserialization execution. Unknown/incomplete/changed actors refuse.
local M={prefix='40k_nec_save_'}
function M.Write(S,id,kind,state)
 if not S.ValidUnitID(id)then return end
 local function put(k,v)S.SetUnitRulesParam(id,M.prefix..k,v,{allied=true})end
 put('version',kind and 1 or 0);put('kind',kind)
 if not kind then return end
 local i=state.identity;put('def',i.def);put('team',i.team);put('token',i.token)
 put('finish',state.finish);put('cooldown',state.cooldown)
 local s=state.snapshot;put('snapshot',s and 1 or 0)
 if not s then return end
 put('source_team',s.team);put('fire',s.firestate);put('move',s.movestate)
 for _,key in ipairs({'buildTime','metalCost','energyCost'})do put(key,s.costs[key])end
 put('queue_count',#s.queue)
 for n,c in ipairs(s.queue)do
  put('q'..n..'_id',c.id);put('q'..n..'_count',#(c.params or {}))
  for j,v in ipairs(c.params or {})do put('q'..n..'_p'..j,v)end
 end
end
function M.Read(S,id)
 local function get(k)return S.GetUnitRulesParam(id,M.prefix..k)end
 if get('version')~=1 then return end
 local r={kind=get('kind'),state={identity={def=get('def'),team=get('team'),token=get('token')},finish=get('finish'),cooldown=get('cooldown')}}
 if get('snapshot')==1 then
  local n=get('queue_count');if type(n)~='number' or n<0 or n~=math.floor(n) or n>100000 then return end
  local s={team=get('source_team'),firestate=get('fire'),movestate=get('move'),costs={},queue={}};r.state.snapshot=s
  for _,k in ipairs({'buildTime','metalCost','energyCost'})do s.costs[k]=get(k)end
  for x=1,n do
   local count=get('q'..x..'_count');if type(count)~='number' or count<0 or count~=math.floor(count) or count>100000 then return end
   local c={id=get('q'..x..'_id'),params={}};s.queue[x]=c
   for j=1,count do local v=get('q'..x..'_p'..j);if type(v)~='number' then return end;c.params[j]=v end
  end
 end
 return r
end
return M
