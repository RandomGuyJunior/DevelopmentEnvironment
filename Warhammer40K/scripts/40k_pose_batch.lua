-- Per-actor atomic source Apply batching using pinned native MultiMove/Turn.
-- No source pose/timing change; queue calls follow ALL instant vector updates.
local unpackArgs=unpack or table.unpack
return function(directMove,directTurn,bones,native)
 native=native or (Spring and Spring.UnitScript)
 local multiMove=native and native.MultiMove
 local multiTurn=native and native.MultiTurn
 local eligible=type(multiMove)=='function' and type(multiTurn)=='function'
 local seen={}
 for _,pieceID in ipairs(bones) do
  if seen[pieceID] then eligible=false end
  seen[pieceID]=true
 end
 local instantMove,instantTurn,queueMove,queueTurn={},{},{},{}
 local moveCount,turnCount,queueMoveCount,queueTurnCount=0,0,0,0
 local active=false
 local function append(buffer,count,pieceID,axis,destination,speed)
  buffer[count+1],buffer[count+2],buffer[count+3],buffer[count+4]=pieceID,axis,destination,speed
  return count+4
 end
 local function flush(buffer,count,nativeCall)
  -- MultiExec executes first tuple then remaining tuples in reverse. Source
  -- commands in each buffer address distinct piece/axis pairs, so commute.
  -- Never combine instant and queued commands in the same native invocation.
  for first=1,count,256 do nativeCall(unpackArgs(buffer,first,math.min(count,first+255))) end
 end
 local api={}
 function api.Begin()
  assert(not active,'40K pose batch cannot nest atomic Apply')
  moveCount,turnCount,queueMoveCount,queueTurnCount=0,0,0,0
  active=eligible
 end
 function api.Move(pieceID,axis,destination,speed)
  if not active then return directMove(pieceID,axis,destination,speed) end
  if speed==nil or speed==0 then moveCount=append(instantMove,moveCount,pieceID,axis,destination,0)
  else queueMoveCount=append(queueMove,queueMoveCount,pieceID,axis,destination,speed) end
 end
 function api.Turn(pieceID,axis,destination,speed)
  if not active then return directTurn(pieceID,axis,destination,speed) end
  if speed==nil or speed==0 then turnCount=append(instantTurn,turnCount,pieceID,axis,destination,0)
  else queueTurnCount=append(queueTurn,queueTurnCount,pieceID,axis,destination,speed) end
 end
 function api.Flush()
  if not active then return end
  active=false
  flush(instantMove,moveCount,multiMove)
  flush(instantTurn,turnCount,multiTurn)
  flush(queueMove,queueMoveCount,multiMove)
  flush(queueTurn,queueTurnCount,multiTurn)
 end
 return api
end
