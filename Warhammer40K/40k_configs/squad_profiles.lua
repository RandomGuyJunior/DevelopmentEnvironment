-- Stable IDs are an explicit save/UI contract. Only four ordinary line families.
-- Capacities are BAR-scale authored choices; costs come from final actor defs.
local profiles={marine_tactical={id=1,product='imp_marine',member='imp_marine_member',capacity=4,
  name='Tactical Marine Squad',shortRole='Tactical squad',
  description='One factory order buys all 4 Marines. Builders heal survivors and replace casualties for resources. Permanent Armoury research equips one heavy bolter.',
  specialSlot=4,special='imp_marine_heavy_member',sourceSpecial='imp_devastator',
  research='marine_squad_heavy_bolter',spacing=24,
  researchRow={name='Squad heavy bolter',description='Permanently equips one living member per Tactical squad with a genuine heavy bolter. Missing members still require paid builder repair.',
   producer='imp_marine_armoury',cost={metal=350,energy=1500},time=50,
   requires={buildings={'imp_marine_armoury'}}}},
 guard_line={id=2,product='imp_guardsman',member='imp_guardsman_member',capacity=8,spacing=20,
  name='Guardsman Squad',shortRole='Lasgun squad',description='8 real Guardsmen with lasguns; builders heal survivors and restore casualties for resources.'},
 ork_shoota={id=3,product='ork_boy',member='ork_boy_member',capacity=8,spacing=24,
  name='Shoota Boyz Mob',shortRole='Shoota mob',description='8 Shoota Boyz per factory order. Builders restore casualties for resources. Waaagh Banner research permanently equips one rokkit specialist.',
  specialSlot=8,special='ork_boy_rokkit_member',sourceSpecial='ork_tankbusta',research='ork_squad_rokkit',
  researchRow={name='Mob rokkit specialist',description='Permanently equips one living member per Shoota mob as a genuine Tankbusta. Missing bodies still require paid builder repair.',
   producer='ork_waaagh_banner',cost={metal=300,energy=1500},time=40,requires={buildings={'ork_waaagh_banner'}}}},
 necron_warrior={id=4,product='nec_warrior',member='nec_warrior_member',capacity=5,spacing=24,
  name='Necron Warrior Phalanx',shortRole='Gauss phalanx',description='One factory order buys all 5 Necron Warriors with gauss flayers. Builders heal survivors and restore casualties for resources.'}}
return {version=2,profiles=profiles,
 byID={[1]='marine_tactical',[2]='guard_line',[3]='ork_shoota',[4]='necron_warrior'},
 order={'marine_tactical','guard_line','ork_shoota','necron_warrior'}}
