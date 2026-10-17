-- Read-only current production contract; no model or donor replacement.
local M={}
function M.Validate(D,N)
 local commander=N.corcom;local factory=N.fortyk_ork_air_factory;local product=N.ork_fighta_bomba
 assert(commander and factory and product,'Current genuine Ork air route absent')
 local c,f,p=D[commander.id],D[factory.id],D[product.id];local cp=f.customParams or{};local pp=p.customParams or{}
 assert(f.isFactory and not f.canFly and cp.prototype40k_native_donor=='corap'
  and tostring(f.scriptName):lower()=='units/corap.cob','Actual native CORAP air producer required')
 assert(f.metalCost==630 and f.energyCost==1100 and f.buildTime==5380 and f.buildSpeed==150,'Current native CORAP paid bill changed')
 local function has(t,id)for _,v in ipairs(t or{})do if v==id then return true end end end
 assert(has(c.buildOptions,factory.id)and has(f.buildOptions,product.id),'Actual current paid menus required')
 assert(p.canFly and pp.animsource=='ork_fighta_bomba'and tonumber(pp.prototype40k_ork_aircraft_domain)==1
  and #(p.weapons or{})==4 and not pp.prototype40k_squad_product,'Genuine individual four-mount Fighta required')
 assert(p.metalCost==140 and p.energyCost==1400 and p.buildTime==70*f.buildSpeed,'Genuine Fighta paid bill changed')
 return{commander=commander.id,factory=factory.id,product=product.id}
end
return M
