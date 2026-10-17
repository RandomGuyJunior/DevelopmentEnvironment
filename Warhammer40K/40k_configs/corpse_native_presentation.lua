-- Prepared native FEATURE presentation only. No paid bodies/deaths or economy acceptance.
local M={Option='prototype_corpse_presentation_fixture',Rows={
 {actor='imp_scout',feature='40k_scout_corpse',pilot='prototype_scout_remains_pilot'},
 {actor='imp_kasrkin',feature='40k_kasrkin_corpse',pilot='prototype_guard_kasrkin_remains_pilot'},
 {actor='imp_ogryn',feature='40k_ogryn_corpse',pilot='prototype_ogryn_remains_pilot'}}}
local function on(v)return v==true or v==1 or v=='1'end
local function empty(v)return type(v)=='table'and next(v)==nil end
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
function M.Enabled(o)return type(o)=='table'and on(o[M.Option])end
function M.Admit(o,F)
 assert(M.Enabled(o)and o.prototype_diagnostic=='normal'and tonumber(o.prototype_test_speed or 1)==1,'Explicit normal-speed presentation only')
 assert(on(o.prototype_development_playtest)and on(o.prototype_source_progression),'Development source progression required')
 local result={};for i,r in ipairs(M.Rows)do
  assert(on(o[r.pilot]),'Required closed source pilot missing: '..r.actor)
  local found;for id,d in pairs(F)do if d.name==r.feature then
   assert(not found,'Duplicate compiled FeatureDef');local cp=d.customParams or{}
   assert(cp.parent_actor==r.actor and on(cp.prototype40k_tactical_remains),'Genuine compiled source parent required')
   assert(d.modelname==r.feature..'.glb' or d.modelname=='objects3d/'..r.feature..'.glb','Exact compiled private model required')
   assert(d.metal==0 and d.energy==0 and d.resurrectable==0 and d.blocking==false,'Zero-currency nonblocking source definition required')
   found=id
  end end;assert(found,'Missing actual compiled FeatureDef '..r.feature);result[i]={id=found,row=r}
 end;return result
end
function M.New(S,F,rows,mapX,mapZ)
 assert(finite(mapX)and finite(mapZ)and mapX>=1600 and mapZ>=1600,'Bounded map required')
 local R={owned={},done=false};local team=S.GetGaiaTeamID()
 local function check(row)
  assert(not row.retired,'Created feature retired');assert(S.GetFeatureDefID(row.fid)==row.id and S.GetFeatureTeam(row.fid)==team,'Created feature identity changed')
  local x,y,z=S.GetFeaturePosition(row.fid);assert(finite(x)and finite(y)and finite(z),'Actual feature position required')
  assert(math.abs(x-row.x)<.02 and math.abs(z-row.z)<.02 and math.abs(y-S.GetGroundHeight(x,z))<.02,'Actual feature root grounding changed')
  local m,mm,e,ee=S.GetFeatureResources(row.fid);assert(m==0 and mm==0 and e==0 and ee==0,'Presentation must stay zero currency')
  local radius,height=S.GetFeatureRadius(row.fid),S.GetFeatureHeight(row.fid)
  assert(finite(radius)and radius>0 and radius<=64 and finite(height)and height>0 and height<=64,'Actual bounded model geometry required')
  return x,y,z,radius,height
 end
 function R.Begin()
  local site;for z=600,mapZ-600,256 do for x=600,mapX-600,256 do
   local y=S.GetGroundHeight(x,z);local clear=finite(y)and y>0 and empty(S.GetUnitsInCylinder(x,z,300))and empty(S.GetFeaturesInCylinder(x,z,300))
   for _,dx in ipairs({-160,-80,0,80,160})do for _,dz in ipairs({-64,0,64})do local h=S.GetGroundHeight(x+dx,z+dz);clear=clear and finite(h)and math.abs(h-y)<.02 end end
   if clear then site={x,y,z};break end
  end;if site then break end end;
  -- Exact legacy search stays first. Only the admitted two-Ork pair gets denser sampling.
  if not site and #rows==2 and rows[1].row.actor=='ork_burna'and rows[2].row.actor=='ork_slugga'then
   local count={candidates=0,finite=0,dry=0,units=0,features=0,height=0,heightRows=0}
   local maximum=(math.floor((mapX-1200)/32)+1)*(math.floor((mapZ-1200)/32)+1)
   for z=600,mapZ-600,32 do for x=600,mapX-600,32 do
    count.candidates=count.candidates+1
    local y=S.GetGroundHeight(x,z);local clear=false
    if not finite(y)then count.finite=count.finite+1
    elseif y<=0 then count.dry=count.dry+1
    elseif not empty(S.GetUnitsInCylinder(x,z,300))then count.units=count.units+1
    elseif not empty(S.GetFeaturesInCylinder(x,z,300))then count.features=count.features+1
    else clear=true end
    for _,dx in ipairs({-160,-80,0,80,160})do for _,dz in ipairs({-64,0,64})do
     local h=S.GetGroundHeight(x+dx,z+dz);count.heightRows=count.heightRows+1
     if not finite(h)then count.finite=count.finite+1
     elseif finite(y)and math.abs(h-y)>=.02 then count.height=count.height+1 end
     clear=clear and finite(h)and math.abs(h-y)<.02
    end end
    if clear then site={x,y,z};break end
   end;if site then break end end
   S.Echo('40K CORPSE SITE SEARCH','ork32','candidates',count.candidates,'maximum',maximum,'finite',count.finite,'dry',count.dry,'units',count.units,'features',count.features,'height',count.height,'heightRows',count.heightRows,'nativeAccepted=false')
  end
  assert(site,'Dry clear level sample site unavailable')
  for i,row in ipairs(rows)do
   local x,z=site[1]+(i-2)*160,site[3];local y=S.GetGroundHeight(x,z)
   local fid=S.CreateFeature(row.row.feature,x,y,z,0,team);assert(type(fid)=='number'and fid>=0 and fid%1==0,'Native feature creation refused')
   for _,prior in ipairs(R.owned)do assert(prior.fid~=fid,'Repeated native feature ID')end
   local own={fid=fid,id=row.id,x=x,z=z,actor=row.row.actor};R.owned[#R.owned+1]=own
   check(own) -- Definition is already zero; do not grant/mutate resources.
  end
  return R.owned
 end
 function R.Check(emit)for _,row in ipairs(R.owned)do local x,y,z,r,h=check(row);if emit then S.Echo('40K CORPSE PRESENTATION FEATURE',row.actor,row.fid,row.id,x,y,z,r,h,'root_grounded_only','paid=false','death=false','renderAccepted=false')end end end
 function R.FeatureDestroyed(fid)for _,row in ipairs(R.owned)do if row.fid==fid then row.retired=true end end end
 function R.Cleanup()for _,row in ipairs(R.owned)do
  if not row.retired and S.GetFeatureDefID(row.fid)==row.id and S.GetFeatureTeam(row.fid)==team then row.retired=true;S.DestroyFeature(row.fid)
  else S.Echo('40K CORPSE PRESENTATION CLEANUP_REFUSED',row.fid)end
 end;R.owned={}end
 return R
end
return M
