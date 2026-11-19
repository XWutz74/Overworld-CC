--[[
  Overworld-CC - difficulty presets
  Converted from the browser game by tools/convert-web.js.
  economy: startCash/startDebt/loanRate/bankRate/volatility/costs are factors,
           spikeChance is the chance per good and day of a crash or boom.
  combat:  encounterChance % per day, enemyStrength/enemyCount factors,
           runBonus escape % points, arrestFine % of cash.
  lengths: game lengths in days, 0 = endless.
]]
return {
  economy = {
    {
      id = "easy",
      name = { en = "Easy", de = "Leicht" },
      startCash = 1.5,
      startDebt = 0.7,
      loanRate = 0.7,
      bankRate = 2,
      volatility = 0.8,
      spikeChance = 0.05,
      costs = 0.8
    },
    {
      id = "normal",
      name = { en = "Normal", de = "Normal" },
      startCash = 1,
      startDebt = 1,
      loanRate = 1,
      bankRate = 1,
      volatility = 1,
      spikeChance = 0.035,
      costs = 1
    },
    {
      id = "hard",
      name = { en = "Hard", de = "Schwer" },
      startCash = 0.75,
      startDebt = 1.3,
      loanRate = 1.2,
      bankRate = 0.5,
      volatility = 1.2,
      spikeChance = 0.025,
      costs = 1.25
    }
  },
  combat = {
    {
      id = "easy",
      name = { en = "Easy", de = "Leicht" },
      startHealth = 100,
      encounterChance = 22,
      enemyStrength = 0.75,
      enemyCount = 0.8,
      runBonus = 10,
      arrestFine = 10
    },
    {
      id = "normal",
      name = { en = "Normal", de = "Normal" },
      startHealth = 100,
      encounterChance = 32,
      enemyStrength = 1,
      enemyCount = 1,
      runBonus = 0,
      arrestFine = 20
    },
    {
      id = "hard",
      name = { en = "Hard", de = "Schwer" },
      startHealth = 100,
      encounterChance = 42,
      enemyStrength = 1.25,
      enemyCount = 1.3,
      runBonus = -10,
      arrestFine = 35
    }
  },
  lengths = { 15, 30, 60, 90, 180, 365, 0 }
}
