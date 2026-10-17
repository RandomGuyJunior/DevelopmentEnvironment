-- Typed optional two-Ork presentation; unchanged elite module stays the default.
local Base=VFS.Include('40k_configs/corpse_native_presentation.lua')
local M={Option=Base.Option,Selector='prototype_corpse_presentation_actors',New=Base.New}
local Rows={
 {actor='ork_burna',feature='40k_burna_corpse',pilot='prototype_burna_remains_pilot',squad='prototype_ork_burna_squad'},
 {actor='ork_slugga',feature='40k_slugga_corpse',pilot='prototype_slugga_remains_pilot',squad='prototype_ork_slugga_squad'}}
local function on(v)return v==true or v==1 or v=='1'end
local function selected(o)
 local value=o[M.Selector];if value==nil or value==''then return false end
 assert(type(value)=='string'and value=='ork','Exact typed ork presentation selector required')
 return true
end
function M.Enabled(o)
 if not Base.Enabled(o)then assert(type(o)~='table'or o[M.Selector]==nil or o[M.Selector]=='','Inactive presentation selector must be empty');return false end
 selected(o);return true
end
function M.Admit(o,F)
 if not selected(o)then return Base.Admit(o,F)end
 assert(Base.Enabled(o)and o.prototype_diagnostic=='normal'and tonumber(o.prototype_test_speed or 1)==1,'Explicit normal-speed presentation only')
 assert(on(o.prototype_development_playtest)and on(o.prototype_source_progression),'Development source progression required')
 assert(not on(o.prototype_scale085_pilot),'Unpaired Ork corpse scale refused')
 local result={};for i,r in ipairs(Rows)do
  assert(on(o[r.pilot])and on(o[r.squad]),'Required closed paid Ork pilot missing: '..r.actor)
  local found;for id,d in pairs(F)do if d.name==r.feature then
   assert(not found,'Duplicate compiled FeatureDef');local cp=d.customParams or{}
   assert(cp.parent_actor==r.actor and on(cp.prototype40k_tactical_remains),'Genuine compiled source parent required')
   assert(d.modelname==r.feature..'.glb'or d.modelname=='objects3d/'..r.feature..'.glb','Exact compiled private model required')
   assert(d.metal==0 and d.energy==0 and d.resurrectable==0 and d.blocking==false and d.reclaimable==true,'Zero-currency nonblocking reclaimable source definition required')
   found=id
  end end;assert(found,'Missing actual compiled FeatureDef '..r.feature);result[i]={id=found,row=r}
 end;return result
end
return M
