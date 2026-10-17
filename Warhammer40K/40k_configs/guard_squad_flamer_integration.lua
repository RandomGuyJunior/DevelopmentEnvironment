-- One scoped default-off Guard role selector; existing generic role owner unchanged.
local M={Option='prototype_guard_squad_flamer',Source='imp_guardsman_flamer',Corpse='40k_guardsman_flamer_corpse'}
local function yes(v)return v==true or v==1 or v=='1'end
function M.Enabled(options)return yes((options or{})[M.Option])end
function M.Profiles(base,options,sourceEnabled,role)
 if not M.Enabled(options)then return base end
 assert(sourceEnabled==true,'Guard flamer candidate requires ordinary source progression')
 assert(not yes((options or{}).prototype_scale085_pilot),'Unpaired Guard flamer scale085 candidate refused')
 return role.Configure(base)
end
function M.Prepare(defs,V,base,options,sourceEnabled,role)
 local profiles=M.Profiles(base,options,sourceEnabled,role)
 if not M.Enabled(options)then return{enabled=false,profiles=base}end
 assert(not defs[M.Source],'Guard flamer source definition already exists')
 local definition=role.SourceDefinition(assert(defs.imp_guardsman))
 local view=setmetatable({[M.Source]=definition},{__index=defs})
 local report=role.Preflight(view,V)
 assert(V.FileExists('objects3d/'..M.Corpse..'.glb'),'Same-weapon genuine flamer remains required')
 return{enabled=true,profiles=profiles,definition=definition,report=report,source=M.Source,corpse=M.Corpse,nativeAccepted=false}
end
return M
