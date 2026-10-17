-- Small, ordinary LUS root animation. Native aircraft physics, unit orders,
-- targeting and damage remain unchanged. Every visible part, actual aim/muzzle
-- piece and exhaust marker is a descendant of this identity-bind root.
local M={Version=2,amplitude=1.5,period=6,sampleSeconds=.1,entranceSeconds=1.5,
 maxAnimationSpeed=3.2,returnSpeed=1.5,signal=2^27,
 entrySpeed=.2,exitSpeed=.35,settleSeconds=.3}
local S=Spring
local US=assert(S.UnitScript,'Native unit-script animation API required')
assert(US.GetPieceTranslation,'Native actual root translation required')
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end

function M.IsIdle(id,holding)
 if not S.ValidUnitID(id)then return false,'invalid-unit' end
 if S.GetUnitIsDead(id)then return false,'dead' end
 if S.GetUnitIsStunned(id)then return false,'stunned' end
 if not S.GetUnitIsActive(id)then return false,'inactive' end
 local _,_,_,_,built=S.GetUnitHealth(id)
 if not finite(built)or built<1 then return false,'unfinished' end
 local move=S.GetUnitMoveTypeData(id)
 if not move or move.name~='gunship'then return false,'native-state-unavailable' end
 if move.aircraftState~='hovering'and move.aircraftState~='flying'then
  return false,'native-'..tostring(move.aircraftState)
 end
 local command=S.GetUnitCurrentCommand(id)
 -- Native stationary combat can still be FLYING with an ATTACK(20) queued.
 -- A move/patrol/fight/guard command never enables this idle presentation.
 if command~=nil and command~=0 and command~=20 then return false,'command-'..tostring(command) end
 local x,y,z=S.GetUnitVelocity(id)
 if not(finite(x)and finite(y)and finite(z))then return false,'invalid-velocity' end
 local speed=math.sqrt(x*x+y*y+z*z)
 local limit=holding and M.exitSpeed or M.entrySpeed
 if speed>limit then return false,'moving',speed end
 return true,command==20 and'stationary-attack'or'settled-'..move.aircraftState,speed
end

local function context(c)
 -- VFS.Include does NOT inherit the caller's LUS environment. The r94 native
 -- log proves its bare Signal was nil at startup. Explicit caller bindings
 -- also keep unitID/thread ownership correct without modifying environments.
 assert(type(c)=='table'and finite(c.unitID)and c.y_axis==2,'Explicit Gunship LUS context required')
 for _,name in ipairs({'Signal','SetSignalMask','Move','Sleep','StartThread'})do
  assert(type(c[name])=='function','Gunship LUS binding missing: '..name)
 end
 return c
end

local function returnToNeutral(root,c)
 -- Positive speed uses the native interpolated Move animation, never MoveNow.
 c.Move(root,c.y_axis,0,M.returnSpeed)
end

function M.Run(root,c)
 c=context(c);c.SetSignalMask(M.signal)
 local seconds,gain,settled=0,0,0
 local holding=false
 local lastWitnessFrame,lastWitnessGate=-30,nil
 local startupWitnessCount,activeWitnessCount,gateWitnessCount=0,0,0
 while S.ValidUnitID(c.unitID)and not S.GetUnitIsDead(c.unitID)do
  seconds=seconds+M.sampleSeconds
  local candidate,reason,speed=M.IsIdle(c.unitID,holding)
  if candidate then settled=settled+M.sampleSeconds else settled=0 end
  local eligible=candidate and(settled+1e-8>=M.settleSeconds or holding)
  holding=eligible
  -- Keep phase continuous across brief gate changes. Smoothly blend the
  -- amplitude instead of restarting the sine from zero every100 milliseconds.
  gain=math.max(0,math.min(1,gain+(eligible and 1 or-1)*M.sampleSeconds/M.entranceSeconds))
  local envelope=gain*gain*(3-2*gain)
  local target=M.amplitude*envelope*math.sin(seconds*2*math.pi/M.period)
  local _,actual=US.GetPieceTranslation(root)
  if finite(actual)then
   local delta=math.abs(target-actual)
   if delta>1e-8 then
    -- Reach the target over the entire sample interval. Native Move fills
    -- simulation and rendered frames, rather than moving fast then holding.
    c.Move(root,c.y_axis,target,math.min(M.maxAnimationSpeed,delta/M.sampleSeconds))
   end
  else
   reason='invalid-root-translation';gain=0;holding=false;settled=0;candidate=false;eligible=false
   target=0;returnToNeutral(root,c)
  end
  -- Optional existing HUMAN fixture callback; absent in normal play. It is a
  -- caller-bound read-only sink, never a helper-global GG lookup or service.
  local frame=S.GetGameFrame()
  if type(c.Witness)=='function'and frame-lastWitnessFrame>=30 then
   local gate=candidate and not eligible and'settling'or reason
   local active=eligible or gain>0 or(finite(actual)and math.abs(actual)>.05)
   local budget
   -- The first Create callback can precede fixture ownership/installation.
   -- Three bounded startup samples ensure a later running descriptor survives.
   if startupWitnessCount<3 then startupWitnessCount=startupWitnessCount+1;budget='startup'
   elseif active and activeWitnessCount<120 then activeWitnessCount=activeWitnessCount+1;budget='active'
   elseif gate~=lastWitnessGate and gateWitnessCount<16 then gateWitnessCount=gateWitnessCount+1;budget='gate-change' end
   if budget then
    lastWitnessFrame=frame;lastWitnessGate=gate
    c.Witness({frame=frame,eligible=eligible,gate=gate,targetY=target,actualY=actual,
     phaseSeconds=seconds,gain=gain,running=true,speed=speed,budget=budget})
   end
  end
  c.Sleep(M.sampleSeconds*1000)
 end
 returnToNeutral(root,c)
end

function M.Start(root,c)
 c=context(c);c.Signal(M.signal)
 return c.StartThread(M.Run,root,c)
end

function M.Stop(root,c)
 c=context(c);c.Signal(M.signal)
 returnToNeutral(root,c)
end

return M
