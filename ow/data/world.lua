--[[
  Overworld-CC - world content
  Converted from the browser game by tools/convert-web.js.
  Cities, districts, goods, items, enemies, banks and loan sharks.
  Names use { en = "...", de = "..." }; "de" is optional. Money is in dollars,
  percentages are plain numbers (15 means 15 %).
  goods:   min/max normal price, lowSpike/highSpike crash/boom factor,
           avail chance (0-1) a district sells it, qty {smallest, largest}.
  items:   type storage|armor|vehicle|weapon|ammo|tool, space extra room,
           armor % absorbed, run escape bonus, notice extra encounter chance,
           violence only sold with violence on, sellable false = can't sell.
  enemies: count group size, hp, accuracy %, damage % per hit, bribe $ per member, loot.
  banks:   rate yearly %, min opening deposit and minimum balance.
  sharks:  rate daily %, days until due, amount range, early repayment fee %.
]]
return {
  start = { city = "ny", district = "manhattan", cash = 2000, debt = 5500, debtShark = "tybalt", coat = 100 },
  cities = {
    {
      id = "ny",
      name = { en = "New York", de = "New York" },
      districts = {
        {
          id = "manhattan",
          name = { en = "Manhattan" },
          cops = "Detective Talbot",
          mafia = "Don Angelo",
          gang = "Marcellus",
          store = true,
          bank = true,
          hospital = "Manhattan General",
          sharks = { "tybalt" }
        },
        {
          id = "bronx",
          name = { en = "Bronx" },
          cops = "Detective Lucius",
          mafia = "Don Campeius",
          gang = "Ceres",
          store = true,
          bank = true,
          hospital = "Bronx Lebanon",
          sharks = { "shylock" }
        },
        {
          id = "queens",
          name = { en = "Queens" },
          cops = "Detective Octavius",
          mafia = "Don Falconbridge",
          gang = "Jaques",
          store = true,
          bank = true,
          hospital = "Queens Memorial",
          sharks = {  }
        },
        {
          id = "brooklyn",
          name = { en = "Brooklyn" },
          cops = "Detective Cornelius",
          mafia = "Don Pedro",
          gang = "Dromio",
          store = true,
          bank = true,
          hospital = "Kings County",
          sharks = { "portia" }
        },
        {
          id = "statenisland",
          name = { en = "Staten Island", de = "Staten Island" },
          cops = "Detective Aguecheek",
          mafia = "Don Armado",
          gang = "Philip",
          store = true,
          bank = true,
          hospital = "Richmond University",
          sharks = {  }
        }
      }
    }
  },
  goods = {
    {
      id = "diamonds",
      name = { en = "Diamonds", de = "Diamanten" },
      min = 15000,
      max = 30000,
      lowSpike = 0.55,
      highSpike = 1.6,
      avail = 0.7,
      qty = { 2, 80 }
    },
    {
      id = "gold",
      name = { en = "Gold Bars", de = "Goldbarren" },
      min = 5000,
      max = 14000,
      lowSpike = 0.5,
      highSpike = 2.5,
      avail = 0.8,
      qty = { 5, 110 }
    },
    {
      id = "watches",
      name = { en = "Luxury Watches", de = "Luxusuhren" },
      min = 7500,
      max = 13000,
      lowSpike = 0.6,
      highSpike = 1.5,
      avail = 0.75,
      qty = { 5, 90 }
    },
    {
      id = "art",
      name = { en = "Stolen Art", de = "Gestohlene Kunst" },
      min = 1900,
      max = 4900,
      lowSpike = 0.5,
      highSpike = 1.8,
      avail = 0.6,
      qty = { 2, 95 }
    },
    {
      id = "bags",
      name = { en = "Designer Bags", de = "Designer-Taschen" },
      min = 500,
      max = 3400,
      lowSpike = 0.5,
      highSpike = 1.8,
      avail = 0.8,
      qty = { 10, 160 }
    },
    {
      id = "phones",
      name = { en = "Smartphones", de = "Smartphones" },
      min = 1000,
      max = 2500,
      lowSpike = 0.6,
      highSpike = 1.6,
      avail = 0.85,
      qty = { 20, 240 }
    },
    {
      id = "consoles",
      name = { en = "Game Consoles", de = "Spielkonsolen" },
      min = 900,
      max = 1800,
      lowSpike = 0.6,
      highSpike = 1.6,
      avail = 0.8,
      qty = { 20, 200 }
    },
    {
      id = "sneakers",
      name = { en = "Limited Sneakers", de = "Limitierte Sneaker" },
      min = 630,
      max = 2800,
      lowSpike = 0.6,
      highSpike = 1.8,
      avail = 0.75,
      qty = { 10, 200 }
    },
    {
      id = "perfume",
      name = { en = "Perfume", de = "Parfüm" },
      min = 600,
      max = 1200,
      lowSpike = 0.6,
      highSpike = 1.6,
      avail = 0.85,
      qty = { 10, 220 }
    },
    {
      id = "jeans",
      name = { en = "Designer Jeans", de = "Designer-Jeans" },
      min = 230,
      max = 800,
      lowSpike = 0.6,
      highSpike = 1.7,
      avail = 0.85,
      qty = { 20, 280 }
    },
    {
      id = "cigarettes",
      name = { en = "Cigarette Cartons", de = "Zigarettenstangen" },
      min = 300,
      max = 1000,
      lowSpike = 0.6,
      highSpike = 1.8,
      avail = 0.85,
      qty = { 20, 250 }
    },
    {
      id = "whisky",
      name = { en = "Rare Whisky", de = "Seltener Whisky" },
      min = 235,
      max = 980,
      lowSpike = 0.6,
      highSpike = 1.8,
      avail = 0.85,
      qty = { 20, 250 }
    },
    {
      id = "software",
      name = { en = "Bootleg Software", de = "Raubkopien" },
      min = 250,
      max = 490,
      lowSpike = 0.6,
      highSpike = 1.7,
      avail = 0.85,
      qty = { 20, 260 }
    },
    {
      id = "fireworks",
      name = { en = "Fireworks", de = "Feuerwerk" },
      min = 110,
      max = 300,
      lowSpike = 0.5,
      highSpike = 2,
      avail = 0.85,
      qty = { 30, 300 }
    },
    {
      id = "sunglasses",
      name = { en = "Knockoff Sunglasses", de = "Gefälschte Sonnenbrillen" },
      min = 5,
      max = 60,
      lowSpike = 0.4,
      highSpike = 2.5,
      avail = 0.9,
      qty = { 50, 320 }
    }
  },
  items = {
    {
      id = "calculator",
      type = "tool",
      name = { en = "Calculator", de = "Taschenrechner" },
      price = 12,
      desc = { en = "Shows your profit per item in the inventory and status bar.", de = "Zeigt deinen Gewinn pro Stück im Inventar und in der Statuszeile." }
    },
    {
      id = "tablet",
      type = "tool",
      name = { en = "Tablet", de = "Tablet" },
      price = 900,
      desc = {
        en = "Stores every price you see. Unlocks price history, market overview and the highest price seen.",
        de = "Speichert jeden Preis, den du siehst. Schaltet Preisverlauf, Marktübersicht und den höchsten gesehenen Preis frei."
      }
    },
    {
      id = "laptop",
      type = "tool",
      name = { en = "Laptop", de = "Laptop" },
      price = 2400,
      desc = {
        en = "Stores every price you see. Unlocks price history, market overview, highest and lowest price and trend arrows.",
        de = "Speichert jeden Preis, den du siehst. Schaltet Preisverlauf, Marktübersicht, höchsten und tiefsten Preis sowie Trendpfeile frei."
      }
    },
    {
      id = "cargopants",
      type = "storage",
      slot = "pants",
      name = { en = "Cargo Pants", de = "Cargohose" },
      price = 60,
      space = 20,
      desc = { en = "Lots of pockets. +20 space.", de = "Viele Taschen. +20 Platz." }
    },
    {
      id = "backpack",
      type = "storage",
      slot = "bag",
      name = { en = "Backpack", de = "Rucksack" },
      price = 1200,
      space = 60,
      desc = { en = "+60 space.", de = "+60 Platz." }
    },
    {
      id = "largecoat",
      type = "storage",
      slot = "coat",
      name = { en = "Large Trenchcoat", de = "Großer Trenchcoat" },
      price = 600,
      space = 50,
      desc = { en = "Replaces your coat. +50 space.", de = "Ersetzt deinen Mantel. +50 Platz." }
    },
    {
      id = "leather",
      type = "armor",
      slot = "armor",
      name = { en = "Leather Armor", de = "Lederrüstung" },
      price = 600,
      armor = 10,
      desc = { en = "Absorbs 10 % of damage.", de = "Fängt 10 % des Schadens ab." }
    },
    {
      id = "vest",
      type = "armor",
      slot = "armor",
      name = { en = "Bulletproof Vest", de = "Schusssichere Weste" },
      price = 3000,
      armor = 25,
      desc = { en = "Absorbs 25 % of damage.", de = "Fängt 25 % des Schadens ab." }
    },
    {
      id = "bodyarmor",
      type = "armor",
      slot = "armor",
      name = { en = "Body Armor", de = "Körperpanzer" },
      price = 6000,
      armor = 40,
      desc = { en = "Absorbs 40 % of damage.", de = "Fängt 40 % des Schadens ab." }
    },
    {
      id = "motorcycle",
      type = "vehicle",
      slot = "vehicle",
      name = { en = "Motorcycle", de = "Motorrad" },
      price = 48000,
      space = 40,
      run = 15,
      notice = 0,
      desc = { en = "+40 space. Much easier to escape.", de = "+40 Platz. Flucht deutlich leichter." }
    },
    {
      id = "sedan",
      type = "vehicle",
      slot = "vehicle",
      name = { en = "Sedan", de = "Limousine" },
      price = 60000,
      space = 120,
      run = 5,
      notice = 2,
      desc = { en = "+120 space. Easier to escape.", de = "+120 Platz. Flucht etwas leichter." }
    },
    {
      id = "musclecar",
      type = "vehicle",
      slot = "vehicle",
      name = { en = "Muscle Car", de = "Muscle Car" },
      price = 85000,
      space = 140,
      run = 10,
      notice = 5,
      desc = { en = "+140 space. Fast, but loud.", de = "+140 Platz. Schnell, aber laut." }
    },
    {
      id = "sportscar",
      type = "vehicle",
      slot = "vehicle",
      name = { en = "Sports Car", de = "Sportwagen" },
      price = 150000,
      space = 90,
      run = 20,
      notice = 5,
      desc = { en = "+90 space. Best for escaping.", de = "+90 Platz. Am besten zum Fliehen." }
    },
    {
      id = "van",
      type = "vehicle",
      slot = "vehicle",
      name = { en = "Van", de = "Van" },
      price = 120000,
      space = 350,
      run = -5,
      notice = 6,
      desc = { en = "+350 space. Harder to escape.", de = "+350 Platz. Flucht schwieriger." }
    },
    {
      id = "rentaltruck",
      type = "vehicle",
      slot = "vehicle",
      name = { en = "Rental Truck", de = "Mietlaster" },
      price = 180000,
      space = 550,
      run = -10,
      notice = 8,
      desc = { en = "+550 space. Slow and noticeable.", de = "+550 Platz. Langsam und auffällig." }
    },
    {
      id = "truck",
      type = "vehicle",
      slot = "vehicle",
      name = { en = "Truck", de = "Lkw" },
      price = 300000,
      space = 900,
      run = -15,
      notice = 10,
      desc = { en = "+900 space. Slow and very noticeable.", de = "+900 Platz. Langsam und sehr auffällig." }
    },
    {
      id = "rig",
      type = "vehicle",
      slot = "vehicle",
      name = { en = "Semi Truck", de = "Sattelzug" },
      price = 750000,
      space = 2000,
      run = -25,
      notice = 15,
      desc = { en = "+2000 space. Everyone sees you coming.", de = "+2000 Platz. Jeder sieht dich kommen." }
    },
    {
      id = "limo",
      type = "vehicle",
      slot = "vehicle",
      name = { en = "Stretch Limo", de = "Stretch-Limo" },
      price = 400000,
      space = 250,
      run = -10,
      notice = 12,
      desc = { en = "+250 space. Pure style, attracts attention.", de = "+250 Platz. Purer Stil, zieht Aufmerksamkeit an." }
    },
    {
      id = "bat",
      type = "weapon",
      violence = true,
      name = { en = "Baseball Bat", de = "Baseballschläger" },
      price = 12,
      damage = { 6, 12 },
      accuracy = 70,
      desc = { en = "Better than bare hands.", de = "Besser als bloße Fäuste." }
    },
    {
      id = "knife",
      type = "weapon",
      violence = true,
      name = { en = "Knife", de = "Messer" },
      price = 40,
      damage = { 7, 14 },
      accuracy = 65,
      desc = { en = "Small and quiet.", de = "Klein und leise." }
    },
    {
      id = "stungun",
      type = "weapon",
      violence = true,
      name = { en = "Stun Gun", de = "Elektroschocker" },
      price = 250,
      damage = { 10, 16 },
      accuracy = 60,
      desc = { en = "Short range, no ammo needed.", de = "Kurze Reichweite, keine Munition nötig." }
    },
    {
      id = "pistol9",
      type = "weapon",
      violence = true,
      name = { en = "9mm Pistol", de = "9-mm-Pistole" },
      price = 600,
      damage = { 14, 24 },
      accuracy = 60,
      ammo = "ammo9",
      desc = { en = "Uses 9mm ammo.", de = "Braucht 9-mm-Munition." }
    },
    {
      id = "pistol45",
      type = "weapon",
      violence = true,
      name = { en = ".45 Pistol", de = ".45 Pistole" },
      price = 960,
      damage = { 18, 28 },
      accuracy = 58,
      ammo = "ammo45",
      desc = { en = "Uses .45 ammo.", de = "Braucht .45-Munition." }
    },
    {
      id = "pistol357",
      type = "weapon",
      violence = true,
      name = { en = ".357 Revolver", de = ".357 Revolver" },
      price = 900,
      damage = { 20, 30 },
      accuracy = 55,
      ammo = "ammo357",
      desc = { en = "Uses .357 ammo.", de = "Braucht .357-Munition." }
    },
    {
      id = "shotgun",
      type = "weapon",
      violence = true,
      name = { en = "12 Gauge Shotgun", de = "Schrotflinte" },
      price = 1200,
      damage = { 26, 40 },
      accuracy = 62,
      ammo = "ammo12",
      desc = { en = "Uses 12 gauge shells.", de = "Braucht Schrotpatronen." }
    },
    {
      id = "uzi",
      type = "weapon",
      violence = true,
      name = { en = "Uzi 9mm", de = "Uzi 9 mm" },
      price = 5400,
      damage = { 12, 20 },
      accuracy = 55,
      ammo = "ammo9",
      shots = 3,
      desc = { en = "Fires 3 shots per round. Uses 9mm ammo.", de = "Feuert 3 Schüsse pro Runde. Braucht 9-mm-Munition." }
    },
    {
      id = "rifle",
      type = "weapon",
      violence = true,
      name = { en = "Assault Rifle", de = "Sturmgewehr" },
      price = 4800,
      damage = { 28, 44 },
      accuracy = 66,
      ammo = "ammo223",
      shots = 2,
      desc = { en = "Fires 2 shots per round. Uses .223 ammo.", de = "Feuert 2 Schüsse pro Runde. Braucht .223-Munition." }
    },
    { id = "ammo9", type = "ammo", violence = true, sellable = false, name = { en = "9mm Ammo (20)", de = "9-mm-Munition (20)" }, price = 48, rounds = 20 },
    { id = "ammo45", type = "ammo", violence = true, sellable = false, name = { en = ".45 Ammo (20)", de = ".45-Munition (20)" }, price = 48, rounds = 20 },
    { id = "ammo357", type = "ammo", violence = true, sellable = false, name = { en = ".357 Ammo (20)", de = ".357-Munition (20)" }, price = 48, rounds = 20 },
    {
      id = "ammo12",
      type = "ammo",
      violence = true,
      sellable = false,
      name = { en = "12 Gauge Shells (20)", de = "Schrotpatronen (20)" },
      price = 48,
      rounds = 20
    },
    { id = "ammo223", type = "ammo", violence = true, sellable = false, name = { en = ".223 Ammo (20)", de = ".223-Munition (20)" }, price = 48, rounds = 20 }
  },
  enemies = {
    cops = {
      count = { 1, 3 },
      hp = 18,
      accuracy = 40,
      damage = { 4, 9 },
      bribe = 400,
      loot = { 0, 0 },
      members = { en = "officers", de = "Beamte" },
      member = { en = "officer", de = "Beamter" }
    },
    gang = {
      count = { 2, 5 },
      hp = 12,
      accuracy = 30,
      damage = { 3, 8 },
      bribe = 150,
      loot = { 50, 600 },
      members = { en = "gang members", de = "Gangmitglieder" },
      member = { en = "gang member", de = "Gangmitglied" }
    },
    mafia = {
      count = { 1, 4 },
      hp = 20,
      accuracy = 45,
      damage = { 5, 11 },
      bribe = 600,
      loot = { 200, 2000 },
      members = { en = "enforcers", de = "Vollstrecker" },
      member = { en = "enforcer", de = "Vollstrecker" }
    },
    shark = {
      count = { 1, 3 },
      hp = 20,
      accuracy = 45,
      damage = { 5, 10 },
      bribe = 0,
      loot = { 0, 0 },
      members = { en = "collectors", de = "Geldeintreiber" },
      member = { en = "collector", de = "Geldeintreiber" }
    }
  },
  banks = {
    { id = "first", name = { en = "First Bank" }, district = "manhattan", rate = 1, min = 100, atm = false },
    { id = "empire", name = { en = "Empire Savings" }, district = "manhattan", rate = 3, min = 5000, atm = true },
    { id = "second", name = { en = "Second Bank" }, district = "bronx", rate = 2, min = 500, atm = true },
    { id = "third", name = { en = "Third Bank" }, district = "queens", rate = 4, min = 10000, atm = true },
    { id = "harbor", name = { en = "Harbor Trust" }, district = "brooklyn", rate = 2, min = 1000, atm = false },
    { id = "island", name = { en = "Island Credit Union" }, district = "statenisland", rate = 5, min = 25000, atm = true }
  },
  sharks = {
    {
      id = "tybalt",
      name = "Tybalt",
      district = "manhattan",
      rate = 15,
      days = 10,
      amount = { 1000, 10000 },
      early = 10
    },
    {
      id = "shylock",
      name = "Shylock",
      district = "bronx",
      rate = 8,
      days = 20,
      amount = { 10000, 60000 },
      early = 15
    },
    {
      id = "portia",
      name = "Portia",
      district = "brooklyn",
      rate = 5,
      days = 30,
      amount = { 50000, 250000 },
      early = 20
    }
  },
  hospitalPrice = 70
}
