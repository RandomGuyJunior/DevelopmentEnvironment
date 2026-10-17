function widget:GetInfo()return{name='40K mixed v2 native framing',desc='Opt-in actual population camera and readbacks',author='Local project',layer=1008,enabled=true}end
local opts=Spring.GetModOptions()or{}
if opts.prototype_diagnostic~='mixedperf2'or tostring(opts.prototype_mixed_v2)~='1'or not VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(opts.prototype_source_progression)then return end
local cfg=VFS.Include('40k_configs/mixed_v2.lua')
local planner=VFS.Include('40k_configs/mixed_v2_camera_plan.lua')
local original,serial,clock,last,lastRender= nil,0,0,-1,-1
local plan,rows,expected,stable,appliedAt,applies= nil,nil,nil,0,0,0
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function json(v)
 if type(v)=='number'then return finite(v)and string.format('%.17g',v)or'null'end
 if type(v)=='boolean'then return v and'true'or'false'end
 if type(v)=='string'then return'"'..v:gsub('[%z\1-\31\\"]',function(c)return string.format('\\u%04x',c:byte())end)..'"'end
 if type(v)~='table'then return'null'end
 local out={};for k,x in pairs(v)do out[#out+1]=json(tostring(k))..':'..json(x)end;table.sort(out);return'{'..table.concat(out,',')..'}'
end
local function log(event,data)data=data or{};data.event=event;data.serial=serial;data.frame=Spring.GetGameFrame();Spring.Echo('40K_MIXED_V2_CAMERA '..json(data))end
local function read(name,...)
 if type(Spring[name])~='function'then return nil,'api_missing_'..name end
 local v={pcall(Spring[name],...)};if not v[1]then return nil,'api_failed_'..name end;table.remove(v,1);return v
end
local function collect()
 local ids,why=read('GetAllUnits');if not ids or type(ids[1])~='table'then return nil,why or 'native_inventory_missing'end
 local out={};local selected=cfg.Selected(opts)
 for _,id in ipairs(ids[1])do
  local marker=read('GetUnitRulesParam',id,'40k_mixed_v2_seed')
  if marker and marker[1]==serial then
   local def=read('GetUnitDefID',id);local d=def and UnitDefs[def[1]]
   if not d or not selected[d.name]then return nil,'seed_identity_outside_exact_fixture'end
   local p=read('GetUnitPosition',id);local r=read('GetUnitRadius',id)
   if not(p and r and finite(p[1])and finite(p[2])and finite(p[3])and finite(r[1])and r[1]>0)then return nil,'native_seed_geometry_unreadable'end
   local row={id=id,x=p[1],y=p[2],z=p[3],radius=r[1]}
   local command=read('GetUnitCurrentCommand',id)
   if command and command[1]==10 and finite(command[4])and finite(command[5])and finite(command[6])then row.move={command[4],command[5],command[6]}end
   out[#out+1]=row
  end
 end
 table.sort(out,function(a,b)return a.id<b.id end);return out
end
local function apply(current,width,height)
 local proposed,why=planner.Plan(current,width,height,Spring.GetGroundHeight)
 if not proposed then return false,why end
 local ok=read('SetCameraState',proposed.camera,0)
 if not ok then return false,'native_camera_apply_failed'end
 plan=proposed;rows=current;appliedAt=clock;stable=0;applies=applies+1
 log('apply',{expected=expected,readable=#rows,requested=plan.camera,bounds=plan.bounds,view=plan.viewport,applyCount=applies,
  fidelity='camera only; no icons/LOD/textures/shaders/stats changes',population='diagnostic unpaid seeds; not paid acceptance'})
 return true
end
local function observations(current)
 local state,why=read('GetCameraState');local actual=read('GetCameraPosition');local view=read('GetViewGeometry')
 if not(state and type(state[1])=='table'and actual and view and finite(view[1])and finite(view[2]))then return nil,why or 'camera_view_readback_missing'end
 local c=state[1];local okay=c.mode==1 and c.name=='ta'
 for _,k in ipairs({'px','pz','height','angle'})do okay=okay and finite(c[k])and math.abs(c[k]-plan.camera[k])<.5 end
 for a=1,3 do okay=okay and finite(actual[a])and math.abs(actual[a]-plan.expectedRender[a])<.75 end
 local models=read('GetVisibleUnits',-1,nil,false);local icons=read('GetVisibleUnits',-1,nil,true)
 if not(models and icons and type(models[1])=='table'and type(icons[1])=='table')then return nil,'native_model_visibility_missing'end
 local modelSet,iconSet={},{};for _,id in ipairs(models[1])do modelSet[id]=true end;for _,id in ipairs(icons[1])do iconSet[id]=true end
 local visible,including,projected,unreadable=0,0,0,0
 for _,r in ipairs(current)do
  if modelSet[r.id]then visible=visible+1 end;if iconSet[r.id]then including=including+1 end
  local p=read('WorldToScreenCoords',r.x,r.y,r.z)
  if p and finite(p[1])and finite(p[2])and finite(p[3])then
   if p[1]>=16 and p[2]>=16 and p[1]<=view[1]-16 and p[2]<=view[2]-16 and p[3]>=0 and p[3]<=1 then projected=projected+1 end
  else unreadable=unreadable+1 end
 end
 return{camera=c,renderCamera=actual,view=view,controllerAndRenderMatch=okay,visibleSeedModels=visible,visibleIncludingIcons=including,
  projectedSeedCenters=projected,projectionUnreadable=unreadable,readableAliveSeeds=#current,expected=expected,settleSeconds=clock-appliedAt,
  modelFraction=#current>0 and visible/#current or nil,initialTarget=expected,phase=cfg.Window(serial).phase,populationScope=cfg.Window(serial).populationScope,
  visibilityAPI='native frustum/LOS/noDraw/icon classification; not pixel/GPU draw or HUD proof'}
end
function widget:Initialize()
 local s=read('GetCameraState');original=s and s[1]
 log('start',{stockHUD='unchanged; native review required',quality='unchanged'})
end
function widget:Shutdown()if original then Spring.SetCameraState(original,0)end end
function widget:DrawScreen()
 if not plan or stable>=3 or lastRender==clock then return end;lastRender=clock
 local state=read('GetCameraState');local actual=read('GetCameraPosition')
 local c=state and state[1];local okay=type(c)=='table'and c.mode==1 and c.name=='ta'and actual~=nil
 if okay then
  for _,k in ipairs({'px','pz','height','angle'})do okay=okay and finite(c[k])and math.abs(c[k]-plan.camera[k])<.5 end
  for a=1,3 do okay=okay and finite(actual[a])and math.abs(actual[a]-plan.expectedRender[a])<.75 end
 end
 stable=okay and stable+1 or 0
end
function widget:Update(dt)
 if finite(dt)and dt>0 then clock=clock+dt end
 if Spring.GetGameRulesParam('40k_mixed_v2_done')==1 then return end
 local currentSerial=Spring.GetGameRulesParam('40k_mixed_v2_serial')or 0
 if currentSerial<1 then return end
 local fresh=currentSerial~=serial
 if not fresh and clock-last<1 then return end;last=clock
 if fresh then serial=currentSerial;expected=cfg.Window(serial) and cfg.Window(serial).target;plan=nil;stable=0;applies=0 end
 if not expected then log('refused',{reason='serial_outside_six_windows'});return end
 local current,why=collect()
 if not current or #current==0 or #current>expected or (#current~=expected and (not plan or cfg.Window(serial).phase~='combat')) then log('refused',{reason=why or'exact_native_population_unreadable_or_lost',readable=current and #current or nil,expected=expected});return end
 local view=read('GetViewGeometry');if not view then log('refused',{reason='viewport_unreadable'});return end
 if not plan or view[1]~=plan.viewport.width or view[2]~=plan.viewport.height then
  local okay,reason=apply(current,view[1],view[2]);if not okay then log('refused',{reason=reason})end;return
 end
 local row,reason=observations(current)
 if not row then log('refused',{reason=reason});return end
 -- Reframe moving bounds only while settling. No hidden camera correction in a measurement window.
 local measuredPopulation=cfg.Window(serial).phase=='combat' and #current or expected
 if row.projectedSeedCenters<measuredPopulation and clock-appliedAt<4 and applies<3 then
  local okay,reason=apply(current,view[1],view[2]);if not okay then log('refused',{reason=reason})end;return
 end
 if not row.controllerAndRenderMatch then stable=0 end
 row.stableRenderedObservations=stable
 row.ready=row.controllerAndRenderMatch and stable>=3 and row.projectionUnreadable==0 and row.projectedSeedCenters==measuredPopulation
  and row.readableAliveSeeds==measuredPopulation and row.visibleSeedModels/measuredPopulation>=cfg.minVisibleFraction and clock-appliedAt>=.5
 row.reason=row.ready and'native_framing_readbacks_only'or'camera_population_projection_or_model_visibility_refused'
 log(row.ready and'readback' or'refused',row)
end
