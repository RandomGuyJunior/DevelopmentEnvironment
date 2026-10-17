function gadget:GetInfo()
    return {name="40K Russ track uniforms", desc="Distance-driven source track atlas UVs", author="Local Recoil Project", layer=1, enabled=true}
end
if gadgetHandler:IsSyncedCode() then return false end
local tracks = {}
local russDefID = UnitDefNames.imp_russ and UnitDefNames.imp_russ.id
local repeatsPerElmo = 13 / 45 -- source 13 repeats/sec, prototype nominal45 elmos/sec
local function forwardVelocity(id)
    local vx, _, vz = Spring.GetUnitVelocity(id)
    local dx, _, dz = Spring.GetUnitDirection(id)
    if not vx or not dx then return 0 end
    local length = math.sqrt(dx*dx + dz*dz)
    if length < 0.001 then return 0 end
    return (vx*dx + vz*dz) / length -- native velocity: elmos/simulation frame
end
function gadget:UnitCreated(id, defID)
    if defID == russDefID then tracks[id] = {phase=0, velocity=0, frame=Spring.GetGameFrame()} end
end
function gadget:UnitDestroyed(id) tracks[id] = nil end
function gadget:Initialize()
    if not russDefID or not gl.SetUnitBufferUniforms then
        Spring.Echo("[40K tracks] native uniform API/unit unavailable; static fallback")
        gadgetHandler:RemoveGadget(self)
        return
    end
    for _, id in ipairs(Spring.GetAllUnits()) do self:UnitCreated(id, Spring.GetUnitDefID(id)) end
end
function gadget:GameFrame(frame)
    for id, state in pairs(tracks) do
        -- Advance through simulation time only; stopping freezes the belt.
        state.phase = (state.phase + state.velocity * (frame-state.frame) * repeatsPerElmo) % 1
        state.velocity = forwardVelocity(id)
        state.frame = frame
    end
end
function gadget:DrawWorld()
    local fraction = Spring.GetFrameTimeOffset()
    local _, _, isPaused = Spring.GetGameSpeed()
    if isPaused then fraction = 0 end
    for id, state in pairs(tracks) do
        local phase = (state.phase + state.velocity * fraction * repeatsPerElmo) % 1
        gl.SetUnitBufferUniforms(id, {phase, phase, 1}, 13)
    end
end
function gadget:Shutdown()
    if gl.SetUnitBufferUniforms then
        for id in pairs(tracks) do
            if Spring.ValidUnitID(id) then gl.SetUnitBufferUniforms(id, {0, 0, 0}, 13) end
        end
    end
end
