-- Owned by the existing infantry-remains controller; never pays team resources.
-- No asset fallback: the caller must provide a real generic mixed-faction pile.
local M={Version=1,Feature='40k_mixed_infantry_pile'}
M.Actors={ork_gretchin_combat=true,space_marine=true,guardsman=true,ork_boy=true,nec_warrior=true,
 imp_devastator=true,guardsman_flamer=true,imp_kasrkin=true,imp_scout=true,
 imp_ogryn=true,imp_terminator=true,ork_nob=true,ork_burna=true,ork_slugga=true,
 nec_flayed=true,nec_immortal=true}
local function finite(x)return type(x)=='number'and x==x and math.abs(x)<math.huge end
local function natural(x)return finite(x)and x>=0 and x%1==0 end
local function sorted(t)local r={};for k in pairs(t)do r[#r+1]=k end;table.sort(r);return r end
local function copy(t)local r={};for k,v in pairs(t)do r[k]=v end;return r end
local function exactFloat(x)
 if not finite(x)or x<0 then return false end
 if x==0 then return true end
 local _,exponent=math.frexp(x)
 if exponent>128 then return false end
 local step=math.ldexp(1,math.max(-149,exponent-24))
 return x/step%1==0
end
local function addExact(a,b)local c=a+b;return finite(c)and c-a==b and c-b==a and c or nil end
M.ExactNativeResource=exactFloat
function M.Definition(model)
 assert(type(model)=='string'and model:match('%.glb$'),'Explicit reviewed pile asset required')
 return{name='Mixed infantry remains',description='Combined remaining infantry salvage',object=model,
  blocking=false,reclaimable=true,autoreclaimable=true,resurrectable=0,indestructible=true,flammable=false,
  damage=100,metal=0,energy=0,reclaimtime=1,footprintx=1,footprintz=1,featuredead='',
  customparams={prototype40k_infantry_pile=1,corpse_pile_schema=1}}
end
function M.New(S,U,F,owner,C,options)
 options=options or{}
 local radius=options.radius or 64;local minimum=options.minimumBodies or 6
 local batch=options.maxFeatures or 16;local scan=options.maxLocalScan or 64
 local interval=options.interval or 15;local cooldown=options.reclaimCooldown or 90
 assert(finite(radius)and radius>=16 and radius<=128)
 assert(natural(minimum)and minimum>=2 and minimum<=32)
 assert(natural(batch)and batch>=minimum and batch<=32 and natural(scan)and scan>=batch and scan<=128)
 assert(natural(interval)and interval>=1 and natural(cooldown)and cooldown>=interval)
 assert(type(owner.features)=='table'and type(owner.flights)=='table')
 for _,api in ipairs({'GetFeatureDefID','GetFeatureTeam','GetFeaturePosition','GetFeatureResources',
  'SetFeatureResources','SetFeatureBlocking','GetFeatureRulesParam','SetFeatureRulesParam','CreateFeature','DestroyFeature',
  'GetGameFrame','GetGroundHeight','GetUnitDefID','GetUnitCommands','GetUnitCommandCount'})do
  assert(type(S[api])=='function','Missing pile API '..api)
 end
 assert(natural(options.maxUnits)and options.maxUnits>0 and type(C.RECLAIM)=='number')
 local pileDef
 for id,d in pairs(F)do if d.name==M.Feature then
  local cp=d.customParams or{}
  assert(not pileDef and tostring(cp.prototype40k_infantry_pile)=='1'and d.reclaimable
   and d.resurrectable==0 and d.destructable==false and d.burnable==false and not d.blocking,'Invalid pile FeatureDef')
  assert((d.metal or 0)==0 and(d.energy or 0)==0,'Pile defaults must carry no entitlement')
  pileDef=id
 end end
 assert(pileDef,'Real generic mixed-faction pile FeatureDef/assets required')
 local A={locked={},retired={},stats={merges=0,deferred=0},failed=false}
 local tracked,cells,cellQueue,cellPending={},{},{},{};local cellHead,cellTail=1,0
 local unitQueue,unitPending,unitHead,unitTail={},{},1,0
 local commands,unknown,direct,areas={},{},{},{};local dirtyCount,unknownCount,areaCount=0,0,0
 local busyUntil={};local cellSize=radius/2
 local offsets={{0,0}}
 for ring=1,2 do for dx=-ring,ring do for dz=-ring,ring do
  if math.max(math.abs(dx),math.abs(dz))==ring then offsets[#offsets+1]={dx,dz}end
 end end end
 local function cellKey(x,z)return math.floor(x/cellSize)..':'..math.floor(z/cellSize)end
 local function schedule(key)
  if key and not cellPending[key]then cellTail=cellTail+1;cellQueue[cellTail]=key;cellPending[key]=true end
 end
 local function resources(fid)
  local t={S.GetFeatureResources(fid)}
  if #t~=6 then return nil end
  for _,v in ipairs(t)do if not finite(v)or v<0 then return nil end end
  if t[1]>t[2]or t[3]>t[4]or t[5]>1 or t[6]<1 or t[6]>1000000 then return nil end
  return t
 end
 local function tupleEqual(a,b)
  if not a or not b then return false end
  for i=1,6 do if a[i]~=b[i]then return false end end;return true
 end
 local function setTuple(fid,t)
  S.SetFeatureResources(fid,t[1],t[3],t[6],t[5],t[2],t[4])
  return tupleEqual(resources(fid),t)
 end
 local function zero(fid,time)return setTuple(fid,{0,0,0,0,1,time})end
 local function countsValid(counts)
  if type(counts)~='table'then return false end
  local n,total=0,0
  for key,value in pairs(counts)do
   local actor,team;if type(key)=='string'then actor,team=key:match('^([%w_]+)@(%d+)$')end
   if not actor or not M.Actors[actor]or not natural(tonumber(team))or not natural(value)or value<1 then return false end
   n=n+1;total=total+value
  end
  return n>0 and n<=64 and total<=1048576,total
 end
 local function metadata(fid,counts)
  local keys=sorted(counts)
  S.SetFeatureRulesParam(fid,'40k_pile_kind_count',#keys,{private=true})
  for i,key in ipairs(keys)do
   -- String rule parameters are supported by this pinned native API.
   S.SetFeatureRulesParam(fid,'40k_pile_kind_'..i,key,{private=true})
   S.SetFeatureRulesParam(fid,'40k_pile_count_'..i,counts[key],{private=true})
  end
  S.SetFeatureRulesParam(fid,'40k_pile_version',M.Version,{private=true})
 end
 function A.FeatureLost(fid)
  local t=tracked[fid]
  if t then
   local cell=cells[t.cell];if cell then
    if t.previous then tracked[t.previous].next=t.next else cell.first=t.next end
    if t.next then tracked[t.next].previous=t.previous else cell.last=t.previous end
    if cell.cursor==fid then cell.cursor=t.next or cell.first end
    cell.count=cell.count-1;if cell.count==0 then cells[t.cell]=nil end
   end
   tracked[fid]=nil;schedule(t.cell)
  end
  A.locked[fid]=nil;A.retired[fid]=nil;busyUntil[fid]=nil
 end
 function A.Observe(fid)
  if tracked[fid]or owner.flights[fid]or A.retired[fid]then return false end
  local row=owner.features[fid];if not row then return false end
  local def=F[S.GetFeatureDefID(fid)];local cp=def and def.customParams or{}
  if row.pile then
   if S.GetFeatureDefID(fid)~=pileDef or not countsValid(row.counts)then return false end
  elseif not M.Actors[row.actor]or tostring(cp.prototype40k_tactical_remains)~='1'
   or cp.parent_actor~=row.actor or not U[row.def]or U[row.def].isBuilding or U[row.def].canFly then return false end
  local x,y,z=S.GetFeaturePosition(fid)
  if not finite(x)or not finite(y)or not finite(z)or not natural(row.team)then return false end
  local key=cellKey(x,z);local cell=cells[key]or{count=0};cells[key]=cell
  tracked[fid]={cell=key,x=x,y=y,z=z,previous=cell.last,row=row,def=S.GetFeatureDefID(fid)}
  if cell.last then tracked[cell.last].next=fid else cell.first=fid end
  cell.last=fid;cell.count=cell.count+1;schedule(key);return true
 end
 function A.UnitChanged(id,def)
  def=def or S.GetUnitDefID(id)
  if not commands[id]and not unknown[id]and not(U[def]and U[def].canReclaim)then return end
  if not unitPending[id]then unitTail=unitTail+1;unitQueue[unitTail]=id;unitPending[id]=true;dirtyCount=dirtyCount+1 end
 end
 function A.UnitLost(id)
  local prior=commands[id];commands[id]=nil
  if prior then for _,p in ipairs(prior)do if p.feature then
   direct[p.feature]=(direct[p.feature]or 1)-1;if direct[p.feature]==0 then direct[p.feature]=nil end
   local t=tracked[p.feature];if t then schedule(t.cell)end
   elseif p.area then areas[p]=nil;areaCount=areaCount-1 end end end
  if unknown[id]then unknown[id]=nil;unknownCount=unknownCount-1 end
 end
 local function readCommands(id)
  A.UnitLost(id)
  if not S.GetUnitDefID(id)then return end
  local count=S.GetUnitCommandCount(id)
  if not natural(count)or count>128 then unknown[id]=true;unknownCount=unknownCount+1;return end
  local queue=S.GetUnitCommands(id,128)
  if type(queue)~='table'or #queue~=count then unknown[id]=true;unknownCount=unknownCount+1;return end
  local rows={}
  for _,command in ipairs(queue)do if command.id==C.RECLAIM then
   local p=command.params
   if type(p)~='table'then unknown[id]=true;unknownCount=unknownCount+1;return end
   if #p==1 and natural(p[1])then
    if p[1]>=options.maxUnits then rows[#rows+1]={feature=p[1]-options.maxUnits}end
   elseif #p>=4 and finite(p[1])and finite(p[3])and finite(p[4])and p[4]>=0 then
    rows[#rows+1]={area=true,x=p[1],z=p[3],radius=p[4]}
   else unknown[id]=true;unknownCount=unknownCount+1;return end
  end end
  if #rows>0 then
   commands[id]=rows
   for _,p in ipairs(rows)do if p.feature then direct[p.feature]=(direct[p.feature]or 0)+1
    else areas[p]=true;areaCount=areaCount+1 end end
  end
 end
 local function busy(fid,x,z,frame)
  if A.locked[fid]or owner.flights[fid]or(busyUntil[fid]or-1)>=frame then return true end
  if direct[fid]then return true end
  for r in pairs(areas)do if(x-r.x)^2+(z-r.z)^2<=r.radius^2 then return true end end
  return false
 end
 function A.AllowFeatureBuildStep(builder,team,fid,def,part)
  if A.creating or A.locked[fid]or A.retired[fid]then return false end
  if tracked[fid]and finite(part)and part<0 then busyUntil[fid]=S.GetGameFrame()+cooldown;schedule(tracked[fid].cell)end
  return true
 end
 local function snapshot(fid,frame)
  local t,row=tracked[fid],owner.features[fid]
  if not t or not row or row~=t.row or owner.flights[fid]or S.GetFeatureDefID(fid)~=t.def or S.GetFeatureTeam(fid)~=row.team then return nil end
  local x,y,z=S.GetFeaturePosition(fid)
  if x~=t.x or y~=t.y or z~=t.z or busy(fid,x,z,frame)then return nil end
  local values=resources(fid);if not values then return nil end
  local counts=row.pile and copy(row.counts)or{[row.actor..'@'..row.team]=1}
  if not countsValid(counts)then return nil end
  return{id=fid,row=row,x=x,y=y,z=z,values=values,counts=counts}
 end
 local function retire(fid)
  A.retired[fid]=true;A.locked[fid]=true
  S.SetFeatureRulesParam(fid,'40k_pile_retired',1,{private=true})
  -- Native DestroyFeature schedules deletion. FeatureLost releases state later.
  pcall(S.DestroyFeature,fid)
 end
 function A.Merge(ids,frame)
  if A.failed or dirtyCount>0 or unknownCount>0 or areaCount>64 or next(A.retired)then return false,'pending_native_state'end
  if type(ids)~='table'or #ids<2 or #ids>batch then return false,'batch_size'end
  local ordered={};for i,id in ipairs(ids)do if not natural(id)then return false,'feature_id'end;ordered[i]=id end;table.sort(ordered)
  local rows,counts={},{};local metal,energy,work,bodies=0,0,0,0
  for i,id in ipairs(ordered)do
   if i>1 and id==ordered[i-1]then return false,'duplicate_feature'end
   local r=snapshot(id,frame);if not r then return false,'not_idle_infantry'end
   if rows[1]and(r.x-rows[1].x)^2+(r.z-rows[1].z)^2>radius^2 then return false,'outside_radius'end
   metal=addExact(metal,r.values[1]);energy=addExact(energy,r.values[3])
   if not metal or not energy then return false,'unrepresentable_sum'end
   work=work+r.values[6]*r.values[5]
   for key,n in pairs(r.counts)do counts[key]=(counts[key]or 0)+n;bodies=bodies+n end
   rows[#rows+1]=r
  end
  if bodies<minimum then return false,'density'end
  if not countsValid(counts)then return false,'metadata_limit'end
  if not exactFloat(metal)or not exactFloat(energy)then return false,'unrepresentable_sum'end
  -- CreateFeature runs FeatureCreated callbacks synchronously. Lock donors before
  -- that first callback boundary, not merely before their resource writes.
  for _,r in ipairs(rows)do A.locked[r.id]=true end
  local function releaseSources()for _,r in ipairs(rows)do A.locked[r.id]=nil end end
  -- Retain the first sorted source's exact position, avoiding ground resnapping.
  local anchor=rows[1];A.creating=true
  local created,fid=pcall(S.CreateFeature,M.Feature,anchor.x,anchor.y,anchor.z,0,anchor.row.team)
  A.creating=false
  if not created or fid==nil then releaseSources();return false,'creation_failed'end
  if not natural(fid)or tracked[fid]or owner.features[fid]then releaseSources();A.failed=true;return false,'invalid_created_identity'end
  A.locked[fid]=true
  local pristine=resources(fid)
  if S.GetFeatureDefID(fid)~=pileDef or not pristine or pristine[1]~=0 or pristine[2]~=0 or pristine[3]~=0 or pristine[4]~=0 then
   local cleaned=pcall(function()assert(zero(fid,1));retire(fid)end)
   releaseSources()
   if not cleaned then A.failed=true end
   return false,'unsafe_pile_definition'end
  local desired={metal,metal,energy,energy,1,math.max(1,math.min(1000000,work))}
  -- reclaimTime is native float32 and is presentation/progress, not a resource.
  -- Set it before touching donors, then use its actual native value thereafter.
  local prepared,prepareError=pcall(function()
   -- Synced weapon rays skip this bit; stock GUI selection uses noSelect instead.
   -- Configure the new zero-resource feature before any donor entitlement changes.
   assert(S.SetFeatureBlocking(fid,false,false,false,false)==false,'pile_non_obstruction_failed')
   S.SetFeatureResources(fid,0,0,desired[6],1,0,0);desired[6]=select(6,S.GetFeatureResources(fid))
   assert(finite(desired[6])and desired[6]>=1 and desired[6]<=1000000,'pile_preparation_failed')
   metadata(fid,counts)
   assert(dirtyCount==0 and unknownCount==0 and areaCount<=64,'commands_changed')
   for _,r in ipairs(rows)do assert(tupleEqual(resources(r.id),r.values),'source_changed')end
  end)
  if not prepared then
   -- Prewrite refusal must preserve any intervening source change. Restoring a
   -- stale snapshot here could undo a reclaim or other legitimate owner action.
   local cleaned=pcall(function()assert(zero(fid,1));retire(fid)end)
   releaseSources();if not cleaned then A.failed=true end
   return false,'prewrite_refused:'..tostring(prepareError)
  end
  local attempted={}
  local ok,err=pcall(function()
   for _,r in ipairs(rows)do
    assert(tupleEqual(resources(r.id),r.values),'source_changed_during_write')
    attempted[#attempted+1]=r;assert(zero(r.id,r.values[6]),'donor_zero_failed')
   end
   assert(setTuple(fid,desired),'pile_resources_failed')
  end)
  if not ok then
   -- Nothing has been deleted. Native writes are reversible for these valid IDs.
   local rollback=pcall(function()
    assert(zero(fid,desired[6]),'pile_rollback_failed')
    for _,r in ipairs(attempted)do assert(setTuple(r.id,r.values),'donor_rollback_failed')end
   end)
   if not rollback then A.failed=true;return false,'unrecoverable_native_write'end
   releaseSources()
   retire(fid);return false,'rolled_back:'..tostring(err)
  end
  owner.features[fid]={pile=true,counts=counts,team=anchor.row.team,metal=metal,energy=energy,work=desired[6]}
  for _,r in ipairs(rows)do retire(r.id)end
  A.locked[fid]=nil;A.Observe(fid);A.stats.merges=A.stats.merges+1
  return true,fid
 end
 function A.RestoreFeature(fid)
  if S.GetFeatureRulesParam(fid,'40k_pile_retired')==1 then
   local r=resources(fid);assert(r and r[1]==0 and r[3]==0,'Retired corpse still owns resources');retire(fid);return true
  end
  if S.GetFeatureDefID(fid)~=pileDef then return false end
  assert(S.GetFeatureRulesParam(fid,'40k_pile_version')==M.Version,'Unowned pile refused')
  local n=S.GetFeatureRulesParam(fid,'40k_pile_kind_count');assert(natural(n)and n>=1 and n<=64,'Invalid pile kind count')
  local counts={};for i=1,n do
   local key=S.GetFeatureRulesParam(fid,'40k_pile_kind_'..i);local count=S.GetFeatureRulesParam(fid,'40k_pile_count_'..i)
   assert(type(key)=='string'and not counts[key],'Duplicate pile kind');counts[key]=count
  end
  assert(countsValid(counts),'Invalid pile counts');local r=assert(resources(fid),'Invalid saved pile resources')
  assert(S.SetFeatureBlocking(fid,false,false,false,false)==false,'saved_pile_non_obstruction_failed')
  owner.features[fid]={pile=true,counts=counts,team=S.GetFeatureTeam(fid),metal=r[2],energy=r[4],work=r[6]}
  assert(A.Observe(fid),'Saved pile could not be indexed');return true
 end
 function A.Frame(frame)
  if A.failed then return end
  -- At most one retired batch exists; native deletion is deferred, not hidden.
  for _,fid in ipairs(sorted(A.retired))do
   if not S.GetFeatureDefID(fid)then A.FeatureLost(fid);owner.features[fid]=nil
   else pcall(S.DestroyFeature,fid)end
  end
  -- Process command events after native GiveCommandReal has mutated the queue.
  for _=1,16 do
   if unitHead>unitTail then unitQueue={};unitHead,unitTail=1,0;break end
   local id=unitQueue[unitHead];unitQueue[unitHead]=nil;unitHead=unitHead+1
   unitPending[id]=nil;dirtyCount=dirtyCount-1;readCommands(id)
  end
  if frame%interval~=0 or dirtyCount>0 or unknownCount>0 or areaCount>64 or next(A.retired)then return end
  for _=1,2 do
   if cellHead>cellTail then cellQueue={};cellHead,cellTail=1,0;break end
   local key=cellQueue[cellHead];cellQueue[cellHead]=nil;cellHead=cellHead+1;cellPending[key]=nil
   local cx,cz=key:match('^(-?%d+):(-?%d+)$');cx,cz=tonumber(cx),tonumber(cz)
   local ids,more={},false
   -- One shared budget across the center and at most24 neighboring cells. This
   -- admits a tight group across cell boundaries without scanning a whole map.
   for _,offset in ipairs(offsets)do
    local cell=cells[(cx+offset[1])..':'..(cz+offset[2])]
    local id=cell and(cell.cursor or cell.first)
    while id and #ids<scan do ids[#ids+1]=id;id=tracked[id].next end
    if cell then cell.cursor=id or cell.first end
    if id then more=true end
    if #ids==scan then more=true;break end
   end
   table.sort(ids)
   local selected={};local first
   for _,fid in ipairs(ids)do
    local r=snapshot(fid,frame)
    if r and(not first or(r.x-first.x)^2+(r.z-first.z)^2<=radius^2)then
     first=first or r;selected[#selected+1]=fid;if #selected==batch then break end
    end
   end
   if #selected>=2 then local ok=A.Merge(selected,frame);if not ok then A.stats.deferred=A.stats.deferred+1 end end
   -- A protected area is retried at most twice per interval, never per body/frame.
   if #selected<#ids or more then schedule(key)end
  end
 end
 return A
end
return M
