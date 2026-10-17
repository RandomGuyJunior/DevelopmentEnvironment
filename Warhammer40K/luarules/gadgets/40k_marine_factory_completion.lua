function gadget:GetInfo()
 return {name='40K genuine Marine factory completion',desc='Native owned product evidence for source production drop sequence',author='Local project',layer=60,enabled=true}
end
if not gadgetHandler:IsSyncedCode()then return false end
function gadget:UnitFromFactory(id,def,team,factory,factoryDef)
 local d=UnitDefs[factoryDef];local cp=d and d.customParams or{}
 if not d or not d.isFactory or not cp.source_native_pieces then return end
 if Spring.GetUnitTeam(id)~=team or Spring.GetUnitTeam(factory)~=team then return end
 local hp,_,_,_,built=Spring.GetUnitHealth(id)
 if not hp or hp<=0 or not built or built<1 then return end
 local env=Spring.UnitScript.GetScriptEnv(factory)
 if env and type(env.Recoil40KFactoryProductFinished)=='function'then
  local okay=Spring.UnitScript.CallAsUnit(factory,env.Recoil40KFactoryProductFinished,id)
  if okay~=true then Spring.Echo('40K SOURCE FACTORY completion pose refused',factory,id)end
 end
end
