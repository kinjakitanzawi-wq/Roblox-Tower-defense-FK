--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UnitConfig = require(
	ReplicatedStorage
		:WaitForChild("Config")
		:WaitForChild("UnitConfig")
)

type AbilityConfig = UnitConfig.AbilityConfig

local AbilityService = {}

local THINK_RATE = 0.10

local unitsFolder = workspace:WaitForChild("Units")
local alliesFolder = unitsFolder:WaitForChild("Allies")
local enemiesFolder = unitsFolder:WaitForChild("Enemies")

local vfxInstance = ReplicatedStorage:FindFirstChild("PlayUnitVFX")

if not vfxInstance then
	vfxInstance = Instance.new("RemoteEvent")
	vfxInstance.Name = "PlayUnitVFX"
	vfxInstance.Parent = ReplicatedStorage
end

assert(vfxInstance:IsA("RemoteEvent"), "PlayUnitVFX must be a RemoteEvent")

local vfxEvent = vfxInstance :: RemoteEvent

local registeredUnits: {[Model]: boolean} = {}
local matchEndedChecker: (() -> boolean)? = nil

local castGeneration = 0
local initialized = false

local function isMatchEnded(): boolean
	return matchEndedChecker ~= nil and matchEndedChecker()
end

local function getHumanoid(unit: Model): Humanoid?
	return unit:FindFirstChildWhichIsA("Humanoid", true)
end

local function getRoot(unit: Model): BasePart?
	local root = unit:FindFirstChild("HumanoidRootPart", true)

	if root and root:IsA("BasePart") then
		return root
	end

	return nil
end

local function isEnemyAlive(enemy: Model): boolean
	local humanoid = getHumanoid(enemy)
	local root = getRoot(enemy)

	return humanoid ~= nil
		and root ~= nil
		and humanoid.Health > 0
end

local function faceTarget(unit: Model, target: Model)
	local root = getRoot(unit)
	local targetRoot = getRoot(target)

	if not root or not targetRoot then
		return
	end

	local lookPosition = Vector3.new(
		targetRoot.Position.X,
		root.Position.Y,
		targetRoot.Position.Z
	)

	if (lookPosition - root.Position).Magnitude <= 0.01 then
		return
	end

	root.CFrame = CFrame.lookAt(root.Position, lookPosition)
end

local function findNearestEnemy(position: Vector3, maxRange: number): Model?
	local nearest: Model? = nil
	local nearestDistance = math.huge

	for _, instance in ipairs(enemiesFolder:GetChildren()) do
		if not instance:IsA("Model") or not isEnemyAlive(instance) then
			continue
		end

		local root = getRoot(instance)

		if not root then
			continue
		end

		local distance = (root.Position - position).Magnitude

		if distance <= maxRange and distance < nearestDistance then
			nearest = instance
			nearestDistance = distance
		end
	end

	return nearest
end

local function getEnemiesInRadius(position: Vector3, radius: number): {Model}
	local enemies: {Model} = {}

	for _, instance in ipairs(enemiesFolder:GetChildren()) do
		if not instance:IsA("Model") or not isEnemyAlive(instance) then
			continue
		end

		local root = getRoot(instance)

		if root and (root.Position - position).Magnitude <= radius then
			table.insert(enemies, instance)
		end
	end

	return enemies
end

local function getEnemiesInCone(
	position: Vector3,
	direction: Vector3,
	maxRange: number,
	coneAngle: number
): {Model}

	local enemies: {Model} = {}

	local flatDirection = Vector3.new(direction.X, 0, direction.Z)

	if flatDirection.Magnitude <= 0.001 then
		return enemies
	end

	local forward = flatDirection.Unit
	local minimumDot = math.cos(math.rad(coneAngle * 0.5))

	for _, instance in ipairs(enemiesFolder:GetChildren()) do
		if not instance:IsA("Model") or not isEnemyAlive(instance) then
			continue
		end

		local root = getRoot(instance)

		if not root then
			continue
		end

		local offset = root.Position - position
		local flatOffset = Vector3.new(offset.X, 0, offset.Z)
		local distance = flatOffset.Magnitude

		if distance <= 0.001 or distance > maxRange then
			continue
		end

		if forward:Dot(flatOffset.Unit) >= minimumDot then
			table.insert(enemies, instance)
		end
	end

	return enemies
end

local function damageEnemy(enemy: Model, damage: number)
	if isMatchEnded() then
		return
	end

	local humanoid = getHumanoid(enemy)

	if humanoid and humanoid.Health > 0 then
		humanoid:TakeDamage(damage)
	end
end

local function calculateDamage(unit: Model, ability: AbilityConfig): number
	local damage = unit:GetAttribute("Damage")
	local baseDamage = if typeof(damage) == "number" then damage else 0

	return baseDamage * (ability.DamageMultiplier or 1)
end

local function playVFX(unit: Model, ability: AbilityConfig, position: Vector3)
	if isMatchEnded() then
		return
	end

	vfxEvent:FireAllClients(unit, ability.Name, position, {
		VFXDuration = ability.VFXDuration,
		VFXYaw = ability.VFXYaw,
		SkyHeight = ability.SkyHeight,
		FallTime = ability.FallTime,
		ImpactHoldTime = ability.ImpactHoldTime,
	})
end

local function isCastValid(unit: Model, generation: number): boolean
	return generation == castGeneration
		and registeredUnits[unit] == true
		and unit.Parent ~= nil
		and not isMatchEnded()
end

local function useTargetAOE(unit: Model, ability: AbilityConfig): boolean
	if isMatchEnded() then
		return false
	end

	local root = getRoot(unit)

	if not root then
		return false
	end

	local range = ability.CastRange or unit:GetAttribute("Range") or 10

	if typeof(range) ~= "number" then
		return false
	end

	local target = findNearestEnemy(root.Position, range)

	if not target then
		return false
	end

	local targetRoot = getRoot(target)

	if not targetRoot then
		return false
	end

	faceTarget(unit, target)

	local impactPosition = targetRoot.Position
	local damage = calculateDamage(unit, ability)
	local radius = ability.Radius or 4

	playVFX(unit, ability, impactPosition)

	for _, enemy in ipairs(getEnemiesInRadius(impactPosition, radius)) do
		damageEnemy(enemy, damage)
	end

	return true
end

local function useSkyDrop(unit: Model, ability: AbilityConfig): boolean
	if isMatchEnded() then
		return false
	end

	local root = getRoot(unit)

	if not root then
		return false
	end

	local range = ability.CastRange or unit:GetAttribute("Range") or 10

	if typeof(range) ~= "number" then
		return false
	end

	local target = findNearestEnemy(root.Position, range)

	if not target then
		return false
	end

	local targetRoot = getRoot(target)

	if not targetRoot then
		return false
	end

	faceTarget(unit, target)

	local impactPosition = targetRoot.Position
	local damage = calculateDamage(unit, ability)
	local radius = ability.Radius or 6
	local fallTime = ability.FallTime or 0.65
	local generation = castGeneration

	playVFX(unit, ability, impactPosition)

	task.delay(fallTime, function()
		if not isCastValid(unit, generation) then
			return
		end

		for _, enemy in ipairs(getEnemiesInRadius(impactPosition, radius)) do
			damageEnemy(enemy, damage)
		end
	end)

	return true
end

local function useCone(unit: Model, ability: AbilityConfig): boolean
	if isMatchEnded() then
		return false
	end

	local root = getRoot(unit)

	if not root then
		return false
	end

	local range = ability.CastRange or unit:GetAttribute("Range") or 10

	if typeof(range) ~= "number" then
		return false
	end

	local target = findNearestEnemy(root.Position, range)

	if not target then
		return false
	end

	local targetRoot = getRoot(target)

	if not targetRoot then
		return false
	end

	faceTarget(unit, target)

	local direction = targetRoot.Position - root.Position
	local damage = calculateDamage(unit, ability)
	local coneAngle = ability.ConeAngle or 40
	local hitDelay = ability.HitDelay or 0
	local generation = castGeneration

	playVFX(unit, ability, targetRoot.Position)

	task.delay(hitDelay, function()
		if not isCastValid(unit, generation) then
			return
		end

		local currentRoot = getRoot(unit)

		if not currentRoot then
			return
		end

		for _, enemy in ipairs(
			getEnemiesInCone(
				currentRoot.Position,
				direction,
				range,
				coneAngle
			)
		) do
			damageEnemy(enemy, damage)
		end
	end)

	return true
end

local abilityHandlers: {
	[string]: (Model, AbilityConfig) -> boolean
} = {
	[UnitConfig.AbilityTypes.TargetAOE] = useTargetAOE,
	[UnitConfig.AbilityTypes.SkyDrop] = useSkyDrop,
	[UnitConfig.AbilityTypes.Cone] = useCone,
}

function AbilityService.SetMatchEndedChecker(checker: () -> boolean)
	matchEndedChecker = checker
end

function AbilityService.UseAbility(unit: Model, ability: AbilityConfig): boolean
	if isMatchEnded() then
		return false
	end

	local handler = abilityHandlers[ability.Type]

	if not handler then
		warn(`[AbilityService] Unknown ability type: {ability.Type}`)
		return false
	end

	return handler(unit, ability)
end

function AbilityService.RegisterUnit(unit: Model)
	if registeredUnits[unit] or isMatchEnded() then
		return
	end

	local unitData = UnitConfig.GetAlly(unit.Name)

	if not unitData or #unitData.Abilities == 0 then
		return
	end

	registeredUnits[unit] = true
	unit:SetAttribute("AbilitySystemHooked", true)

	task.spawn(function()
		local humanoid: Humanoid? = nil
		local root: BasePart? = nil
		local startedAt = os.clock()

		while registeredUnits[unit]
			and unit.Parent
			and not isMatchEnded()
			and os.clock() - startedAt < 5
		do
			humanoid = getHumanoid(unit)
			root = getRoot(unit)

			if humanoid and root and unit:GetAttribute("Damage") ~= nil then
				break
			end

			task.wait(0.05)
		end

		if not humanoid
			or not root
			or not registeredUnits[unit]
			or isMatchEnded()
		then
			AbilityService.UnregisterUnit(unit)
			return
		end

		local lastUsed: {[number]: number} = {}

		for index in ipairs(unitData.Abilities) do
			lastUsed[index] = 0
		end

		while registeredUnits[unit]
			and unit.Parent
			and humanoid.Health > 0
			and not isMatchEnded()
		do
			task.wait(THINK_RATE)

			if not registeredUnits[unit] or isMatchEnded() then
				break
			end

			local now = workspace:GetServerTimeNow()

			for index, ability in ipairs(unitData.Abilities) do
				if now - lastUsed[index] < ability.Cooldown then
					continue
				end

				if AbilityService.UseAbility(unit, ability) then
					lastUsed[index] = now
					break
				end
			end
		end

		AbilityService.UnregisterUnit(unit)
	end)
end

function AbilityService.UnregisterUnit(unit: Model)
	if not registeredUnits[unit] then
		return
	end

	registeredUnits[unit] = nil

	if unit.Parent then
		unit:SetAttribute("AbilitySystemHooked", false)
	end
end

function AbilityService.CancelAll()
	castGeneration += 1

	local unitsToRemove: {Model} = {}

	for unit in pairs(registeredUnits) do
		table.insert(unitsToRemove, unit)
	end

	for _, unit in ipairs(unitsToRemove) do
		AbilityService.UnregisterUnit(unit)
	end
end

function AbilityService.Init()
	if initialized then
		return
	end

	initialized = true

	for _, instance in ipairs(alliesFolder:GetChildren()) do
		if instance:IsA("Model") then
			AbilityService.RegisterUnit(instance)
		end
	end

	alliesFolder.ChildAdded:Connect(function(instance)
		if instance:IsA("Model") then
			AbilityService.RegisterUnit(instance)
		end
	end)

	alliesFolder.ChildRemoved:Connect(function(instance)
		if instance:IsA("Model") then
			AbilityService.UnregisterUnit(instance)
		end
	end)
end

return AbilityService
