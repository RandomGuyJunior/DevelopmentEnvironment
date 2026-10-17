-- Pure pre-hook gate. Caller obtains Game from the actual native game and logs
-- the receipt OUTSIDE the archive; this module never installs a hook itself.
local M = {}
local function valid(value)
 return type(value)=='string' and #value==128 and value:match('^[0-9a-fA-F]+$')~=nil
end
function M.Check(game, engine, expected, emit)
 game=type(game)=='table' and game or {}
 engine=type(engine)=='table' and engine or {}
 local actual=game.modChecksum
 local receipt={schema=1, game_name=game and game.gameName, game_version=game and game.gameVersion,
  engine_full_version=engine and engine.versionFull, actual_checksum=actual}
 if not valid(actual) then receipt.status='REFUSED_INVALID_NATIVE_CHECKSUM'
 elseif expected==nil or expected=='' then receipt.status='REFUSED_MISSING_EXPECTED_CHECKSUM'
 elseif not valid(expected) then receipt.status='REFUSED_INVALID_EXPECTED_CHECKSUM'
 elseif expected~=actual then receipt.status='REFUSED_DIFFERENT_CHECKSUM'
 else receipt.status='CHECKSUM_MATCH_ONLY' end
 if emit then emit(receipt) end
 return receipt.status=='CHECKSUM_MATCH_ONLY', receipt
end
return M
