-- Presentation only on the already integrated stable native constructor.
-- Ordinary promotion requires exact root-owned native acceptance; review is
-- explicit isolated candidate scope, never an alternate production graph.
local M={Version=1,Key='ork_mek_kopta',Script='40k_ork_smertolet_builder.lua'}
function M.ReviewEnabled(options)
 local function on(v)return v==true or v==1 or v=='1'end
 options=options or{}
 if not on(options.prototype_ork_mek_kopta_source_review)then return false end
 assert(on(options.prototype_development_playtest)and on(options.prototype_source_progression)and options.prototype_diagnostic=='normal'and tonumber(options.prototype_test_speed)==1,'isolated_normal_source_review_required')
 return true
end
local function copy(v)if type(v)~='table'then return v end;local t={};for k,x in pairs(v)do t[k]=copy(x)end;return t end
local function positive(v)return type(v)=='number'and v==v and v>0 and v<math.huge end
function M.Closed(f,V)
 if type(f)~='table'or f.schema~=1 or f.key~=M.Key or f.recipe~='ORK-BLD-A1'or f.sourceAsset~='MOW-01'or f.sourceLabel~='smertolet'
  or f.objectname~='40k/ork_mek_kopta.glb'or f.script~=M.Script or f.triangles~=16121 or f.originalScale~=.5
  or type(f.modelSHA256)~='string'or#f.modelSHA256~=64 or not f.nativeMidpoint or not f.bodyBounds or not f.selectionSweepBounds
  or not f.pieces or not f.pieces.nano or not f.pieces.rotor_a or not f.pieces.rotor_b or not positive(f.rotorA)or not positive(f.rotorB)
  or not f.rotors or not f.rotors.rotor_a or not f.rotors.rotor_b or f.rotors.rotor_a.axis~='y'or f.rotors.rotor_b.axis~='y'or f.salvageOwner~='unchanged_native_feature_chain'then return false end
 for _,field in ipairs({'collisionvolumescales','collisionvolumeoffsets','selectionvolumescales','selectionvolumeoffsets'})do if type(f[field])~='string'then return false end end
 for _,path in ipairs({'objects3d/'..f.objectname,'objects3d/'..f.objectname..'.lua','unittextures/ork_mek_kopta_tex1.png','unittextures/ork_mek_kopta_tex2.png','scripts/'..M.Script})do if not V or not V.FileExists or not V.FileExists(path)then return false end end
 return true
end
function M.Prepare(base,V,f,reviewOnly)
 if not M.Closed(f,V)then return nil,'genuine_smertolet_closure_pending'end
 local cp=base and base.customparams or{}
 if not base or base.builder~=true or base.canfly~=true or base.canmove~=true or cp.prototype40k_native_donor~='corca'
  or cp.prototype40k_constructor_domain~='air'or tonumber(cp.prototype40k_constructor_tier)~=1
  or base.metalcost~=115 or base.energycost~=2200 or base.buildtime~=5200 or base.workertime~=55
  or not positive(base.builddistance)or cp.prototype40k_temporary_constructor_appearance~=1 then return nil,'current_native_singleton_constructor_required'end
 if base.corpse~='dead'or type(base.featuredefs)~='table'then return nil,'existing_native_salvage_chain_required'end
 for _,key in ipairs({'dead','dead_medium','dead_severe'})do local row=base.featuredefs[key]
  if not row or row.metal~=28.75 or row.energy~=550 or row.reclaimable~=true or row.indestructible~=true or row.blocking~=false then return nil,'unchanged_quarter_cost_native_salvage_required'end
 end
 if not reviewOnly and f.nativeAccepted~=true then return nil,'native_rotor_flight_build_acceptance_pending'end
 if reviewOnly and f.nativeAccepted~=false then return nil,'honest_unaccepted_review_required'end
 local d=copy(base);local c=d.customparams
 d.objectname=f.objectname;d.script=M.Script
 d.collisionvolumetype='Box';d.collisionvolumescales=f.collisionvolumescales;d.collisionvolumeoffsets=f.collisionvolumeoffsets
 d.selectionvolumetype='Box';d.selectionvolumescales=f.selectionvolumescales;d.selectionvolumeoffsets=f.selectionvolumeoffsets
 d.usepiececollisionvolumes=false;d.usepieceselectionvolumes=false
 -- Footprint, flight physics, costs, power, health/mass, transport, native
 -- repair/reclaim/assist capabilities, buildOptions and whole feature chain
 -- remain byte-for-byte equivalent after the cloned presentation edits.
 c.normaltex=nil;c.animsource=nil;c.prototype40k_shared_visual_source=nil;c.prototype40k_theme_pending=nil
 c.prototype40k_theme='mow01_genuine_smertolet_source';c.prototype40k_source_clip_claim=0
 c.prototype40k_rotor_a_axis='y';c.prototype40k_rotor_b_axis='y';c.prototype40k_rotor_a_speed=f.rotorA;c.prototype40k_rotor_b_speed=f.rotorB
 c.prototype40k_source_presentation_model_sha256=f.modelSHA256;c.prototype40k_source_presentation_review=reviewOnly and 1 or 0
 c.prototype40k_temporary_constructor_appearance=nil
 c.prototype40k_constructor_appearance_note='Genuine smertolet source model; native constructor behaviour'..(reviewOnly and'; isolated visual/flight/build review pending'or'')
 return d
end
function M.Apply(defs,V,f,scope)
 local review=scope=='isolated_root_native_presentation_review'
 if scope~=nil and not review then return{definitions={},pending={'invalid_review_scope'},nativeAccepted=false}end
 local d,why=M.Prepare(defs[M.Key],V,f,review)
 if not d then return{definitions={},pending={why},nativeAccepted=false}end
 defs[M.Key]=d;return{definitions={M.Key},pending={},nativeAccepted=f.nativeAccepted==true,reviewOnly=review}
end
return M
