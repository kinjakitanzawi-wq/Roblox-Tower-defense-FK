--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UnitConfig = require(
	ReplicatedStorage
		:WaitForChild("Config")
		:WaitForChild("UnitConfig")
)

local AbilityService = {}

local THINK_RATE = 0.10

local unitsFolder = workspace:WaitForChild("Units")
local alliesFolder = unitsFolder:WaitForChild("Allies")
local enemiesFolder = unitsFolder:WaitForChild("Enemies")

local vfxEvent = ReplicatedStorage:FindFirstChild("PlayUnitVFX")

if not vfxEvent then
	vfxEvent = Instance.new("RemoteEvent")
	vfxEvent.Name = "PlayUnitVFX"
	vfxEvent.Parent = ReplicatedStorage
end

local registeredUnits = {}

local function getHumanoid(unit)
	if not unit then
		return nil
	end

	return unit:FindFirstChildWhichIsA("Humanoid", true)
end

local function getRoot(unit)
	if not unit then
		return nil
	end

	return unit:FindFirstChild("HumanoidRootPart", true)
end

local function isEnemyAlive(enemy)
	if not enemy or not enemy.Parent then
		return false
	end

	local humanoid = getHumanoid(enemy)
	local root = getRoot(enemy)

	return humanoid ~= nil
		and root ~= nil
		and humanoid.Health > 0
end

local function faceTarget(unit, target)
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

	root.CFrame = CFrame.lookAt(
		root.Position,
		lookPosition
	)
end

local function findNearestEnemy(position, maxRange)
	local nearestEnemy = nil
	local nearestDistance = math.huge

	for _, enemy in ipairs(enemiesFolder:GetChildren()) do
		if not isEnemyAlive(enemy) then
			continue
		end

		local root = getRoot(enemy)

		if not root then
			continue
		end

		local distance = (
			root.Position - position
		).Magnitude

		if distance <= maxRange and distance < nearestDistance then
			nearestEnemy = enemy
			nearestDistance = distance
		end
	end

	return nearestEnemy
end

local function getEnemiesInRadius(position, radius)
	local result = {}

	for _, enemy in ipairs(enemiesFolder:GetChildren()) do
		if not isEnemyAlive(enemy) then
			continue
		end

		local root = getRoot(enemy)

		if not root then
			continue
		end

		local distance = (
			root.Position - position
		).Magnitude

		if distance <= radius then
			table.insert(result, enemy)
		end
	end

	return result
end

local function getEnemiesInCone(
	origin,
	direction,
	range,
	coneAngle
)
	local result = {}

	local flatDirection = Vector3.new(
		direction.X,
		0,
		direction.Z
	)

	if flatDirection.Magnitude <= 0.01 then
		return result
	end

	flatDirection = flatDirection.Unit

	local minimumDot = math.cos(
		math.rad(coneAngle * 0.5)
	)

	for _, enemy in ipairs(enemiesFolder:GetChildren()) do
		if not isEnemyAlive(enemy) then
			continue
		end

		local root = getRoot(enemy)

		if not root then
			continue
		end

		local offset = root.Position - origin

		local flatOffset = Vector3.new(
			offset.X,
			0,
			offset.Z
		)

		local distance = flatOffset.Magnitude

		if distance <= 0.01 or distance > range then
			continue
		end

		local enemyDirection = flatOffset.Unit
		local dot = flatDirection:Dot(enemyDirection)

		if dot >= minimumDot then
			table.insert(result, enemy)
		end
	end

	return result
end

local function damageEnemy(enemy, damage)
	if damage <= 0 then
		return
	end

	local humanoid = getHumanoid(enemy)

	if not humanoid or humanoid.Health <= 0 then
		return
	end

	humanoid:TakeDamage(damage)
end

local function calculateDamage(unit, ability)
	local baseDamage =
		unit:GetAttribute("Damage")
		or 10

	local multiplier =
		ability.DamageMultiplier
		or 1

	return math.max(
		0,
		math.floor(baseDamage * multiplier)
	)
end

local function playVFX(unit, ability, position)
	vfxEvent:FireAllClients(
		unit,
		ability.Name,
		position,
		{
			VFXDuration = ability.VFXDuration or 1,
			VFXYaw = ability.VFXYaw or 0,

			SkyHeight = ability.SkyHeight or 30,
			FallTime = ability.FallTime or 0.65,
			ImpactHoldTime = ability.ImpactHoldTime or 0.15,
		}
	)
end

local function useTargetAOE(unit, ability)
	local root = getRoot(unit)

	if not root then
		return false
	end

	local range =
		ability.CastRange
		or unit:GetAttribute("Range")
		or 10

	local target = findNearestEnemy(
		root.Position,
		range
	)

	if not target then
		return false
	end

	local targetRoot = getRoot(target)

	if not targetRoot then
		return false
	end

	faceTarget(unit, target)

	local impactPosition = targetRoot.Position

	playVFX(
		unit,
		ability,
		impactPosition
	)

	local damage = calculateDamage(
		unit,
		ability
	)

	local radius = ability.Radius or 4

	for _, enemy in ipairs(
		getEnemiesInRadius(
			impactPosition,
			radius
		)
	) do
		damageEnemy(
			enemy,
			damage
		)
	end

	return true
end

local function useSkyDrop(unit, ability)
	local root = getRoot(unit)

	if not root then
		return false
	end

	local range =
		ability.CastRange
		or unit:GetAttribute("Range")
		or 10

	local target = findNearestEnemy(
		root.Position,
		range
	)

	if not target then
		return false
	end

	local targetRoot = getRoot(target)

	if not targetRoot then
		return false
	end

	faceTarget(unit, target)

	local impactPosition = targetRoot.Position

	playVFX(
		unit,
		ability,
		impactPosition
	)

	local damage = calculateDamage(
		unit,
		ability
	)

	local radius = ability.Radius or 6
	local fallTime = ability.FallTime or 0.65

	task.delay(fallTime, function()
		for _, enemy in ipairs(
			getEnemiesInRadius(
				impactPosition,
				radius
			)
		) do
			damageEnemy(
				enemy,
				damage
			)
		end
	end)

	return true
end

local function useCone(unit, ability)
	local root = getRoot(unit)

	if not root then
		return false
	end

	local range =
		ability.CastRange
		or unit:GetAttribute("Range")
		or 10

	local target = findNearestEnemy(
		root.Position,
		range
	)

	if not target then
		return false
	end

	local targetRoot = getRoot(target)

	if not targetRoot then
		return false
	end

	faceTarget(unit, target)

	local direction =
		targetRoot.Position
		- root.Position

	playVFX(
		unit,
		ability,
		targetRoot.Position
	)

	local damage = calculateDamage(
		unit,
		ability
	)

	local coneAngle =
		ability.ConeAngle
		or 40

	local hitDelay =
		ability.HitDelay
		or 0

	task.delay(hitDelay, function()
		if not unit.Parent then
			return
		end

		local currentRoot = getRoot(unit)

		if not currentRoot then
			return
		end

		local enemies = getEnemiesInCone(
			currentRoot.Position,
			direction,
			range,
			coneAngle
		)

		for _, enemy in ipairs(enemies) do
			damageEnemy(
				enemy,
				damage
			)
		end
	end)

	return true
end

local abilityHandlers = {
	TARGET_AOE = useTargetAOE,
	SKY_DROP = useSkyDrop,
	CONE = useCone,
}

function AbilityService.UseAbility(
	unit,
	ability
)
	if not unit or not ability then
		return false
	end

	local handler =
		abilityHandlers[ability.Type]

	if not handler then
		warn(
			"[AbilityService] Unknown ability type:",
			ability.Type
		)

		return false
	end

	return handler(
		unit,
		ability
	)
end

function AbilityService.RegisterUnit(unit)
	if not unit:IsA("Model") then
		return
	end

	if registeredUnits[unit] then
		return
	end

	local unitData =
		UnitConfig.Allies[unit.Name]

	if not unitData then
		return
	end

	local abilities =
		unitData.Abilities

	if not abilities or #abilities == 0 then
		return
	end

	registeredUnits[unit] = true

	task.spawn(function()
		local humanoid
		local root

		local started = os.clock()

		while
			unit.Parent
			and os.clock() - started < 5
		do
			humanoid = getHumanoid(unit)
			root = getRoot(unit)

			if
				humanoid
				and root
				and unit:GetAttribute("Damage") ~= nil
			then
				break
			end

			task.wait(0.05)
		end

		if
			not unit.Parent
			or not humanoid
			or not root
		then
			registeredUnits[unit] = nil
			return
		end

		local lastUsed = {}

		for index in ipairs(abilities) do
			lastUsed[index] = 0
		end

		while
			unit.Parent
			and humanoid.Health > 0
		do
			task.wait(THINK_RATE)

			local now =
				workspace:GetServerTimeNow()

			for index, ability in ipairs(abilities) do
				local cooldown =
					ability.Cooldown
					or 1

				if
					now - lastUsed[index]
					< cooldown
				then
					continue
				end

				local success =
					AbilityService.UseAbility(
						unit,
						ability
					)

				if success then
					lastUsed[index] = now
					break
				end
			end
		end

		registeredUnits[unit] = nil
	end)
end

function AbilityService.UnregisterUnit(unit)
	registeredUnits[unit] = nil
end

function AbilityService.Init()
	for _, unit in ipairs(
		alliesFolder:GetChildren()
	) do
		AbilityService.RegisterUnit(unit)
	end

	alliesFolder.ChildAdded:Connect(
		function(unit)
			AbilityService.RegisterUnit(unit)
		end
	)

	alliesFolder.ChildRemoved:Connect(
		function(unit)
			AbilityService.UnregisterUnit(unit)
		end
	)
end

return AbilityService
