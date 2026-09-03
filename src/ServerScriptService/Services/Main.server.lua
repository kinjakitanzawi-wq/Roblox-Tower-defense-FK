--!strict

local ServerScriptService =
	game:GetService("ServerScriptService")

local services =
	ServerScriptService:WaitForChild("Services")

local UnitService =
	require(services:WaitForChild("UnitService"))

local UnitAIService =
	require(services:WaitForChild("UnitAIService"))

local AbilityService =
	require(services:WaitForChild("AbilityService"))

local DeploymentService =
	require(services:WaitForChild("DeploymentService"))

local MatchService =
	require(services:WaitForChild("MatchService"))

local WaveService =
	require(services:WaitForChild("WaveService"))

local map =
	workspace:WaitForChild("The City of Atlantis")

local waypointFolder =
	map:FindFirstChild(
		"Waypoints",
		true
	)

if not waypointFolder then
	error("[Main] Waypoints folder not found")
end

local unitsFolder =
	workspace:WaitForChild("Units")

local alliesFolder =
	unitsFolder:WaitForChild("Allies")

local enemiesFolder =
	unitsFolder:WaitForChild("Enemies")

local waypoints = {}

for _, waypoint in ipairs(
	waypointFolder:GetChildren()
) do
	if tonumber(waypoint.Name) then
		table.insert(
			waypoints,
			waypoint
		)
	end
end

table.sort(
	waypoints,
	function(a, b)
		return
			tonumber(a.Name)
			< tonumber(b.Name)
	end
)

if #waypoints == 0 then
	error("[Main] No numbered waypoints found")
end

local function getWaypointPosition(
	waypoint: Instance
): Vector3
	if waypoint:IsA("BasePart") then
		return waypoint.Position
	end

	if waypoint:IsA("Model") then
		return waypoint:GetPivot().Position
	end

	if waypoint:IsA("Attachment") then
		return waypoint.WorldPosition
	end

	error("[Main] Unsupported waypoint type")
end

local allySpawn =
	getWaypointPosition(
		waypoints[1]
	)

local enemySpawn =
	getWaypointPosition(
		waypoints[#waypoints]
	)

UnitService.Init()

UnitService.SetSpawnPositions(
	allySpawn,
	enemySpawn
)

UnitAIService.SetWaypoints(
	waypoints
)

MatchService.SetMap(map)

MatchService.SetStopUnitsHandler(
	UnitAIService.StopAll
)

MatchService.Init()

UnitAIService.SetBaseDamageHandler(
	MatchService.DamageBase
)

UnitAIService.SetMatchEndedChecker(
	MatchService.IsEnded
)

DeploymentService.SetSpawnHandler(
	UnitService.SpawnAlly
)

UnitService.SetSpawnCallback(
	function(unit)
		UnitAIService.RegisterUnit(unit)

		if
			unit:GetAttribute("Team")
			== "Ally"
		then
			AbilityService.RegisterUnit(unit)
		end
	end
)

AbilityService.Init()
DeploymentService.Init()

WaveService.SetMap(map)

WaveService.SetEnemiesFolder(
	enemiesFolder
)

WaveService.SetSpawnEnemyHandler(
	UnitService.SpawnEnemy
)

WaveService.SetMatchEndedChecker(
	MatchService.IsEnded
)

WaveService.OnAllWavesCompleted(
	function()
		if not MatchService.IsEnded() then
			MatchService.EndMatch("Ally")
		end
	end
)

task.spawn(function()
	WaveService.Start()
end)
