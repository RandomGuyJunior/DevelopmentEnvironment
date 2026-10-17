-- Authored tandem presentation. Native aircraft/builder semantics remain the
-- owner; the single pilot and emitter are model pieces, not extra actors.
local front,rear,nano=piece('rotor_a','rotor_b','nano')
local cp=UnitDefs[unitDefID].customParams
assert(cp.prototype40k_rotor_a_axis=='y'and cp.prototype40k_rotor_b_axis=='y','disc_aligned_axes_required')
local a=assert(tonumber(cp.prototype40k_rotor_a_speed))
local b=assert(tonumber(cp.prototype40k_rotor_b_speed))
assert(a==a and b==b and a>0 and a<math.huge and b<0 and b>-math.huge,'finite_counter_rotating_rates_required')
function script.Create()
 Spring.SetUnitNanoPieces(unitID,{nano})
 Spin(front,y_axis,a,math.abs(a)*.5)
 Spin(rear,y_axis,b,math.abs(b)*.5)
end
function script.QueryNanoPiece()return nano end
function script.QueryBuildInfo()return nano end
function script.StartBuilding(heading,pitch)SetUnitValue(COB.INBUILDSTANCE,1)end
function script.StopBuilding()SetUnitValue(COB.INBUILDSTANCE,0)end
function script.Killed()
 StopSpin(front,y_axis);StopSpin(rear,y_axis)
 return 1 -- Select unchanged native dead feature once; no scripted payout.
end
