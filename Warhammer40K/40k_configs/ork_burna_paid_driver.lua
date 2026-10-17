-- Paid burna fixture leaf; shared diagnostics do not own squad runtime.
local driver=VFS.Include('40k_configs/ork_paid_infantry_driver.lua')
local M={Version=1,Option='prototype_ork_burna_native_fixture'}
function M.Enabled(o)local v=(o or{})[M.Option];return v==true or v==1 or v=='1'end
function M.Tasks(plan)assert(plan and plan.actor=='ork_burna'and plan.cohorts==2,'exact_two_paid_burna_cohorts_required');return driver.Tasks(plan)end
function M.New(S,D,N,P,R,physical,placement,plan,emit)
 if not plan or plan.actor~='ork_burna'or plan.cohorts~=2 then return{result='FAIL exact_two_paid_burna_cohorts_required'}end
 return driver.New(S,D,N,P,R,physical,placement,plan,emit)
end
return M
