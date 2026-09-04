--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UnitConfig = require(
	ReplicatedStorage
		:WaitForChild("Config")
		:WaitForChild("UnitConfig")
)

local DeploymentService = {}

local unitsFolder = workspace:WaitForChild("Units")
local alliesFolder = unitsFolder:WaitForChild("Allies")

local deployInstance = ReplicatedStorage:FindFirstChild("DeployUnitEvent")

if not deployInstance then
	deployInstance = Instance.new("RemoteEvent")
	deployInstance.Name = "DeployUnitEvent"
	deployInstance.Parent = ReplicatedStorage
end

assert(deployInstance:IsA("RemoteEvent"), "DeployUnitEvent must be a RemoteEvent")

local deployEvent = deployInstance :: RemoteEvent

local cooldownsByPlayer: {
	[Player]: {[string]: number}
} = {}

local spawnHandler: ((string, Player) -> boolean)? = nil
local matchEndedChecker: (() -> boolean)? = nil

local initialized = false

local function isMatchEnded(): boolean
	return matchEndedChecker ~= nil and matchEndedChecker()
end

local function countOwnedUnits(player: Player, unitName: string): number
	local count = 0

	for _, unit in ipairs(alliesFolder:GetChildren()) do
		if unit.Name == unitName
			and unit:GetAttribute("OwnerUserId") == player.UserId
		then
			count += 1
		end
	end

	return count
end

local function updateDeployCount(player: Player, unitName: string)
	local config = UnitConfig.GetAlly(unitName)

	if not config then
		return
	end

	player:SetAttribute(
		`{unitName}Deployed`,
		countOwnedUnits(player, unitName)
	)

	player:SetAttribute(
		`{unitName}DeployLimit`,
		config.DeployLimit
	)
end

local function updateAllDeployCounts(player: Player)
	for unitName in pairs(UnitConfig.Allies) do
		updateDeployCount(player, unitName)
	end
end

local function getCooldowns(player: Player): {[string]: number}
	local playerCooldowns = cooldownsByPlayer[player]

	if not playerCooldowns then
		playerCooldowns = {}
		cooldownsByPlayer[player] = playerCooldowns
	end

	return playerCooldowns
end

local function canDeploy(
	player: Player,
	unitName: unknown
): (boolean, string?)

	if isMatchEnded() then
		return false, "MATCH_ENDED"
	end

	if typeof(unitName) ~= "string" then
		return false, "INVALID_UNIT"
	end

	local config = UnitConfig.GetAlly(unitName)

	if not config then
		return false, "UNKNOWN_UNIT"
	end

	if countOwnedUnits(player, unitName) >= config.DeployLimit then
		return false, "DEPLOY_LIMIT"
	end

	local energyAttribute = player:GetAttribute("Energy")
	local energy = if typeof(energyAttribute) == "number" then energyAttribute else 0

	if energy < config.Cost then
		return false, "NOT_ENOUGH_ENERGY"
	end

	local lastDeploy = getCooldowns(player)[unitName] or 0
	local now = workspace:GetServerTimeNow()

	if now - lastDeploy < config.DeployCooldown then
		return false, "COOLDOWN"
	end

	return true, nil
end

function DeploymentService.SetSpawnHandler(handler: (string, Player) -> boolean)
	spawnHandler = handler
end

function DeploymentService.SetMatchEndedChecker(checker: () -> boolean)
	matchEndedChecker = checker
end

function DeploymentService.TryDeploy(
	player: Player,
	unitName: unknown
): (boolean, string?)

	local allowed, reason = canDeploy(player, unitName)

	if not allowed then
		return false, reason
	end

	if typeof(unitName) ~= "string" then
		return false, "INVALID_UNIT"
	end

	local config = UnitConfig.GetAlly(unitName)

	if not config then
		return false, "UNKNOWN_UNIT"
	end

	if not spawnHandler then
		warn("[DeploymentService] Spawn handler has not been configured")
		return false, "SPAWN_UNAVAILABLE"
	end

	if isMatchEnded() then
		return false, "MATCH_ENDED"
	end

	if not spawnHandler(unitName, player) then
		return false, "SPAWN_FAILED"
	end

	local energyAttribute = player:GetAttribute("Energy")
	local energy = if typeof(energyAttribute) == "number" then energyAttribute else 0

	player:SetAttribute("Energy", math.max(0, energy - config.Cost))

	getCooldowns(player)[unitName] = workspace:GetServerTimeNow()

	updateDeployCount(player, unitName)

	return true, nil
end

function DeploymentService.Init()
	if initialized then
		return
	end

	initialized = true

	for _, player in ipairs(Players:GetPlayers()) do
		updateAllDeployCounts(player)
	end

	Players.PlayerAdded:Connect(updateAllDeployCounts)

	Players.PlayerRemoving:Connect(function(player)
		cooldownsByPlayer[player] = nil
	end)

	alliesFolder.ChildAdded:Connect(function(unit)
		local ownerUserId = unit:GetAttribute("OwnerUserId")

		if typeof(ownerUserId) ~= "number" then
			return
		end

		local player = Players:GetPlayerByUserId(ownerUserId)

		if player then
			updateDeployCount(player, unit.Name)
		end
	end)

	alliesFolder.ChildRemoved:Connect(function(unit)
		local ownerUserId = unit:GetAttribute("OwnerUserId")

		if typeof(ownerUserId) ~= "number" then
			return
		end

		local player = Players:GetPlayerByUserId(ownerUserId)

		if player then
			task.defer(updateDeployCount, player, unit.Name)
		end
	end)

	deployEvent.OnServerEvent:Connect(function(player, unitName)
		DeploymentService.TryDeploy(player, unitName)
	end)
end

return DeploymentService
