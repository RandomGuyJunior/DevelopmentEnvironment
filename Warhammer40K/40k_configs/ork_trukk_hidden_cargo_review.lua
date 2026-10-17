-- Native hidden attachment sentinel; source-only candidate, no acceptance grant.
local M={}
function M.Piece(d,source,physicalPiece,options)
 local c=d and(d.customParams or d.customparams)or{}
 options=options or{}
 if options.prototype_diagnostic~='roster'or tostring(options.prototype_transport_review)~='1'
  or tostring(options.prototype_transport_envelope_review)~='1'then return physicalPiece end
 if source~='ork_trukk'or not d or d.name~='ork_trukk'or c.animsource~='ork_trukk'
  or tostring(c.prototype40k)~='1'or c.faction~='Orks'
  or c.source_transport_capacity_policy~='six_actors_footprint4_v1'
  or tonumber(c.source_transport_actor_capacity)~=6
  or tonumber(d.transportCapacity or d.transportcapacity)~=24
  or tonumber(d.transportSize or d.transportsize)~=4
  or d.canFly==true or d.canfly==true then return physicalPiece end
 -- Lua piece 0 maps to native -1. Native CanTransport, six logical slots,
 -- transporter hierarchy and the existing detach/ground landing remain owners.
 return 0
end
return M
