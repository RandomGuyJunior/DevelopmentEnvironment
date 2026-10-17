-- Read-only current native producer/product gate for an ordinary paid witness.
local M={}
function M.Validate(D,N)
 local lord=N.nec_lord;local factory=N.nec_vehicle_factory;local product=N.nec_destroyer
 assert(lord and factory and product,'Necron paid route absent')
 local c,f,p=D[lord.id],D[factory.id],D[product.id];local cp=f.customParams or{}
 assert(tonumber(cp.prototype40k_native_factory_pilot)==1 and cp.prototype40k_native_factory_donor=='wh40k_armvp'
  and cp.prototype40k_native_factory_domain=='vehicle','Necron native pilot required')
 assert(not f.canAttack and #(f.weapons or{})==0 and f.isFactory,'Genuinely unarmed native producer required')
 assert(f.metalCost==590 and f.energyCost==1550 and f.buildTime==5700 and f.buildSpeed==150,'Current Necron native factory bill changed')
 local function has(t,key)for _,v in ipairs(t or{})do if v==key then return true end end;return false end
 assert(has(c.buildOptions,factory.id)and has(f.buildOptions,product.id),'Actual current producer route missing')
 for _,key in ipairs({'metalCost','energyCost','buildTime'})do assert(type(p[key])=='number'and p[key]>0,'Actual paid vehicle bill required')end
 assert(p.metalCost==260 and p.energyCost==1300 and p.buildTime==2400,'Current Necron Destroyer paid bill changed')
 assert(not(p.customParams or{}).prototype40k_squad_product,'Vehicle product must remain individual')
 return{commander=lord.id,factory=factory.id,product=product.id}
end
return M
