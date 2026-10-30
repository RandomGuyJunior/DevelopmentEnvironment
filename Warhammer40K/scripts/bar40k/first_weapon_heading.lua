-- Non-firing native heading reference. Never moves/rotates a unit in Lua.
return function()
 local names={"AimFromWeapon","QueryWeapon","AimWeapon","BlockShot","FireWeapon","Shot"}
 for _,name in ipairs(names)do
  local original=script[name]
  if original then
   script[name]=function(n,...)
    if n==1 then
     if name=="AimWeapon"then return false end
     if name=="BlockShot"then return true end
     if name=="AimFromWeapon"or name=="QueryWeapon"then return original(1,...)end
     return
    end
    return original(n-1,...)
   end
  end
 end
end
