--!strict

local WaveConfig = {}

WaveConfig.StartDelay = 5
WaveConfig.Intermission = 5
WaveConfig.FinalClearBonus = 1500

local function enemyGroup(
	enemyName: string,
	amount: number,
	spawnDelay: number
)
	return {
		Enemy = enemyName,
		Amount = amount,
		SpawnDelay = spawnDelay,
	}
end

local function createWave(
	clearReward: number,
	...: { Enemy: string, Amount: number, SpawnDelay: number }
)
	local wave = {
		ClearReward = clearReward,
	}

	for _, group in ipairs({ ... }) do
		table.insert(wave, group)
	end

	return wave
end

WaveConfig.Waves = {
	createWave(
		200,

		enemyGroup(
			"Bandit",
			3,
			2
		)
	),

	createWave(
		300,

		enemyGroup(
			"Bandit",
			5,
			1.8
		)
	),

	createWave(
		450,

		enemyGroup(
			"Bandit",
			4,
			1.5
		),

		enemyGroup(
			"FastBandit",
			3,
			1.2
		)
	),

	createWave(
		650,

		enemyGroup(
			"Bandit",
			5,
			1.3
		),

		enemyGroup(
			"FastBandit",
			3,
			1
		),

		enemyGroup(
			"TankBandit",
			2,
			2.5
		)
	),

	createWave(
		1000,

		enemyGroup(
			"Bandit",
			5,
			1.1
		),

		enemyGroup(
			"FastBandit",
			4,
			0.8
		),

		enemyGroup(
			"TankBandit",
			2,
			2
		),

		enemyGroup(
			"BossBandit",
			1,
			1
		)
	),
}

return WaveConfig
