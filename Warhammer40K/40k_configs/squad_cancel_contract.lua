-- Observer contract only. Never calls the squad owner or writes engine state.
local C={}
local function finite(x)return type(x)=='number'and x==x and math.abs(x)<math.huge end
local function integer(x,min)return finite(x)and x>=min and x%1==0 end
local function near(a,b)return finite(a)and finite(b)and math.abs(a-b)<=.02 end
local function prices(row,full)
 for _,k in ipairs(full and {'metal','energy','work','fullMetal','fullEnergy','fullWork'}or {'metal','energy','work'})do
  if not finite(row[k])or row[k]<=0 then return false end
 end
 return true
end
local function balances(row,after)
 for _,k in ipairs(after and {'beforeMetal','beforeEnergy','afterMetal','afterEnergy'}or {'beforeMetal','beforeEnergy','storage'})do
  if not finite(row[k])or row[k]<0 then return false end
 end
 return true
end
function C.Partial(row)
 if type(row)~='table'or not finite(row.progress) or row.progress<.10 or row.progress>.35 then return false,'not_partial_paid_progress' end
 if not prices(row,true)or not balances(row,false)or row.storage<row.beforeMetal then return false,'invalid_price_or_storage' end
 if row.finished or row.released or row.members~=0 or row.pending or row.reserved~=0 then return false,'premature_cohort_or_reservation' end
 if not integer(row.tag,1)or not integer(row.definition,1)or not integer(row.command,-2147483648) or row.queueCount~=1 or row.command~=-row.definition then return false,'wrong_native_build_queue' end
 if not near(row.metal,row.fullMetal) or not near(row.energy,row.fullEnergy) or not near(row.work,row.fullWork) then return false,'wrong_full_paid_bill' end
 if row.storage-row.beforeMetal < row.metal*row.progress+.1 then return false,'refund_storage_headroom' end
 return true
end
function C.Cancel(row)
 if type(row)~='table'or not finite(row.progress)or row.progress<.10 or row.progress>.35 or not prices(row,false)or not balances(row,true)then return false,'invalid_cancel_inputs' end
 if not row.destroyed or row.finished or row.released or row.alive or row.queueCount~=0 or row.pending or row.reserved~=0 or row.members~=0 then return false,'cancellation_not_closed' end
 if not near(row.afterMetal-row.beforeMetal,row.metal*row.progress) then return false,'native_metal_refund_mismatch' end
 if not near(row.afterEnergy,row.beforeEnergy) then return false,'energy_refund_or_interference' end
 return true
end
function C.Delivered(row)
 if type(row)~='table'or not integer(row.id,0)or not integer(row.cancelled,0)or not integer(row.team,0)or not integer(row.expectedTeam,0)or type(row.bodies)~='table'then return false,'invalid_delivery_inputs' end
 for _,k in ipairs({'fullMetal','fullEnergy','fullWork'})do if not finite(row[k])or row[k]<=0 then return false,'invalid_full_bill' end end
 if not row or not row.finished or not row.released or not row.sawReservation or row.pending or row.reserved~=0 then return false,'missing_finish_release_or_reservation' end
 if row.id==row.cancelled or row.count~=4 or row.profile~='marine_tactical' or row.team~=row.expectedTeam then return false,'wrong_fixed_paid_cohort' end
 local seen={};for _,b in ipairs(row.bodies or{})do
  if type(b)~='table'or not integer(b.id,0)or not integer(b.team,0)or not prices(b,false)then return false,'invalid_body_inputs' end
  if seen[b.id] or b.id==row.cancelled or not b.finished or not b.alive or b.progress~=1 or b.transport or b.team~=row.expectedTeam then return false,'invalid_real_body' end
  if not near(b.metal,row.fullMetal/4) or not near(b.energy,row.fullEnergy/4) or not near(b.work,row.fullWork/4) then return false,'invalid_body_bill' end
  seen[b.id]=true
 end
 if #row.bodies~=4 then return false,'missing_real_bodies' end
 return true
end
function C.Capacity(count,reserved,maximum)return integer(count,0)and integer(reserved,0)and integer(maximum,0)and count+reserved<=maximum end
function C.Step(part)return finite(part)and part>=0 and part<=1 end
function C.Builder(row)
 if type(row)~='table'or not integer(row.id,0)or not integer(row.product,0)or not integer(row.factory,0)or not integer(row.commander,0)or not integer(row.team,0)or not integer(row.expectedTeam,0)then return false end
 for _,k in ipairs({'definition','expectedFactoryDefinition','expectedCommanderDefinition','producerDefinition'})do if not integer(row[k],1)then return false end end
 if row.product==row.factory or row.product==row.commander or row.factory==row.commander then return false end
 if row.team~=row.expectedTeam or row.callbackTeam~=row.expectedTeam or row.live~=true or row.target~=row.product then return false end
 if row.producerLive~=true or row.producerTeam~=row.expectedTeam or row.producerDefinition~=row.expectedFactoryDefinition or row.producerTarget~=row.product then return false end
 if row.id==row.factory then return row.isFactory==true and row.definition==row.expectedFactoryDefinition end
 return row.id==row.commander and row.definition==row.expectedCommanderDefinition and row.isBuilder==true and row.canAssist==true and finite(row.buildSpeed)and row.buildSpeed>0
end
return C
