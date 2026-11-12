-- Great Gargant only. Native reloads, targets and projectile simulation stay
-- authoritative; actual volley starts are separated for readable heavy fire.
return function(data)
 local oldFire,oldShot,oldQuery,oldBlock=script.FireWeapon,script.Shot,script.QueryWeapon,script.BlockShot
 local gun=data.weaponMounts[2]
 local perBarrel,count=10,0
 local muzzle=piece(gun.muzzles[1])
 local armed={};local nextHeavyVolley=0
 local gap=math.ceil(Game.gameSpeed*.75)
 function script.BlockShot(n)
  if oldBlock(n)then return true end
  return n>=1 and n<=3 and Spring.GetGameFrame()<nextHeavyVolley
 end
 function script.FireWeapon(n)
  if n>=1 and n<=3 then armed[n]=true end
  if n==2 then count=0;muzzle=piece(gun.muzzles[1])end
  oldFire(n)
 end
 function script.Shot(n)
  if armed[n]then
   armed[n]=nil;nextHeavyVolley=Spring.GetGameFrame()+gap
  end
  if n~=2 then return oldShot(n)end
  count=count%(perBarrel*2)+1
  local barrel=math.floor((count-1)/perBarrel)+1
  muzzle=piece(gun.muzzles[barrel])
  if (count-1)%perBarrel==0 and gun.sfx then EmitSfx(muzzle,1023+gun.sfx)end
 end
 function script.QueryWeapon(n)
  if n==2 then return muzzle end
  return oldQuery(n)
 end
end
