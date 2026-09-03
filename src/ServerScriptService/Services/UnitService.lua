--!strict

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")

local UnitConfig = require(
	ReplicatedStorage
		:WaitForChild("Config")
		:WaitForChild("UnitConfig")
)

local UnitService = {}

local SPAWN_HEIGHT = 2
local UNIT_COLLISION_GROUP = "BattleUnits"

local unitsFolder = workspace:WaitForChild("Units")
local alliesFolder = unitsFolder:WaitForChild("Allies")
local enemiesFolder = unitsFolder:WaitForChild("Enemies")

local storedUnits = ServerStorage:WaitForChild("Units")
local storedAllies = storedUnits:WaitForChild("Allies")
local storedEnemies = storedUnits:WaitForChild("Enemies")

local allySpawnPosition: Vector3? = nil
local enemySpawnPosition: Vector3? = nil

local onUnitSpawned: ((Model) -> ())? = nil

local function getHumanoid(unit: Model): Humanoid?
	return unit:FindFirstChildWhichIsA(
		"Humanoid",
		true
	)
end

local function getRoot(unit: Model): BasePart?
	local root = unit:FindFirstChild(
		"HumanoidRootPart",
		true
	)

	if root and root:IsA("BasePart") then
		return root
	end

	return nil
end

local function findTemplate(
	folder: Instance,
	unitName: string
): Model?
	local direct = folder:FindFirstChild(unitName)

	if direct then
		if direct:IsA("Model") then
			return direct
		end

		if direct:IsA("Folder") then
			local nested =
				direct:FindFirstChildWhichIsA(
					"Model",
					true
				)

			if nested then
				return nested
			end
		end
	end

	for _, object in ipairs(
		folder:GetDescendants()
	) do
		if
			object:IsA("Model")
			and string.lower(object.Name)
				== string.lower(unitName)
		then
			return object
		end
	end

	return nil
end

local function scaleUnit(
	unit: Model,
	scale: number?
)
	local amount = math.clamp(
		scale or 1,
		0.25,
		2
	)

	if amount == 1 then
		return
	end

	local success, message = pcall(function()
		unit:ScaleTo(amount)
	end)

	if not success then
		warn(
			"[UnitService] Failed to scale unit:",
			message
		)
	end
end

local function cleanUnit(unit: Model)
	for _, object in ipairs(
		unit:GetDescendants()
	) do
		if
			object:IsA("Script")
			or object:IsA("LocalScript")
			or object:IsA("ModuleScript")
		then
			object:Destroy()
			continue
		end

		if
			object:IsA("ParticleEmitter")
			or object:IsA("Trail")
			or object:IsA("Beam")
			or object:IsA("Fire")
			or object:IsA("Smoke")
			or object:IsA("Sparkles")
			or object:IsA("PointLight")
			or object:IsA("SpotLight")
			or object:IsA("SurfaceLight")
		then
			object.Enabled = false
		end
	end
end

local function preparePhysicalRig(
	unit: Model
): boolean
	local root = getRoot(unit)

	if not root then
		return false
	end

	for _, object in ipairs(
		unit:GetDescendants()
	) do
		if object:IsA("BasePart") then
			object.Anchored = false
			object.CanTouch = false
			object.CanQuery = false
			object.CollisionGroup =
				UNIT_COLLISION_GROUP
		end
	end

	local connected = {}

	for _, part in ipairs(
		root:GetConnectedParts(true)
	) do
		connected[part] = true
	end

	connected[root] = true

	for _, object in ipairs(
		unit:GetDescendants()
	) do
		if
			object:IsA("BasePart")
			and object ~= root
			and not connected[object]
		then
			object.CanCollide = false
			object.Massless = true

			local weld =
				Instance.new("WeldConstraint")

			weld.Name = "UnitAutoWeld"
			weld.Part0 = root
			weld.Part1 = object
			weld.Parent = root
		end
	end

	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	return true
end

local function applyStats(
	unit: Model,
	stats,
	team: string
): boolean
	local humanoid = getHumanoid(unit)
	local root = getRoot(unit)

	if not humanoid or not root then
		return false
	end

	unit:SetAttribute("Team", team)

	unit:SetAttribute(
		"Damage",
		stats.Damage
	)

	unit:SetAttribute(
		"AttackCooldown",
		stats.AttackCooldown
	)

	unit:SetAttribute(
		"WalkSpeed",
		stats.WalkSpeed
	)

	unit:SetAttribute(
		"Range",
		stats.Range
	)

	unit:SetAttribute(
		"BaseDamage",
		stats.BaseDamage or 100
	)

	unit:SetAttribute(
		"LastAttack",
		0
	)

	humanoid.MaxHealth =
		stats.MaxHealth

	humanoid.Health =
		stats.MaxHealth

	humanoid.WalkSpeed =
		stats.WalkSpeed

	humanoid.AutoRotate = true

	humanoid.Died:Connect(function()
		task.delay(0.5, function()
			if unit.Parent then
				unit:Destroy()
			end
		end)
	end)

	return true
end

local function prepareUnit(
	unit: Model,
	stats,
	team: string
): boolean
	cleanUnit(unit)

	if not preparePhysicalRig(unit) then
		return false
	end

	if not applyStats(
		unit,
		stats,
		team
	) then
		return false
	end

	return true
end

local function placeUnit(
	unit: Model,
	position: Vector3
)
	unit:PivotTo(
		CFrame.new(
			position
				+ Vector3.new(
					0,
					SPAWN_HEIGHT,
					0
				)
		)
	)
end

function UnitService.SetSpawnPositions(
	allyPosition: Vector3,
	enemyPosition: Vector3
)
	allySpawnPosition = allyPosition
	enemySpawnPosition = enemyPosition
end

function UnitService.SetSpawnCallback(
	callback: (Model) -> ()
)
	onUnitSpawned = callback
end

function UnitService.SpawnAlly(
	unitName: string,
	ownerPlayer: Player
): boolean
	if not allySpawnPosition then
		warn(
			"[UnitService] Ally spawn position has not been set"
		)

		return false
	end

	local stats =
		UnitConfig.Allies[unitName]

	if not stats then
		return false
	end

	local template =
		findTemplate(
			storedAllies,
			unitName
		)

	if not template then
		warn(
			"[UnitService] Ally template not found:",
			unitName
		)

		return false
	end

	local unit = template:Clone()

	unit.Name = unitName

	unit:SetAttribute(
		"OwnerUserId",
		ownerPlayer.UserId
	)

	unit:SetAttribute(
		"OwnerName",
		ownerPlayer.Name
	)

	scaleUnit(
		unit,
		stats.Scale
	)

	unit.Parent = alliesFolder

	placeUnit(
		unit,
		allySpawnPosition
	)

	if not prepareUnit(
		unit,
		stats,
		"Ally"
	) then
		unit:Destroy()
		return false
	end

	if onUnitSpawned then
		onUnitSpawned(unit)
	end

	return true
end

function UnitService.SpawnEnemy(
	unitName: string
): Model?
	if not enemySpawnPosition then
		warn(
			"[UnitService] Enemy spawn position has not been set"
		)

		return nil
	end

	local stats =
		UnitConfig.Enemies[unitName]

	if not stats then
		return nil
	end

	local template =
		findTemplate(
			storedEnemies,
			unitName
		)

	if not template then
		warn(
			"[UnitService] Enemy template not found:",
			unitName
		)

		return nil
	end

	local unit = template:Clone()

	unit.Name = unitName

	scaleUnit(
		unit,
		stats.Scale
	)

	unit.Parent = enemiesFolder

	placeUnit(
		unit,
		enemySpawnPosition
	)

	if not prepareUnit(
		unit,
		stats,
		"Enemy"
	) then
		unit:Destroy()
		return nil
	end

	if onUnitSpawned then
		onUnitSpawned(unit)
	end

	return unit
end

function UnitService.GetHumanoid(
	unit: Model
): Humanoid?
	return getHumanoid(unit)
end

function UnitService.GetRoot(
	unit: Model
): BasePart?
	return getRoot(unit)
end

function UnitService.Init()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(
			UNIT_COLLISION_GROUP
		)
	end)
end

return UnitService
