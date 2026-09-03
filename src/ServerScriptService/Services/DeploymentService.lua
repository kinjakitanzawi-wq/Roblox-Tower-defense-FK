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

local deployEvent = ReplicatedStorage:FindFirstChild("DeployUnitEvent")

if not deployEvent then
	deployEvent = Instance.new("RemoteEvent")
	deployEvent.Name = "DeployUnitEvent"
	deployEvent.Parent = ReplicatedStorage
end

local playerCooldowns: {
	[Player]: { [string]: number }
} = {}

local spawnHandler: ((string, Player) -> boolean)? = nil

local function countOwnedUnits(
	player: Player,
	unitName: string
): number
	local count = 0

	for _, unit in ipairs(alliesFolder:GetChildren()) do
		if
			unit.Name == unitName
			and unit:GetAttribute("OwnerUserId") == player.UserId
		then
			count += 1
		end
	end

	return count
end

local function updateDeployCount(
	player: Player,
	unitName: string
)
	local config = UnitConfig.Allies[unitName]

	if not config then
		return
	end

	local deployed = countOwnedUnits(
		player,
		unitName
	)

	player:SetAttribute(
		unitName .. "Deployed",
		deployed
	)

	player:SetAttribute(
		unitName .. "DeployLimit",
		config.DeployLimit
	)
end

local function updateAllDeployCounts(
	player: Player
)
	for unitName in pairs(UnitConfig.Allies) do
		updateDeployCount(
			player,
			unitName
		)
	end
end

local function getCooldownTable(
	player: Player
): { [string]: number }
	local cooldowns = playerCooldowns[player]

	if cooldowns then
		return cooldowns
	end

	cooldowns = {}
	playerCooldowns[player] = cooldowns

	return cooldowns
end

local function canDeploy(
	player: Player,
	unitName: string
): (boolean, any)
	if typeof(unitName) ~= "string" then
		return false, nil
	end

	local config = UnitConfig.Allies[unitName]

	if not config then
		return false, nil
	end

	local deployed = countOwnedUnits(
		player,
		unitName
	)

	if deployed >= config.DeployLimit then
		updateDeployCount(
			player,
			unitName
		)

		return false, config
	end

	local energy =
		player:GetAttribute("Energy")
		or 0

	if energy < config.Cost then
		return false, config
	end

	local cooldowns =
		getCooldownTable(player)

	local lastDeploy =
		cooldowns[unitName]
		or 0

	local now =
		workspace:GetServerTimeNow()

	if
		now - lastDeploy
		< config.DeployCooldown
	then
		return false, config
	end

	return true, config
end

function DeploymentService.SetSpawnHandler(
	handler: (string, Player) -> boolean
)
	spawnHandler = handler
end

function DeploymentService.TryDeploy(
	player: Player,
	unitName: string
): boolean
	local allowed, config =
		canDeploy(
			player,
			unitName
		)

	if not allowed or not config then
		return false
	end

	if not spawnHandler then
		warn(
			"[DeploymentService] Spawn handler has not been registered"
		)

		return false
	end

	local spawned =
		spawnHandler(
			unitName,
			player
		)

	if not spawned then
		return false
	end

	local energy =
		player:GetAttribute("Energy")
		or 0

	player:SetAttribute(
		"Energy",
		math.max(
			0,
			energy - config.Cost
		)
	)

	local cooldowns =
		getCooldownTable(player)

	cooldowns[unitName] =
		workspace:GetServerTimeNow()

	updateDeployCount(
		player,
		unitName
	)

	return true
end

function DeploymentService.Init()
	for _, player in ipairs(
		Players:GetPlayers()
	) do
		updateAllDeployCounts(player)
	end

	Players.PlayerAdded:Connect(
		function(player)
			updateAllDeployCounts(player)
		end
	)

	Players.PlayerRemoving:Connect(
		function(player)
			playerCooldowns[player] = nil
		end
	)

	alliesFolder.ChildAdded:Connect(
		function()
			for _, player in ipairs(
				Players:GetPlayers()
			) do
				task.defer(
					updateAllDeployCounts,
					player
				)
			end
		end
	)

	alliesFolder.ChildRemoved:Connect(
		function()
			for _, player in ipairs(
				Players:GetPlayers()
			) do
				task.defer(
					updateAllDeployCounts,
					player
				)
			end
		end
	)

	deployEvent.OnServerEvent:Connect(
		function(
			player,
			unitName
		)
			if typeof(unitName) ~= "string" then
				return
			end

			DeploymentService.TryDeploy(
				player,
				unitName
			)
		end
	)
end

return DeploymentService
