--!strict

local UnitConfig = {}

export type AbilityConfig = {
	Name: string,
	Type: string,
	Cooldown: number,
	CastRange: number?,
	Radius: number?,
	DamageMultiplier: number?,
	SkyHeight: number?,
	FallTime: number?,
	ImpactHoldTime: number?,
	ConeAngle: number?,
	VFXDuration: number?,
	VFXYaw: number?,
	HitDelay: number?,
}

export type UpgradeConfig = {
	UpgradeCost: number,
	MaxHealth: number,
	Damage: number,
	WalkSpeed: number,
	Range: number,
	BaseDamage: number,
}

export type AllyConfig = {
	MaxHealth: number,
	Damage: number,
	WalkSpeed: number,
	Range: number,
	BaseDamage: number,
	Cost: number,
	DeployCooldown: number,
	DeployLimit: number,
	Scale: number,
	MaxLevel: number,
	AttackEnabled: boolean?,
	AttackCooldown: number?,
	Abilities: {AbilityConfig},
	Upgrades: {[number]: UpgradeConfig},
}

export type EnemyConfig = {
	MaxHealth: number,
	Damage: number,
	AttackCooldown: number,
	WalkSpeed: number,
	Range: number,
	BaseDamage: number,
	Scale: number,
	KillReward: number,
}

UnitConfig.AbilityTypes = {
	TargetAOE = "TARGET_AOE",
	SkyDrop = "SKY_DROP",
	Cone = "CONE",
}

UnitConfig.Allies = {
	Natsu = {
		MaxHealth = 600,
		Damage = 80,
		WalkSpeed = 10,
		Range = 10,
		BaseDamage = 200,

		Cost = 300,
		DeployCooldown = 5,
		DeployLimit = 3,

		Scale = 0.60,
		MaxLevel = 3,
		AttackEnabled = false,

		Abilities = {
			{
				Name = "FlameBurst",
				Type = UnitConfig.AbilityTypes.TargetAOE,
				Cooldown = 1.2,
				Radius = 4,
				DamageMultiplier = 1,
			},
		},

		Upgrades = {
			[2] = {
				UpgradeCost = 700,
				MaxHealth = 750,
				Damage = 110,
				WalkSpeed = 10,
				Range = 11,
				BaseDamage = 250,
			},

			[3] = {
				UpgradeCost = 1200,
				MaxHealth = 950,
				Damage = 150,
				WalkSpeed = 10,
				Range = 12,
				BaseDamage = 325,
			},
		},
	},

	Gojo = {
		MaxHealth = 450,
		Damage = 140,
		WalkSpeed = 9,
		Range = 20,
		BaseDamage = 250,

		Cost = 500,
		DeployCooldown = 7,
		DeployLimit = 2,

		Scale = 0.60,
		MaxLevel = 3,
		AttackEnabled = false,

		Abilities = {
			{
				Name = "BlueBlast",
				Type = UnitConfig.AbilityTypes.SkyDrop,
				Cooldown = 1.8,
				Radius = 6,
				DamageMultiplier = 1,
				SkyHeight = 30,
				FallTime = 0.65,
				ImpactHoldTime = 0.15,
			},
		},

		Upgrades = {
			[2] = {
				UpgradeCost = 900,
				MaxHealth = 550,
				Damage = 190,
				WalkSpeed = 9,
				Range = 22,
				BaseDamage = 320,
			},

			[3] = {
				UpgradeCost = 1600,
				MaxHealth = 700,
				Damage = 260,
				WalkSpeed = 9,
				Range = 24,
				BaseDamage = 420,
			},
		},
	},

	Madara = {
		MaxHealth = 800,
		Damage = 190,
		WalkSpeed = 8,
		Range = 24,
		BaseDamage = 400,

		Cost = 750,
		DeployCooldown = 9,
		DeployLimit = 1,

		Scale = 0.40,
		MaxLevel = 3,
		AttackEnabled = false,

		Abilities = {
			{
				Name = "GreatFire",
				Type = UnitConfig.AbilityTypes.Cone,
				Cooldown = 2.5,
				ConeAngle = 40,
				DamageMultiplier = 1,
				VFXDuration = 1,
				VFXYaw = 180,
				HitDelay = 0.25,
			},
		},

		Upgrades = {
			[2] = {
				UpgradeCost = 1400,
				MaxHealth = 1000,
				Damage = 260,
				WalkSpeed = 8,
				Range = 27,
				BaseDamage = 500,
			},

			[3] = {
				UpgradeCost = 2300,
				MaxHealth = 1300,
				Damage = 360,
				WalkSpeed = 8,
				Range = 30,
				BaseDamage = 650,
			},
		},
	},
} :: {[string]: AllyConfig}

UnitConfig.Enemies = {
	Bandit = {
		MaxHealth = 450,
		Damage = 55,
		AttackCooldown = 1.4,
		WalkSpeed = 8,
		Range = 6,
		BaseDamage = 150,
		Scale = 0.60,
		KillReward = 60,
	},

	FastBandit = {
		MaxHealth = 280,
		Damage = 35,
		AttackCooldown = 1,
		WalkSpeed = 14,
		Range = 6,
		BaseDamage = 120,
		Scale = 0.55,
		KillReward = 75,
	},

	TankBandit = {
		MaxHealth = 1500,
		Damage = 100,
		AttackCooldown = 1.8,
		WalkSpeed = 5,
		Range = 6,
		BaseDamage = 350,
		Scale = 0.70,
		KillReward = 180,
	},

	BossBandit = {
		MaxHealth = 5000,
		Damage = 180,
		AttackCooldown = 1.5,
		WalkSpeed = 6,
		Range = 7,
		BaseDamage = 800,
		Scale = 0.75,
		KillReward = 1000,
	},
} :: {[string]: EnemyConfig}

function UnitConfig.GetAlly(name: string): AllyConfig?
	return UnitConfig.Allies[name]
end

function UnitConfig.GetEnemy(name: string): EnemyConfig?
	return UnitConfig.Enemies[name]
end

function UnitConfig.GetUpgrade(unitName: string, level: number): UpgradeConfig?
	local unit = UnitConfig.GetAlly(unitName)

	if not unit then
		return nil
	end

	return unit.Upgrades[level]
end

function UnitConfig.GetAbility(unitName: string, abilityName: string): AbilityConfig?
	local unit = UnitConfig.GetAlly(unitName)

	if not unit then
		return nil
	end

	for _, ability in ipairs(unit.Abilities) do
		if ability.Name == abilityName then
			return ability
		end
	end

	return nil
end

function UnitConfig.IsValidAbilityType(abilityType: string): boolean
	return abilityType == UnitConfig.AbilityTypes.TargetAOE
		or abilityType == UnitConfig.AbilityTypes.SkyDrop
		or abilityType == UnitConfig.AbilityTypes.Cone
end

function UnitConfig.Validate()
	for unitName, unit in pairs(UnitConfig.Allies) do
		assert(unit.MaxHealth > 0, `{unitName}: invalid MaxHealth`)
		assert(unit.Damage >= 0, `{unitName}: invalid Damage`)
		assert(unit.Range > 0, `{unitName}: invalid Range`)
		assert(unit.Cost >= 0, `{unitName}: invalid Cost`)
		assert(unit.DeployLimit > 0, `{unitName}: invalid DeployLimit`)

		for _, ability in ipairs(unit.Abilities) do
			assert(
				UnitConfig.IsValidAbilityType(ability.Type),
				`{unitName}: invalid ability type {ability.Type}`
			)

			assert(ability.Cooldown >= 0, `{unitName}: invalid ability cooldown`)
		end
	end

	for enemyName, enemy in pairs(UnitConfig.Enemies) do
		assert(enemy.MaxHealth > 0, `{enemyName}: invalid MaxHealth`)
		assert(enemy.WalkSpeed >= 0, `{enemyName}: invalid WalkSpeed`)
		assert(enemy.AttackCooldown >= 0, `{enemyName}: invalid AttackCooldown`)
	end
end

UnitConfig.Validate()

for _, unit in pairs(UnitConfig.Allies) do
	for _, ability in ipairs(unit.Abilities) do
		table.freeze(ability)
	end

	for _, upgrade in pairs(unit.Upgrades) do
		table.freeze(upgrade)
	end

	table.freeze(unit.Abilities)
	table.freeze(unit.Upgrades)
	table.freeze(unit)
end

for _, enemy in pairs(UnitConfig.Enemies) do
	table.freeze(enemy)
end

table.freeze(UnitConfig.AbilityTypes)
table.freeze(UnitConfig.Allies)
table.freeze(UnitConfig.Enemies)

return table.freeze(UnitConfig)
