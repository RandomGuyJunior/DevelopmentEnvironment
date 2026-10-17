-- Read-only matched actual-body lane. Reuses paid-match timer/draw semantics.
local M={}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function quote(s)return '"'..s:gsub('[%z\1-\31\\"]',function(c)return string.format('\\u%04x',c:byte())end)..'"'end
function M.JSON(v)
 local k=type(v);if k=='string'then return quote(v)elseif k=='number'then assert(finite(v),'nonfinite_json');return string.format('%.17g',v)elseif k=='boolean'then return tostring(v)end
 assert(k=='table','unsupported_json');local out={};local keys={};for key in pairs(v)do assert(type(key)=='string','string_record_keys_required');keys[#keys+1]=key end;table.sort(keys)
 for _,key in ipairs(keys)do out[#out+1]=quote(key)..':'..M.JSON(v[key])end;return'{'..table.concat(out,',')..'}'
end
function M.Counts(text)
 assert(type(text)=='string'and #text>0 and #text<=400,'explicit_body_counts_required');local out={};local total=0
 for word in text:gmatch('[^,]+')do local id,n=word:match('^(%d+):(%d+)$');assert(id,'invalid_body_counts');id=tonumber(id);n=tonumber(n);assert(id>0 and n>0 and not out[tostring(id)],'invalid_body_count');out[tostring(id)]=n;total=total+n end
 assert(total>=1 and total<=256 and not text:find(',,',1,true)and text:sub(-1)~=','and text:sub(1,1)~=',','body_count_cap');return out
end
function M.New(S,defs,meta,wanted,count,notify)
 for _,name in ipairs({'GetTimer','DiffTimers','GetDrawFrame','GetGameFrame','GetGameSpeed','GetFPS','GetAllUnits','GetVisibleUnits','GetUnitDefID','GetUnitHealth','GetUnitIsDead','GetSpectatingState','GetCameraState','GetViewGeometry'})do assert(type(S[name])=='function','missing_api:'..name)end
 assert(type(count)=='number'and count==math.floor(count)and count>=30 and count<=600,'interval_count_cap')
 assert(type(meta.source)=='string'and #meta.source==40 and meta.source:match('^%x+$'),'source_pin_required')
 assert(type(meta.engineFull)=='string'and #meta.engineFull>0,'engine_identity_required')
 assert(finite(meta.startFrame)and meta.startFrame%1==0 and meta.startFrame>=1 and meta.startFrame<=36000,'explicit_start_frame_required')
 for _,k in ipairs({'mapChecksum','gameChecksum'})do assert(type(meta[k])=='string'and #meta[k]==128 and meta[k]:match('^%x+$'),'native_checksum_required')end
 local expected=M.JSON(wanted);local rows={};local failed=false;local complete=false;local lastTimer,lastDraw,lastFrame,camera,view,initialDraw;local duplicates=0;local fixedBodyIDs,fixedBodyIDBytes
 local function refuse(reason)failed=true;notify{event='refused',reason=reason,acceptance=false}end
 local function draw()
  local low,high=S.GetDrawFrame();assert(finite(low)and finite(high)and low%1==0 and high%1==0 and low>=0 and low<=65535 and high>=0 and high<=65535,'draw_halves_invalid');return low+high*65536
 end
 local function census(ids)
  assert(type(ids)=='table'and #ids<=256,'body_census_cap');local out={};local models={};local seen={};local n=0
  for k,id in pairs(ids)do assert(type(k)=='number'and k%1==0 and k>=1 and k<=#ids and finite(id)and id%1==0 and id>=0 and not seen[id],'census_identity_invalid');seen[id]=true;n=n+1
   assert(not S.GetUnitIsDead(id),'census_dead_body');local hp=S.GetUnitHealth(id);assert(finite(hp)and hp>0,'body_health_missing');local def=S.GetUnitDefID(id);assert(defs[def]and type(defs[def].modelname)=='string'and #defs[def].modelname>0,'body_model_missing')
   local key=tostring(def);out[key]=(out[key]or 0)+1;local model=defs[def].modelname;models[model]=(models[model]or 0)+1
  end
  assert(n==#ids,'census_array_incomplete');return out,models,seen
 end
 local A={}
 function A.Update()
  if failed or complete then return end
  local ok,why=pcall(function()
   local now=S.GetTimer();local d=draw();local f=S.GetGameFrame();assert(finite(f)and f%1==0 and f>=0,'sim_frame_invalid');if f<meta.startFrame then return end
   if not lastFrame then assert(f==meta.startFrame,'missed_initial_frame');initialDraw=d end
   local desired,actual,paused=S.GetGameSpeed();assert(desired==1 and actual==1 and paused==false,'ordinary_1x_speed_required')
   local spectating,full=S.GetSpectatingState();assert(spectating==true and full==true,'full_native_view_required')
   local c=M.JSON(S.GetCameraState());local w,h,x,y=S.GetViewGeometry();assert(finite(w)and finite(h)and finite(x)and finite(y)and w>0 and h>0,'viewport_missing');local v=M.JSON{w=w,h=h,x=x,y=y}
   if camera then assert(c==camera and v==view,'camera_or_view_changed')else camera,view=c,v end
   local bodies,bodyModels,all=census(S.GetAllUnits());assert(M.JSON(bodies)==expected,'actual_body_count_mismatch')
   local bodyIDs={};for id in pairs(all)do bodyIDs[tostring(id)]=S.GetUnitDefID(id)end
   local bodyIDBytes=M.JSON(bodyIDs)
   if fixedBodyIDBytes then assert(bodyIDBytes==fixedBodyIDBytes,'native_body_identity_changed')else fixedBodyIDs,fixedBodyIDBytes=bodyIDs,bodyIDBytes end
   local visible,visibleModels,visibleIDs=census(S.GetVisibleUnits(-1,nil,false));for id in pairs(visibleIDs)do assert(all[id],'visible_body_not_in_census')end
   assert(M.JSON(visible)==expected,'model_visibility_count_mismatch') -- all configured bodies must be model candidates in this fixed view
   local fps=S.GetFPS();assert(finite(fps)and fps>=0,'native_fps_missing')
   if lastTimer then
    local dt=S.DiffTimers(now,lastTimer);assert(finite(dt)and dt>=0,'negative_or_missing_clock');assert(f>=lastFrame,'sim_frame_reversed')
    if d==lastDraw then duplicates=duplicates+1;return end
    assert(d==lastDraw+1,'incomplete_draw_frames');assert(dt>0,'nonpositive_draw_interval')
    local finish=S.GetTimer();local cost=S.DiffTimers(finish,now);assert(finite(cost)and cost>=0,'negative_recorder_clock')
    rows[#rows+1]={event='interval',index=#rows+1,frame=f,draw=d,seconds=dt,nativeFPS=fps,collectorSeconds=cost,bodyIDs=bodyIDs,bodyCounts=bodies,modelCounts=bodyModels,visibleModelCounts=visibleModels,camera=c,viewport=v,desiredSpeed=desired,actualSpeed=actual,paused=paused,spectating=spectating,fullView=full}
   end
   lastTimer,lastDraw,lastFrame=now,d,f
   if #rows==count then
    complete=true;notify{event='start',metadata=meta,bodyIDs=fixedBodyIDs,expectedCounts=wanted,intervalCount=count,camera=camera,viewport=view,duplicates=duplicates,initialDraw=initialDraw,acceptance=false}
    for _,r in ipairs(rows)do notify(r)end
    notify{event='complete',intervals=#rows,frame=f,draw=d,acceptance=false,scope='Draw-counter wall pacing including collection overhead; native visibility candidates, not GPU execution or display scanout'}
   end
  end)
  if not ok then refuse(tostring(why))end
 end
 function A.Shutdown()if not failed and not complete then refuse('incomplete_interval_window')end end
 return A
end
return M
