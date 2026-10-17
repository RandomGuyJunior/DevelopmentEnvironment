-- Prepared scale contract only: no automatic definition/model modifications.
-- Factors multiply already-converted gameplay geometry, not original source scale.
local M={Version=1,Policy='measured_modest_ground_085_candidate',BaseFactor=.85}
M.Reference={actor='guardsman',coordinate='converted_bind_mesh_Y_up',
 currentBodyHeight=15.631969459122047,targetBodyHeight=13.28717404025374,
 purpose='Modest squad-body reduction relative to the existing 16-unit BAR ground grid; native visual acceptance pending'}
M.Classes={infantry=.85,heavy_infantry=.85,commander=.85,builder=.85,
 vehicle=.85,walker=.85,source_building=.85,
 native_factory=1,air_candidate=1,naval_candidate=1}
M.Exceptions={
 native_factory='Preserve accepted native pad/COB/yard baseline until joint geometry and production scaling is tested',
 air_candidate='Native donor/adaptation dimensions need flight, transport and source-size reconciliation',
 naval_candidate='Native donor/adaptation dimensions need waterline, draught, water movement and source-size reconciliation',
}
function M.Factor(class)
 local value=M.Classes[class];assert(value,'Unknown scale class '..tostring(class));return value
end
function M.Stride(row,factor)
 assert(type(factor)=='number'and factor>0 and factor<=1)
 if not row or not row.contacts or row.contacts<=0 then return nil,'unmeasured_contacts' end
 assert(row.stride>0 and row.rate>0)
 return {stride=row.stride*factor,rate=row.rate,speed=row.stride*factor*row.rate,
  clip=row.clip,contacts=row.contacts,policy='retain_measured_cadence_scale_world_stride'}
end
function M.ActorContract(class)
 local factor=M.Factor(class)
 return {geometry=factor,pieceTranslations=factor,animationTranslations=factor,
  inverseBindTranslations=factor,collisionDimensions=factor,collisionOffsets=factor,
  muzzleOffsets=factor,attachmentOffsets=factor,corpseGeometry=factor,
  animationAngles=1,playback=1,range=1,radar=1,damage=1,cost=1,
  navigation='remeasure_world_envelope_and_round_to_legal_grid',
  transport='account_actual_bodies_and_class_space_not_selection_identity'}
end
return M
