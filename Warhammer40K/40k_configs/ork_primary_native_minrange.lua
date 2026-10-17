-- Real supported native target reads; explicit source artillery minimum-range adaptation.
return function(S,unit,weapon,minimum)
 if not minimum or minimum<=0 then return false end
 local x,_,z=S.GetUnitPosition(unit);if not x then return true end
 local kind,_,target=S.GetUnitWeaponTarget(unit,weapon);local tx,tz
 if kind==1 then tx,_,tz=S.GetUnitPosition(target)
 elseif kind==2 and type(target)=='table'then tx,tz=target[1],target[3]
 else return true end
 if type(tx)~='number'or type(tz)~='number'then return true end
 return (tx-x)^2+(tz-z)^2<minimum^2
end
