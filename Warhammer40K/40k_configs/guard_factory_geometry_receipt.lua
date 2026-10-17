-- Optional read-only proof-time geometry data; no production or acceptance owner.
local M={Version=1}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function integer(v)return finite(v)and v>=0 and v<=2147483647 and v%1==0 end
local function fullCV(S,id)
 local cv={S.GetUnitCollisionVolumeData(id)};assert(#cv==10,'Complete actual native collision metadata required')
 for i=1,6 do assert(finite(cv[i]),'Finite native scale/offset required')end
 assert(cv[1]>0 and cv[2]>0 and cv[3]>0 and integer(cv[7])and cv[7]<=3 and integer(cv[8])and cv[8]<=1 and integer(cv[9])and cv[9]<=2 and type(cv[10])=='boolean','Actual native collision enums/IgnoreHits boolean required')
 return cv
end
function M.New(S,D,N,physical,nativeFinished,emit)
 assert(type(physical)=='table'and type(physical.Outside)=='function'and type(nativeFinished)=='table'and type(emit)=='function')
 local A={};local seen={};local bodyOwner={}
 function A.Capture(mode,parent,row,members,capacity,team,frame)
  assert((mode=='infantry'and capacity==8)or(mode=='vehicle'and capacity==1),'Actual Guard geometry roles only')
  assert(integer(frame)and integer(team)and integer(parent)and type(row)=='table'and integer(row.id)and integer(row.ordinal)and integer(row.finished)and integer(row.released)and frame>=row.released+30,'Real finished/released proof required')
  assert(type(S.GetGameFrame)=='function'and S.GetGameFrame()==frame,'Actual current native proof frame required')
  assert(row.finished<=frame and((mode=='infantry'and(row.ordinal==1 or row.ordinal==2))or(mode=='vehicle'and row.ordinal==1)),'Current exact two-cohort/one-vehicle contract')
  local parentDefinition=mode=='infantry'and N.imp_barracks.id or N.imp_tank_factory.id
  assert(integer(parentDefinition)and parentDefinition>0,'Typed actual native parent definition required')
  assert(S.ValidUnitID(parent)==true and S.GetUnitIsDead(parent)==false and S.GetUnitTeam(parent)==team and S.GetUnitDefID(parent)==parentDefinition,'Actual native Guard parent role/ownership required')
  local parentCV=fullCV(S,parent)
  local parentFacing=S.GetUnitBuildFacing(parent);assert(integer(parentFacing)and parentFacing<=3,'Known raw native parent yard facing required')
  local key=mode..':'..row.id
  assert(type(members)=='table'and #members==capacity,'Fixed actual proof cohort required')
  local length=0;for k in pairs(members)do assert(integer(k)and k>=1 and k<=capacity,'Dense native cohort array');length=length+1 end;assert(length==capacity,'All paid native body slots required')
  local sampled={};local unique={}
  for _,id in ipairs(members)do
   assert(integer(id)and not unique[id]and id~=parent,'Distinct native body');unique[id]=true
   assert(not bodyOwner[id]or bodyOwner[id]==key,'No shared body across paid products')
   assert(S.ValidUnitID(id)==true and S.GetUnitIsDead(id)==false and S.GetUnitTeam(id)==team,'Living owned native body')
   local def=S.GetUnitDefID(id);local finished=nativeFinished[id];local hp,_,_,_,built=S.GetUnitHealth(id)
   assert(integer(def)and def>0,'Typed actual native body definition required')
   assert(finished and finished.def==def and finished.team==team and integer(finished.frame)and finished.frame<=row.released and finite(hp)and hp>0 and built==1,'Actual complete native callback before release/body required')
   if id==row.id then assert(finished.frame==row.finished,'Original exact native finish callback required')end
   if mode=='vehicle'then assert(def==N.imp_sentinel.id and id==row.id,'Actual paid Sentinel required')else assert(row.fixedBodies and row.fixedBodies[id]==def,'Immutable paid infantry body definition required')end
   local clear,w=physical.Outside(S,D,parent,id);assert(clear==true and w and w.parent and w.child,'Actual collision and yard union must be clear')
   local bodyCV=fullCV(S,id)
   local bodyFacing=S.GetUnitBuildFacing(id);assert(integer(bodyFacing)and bodyFacing<=3 and parentFacing==w.parent.facing and bodyFacing==w.child.facing,'Known same-frame raw native yard facing required')
   for i=1,6 do assert(parentCV[i]==w.parent.collider[i]and bodyCV[i]==w.child.collider[i],'Stable same-frame native geometry required')end
   sampled[#sampled+1]={id=id,def=def,finished=finished.frame,w=w,parentCV=parentCV,bodyCV=bodyCV}
  end
  assert(unique[row.id]and #sampled==capacity,'Actual original product belongs to full cohort')
  local output={}
  for _,r in ipairs(sampled)do
   local p,c=r.w.parent,r.w.child;local fields={'schema=1','mode='..mode,'ordinal='..row.ordinal,'product='..row.id,'parent='..parent,'parent_def='..parentDefinition,'body='..r.id,'body_def='..r.def,'team='..team,'frame='..frame,'native_finished='..r.finished,'native_released='..row.released}
   for label,e in pairs({parent=p,body=c})do
    for _,k in ipairs({'minX','maxX','minZ','maxZ'})do assert(finite(e[k]));fields[#fields+1]=label..'_'..k..'='..e[k]end
    assert(e.minX<e.maxX and e.minZ<e.maxZ)
    for i=1,6 do assert(finite(e.collider[i]));fields[#fields+1]=label..'_collider'..i..'='..e.collider[i]end
    local cv=label=='parent'and r.parentCV or r.bodyCV
    for i=7,10 do fields[#fields+1]=label..'_collider'..i..'='..tostring(cv[i])end
    for i=1,3 do assert(finite(e.midpoint[i]));fields[#fields+1]=label..'_midpoint'..i..'='..e.midpoint[i]end
    for i=1,2 do assert(finite(e.yard[i])and e.yard[i]>0);fields[#fields+1]=label..'_yard'..i..'='..e.yard[i]end
    assert(integer(e.facing)and e.facing<=3);fields[#fields+1]=label..'_facing='..e.facing
   end
   fields[#fields+1]='native_collision_yard_clear=true';fields[#fields+1]='paid_debit_accepted=false';fields[#fields+1]='rendered_door_sweep_accepted=false';output[#output+1]=table.concat(fields,' ')
  end
  if not seen[key]then for _,fields in ipairs(output)do emit('GUARD_GEOMETRY_PROOF',fields)end end
  for _,r in ipairs(sampled)do bodyOwner[r.id]=key end
  seen[key]=true;return true
 end
 return A
end
return M
