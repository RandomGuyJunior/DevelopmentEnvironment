-- Exact genuine smertolet: native aircraft movement owns flight; no source
-- combat/flight clip, polling, orders, resource or independent repair owner.
local rotorA,rotorB,nano=piece('rotor_a','rotor_b','nano')
local cp=UnitDefs[unitDefID].customParams
assert(cp.prototype40k_rotor_a_axis=='y'and cp.prototype40k_rotor_b_axis=='y','exact_disc_aligned_native_axes_required')
local speedA=assert(tonumber(cp.prototype40k_rotor_a_speed));local speedB=assert(tonumber(cp.prototype40k_rotor_b_speed))
assert(speedA>0 and speedB>0,'positive_finite_rotor_rates_required')
function script.Create()
 Spring.SetUnitNanoPieces(unitID,{nano})
 Spin(rotorA,y_axis,speedA,math.abs(speedA)*.5);Spin(rotorB,y_axis,speedB,math.abs(speedB)*.5)
end
function script.QueryNanoPiece()return nano end
function script.QueryBuildInfo()return nano end
function script.StartBuilding(heading,pitch)SetUnitValue(COB.INBUILDSTANCE,1)end
function script.StopBuilding()SetUnitValue(COB.INBUILDSTANCE,0)end
function script.Killed()
 StopSpin(rotorA,y_axis);StopSpin(rotorB,y_axis)
 return 1 -- Native selects existing dead feature once; no second payout.
end
