function widget:GetInfo()
 return {name='40K explicit native source bounds capture',desc='Read-only original-renderer model metadata receipt; deliberately demands all registered source models',author='Local project',layer=1004,enabled=true}
end
local options=Spring.GetModOptions() or {}
local function on(x)return x==true or x==1 or x=='1'end
if not on(options.prototype_source_bounds_capture) then return end
local bad=on(options.prototype_demand_model_review) or on(options.prototype_source_atlas_alias_review)
local ignore={prototype_source_bounds_capture=true,prototype_demand_model_review=true,prototype_lazy_metadata_game_checksum=true,prototype_sourcebounds_engine_sha256=true}
-- Stock overrides may return an __index-only readonly proxy: pairs can be empty.
local optionKeys={'prototype_diagnostic','prototype_source_progression','prototype_source_acceptance','prototype_mixed_v2','prototype_mixed_v2_audio','prototype_mixed_force','prototype_profile','prototype_mixed_large','prototype_benchmark_unit','prototype_benchmark_durability_debug','prototype_test_end_frame'}
local function json(v)
 if type(v)=='string'then return '"'..v:gsub('[%z\1-\31\\"]',function(c)return string.format('\\u%04x',c:byte())end)..'"'end
 if type(v)=='number'then assert(v==v and math.abs(v)<math.huge,'nonfinite native metadata');return string.format('%.17g',v)end
 if type(v)=='boolean'then return v and'true'or'false'end
 assert(type(v)=='table','unsupported native metadata type');local a={};for k,x in pairs(v)do a[#a+1]=json(tostring(k))..':'..json(x)end;table.sort(a);return '{'..table.concat(a,',')..'}'
end
-- Echo lines have a native size limit. Preserve every byte of large identities
-- in short ASCII fragments instead of truncating or omitting customParams.
local transportSerial,transportFailed=0,false
local function emit(t)
 if transportFailed then return end
 local raw=json(t);transportSerial=transportSerial+1
 if #raw>1048576 then
  Spring.Echo('40K_SOURCE_BOUNDS '..json({event='refused',reason='native_capture_record_exceeds_transport_bound'}));transportFailed=true;return
 end
 if #raw<=8192 then Spring.Echo('40K_SOURCE_BOUNDS '..raw);return end
 local parts=math.ceil(#raw/2048)
 for part=1,parts do
  local data=raw:sub((part-1)*2048+1,part*2048):gsub('.',function(c)return string.format('%02x',c:byte())end)
  Spring.Echo('40K_SOURCE_BOUNDS '..json({event='fragment',schema=1,serial=transportSerial,part=part,parts=parts,bytes=#raw,encoding='hex',data=data}))
 end
end
local originalRefs={wh40k_corsolar=true,wh40k_corfus=true,wh40k_corafus=true,wh40k_corgeo=true}
local function selected(d)local cp=d.customParams or{};local key=cp.prototype40k_original_generator_reference
 return (on(cp.prototype40k)and(d.modeltype=='glb'or d.modeltype=='gltf'))or(d.modeltype=='s3o'and originalRefs[key]and d.name=='40k_generator_ref_'..key and cp.original_reference_profile==d.name and on(cp.diagnostic_only))end
local ids,index,started,done={},1,false,false
local function identity(d)
 local cp={};for k,v in pairs(d.customParams or{})do if type(v)=='string'or type(v)=='number'or type(v)=='boolean'then cp[k]=v end end
 return {name=d.name,modelname=d.modelname,modelpath=d.modelpath,modeltype=d.modeltype,customParams=cp,xsize=d.xsize,zsize=d.zsize,isBuilding=d.isBuilding,isFactory=d.isFactory,health=d.health,metalCost=d.metalCost,energyCost=d.energyCost,buildTime=d.buildTime}
end
function widget:Update()
 if done or transportFailed then return end
 if bad then emit({event='refused',reason='capture_requires_original_renderer_and_unaliased_materials'});done=true;return end
 if not started then
  for id,d in pairs(UnitDefs)do if selected(d)then ids[#ids+1]=id end end;table.sort(ids)
  if #ids==0 or #ids>512 then emit({event='refused',reason='registered_source_count_outside_bound',count=#ids});done=true;return end
  local opts,availability={},{};for _,k in ipairs(optionKeys)do local v=options[k];availability[k]=v~=nil;if v~=nil then opts[k]=v end end
  emit({event='begin',schema=1,count=#ids,engineVersion=Engine.version,engineVersionFull=Engine.versionFull,gameName=Game.gameName,gameVersion=Game.gameVersion,gameChecksum=Game.modChecksum,mapName=Game.mapName,mapChecksum=Game.mapChecksum,options=opts,optionAvailability=availability,optionScope='explicit known diagnostic/source keys only; raw startscript receipt required for full options',paidAcceptance=false,scope='explicit all-registered source metadata capture; not texture residency/performance evidence'})
  started=true
 end
 -- Bounded reads per UI update; no order/resource/health/placement/camera mutation.
 for n=1,4 do
  local id=ids[index];if not id then emit({event='complete',schema=1,count=#ids});done=true;return end
  local d=UnitDefs[id];local ok,row=pcall(function()
   local m=d.model;local dims=Spring.GetUnitDefDimensions(id);assert(type(dims)=='table','native dimensions unavailable')
   local nativeHeight,nativeRadius=d.height,d.radius
   assert(nativeHeight==dims.height and nativeRadius==dims.radius,'native independent getters disagree')
   return {event='definition',id=id,name=d.name,identity=identity(d),height=nativeHeight,radius=nativeRadius,dimensions=dims,textures=m.textures,frame=Spring.GetGameFrame()}
  end)
  if not ok then emit({event='refused',reason='native_model_metadata_failed',id=id,name=d.name,error=tostring(row)});done=true;return end
  emit(row);index=index+1
 end
end
