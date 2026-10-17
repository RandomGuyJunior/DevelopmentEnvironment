function widget:GetInfo()return {name='40K mixed render evidence',desc='Read-only exact camera/view/visible-population witness',author='Local project',layer=1012,enabled=true}end
local options=Spring.GetModOptions()
if options.prototype_diagnostic~='benchmark' or tostring(options.prototype_mixed_force)~='1'then return end
local function json(v)
 if type(v)=='string'then return '"'..v:gsub('[%z\1-\31\\"]',function(c)return string.format('\\u%04x',c:byte())end)..'"'end
 if type(v)=='number'then return v==v and math.abs(v)<math.huge and tostring(v)or'null'end
 if type(v)=='boolean'then return v and'true'or'false'end
 if type(v)~='table'then return 'null'end
 local out={};for k,x in pairs(v)do out[#out+1]=json(tostring(k))..':'..json(x)end;table.sort(out);return '{'..table.concat(out,',')..'}'
end
local timer,last,stage;local records=0
function widget:Update()
 local current=Spring.GetGameRulesParam('40k_mixed_stage')or 0
 if current==0 or Spring.GetGameRulesParam('40k_mixed_done')==1 or records>=200 then return end
 local now=Spring.GetTimer();if not timer then timer,last=now,now end
 if Spring.DiffTimers(now,timer)>240 then return end
 if stage==current and Spring.DiffTimers(now,last)<1 then return end
 local changed=stage~=current;stage,last=current,now;records=records+1
 local w,h,x,y=Spring.GetViewGeometry()
 local row={event='view_witness',stage=stage,frame=Spring.GetGameFrame(),wall=Spring.DiffTimers(now,timer),camera=Spring.GetCameraState(),view={width=w,height=h,x=x,y=y}}
 if Spring.GetVisibleUnits then
  row.visibleModels=Spring.GetVisibleUnits(-1,nil,false)or{} -- Pinned native arg3false excludes icon actors.
  row.visibleIncludingIcons=Spring.GetVisibleUnits(-1,nil,true)or{}
 else row.coverageGap='native visible-unit API absent'end
 if changed then
  row.activeWidgets={};for _,widget in ipairs(widgetHandler.widgets or{})do local info=widget.GetInfo and widget:GetInfo();if info then row.activeWidgets[#row.activeWidgets+1]=info.name end end;table.sort(row.activeWidgets)
  row.healthPolicy='normal pinned BAR experience/HP policy; observer grants nothing'
  row.scope='existing two-faction six-core mixed fixture; not full three-faction acceptance'
 end
 Spring.Echo('40K_MIXED_BENCH '..json(row))
end
