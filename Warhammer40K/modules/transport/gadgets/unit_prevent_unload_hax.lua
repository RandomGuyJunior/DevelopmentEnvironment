local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Prevent Unload Hax",
		desc = "removes unit velocity on unload (and prevents firing units across the map with 'stored' impulse)",
		author = "Bluestone",
		date = "12/08/2013",
		license = "GNU GPL, v2 or later, horses",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local frameMargin = 10

-- paradropped units (customparams.paratrooper) keep the transport's momentum on unload
local isParatrooper = {}
for udid, ud in pairs(UnitDefs) do
	if ud.customParams.paratrooper then
		isParatrooper[udid] = true
	end
end

local SpSetUnitVelocity = Spring.SetUnitVelocity
local SpGetUnitVelocity = Spring.GetUnitVelocity
local SpGetGroundHeight = Spring.GetGroundHeight
local SpGetUnitPosition = Spring.GetUnitPosition
local SpGetGameFrame = Spring.GetGameFrame
local SpSetUnitPhysics = Spring.SetUnitPhysics
local SpSetUnitDirection = Spring.SetUnitDirection

local unloadedUnits = {}

function gadget:UnitUnloaded(unitID, unitDefID, teamID, transportID)
	if unitID == nil or unitDefID == nil or transportID == nil then
		return
	end
	if isParatrooper[unitDefID] then
		local x, y, z = SpGetUnitVelocity(transportID)
		if x > 10 then
			x = 10
		elseif x < -10 then
			x = -10
		end -- 10 is well above 'normal' air-trans velocity
		if z > 10 then
			z = 10
		elseif z < -10 then
			z = -10
		end
		local bx, by, bz = SpGetUnitPosition(unitID)
		if by - SpGetGroundHeight(bx, bz) < 5 then
			x = 0
			y = 0
			z = 0 --in particular, don't give any velocity if the transport has placed the unit slightly underground (or weirdness...)
		end
		SpSetUnitVelocity(unitID, x, y, z)
	else
		-- prevent unloaded units from sliding across the map
		local px, py, pz = Spring.GetUnitPosition(unitID)
		local dx, dy, dz, rx, ry, rz = Spring.GetUnitDirection(unitID)
		local frame = SpGetGameFrame() + frameMargin
		unloadedUnits[unitID] = {
			-- 40K_GROUND_LANDING_SNAPSHOT: match only the runtime's successful native event.
			transport = transportID,
			px = px,
			py = py,
			pz = pz,
			dx = dx,
			dy = dy,
			dz = dz,
			rx = rx,
			ry = ry,
			rz = rz,
			frame = frame,
		}

		SpSetUnitVelocity(unitID, 0, 0, 0)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	unloadedUnits[unitID] = nil
	if GG and GG.Recoil40KGroundLandings then GG.Recoil40KGroundLandings[unitID]=nil end
end

function gadget:GameFrame(frame)
	-- prevent unloaded units from sliding across the map
	for unitID, data in pairs(unloadedUnits) do
		if data.frame == frame then
			-- reset position
			local px,py,pz=data.px,data.py,data.pz
			local skipReset=false
			local landings=GG and GG.Recoil40KGroundLandings
			local landing=landings and landings[unitID]
			local transportDef=UnitDefs[Spring.GetUnitDefID(data.transport)]
			local approved=landing and landing.frame==frame-frameMargin and landing.transport==data.transport
				and transportDef and not transportDef.canFly and transportDef.customParams
				and tostring(transportDef.customParams.prototype40k)=='1' and transportDef.customParams.animsource=='ork_trukk'
			if approved then
				landings[unitID]=nil
				-- Keep actual ground landing, retaining the native delayed zero-impulse protection.
				if Spring.GetUnitTransporter(unitID)==nil then px,py,pz=SpGetUnitPosition(unitID) else skipReset=true end
			end
			if not skipReset then
				SpSetUnitPhysics(unitID, px, py, pz, 0, 0, 0, 0, 0, 0, 0, 0, 0)
				SpSetUnitDirection(unitID, data.dx, data.dy, data.dz, data.rx, data.ry, data.rz)
			end
			--Spring.GiveOrderToUnit(unitID,CMD.MOVE,{data.px+10*data.dx,data.py,data.pz+10*data.dz},CMD.OPT_SHIFT)
			data = nil
		end
	end
end
