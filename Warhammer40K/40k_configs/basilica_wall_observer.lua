-- Read-only callback/state supplement. No fixture/setup/control/resource ownership.
local M={Version=1,X=768,Z=4352}
local function finite(x)return type(x)=='number'and x==x and math.abs(x)<math.huge end
local function integer(x)return finite(x)and x%1==0 end
function M.New(S,F,G,source,frames,notify,D)
 for _,api in ipairs({'GetGameFrame','GetAllFeatures','ValidFeatureID','GetFeatureDefID','GetFeaturePosition','GetFeatureHealth','GetFeatureResources','GetFeatureBlocking'})do assert(type(S[api])=='function','missing_api:'..api)end
 assert(G.mapName=='Basilica Fall 0.1'and G.mapSizeX==6144 and G.mapSizeZ==6144,'exact_native_map_required')
 assert(type(G.mapChecksum)=='string'and #G.mapChecksum==128 and G.mapChecksum:match('^%x+$'),'native_map_sha512_required')
 assert(type(source)=='string'and #source==40 and source:match('^%x+$'),'source_required')
 local list=D.Frames(frames);local idx=1;local failed=false;local events={};local target,rubble
 local function capture(fid)
  if not fid or not S.ValidFeatureID(fid)then return {exists=false}end
  local pos={S.GetFeaturePosition(fid)};local hp={S.GetFeatureHealth(fid)};local res={S.GetFeatureResources(fid)};local block={S.GetFeatureBlocking(fid)}
  for _,pair in ipairs({{pos,3},{hp,3},{res,6}})do assert(#pair[1]==pair[2],'native_tuple_missing');for _,x in ipairs(pair[1])do assert(finite(x),'native_nonfinite')end end
  assert(#block==7,'blocking_tuple_missing');for _,b in ipairs(block)do assert(type(b)=='boolean','blocking_type')end
  return {exists=true,id=fid,def=S.GetFeatureDefID(fid),position=pos,health=hp,resources=res,blocking=block}
 end
 local ids=S.GetAllFeatures();assert(type(ids)=='table'and #ids<=128,'feature_cap')
 local count=0;for k in pairs(ids)do count=count+1;assert(integer(k)and k>=1 and k<=#ids,'feature_array')end;assert(count==#ids,'feature_array')
 local seen={}
 for _,id in ipairs(ids)do
  assert(integer(id)and not seen[id]and S.ValidFeatureID(id),'feature_identity');seen[id]=true
  local def=F[S.GetFeatureDefID(id)];assert(def,'feature_definition')
  if def.name=='40k_gothic_wall'then local p=capture(id).position
   if p[1]==M.X and p[3]==M.Z then assert(not target,'ambiguous_saved_wall');target=id;assert(def.destructable==true and def.reclaimable==true and def.deathFeatureID and F[def.deathFeatureID]and F[def.deathFeatureID].name=='40k_rubble_remnant','actual_wall_wreck_binding')end
  end
 end
 assert(target,'saved_wall_missing');local A={Target=target}
 local function record(kind,id,values)
  if failed then return end
  local ok,reason=pcall(function()
   assert(#events<64,'callback_cap');local row={kind=kind,id=id,frame=S.GetGameFrame(),values=values};D.Encode(row);events[#events+1]=row
  end)
  if not ok then failed=true;notify({status='refused',frame=S.GetGameFrame(),reason=tostring(reason)})end
 end
 function A.FeatureDamaged(id,def,team,damage,weapon,projectile,attacker,attackerDef,attackerTeam)
  if id==target or id==rubble then record('FeatureDamaged',id,{def=def,team=team,damage=damage,weapon=weapon,projectile=projectile,attacker=attacker,attackerDef=attackerDef,attackerTeam=attackerTeam})end
 end
 function A.FeatureCreated(id,ally)
  if failed or not S.ValidFeatureID(id)then return end
  local def=F[S.GetFeatureDefID(id)];if not def or def.name~='40k_rubble_remnant'then return end
  local p={S.GetFeaturePosition(id)}
  if p[1]==M.X and p[3]==M.Z then
   if rubble then failed=true;notify({status='refused',frame=S.GetGameFrame(),reason='ambiguous_native_rubble'});return end
   rubble=id;record('FeatureCreated',id,{ally=ally,def=S.GetFeatureDefID(id)})
  end
 end
 function A.FeatureDestroyed(id,ally)if id==target or id==rubble then record('FeatureDestroyed',id,{ally=ally})end end
 function A.Frame(frame)
  if failed or not list[idx]or frame<list[idx]then return end
  if frame~=list[idx]then failed=true;notify({status='refused',frame=frame,reason='missed_common_frame'});return end
  local ok,payload=pcall(function()
   assert(S.GetGameFrame()==frame,'native_frame_mismatch')
   return D.Encode({schema=1,frame=frame,source=source,mapChecksum=G.mapChecksum,target=capture(target),rubble=capture(rubble),callbacks=events})
  end)
  if not ok then failed=true;notify({status='refused',frame=frame,reason=tostring(payload)});return end
  notify({status='sample',frame=frame,payload=payload,checksum=D.Checksum(payload)});idx=idx+1
  if not list[idx]then notify({status='complete',frame=frame,samples=#list,nativeAccepted=false})end
 end
 return A
end
return M
