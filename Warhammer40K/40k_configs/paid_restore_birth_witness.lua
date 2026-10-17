-- Read-only synchronous transaction witness. No resource/order/body mutation.
local M={}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function near(a,b)return finite(a)and finite(b)and math.abs(a-b)<.001 end
function M.Observe(S,R,D,N,CMD,commander,seed,slot,role,c,id,def,team,builder)
 local s=R.squads[seed];local j=R.repair[seed];local expected=N[role];local cd=D[S.GetUnitDefID(commander)]
 local queue=S.GetUnitCommands(commander,-1)or{};local head=queue[1]
 local checks={creating=R.creating==true,squad=s~=nil,job=j~=nil,native_builder_nil=builder==nil,
  owner=s and team==s.team and S.GetUnitTeam(id)==s.team or false,
  missing_slot=s and s.slots[slot]==nil or false,generation=s and finite(s.generations[slot])and s.generations[slot]>=1 and s.generations[slot]==math.floor(s.generations[slot])or false,definition=expected and def==expected.id and S.GetUnitDefID(id)==def or false,
  paid_slot=j and j.slot==slot or false,paid_role=j and j.def==role or false,
  full_work=j and near(j.work,c.work)or false,full_metal=j and near(j.metal,c.metal)or false,full_energy=j and near(j.energy,c.energy)or false,
  real_paying_builder=cd and cd.isBuilder==true and cd.isFactory~=true and(cd.buildSpeed or 0)>0 and S.GetUnitTeam(commander)==team or false,
  repair_order=head and head.id==CMD and head.params and head.params[1]==seed or false}
 local passed=true;for _,v in pairs(checks)do if v~=true then passed=false end end
 local proof=passed and{id=id,def=def,team=team,slot=slot,frame=S.GetGameFrame(),work=j.work,metal=j.metal,energy=j.energy,
  priorGeneration=s.generations[slot],commander=commander,nativeBuilder=nil}or nil
 return proof,checks
end
function M.Bound(proof,S,s,slot,role,N,c)
 return type(proof)=='table'and finite(proof.priorGeneration)and proof.priorGeneration>=1 and proof.priorGeneration==math.floor(proof.priorGeneration)and s and proof.slot==slot and proof.def==N[role].id and proof.team==s.team and s.slots[slot]==proof.id and S.GetUnitDefID(proof.id)==N[role].id and S.GetUnitTeam(proof.id)==s.team
  and s.generations[slot]==proof.priorGeneration+1 and near(proof.work,c.work)and near(proof.metal,c.metal)and near(proof.energy,c.energy)
end
return M
