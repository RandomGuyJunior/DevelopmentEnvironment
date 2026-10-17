-- Paid diagnostic construction only; never owns, creates or restores squad bodies.
local M={Version=1}
local rows={
 ork_ard_boy={tier=2,id=21,capacity=8,metal=20,energy=100,work=240,label='Ard8'},
 ork_flash_gitz={tier=3,id=22,capacity=4,metal=60,energy=300,work=720,label='Flash4'},
 ork_kommando={tier=3,id=23,capacity=4,metal=30,energy=150,work=360,label='Kommando4'},
 ork_boy={profile='ork_shoota',tier=2,id=3,capacity=8,metal=12,energy=60,work=120,label='Shoota8'},
 ork_burna={tier=2,id=18,capacity=4,metal=22,energy=110,work=264,label='Burna4'},
 ork_nob={tier=2,id=12,capacity=3,metal=55,energy=275,work=660,label='Nob3'},
 ork_loota={tier=3,id=11,capacity=3,metal=36,energy=180,work=432,label='Loota3'},
 ork_tankbusta={tier=3,id=10,capacity=3,metal=30,energy=150,work=360,label='Tankbusta3'},
 ork_meganob={tier=3,id=13,capacity=3,metal=100,energy=500,work=850,label='Meganob3'},
}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function contains(t,v)for _,x in pairs(t or{})do if x==v then return true end end;return false end
local function definition(D,N,key)local n=N[key];return n and D[n.id]end
local function bill(d)
 assert(d,'actual_route_definition_required')
 local b={metal=d.metalCost,energy=d.energyCost,work=d.buildTime}
 for _,v in pairs(b)do assert(finite(v)and v>0,'finite_positive_actual_bill_required')end
 assert(b.metal and b.energy and b.work,'complete_actual_bill_required')
 return b
end
local function sameBill(a,d)
 return type(a)=='table'and d and finite(a.metal)and finite(a.energy)and finite(a.work)
  and a.metal>0 and a.energy>0 and a.work>0
  and a.metal==d.metalCost and a.energy==d.energyCost and a.work==d.buildTime
end
function M.Tasks(plan)
 local row=rows[plan.actor];assert(row and plan.tier==row.tier,'exact_infantry_tier_required')
 assert(plan.cohorts==1 or plan.cohorts==2,'bounded_paid_cohort_count_required')
 local t={{key='ork_listening_post',owner='commander',role='mex1',metal=true,bill=plan.mexBill},
  {key='ork_generator',owner='commander',role='power1',bill=plan.powerBill},
  {key='ork_generator',owner='commander',role='power2',bill=plan.powerBill},
  {key='ork_listening_post',owner='commander',role='mex2',metal=true,bill=plan.mexBill},
  {key='ork_boyz_hut',owner='commander',role='basicfactory',bill=plan.infantry1Bill},
  {key='corck',owner='basicfactory',role='builder',product=true,bill=plan.builderBill},
  {key='ork_generator',owner='builder',role='power3',bill=plan.powerBill},
  {key='ork_boyz_hut_t2',owner='builder',role='infantry2',bill=plan.infantry2Bill}}
 local owner='infantry2'
 if row.tier==3 then
  t[#t+1]={key='corack',owner='infantry2',role='tier2builder',product=true,bill=plan.tier2BuilderBill}
  t[#t+1]={key='ork_warcamp',owner='tier2builder',role='advancedfactory',bill=plan.advancedBill}
  owner='advancedfactory'
 end
 for i=1,plan.cohorts do t[#t+1]={key=plan.actor,owner=owner,role='cohort'..i,product=true,cohort=true,bill=plan.productBill}end
 return t
end
function M.Plan(D,N,P,actor,cohorts)
 local row=assert(rows[actor],'specified_paid_infantry_profile_required')
 local profile=row.profile or actor
 local p=assert(P and P.profiles and P.profiles[profile],'active_exact_profile_required')
 local body=assert(definition(D,N,p.member),'actual_body_definition_required')
 local full=assert(definition(D,N,p.product),'actual_product_definition_required')
 local plan={actor=actor,profile=profile,id=p.id,capacity=p.capacity,cohorts=cohorts,tier=row.tier,label=row.label,
  builder='corck',builderFactory='ork_boyz_hut',productFactory=row.tier==2 and'ork_boyz_hut_t2'or'ork_warcamp',
  metal=body.metalCost,energy=body.energyCost,work=body.buildTime,productBill=bill(full),
  mexBill=bill(definition(D,N,'ork_listening_post')),powerBill=bill(definition(D,N,'ork_generator')),
  infantry1Bill=bill(definition(D,N,'ork_boyz_hut')),builderBill=bill(definition(D,N,'corck')),
  infantry2Bill=bill(definition(D,N,'ork_boyz_hut_t2'))}
 if row.tier==3 then plan.tier2BuilderBill=bill(definition(D,N,'corack'));plan.advancedBill=bill(definition(D,N,'ork_warcamp'))end
 local ok,why=M.Validate(D,N,P,plan);assert(ok,why)
 return plan
end
function M.Validate(D,N,P,plan)
 if type(plan)~='table'then return false,'typed_exact_recipe_required'end
 local row=rows[plan.actor];local p=P and P.profiles and P.profiles[plan.profile]
 if not row or not p or plan.profile~=(row.profile or plan.actor)or p.product~=plan.actor or p.member~=plan.actor..'_member'
  or p.id~=row.id or p.capacity~=row.capacity or plan.id~=row.id or plan.capacity~=row.capacity
  or plan.tier~=row.tier or plan.label~=row.label or(plan.cohorts~=1 and plan.cohorts~=2)
  or plan.builder~='corck'or plan.builderFactory~='ork_boyz_hut'
  or plan.productFactory~=(row.tier==2 and'ork_boyz_hut_t2'or'ork_warcamp')then return false,'current_exact_recipe_profile_required'end
 local body=definition(D,N,p.member);local full=definition(D,N,p.product)
 if not sameBill({metal=plan.metal,energy=plan.energy,work=plan.work},body)
  or plan.metal~=row.metal or plan.energy~=row.energy or plan.work~=row.work
  or not sameBill(plan.productBill,full)or plan.productBill.metal~=plan.metal*plan.capacity
  or plan.productBill.energy~=plan.energy*plan.capacity or plan.productBill.work~=plan.work*plan.capacity then return false,'exact_full_capacity_product_bill_required'end
 local cp=full.customParams or{}
 if cp.prototype40k_squad_product~=plan.profile or tonumber(cp.prototype40k_squad_capacity)~=plan.capacity then return false,'actual_paid_product_schema_required'end
 local owners={commander='corcom'}
 for _,task in ipairs(M.Tasks(plan))do
  local d=definition(D,N,task.key);local owner=definition(D,N,owners[task.owner])
  if not d or not owner then return false,'actual_route_definition_absent_'..task.key end
  if not sameBill(task.bill,d)then return false,'actual_current_route_bill_required_'..task.key end
  if not contains(owner.buildOptions,d.id)or(task.product and not owner.isFactory)then return false,'current_native_menu_or_factory_required_'..task.key end
  if(task.role=='basicfactory'or task.role=='infantry2'or task.role=='advancedfactory')and not d.isFactory then return false,'actual_infantry_factory_required_'..task.key end
  owners[task.role]=task.key
 end
 return true
end
return M
