-- Separate read-only supplement; existing owner and body digest untouched.
local M={Version=1,FeatureCap=128,OwnerCap=512}
local function finite(n)return type(n)=='number'and n==n and math.abs(n)<math.huge end
local function integer(n)return finite(n)and n==math.floor(n)end
local function bounded(t,cap)
 assert(type(t)=='table','state_table_missing');local n=0
 for _ in pairs(t)do n=n+1;assert(n<=cap,'state_count_cap')end;return n
end
function M.New(S,GG,metadata,frameText,notify,D)
 assert(type(D)=='table'and type(D.Encode)=='function'and type(D.Frames)=='function'and type(D.Checksum)=='function','strict_codec_missing')
 for _,api in ipairs({'GetGameFrame','GetAllFeatures','ValidFeatureID','GetFeatureDefID','GetFeatureTeam','GetFeaturePosition','GetFeatureRotation','GetFeatureDirection','GetFeatureVelocity','GetFeatureBlocking','GetFeatureHealth','GetFeatureResources','GetFeatureRulesParams'})do assert(type(S[api])=='function','missing_api:'..api)end
 assert(type(notify)=='function'and type(metadata)=='table','explicit_interfaces')
 assert(type(metadata.source)=='string'and #metadata.source==40 and metadata.source:match('^%x+$'),'source_pin_missing')
 for _,key in ipairs({'engine','engineFull'})do assert(type(metadata[key])=='string'and #metadata[key]>0,'engine_identity_missing')end
 for _,key in ipairs({'gameChecksum','mapChecksum'})do assert(type(metadata[key])=='string'and #metadata[key]==128 and metadata[key]:match('^%x+$'),'native_checksum_missing')end
 local frames=D.Frames(frameText);local index=1;local failed=false
 local function tuple(fn,id,n,bool)
  local t={fn(id)};assert(#t==n,'native_tuple_incomplete')
  for i=1,n do assert((bool and type(t[i])=='boolean')or(not bool and finite(t[i])),'native_tuple_nonfinite_or_type')end;return t
 end
 local function capture(frame)
  assert(frame==S.GetGameFrame(),'native_frame_mismatch')
  local R=GG.Recoil40KTacticalRemains;assert(type(R)=='table'and type(R.features)=='table','remains_owner_missing')
  local ids=S.GetAllFeatures();local n=bounded(ids,M.FeatureCap);assert(n==#ids,'native_array_incomplete')
  for k in pairs(ids)do assert(integer(k)and k>=1 and k<=n,'native_array_malformed')end
  table.sort(ids);local features={}
  for _,id in ipairs(ids)do
   assert(integer(id)and id>=0 and not features[id]and S.ValidFeatureID(id),'feature_identity_invalid')
   local def,team=S.GetFeatureDefID(id),S.GetFeatureTeam(id)
   assert(integer(def)and def>0 and integer(team),'feature_definition_or_owner_missing')
   local rules=S.GetFeatureRulesParams(id);bounded(rules,128)
   if R.features[id]then assert(rules['40k_remains_version']==1,'owned_remains_metadata_hidden_or_missing')end
   if rules['40k_remains_version']~=nil then
    assert(rules['40k_remains_version']==1,'unsupported_remains_version')
    for _,k in ipairs({'squad','slot','generation','metal','energy','work','team','def'})do assert(finite(rules['40k_remains_'..k]),'remains_metadata_missing:'..k)end
   end
   features[id]={id=id,def=def,team=team,position=tuple(S.GetFeaturePosition,id,3),rotation=tuple(S.GetFeatureRotation,id,3),direction=tuple(S.GetFeatureDirection,id,9),velocity=tuple(S.GetFeatureVelocity,id,4),blocking=tuple(S.GetFeatureBlocking,id,7,true),health=tuple(S.GetFeatureHealth,id,3),resources=tuple(S.GetFeatureResources,id,6),rules=rules}
  end
  local owner={};for _,key in ipairs({'pending','features','entitlements','flights','damage','blasts'})do bounded(R[key],M.OwnerCap);owner[key]=R[key]end
  return{schema=1,frame=frame,metadata=metadata,features=features,remains=owner}
 end
 local A={}
 function A.Frame(frame)
  if failed or not frames[index]or frame<frames[index]then return end
  if frame~=frames[index]then failed=true;notify({status='refused',frame=frame,reason='missed_common_frame'});return end
  local ok,state=pcall(capture,frame);local payload
  if ok then ok,payload=pcall(D.Encode,state)else payload=state end
  if not ok then failed=true;notify({status='refused',frame=frame,reason=tostring(payload)});return end
  notify({status='sample',frame=frame,checksum=D.Checksum(payload),payload=payload});index=index+1
  if not frames[index]then notify({status='complete',frame=frame,samples=#frames})end
 end
 return A
end
return M
