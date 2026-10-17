-- Existing stable A2 constructor: presentation-only, normal acceptance gate.
local M={Version=1,Key='ork_big_mek_kopta',Script='40k_ork_tandem_smertolet_builder.lua'}
local function clone(v)if type(v)~='table'then return v end;local t={};for k,x in pairs(v)do t[k]=clone(x)end;return t end
local function on(v)return v==true or v==1 or v=='1'end
local function positive(v)return type(v)=='number'and v==v and v>0 and v<math.huge end
function M.ReviewEnabled(o)
 o=o or{}
 if not on(o.prototype_ork_big_mek_kopta_source_review)then return false end
 assert(on(o.prototype_development_playtest)and on(o.prototype_source_progression)and o.prototype_diagnostic=='normal'and tonumber(o.prototype_test_speed)==1,'isolated_normal_tandem_review_required')
 return true
end
function M.Closed(f,V)
 if type(f)~='table'or f.schema~=1 or f.key~=M.Key or f.recipe~='ORK-BLD-A2'or f.sourceAsset~='MOW-01'
  or f.sourceLabel~='smertolet / authored tandem adaptation'or f.authoredTandem~=true
  or f.objectname~='40k/ork_big_mek_kopta.glb'or f.script~=M.Script
  or f.sourceBodyStretched~=false or f.sourcePilotCount~=1 or f.sourceTailRotorRetained~=false
  or not positive(f.discClearance)or f.rotorA~=30 or f.rotorB~=-30
  or type(f.modelSHA256)~='string'or#f.modelSHA256~=64 or not f.pieces or not f.pieces.nano
  or not f.pieces.rotor_a or not f.pieces.rotor_b or not f.rotors
  or not f.rotors.rotor_a or not f.rotors.rotor_b
  or f.rotors.rotor_a.axis~='y'or f.rotors.rotor_b.axis~='y'
  or f.salvageOwner~='unchanged_native_feature_chain'then return false end
 for _,field in ipairs({'collisionvolumescales','collisionvolumeoffsets','selectionvolumescales','selectionvolumeoffsets'})do if type(f[field])~='string'then return false end end
 for _,path in ipairs({'objects3d/'..f.objectname,'objects3d/'..f.objectname..'.lua','unittextures/ork_big_mek_kopta_tex1.png','unittextures/ork_big_mek_kopta_tex2.png','scripts/'..M.Script})do if not V or not V.FileExists or not V.FileExists(path)then return false end end
 return true
end
function M.Prepare(base,V,f,review)
 if not M.Closed(f,V)then return nil,'authored_tandem_closure_pending'end
 local cp=base and base.customparams or{}
 if not base or base.builder~=true or base.canfly~=true or base.canmove~=true
  or cp.prototype40k_native_donor~='coraca'or cp.prototype40k_constructor_domain~='air'
  or tonumber(cp.prototype40k_constructor_tier)~=2 or cp.prototype40k_temporary_constructor_appearance~=1
  or base.metalcost~=360 or base.energycost~=11000 or base.buildtime~=22000 or base.workertime~=130
  then return nil,'unchanged_native_A2_constructor_required'end
 if base.corpse~='dead'or type(base.featuredefs)~='table'then return nil,'native_salvage_chain_required'end
 for _,name in ipairs({'dead','dead_medium','dead_severe'})do local r=base.featuredefs[name]
  if not r or r.metal~=90 or r.energy~=2750 or r.reclaimable~=true or r.indestructible~=true or r.blocking~=false then return nil,'unchanged_A2_native_salvage_required'end
 end
 if not review and f.nativeAccepted~=true then return nil,'native_tandem_presentation_acceptance_pending'end
 if review and f.nativeAccepted~=false then return nil,'honest_unaccepted_review_required'end
 local d=clone(base);local c=d.customparams
 d.objectname=f.objectname;d.script=M.Script
 d.collisionvolumetype='Box';d.collisionvolumescales=f.collisionvolumescales;d.collisionvolumeoffsets=f.collisionvolumeoffsets
 d.selectionvolumetype='Box';d.selectionvolumescales=f.selectionvolumescales;d.selectionvolumeoffsets=f.selectionvolumeoffsets
 d.usepiececollisionvolumes=false;d.usepieceselectionvolumes=false
 c.normaltex=nil;c.animsource=nil;c.prototype40k_shared_visual_source=nil;c.prototype40k_theme_pending=nil
 c.prototype40k_theme='mow01_authored_tandem_smertolet';c.prototype40k_source_clip_claim=0
 c.prototype40k_rotor_a_axis='y';c.prototype40k_rotor_b_axis='y';c.prototype40k_rotor_a_speed=f.rotorA;c.prototype40k_rotor_b_speed=f.rotorB
 c.prototype40k_source_presentation_model_sha256=f.modelSHA256;c.prototype40k_source_presentation_review=review and 1 or 0
 c.prototype40k_temporary_constructor_appearance=nil
 c.prototype40k_constructor_appearance_note='Authored tandem smertolet; native T2 constructor behaviour'..(review and'; isolated presentation/flight/build review pending'or'')
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
