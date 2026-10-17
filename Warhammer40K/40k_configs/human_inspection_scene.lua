-- Explicit human preview only. No acceptance, economic grants or normal access.
local M={Option='prototype_human_inspection_scene'}
M.Actors={'ork_morkanaut','ork_warbike_crewed','ork_trukk','ork_gunship','corkorg','ork_dakka_stompa'}
local function yes(v)return v==true or v==1 or v=='1'end
function M.Enabled(o)
 o=o or{};if not yes(o[M.Option])then return false end
 assert(o.prototype_diagnostic=='normal'and yes(o.prototype_source_progression)and yes(o.prototype_development_playtest),'Human preview requires exact normal integrated source context')
 assert(not yes(o.prototype_source_paid_match)and(o.prototype_source_acceptance==nil or o.prototype_source_acceptance==''),'Human preview is not paid or ordinary acceptance')
 assert(yes(o.prototype_stompa_multigun_review)and yes(o.prototype_dakka_reference_review),'Exact existing Dakka multigun/reference pair required')
 assert(yes(o.prototype_wartrukk_transport_pilot)and yes(o.prototype_squad_transport_pilot)and yes(o.prototype_ork_slugga_squad),'Existing real-body full8 transport policy required')
 for k,v in pairs(o)do
  if yes(v)and k~='prototype_source_bounds_capture'and(k:match('_fixture$')or k:match('benchmark')or k:match('probe')or k:match('observer')or k:match('paid_driver')or k=='prototype_burna_flame_combat')then error('Human preview conflicts with automatic diagnostic '..k)end
 end
 assert(tonumber(o.prototype_test_speed or 1)==1,'Human preview uses normal simulation clock')
 return true
end
local function path(v)return tostring(v or''):gsub('\\','/'):lower():gsub('^objects3d/',''):gsub('^scripts/','')end
function M.Validate(D,N)
 local ids={};for _,key in ipairs(M.Actors)do local n=assert(N[key],'Inspection actor missing: '..key);local d=assert(D[n.id],'Inspection native definition missing: '..key)
  assert(d.name==key and d.canMove and not d.isBuilder,'Actual controllable combat actor required: '..key);ids[key]=n.id
 end
 local m=D[ids.ork_morkanaut];assert((m.customParams or{}).source_entity=='evz_morkanaut'and path(m.modelname)=='ork_morkanaut.glb'and path(m.scriptName)=='40k_morkanaut.lua'and #m.weapons==5 and(m.customParams or{}).source_native_kff=='native_plasma_shield_v1','Actual GOH Morkanaut with native KFF required')
 local b=D[ids.ork_warbike_crewed];assert((b.customParams or{}).source_entity=='EVZ_Ork_warbike'and path(b.modelname)=='ork_warbike_crewed.glb'and path(b.scriptName)=='40k_ork_warbike_crewed.lua'and #b.weapons==2,'Actual crewed GOH Warbike required')
 local t=D[ids.ork_trukk];assert(path(t.modelname)=='ork_trukk.glb'and path(t.scriptName)=='40k_wartrukk_squad.lua'and(t.customParams or{}).source_transport_policy=='wartrukk_fixed8_hidden_real_bodies_v1','Actual full8 Wartrukk required')
 local g=D[ids.ork_gunship];assert(g.canFly and path(g.modelname)=='40k/ork_gunship.glb'and path(g.scriptName)=='40k_ork_gunship.lua'and(g.customParams or{}).prototype40k_source_asset=='MOW-02','Actual complete Gunship required')
 local j=D[ids.corkorg];assert(path(j.modelname):match('corkorg%.s3o$')and path(j.scriptName):match('corkorg%.cob$')and not(j.customParams or{}).prototype40k,'Actual original BAR corkorg Juggernaut required')
 local s=D[ids.ork_dakka_stompa];assert(path(s.modelname)=='ork_dakka_stompa_jugref.glb'and path(s.scriptName)=='40k_roster.lua'and(s.customParams or{}).ork_v14_scale_bank=='ork_dakka_stompa_jugref'and math.abs((tonumber((s.customParams or{}).ork_v14_scale_factor)or 0)-.7060140223403837)<.000001,'Actual paired development Dakka reference required')
 return ids
end
-- One atomic preflight before any birth. Ground actors share a flat, empty area.
function M.Site(S,D,ids,Game)
 local offsets={{-560,-360},{-220,-360},{100,-360},{560,-360},{-220,180},{220,180}}
 for _,xf in ipairs({.5,.35,.65})do for _,zf in ipairs({.5,.35,.65})do
  local cx,cz=Game.mapSizeX*xf,Game.mapSizeZ*zf;local ref=S.GetGroundHeight(cx-220,cz+180);local valid=ref and ref>0;local sites={}
  for i,key in ipairs(M.Actors)do
   local x,z=cx+offsets[i][1],cz+offsets[i][2];local y=S.GetGroundHeight(x,z)
   if x<256 or z<256 or x>Game.mapSizeX-256 or z>Game.mapSizeZ-256 or not y or y<0 or math.abs(y-ref)>3 then valid=false end
   if #(S.GetFeaturesInRectangle(x-140,z-140,x+140,z+140)or{})>0 or #(S.GetUnitsInRectangle(x-140,z-140,x+140,z+140)or{})>0 then valid=false end
   if key~='ork_gunship'and not S.TestMoveOrder(ids[key],x,y,z,0,0,0,true,true,false)then valid=false end
   if i>=5 then for _,dx in ipairs({-80,0,80})do for _,dz in ipairs({-80,0,80})do if math.abs(S.GetGroundHeight(x+dx,z+dz)-ref)>3 then valid=false end end end end
   sites[i]={x,y,z}
  end
  if valid then return sites,cx,ref,cz end
 end end
 return nil
end
return M
