-- Clip tables are immutable. BAR caches include bytecode, not its result.
-- Only this artwork data is shared; actor buffers and callbacks remain local.
return function(path)
 GG.Bar40KAnimationData = GG.Bar40KAnimationData or {}
 local data = GG.Bar40KAnimationData[path]
 if not data then
  data = include(path)
  GG.Bar40KAnimationData[path] = data
 end
 return data
end
