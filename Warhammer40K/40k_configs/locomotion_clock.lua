-- Locomotion-only clock. No shared simulation, fire, build or ability clocks.
local M={}
local function finite(v)return type(v)=='number'and v==v and v<math.huge and v>-math.huge end
function M.Step(phase,travelPerSecond,sourceStrideSpeed,duration,dt)
 if not(finite(phase)and finite(travelPerSecond)and finite(sourceStrideSpeed)and finite(duration)and finite(dt))then return nil,'nonfinite'end
 if phase<0 or travelPerSecond<0 or sourceStrideSpeed<=0 or duration<=0 or dt<0 then return nil,'invalid'end
 local rate=travelPerSecond/sourceStrideSpeed
 return(phase+rate*dt)%duration,rate
end
function M.MatchSpeed(sourceStrideSpeed,playback)
 if not(finite(sourceStrideSpeed)and finite(playback))or sourceStrideSpeed<=0 or playback<=0 then return nil,'invalid'end
 return sourceStrideSpeed*playback
end
return M
