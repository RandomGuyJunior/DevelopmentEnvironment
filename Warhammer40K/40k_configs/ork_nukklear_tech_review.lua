-- Exact copied source technology unlock; existing paid runtime owns all payment/save/capture.
local M={Key='ork_source_nukklear_technology'}
local function hash(s)return type(s)=='string'and #s==64 and not s:find('[^0-9a-f]')end
local function copy(t)local o={};for k,v in pairs(t)do o[k]=type(v)=='table'and copy(v)or v end;return o end
function M.Enabled(o)return VFS.Include('40k_configs/ork_primary_paid_review.lua').Enabled(o)end
function M.Extend(V,D,F,o)
 if not M.Enabled(o)then return{enabled=false}end
 local p=F and F.version==1 and F.profile
 if type(p)~='table'or type(p.cost)~='table'or type(p.effects)~='table'or type(p.source_requirements)~='table'or type(p.source_producers)~='table'or p.source~='attrib/research/races/orks/ua_ork_research_tech_nukklear_bomma.lua'or not hash(p.sha256)or not hash(p.source_producer_sha256)or not hash(p.source_waaagh_sha256)or p.cost.metal~=0 or p.cost.energy~=1000 or p.time~=190 or p.native_power_scale~=1 or p.native_implementation~='source_unlock_only_no_stat_modifiers'or #p.effects~=0 or p.source_requirements['requirements.required_1.population_required']~=290 or p.source_requirements['requirements.required_2.research_name']~='research\\races\\orks\\UA_ork_waagh_research.lua' or p.source_requirements['requirements.required_10.structure_name']~='ebps\\races\\orks\\structures\\ork_hq.lua' or p.source_producers[1]~='attrib/ebps/races/orks/structures/ork_bilda_pit.lua'then return nil,'genuine_whole_unlock_profile_missing'end
 if not V.SourceProfiles.ork_source_waaagh or V.SourceProfiles.ork_source_waaagh.sha256~=p.source_waaagh_sha256 or V.SourceBuildings.ork_mek_lab~='ebps/races/orks/structures/ork_bilda_pit.lua'or not V.DefaultBindings.ork_mek_lab then return nil,'actual_waaagh_or_bilda_binding_missing'end
 local producer;for _,d in pairs(D)do if d.name==V.DefaultBindings.ork_mek_lab then producer=d end end
 local cp=producer and producer.customParams or{}
 if not producer or not producer.isBuilder or not producer.buildSpeed or producer.buildSpeed<=0 or cp.source_entity~='attrib/ebps/races/orks/structures/ork_bilda_pit.lua'or not hash(cp.source_model_sha256)or not hash(cp.source_native_glb_sha256)then return nil,'genuine_paid_research_producer_missing'end
 if V.SourceProfiles[M.Key]then return nil,'duplicate_source_technology'end
 V.SourceProfiles[M.Key]=copy(p);V.ResearchProducers[M.Key]='ork_mek_lab'
 V.ResearchConditions[M.Key]={population=290,buildings={'ork_hq'},research={'ork_source_waaagh'}}
 V.SourceBuildings.ork_boy_hut='ebps/races/orks/structures/ork_boy_hut.lua';V.DefaultBindings.ork_boy_hut='ork_boyz_hut'
 V.SourceBuildings.ork_pile_o_guns='ebps/races/orks/structures/ork_pile_o_guns.lua';V.DefaultBindings.ork_pile_o_guns='ork_pile_o_guns'
 V.UnitConditions.ork_mek_lab={buildings={'ork_hq'},any_buildings={'ork_boy_hut','ork_pile_o_guns'}}
 return{enabled=true,applied=true,key=M.Key,source=p.sha256,paid_native_accepted=false}
end
function M.ApplyMenu(D,F,o)
 if not M.Enabled(o)then return{enabled=false}end
 local grot,lab=D.ork_grot,D.ork_mek_lab;local gc=grot and grot.customparams or{};local lc=lab and lab.customparams or{}
 if not F or F.grot_engineer_source_verified~=true or not hash(F.grot_source_sha256)or not grot or not lab or gc.source_entity~='attrib/ebps/races/orks/troops/ork_grot.lua'or lc.source_entity~='attrib/ebps/races/orks/structures/ork_bilda_pit.lua'or not hash(lc.source_model_sha256)or not hash(lc.source_native_glb_sha256)then return nil,'genuine_grot_bilda_menu_missing'end
 local options={};local found=false;for _,key in ipairs(grot.buildoptions or{})do options[#options+1]=key;if key=='ork_mek_lab'then found=true end end
 if not found then return nil,'actual_grot_native_menu_does_not_offer_bilda_pit'end
 -- Preserve current genuine Grot native menu; source building_engineer_ext
 -- supplies role, while original race-wide menu consumer remains qualified.
 return{enabled=true,applied=true,source=F.grot_source_sha256}
end
return M
