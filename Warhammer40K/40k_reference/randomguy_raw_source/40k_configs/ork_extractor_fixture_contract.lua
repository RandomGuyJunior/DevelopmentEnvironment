-- Read-only diagnostic preflight; never owns extraction, damage or refunds.
local M={}
local function finitePositive(v)return type(v)=='number'and v==v and v>0 and v<math.huge end
M.Keys={'ork_listening_post','ork_listening_post_t2','ork_listening_post_t3'}
M.Weapons={'ork_shoota_turret_listeningpost','ork_big_shoota_turret_listeningpost','ork_rokkit_launcher_turret_listeningpost'}
local function field(d,native,raw)if d[native]~=nil then return d[native]end;return d[raw]end
local function cp(d)return d.customParams or d.customparams or{}end
function M.Check(D,N,W)
 local rows={}
 local donor=N.cormoho and D[N.cormoho.id]
 if not donor then return nil,'missing_native_economy_donor'end
 for tier,key in ipairs(M.Keys)do
  local d=N[key]and D[N[key].id]
  if not d then return nil,'missing_stage_'..tier end
  local c=cp(d)
  if c.faction~='Orks'or c.extractor_family~='ork_listening_post'or tonumber(c.extractor_tier)~=tier
   or tonumber(c.listening_post_version)~=2 or tonumber(c.listening_post_stage)~=tier-1
   or c.listening_post_key~='ork_post_stages'then return nil,'stage_identity_'..tier end
  if not field(d,'canAttack','canattack')or not d.weapons or #d.weapons~=1 then return nil,'stage_armament_'..tier end
  local mount=d.weapons[1]
  local weapon=(mount.weaponDef and W and W[mount.weaponDef])or(d.weapondefs and d.weapondefs[mount.def])
  local w=weapon and cp(weapon)
  if not w or w.source_weapon_identity~=M.Weapons[tier]or tonumber(w.listening_post_level)~=tier-1
   or w.source_weapon~='attrib/weapon/'..M.Weapons[tier]..'.lua'then return nil,'source_weapon_'..tier end
  local metal=field(d,'metalCost','metalcost');local energy=field(d,'energyCost','energycost');local work=field(d,'buildTime','buildtime');local yield=field(d,'extractsMetal','extractsmetal')
  if not finitePositive(metal)or not finitePositive(energy)or not finitePositive(work)or not finitePositive(yield)then return nil,'paid_economy_'..tier end
  if tier==2 then
   for _,f in ipairs({{'metalCost','metalcost'},{'energyCost','energycost'},{'buildTime','buildtime'},{'extractsMetal','extractsmetal'}})do
    if field(d,f[1],f[2])~=field(donor,f[1],f[2])then return nil,'native_t2_economy_'..f[1]end
   end
  end
  rows[tier]={key=key,tier=tier,stage=tier-1,weapon=w.source_weapon_identity,metal=metal,energy=energy,work=work,yield=yield,
   muzzle=w.source_muzzle,fireclip=w.source_fireclip}
 end
 if rows[3].yield~=rows[2].yield then return nil,'defensive_t3_changed_yield'end
 return rows
end
return M
