-- Visual-only generator presentation. Native resources/research/death unchanged.
-- Offline tiny facts; no startup model geometry, references or source installs.
local M={Version=2}
M.OrkSources={
 ork_generator={recipe='ORK-ENE-1',object='ork_generator.glb',bank='ork_generator',glb='18d8dd6c4c9533de4f85052ddab66838771fc8065cbf8a753ac31a5eb35daac5'},
 ork_generator_t2={recipe='ORK-ENE-2',object='ork_generator_t2.glb',bank='ork_generator_t2',glb='e06edf2e28f8fdceae49819dbe93bb6f03b00411516272f0bd6999c53cbd8023'},
 ork_generator_t3={recipe='ORK-ENE-3',object='ork_generator_t3.glb',bank='ork_generator_t3',glb='9984049a7402f1ebe602ec6a510db0fe6af8d145ebad8e88db72e2ede6aa1554'},
 ork_geothermal={recipe='ORK-GEO-2',object='ork_bigger_generator.glb',bank='ork_bigger_generator',glb='bf13d722a4ddc2af3967be1fbaa5876e3c0dc650a8a65e65ae1fa83a80ac04ba'},
}
M.Sources={};for key,row in pairs(M.OrkSources)do M.Sources[key]=row end
M.Sources.imp_generator={object='imp_generator.glb',bank='imp_generator',glb='331d40367e2ab9f25c419e3c0f6be94c0910917db0aec32a0fb4fcd1c2e94329'}
M.Sources.imp_thermo={object='imp_thermo.glb',bank='imp_thermo',glb='0f433d921548c3af3c6189766df550897f79a1f3ac74481a143d3a37cdffd946',geo=true}
M.Sources.imp_marine_generator={object='imp_generator.glb',bank='imp_generator',glb='331d40367e2ab9f25c419e3c0f6be94c0910917db0aec32a0fb4fcd1c2e94329'}
M.Sources.imp_marine_thermo={object='imp_thermo.glb',bank='imp_thermo',glb='0f433d921548c3af3c6189766df550897f79a1f3ac74481a143d3a37cdffd946',geo=true}
M.Sources.nec_generator={object='nec_generator.glb',bank='nec_generator',glb='a818e9b8f84e2df832a642b3455ffe2c0c1aa21aeb1da664e998c5e95751f719'}
M.Sources.nec_thermo={object='nec_thermo.glb',bank='nec_thermo',glb='17a3370ed69eef3b2891bb4d9e84ae1f360461df4a73baabd7cce60867962458',geo=true}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function sha(v)return type(v)=='string'and #v==64 and v:match('^[0-9a-f]+$')end
function M.Footprint(b,geo)
 if type(b)~='table'or type(b.min)~='table'or type(b.max)~='table'or #b.min~=3 or #b.max~=3 then return nil end
 for i=1,3 do if not finite(b.min[i])or not finite(b.max[i])or b.max[i]<=b.min[i]then return nil end end
 if math.abs(b.min[1]+b.max[1])>.002 or math.abs(b.min[3]+b.max[3])>.002 or math.abs(b.min[2])>.002 then return nil end
 local x,z=math.max(1,math.ceil((b.max[1]-b.min[1])/16)),math.max(1,math.ceil((b.max[3]-b.min[3])/16))
 if geo then x=math.max(2,x+x%2);z=math.max(2,z+z%2)end
 if x>32 or z>32 then return nil end
 local cells={};for row=0,z-1 do for col=0,x-1 do
  cells[#cells+1]=geo and(col==x/2-1 or col==x/2)and(row==z/2-1 or row==z/2)and'g'or'o'
 end end
 return x,z,table.concat(cells)
end
local function prepare(key,d,V,f)
 local row=M.Sources[key];local cp=d.customparams or{}
 if type(f)~='table'then return nil,'generator_scale_facts_pending'end
 if f.mode=='native_class_match'then
  -- Other factions already using an actual matching vanilla model are explicit
  -- no-op admissions, never relabelled as converted Ork generator artwork.
  if f.key~=key or d.objectname~=f.source_object or not sha(f.reference_unit_sha256)or not sha(f.reference_model_sha256)
   or f.actual_native_object~=true then return nil,'native_class_match_identity'end
  return false
 end
 if not row then return nil,'generator_class_mapping_pending'end
 -- Normal T1 predates fixed-tier recipe metadata; exact object/bank/GLB and
 -- cleaned geometry guards still apply. Foreign and other missing recipes refuse.
 local recipeMatches=cp.prototype40k_ork_v13_recipe==row.recipe or(key=='ork_generator'and cp.prototype40k_ork_v13_recipe==nil)
 if f.key~=key or f.recipe~=row.recipe or not recipeMatches or d.objectname~=row.object or cp.animsource~=row.bank
  or f.source_glb_sha256~=row.glb or f.alias~=key..'_scale_r1' or f.object~=f.alias..'.glb' or f.bank~=f.alias
  or not sha(f.generated_glb_sha256)or not sha(f.reference_unit_sha256)or not sha(f.reference_model_sha256)
  or not sha(f.reference_receipt_sha256)or not finite(f.factor)or f.factor<=0 or f.uniform_scale~=true
  or f.economics_changed~=false or f.clocks_changed~=false then return nil,'generator_scale_identity'end
 if key=='ork_generator'and(f.cleaned_perimeter_components~=9 or f.removed_triangles~=82 or f.retained_central_machinery~=true)then return nil,'clean_central_generator_required'end
 local x,z,yard=M.Footprint(f.bounds,key=='ork_geothermal'or row.geo);if not x then return nil,'generator_scale_bounds'end
 local proof=f.native_bind_midpoint_proof;local mid=f.native_bind_midpoint
 if type(proof)~='table'or proof.model_sha256~=f.generated_glb_sha256 or proof.midpoint_overrides_absent~=true
  or proof.native_axes_importer_rotation_cancels~=true or proof.ModelUtilsSHA256~='a8f8ae34c93b91a73ec5009cd011431ae22fc47b611615b24aa5e30698269ccb'
  or type(mid)~='table'or #mid~=3 then return nil,'generator_scale_midpoint'end
 for i=1,3 do if not finite(mid[i])then return nil,'generator_scale_midpoint'end end
 local textures=f.textures or{tex1=f.alias..'_tex1.png',tex2=f.alias..'_tex2.png'}
 for _,p in ipairs({'objects3d/'..f.object,'objects3d/'..f.object..'.lua','scripts/generated/'..f.bank..'_anim.lua',
  'unittextures/'..textures.tex1,'unittextures/'..textures.tex2})do if not V.FileExists(p)then return nil,'missing_'..p end end
 local corpse=d.corpse and d.featuredefs and d.featuredefs[d.corpse]
 if corpse then
  local wreck=f.wreck
  if type(wreck)~='table'or corpse.object~=wreck.source_object or not sha(wreck.generated_glb_sha256)
   or wreck.object~=f.alias..'_scrap.glb' then return nil,'generator_wreck_scale_pending'end
  local wx,wz=M.Footprint(wreck.bounds,false);if not wx then return nil,'generator_wreck_scale_bounds'end
  for _,p in ipairs({'objects3d/'..wreck.object,'objects3d/'..wreck.object..'.lua'})do if not V.FileExists(p)then return nil,'missing_'..p end end
 end
 local extent,offset={},{ };for i=1,3 do
  extent[i]=f.bounds.max[i]-f.bounds.min[i];offset[i]=(f.bounds.max[i]+f.bounds.min[i])/2-mid[i]
 end
 return {x=x,z=z,yard=yard,extent=table.concat(extent,' '),offset=table.concat(offset,' '),corpse=corpse}
end
function M.Apply(defs,V,ready)
 local report={changed={},nativeUnchanged={},pending={}};ready=ready or{}
 for key,f in pairs(ready)do
  local d=defs[key]
  if not d then report.pending[key]='actual_generator_definition_missing'
  else
   local change,why=prepare(key,d,V,f)
   if change==false then report.nativeUnchanged[#report.nativeUnchanged+1]=key
   elseif not change then report.pending[key]=why
   else
    local cp=d.customparams
    d.objectname=f.object;cp.animsource=f.bank
    -- Shared role/pose contracts retain their exact original identities; only
    -- the private alias bank/metadata contains uniformly transformed positions.
    -- Preserve an existing exact completed-pose profile. Adding a profile for
    -- an actor absent from the shared profile table would assert in the roster.
    cp.prototype40k_visual_scale_profile=f.alias;cp.prototype40k_visual_scale_reference=f.reference_unit
    cp.prototype40k_visual_scale_factor=f.factor;cp.source_native_glb_sha256=f.generated_glb_sha256
    cp.building_placement_policy='generator_centred_uniform_scale_r1';cp.building_placement_model=f.generated_glb_sha256
    d.footprintx=change.x;d.footprintz=change.z;d.yardmap=change.yard
    d.collisionvolumetype='Box';d.collisionvolumescales=change.extent;d.collisionvolumeoffsets=change.offset
    d.selectionvolumetype='Box';d.selectionvolumescales=change.extent;d.selectionvolumeoffsets=change.offset
    if change.corpse then
     local w=f.wreck;change.corpse.object=w.object
     change.corpse.footprintx,change.corpse.footprintz=M.Footprint(w.bounds,false)
    end
    -- No resource/cost, research, health, speed, slope, reload, feature payout,
    -- death callback or build-access field is assigned by this presentation pass.
    report.changed[#report.changed+1]=key
   end
  end
 end
 return report
end
return M
