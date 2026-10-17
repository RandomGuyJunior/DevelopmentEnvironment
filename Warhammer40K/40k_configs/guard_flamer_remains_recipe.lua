-- Private candidate registration only; coordinator must explicitly enable it.
-- Uses the existing native one-entitlement corpse owner, never another payout.
local M={Actor='guardsman_flamer',Feature='40k_guardsman_flamer_corpse',GeometryFactor=1,DefaultEnabled=false,
 SourceClip='die_normal_1',PaidCost={metal=18,energy=90,work=220}}
function M.Register(owner,enabled)
 if enabled~=true then return nil end
 assert(owner.Fraction==.25 and type(owner.Definition)=='function','Existing authoritative native corpse owner required')
 local row=owner.Actors[M.Actor]
 assert(not row or(row.feature==M.Feature and row.name=='Guardsman flamer'),'Conflicting remains registration')
 owner.Actors[M.Actor]={feature=M.Feature,name='Guardsman flamer'}
 return owner.Definition(M.Feature..'.glb',M.Actor)
end
return M
