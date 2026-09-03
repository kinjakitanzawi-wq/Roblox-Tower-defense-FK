--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WaveConfig = require(
	ReplicatedStorage
		:WaitForChild("Config")
		:WaitForChild("WaveConfig")
)

local WaveService = {}

local map: Instance? = nil
local enemiesFolder: Folder? = nil

local spawnEnemyHandler: ((string) -> any)? = nil
local matchEndedChecker: (() -> boolean)? = nil
local waveCompletedCallback: ((number, any) -> ())? = nil
local allWavesCompletedCallback: (() -> ())? = nil

local running = false

local function isMatchEnded(): boolean
	if matchEndedChecker then
		return matchEndedChecker()
	end

	return false
end

local function requireMap(): Instance
	if not map then
		error("[WaveService] Map is not configured")
	end

	return map
end

local function requireEnemiesFolder(): Folder
	if not enemiesFolder then
		error("[WaveService] Enemies folder is not configured")
	end

	return enemiesFolder
end

local function runCountdown(
	seconds: number,
	status: string
): boolean
	local currentMap = requireMap()

	currentMap:SetAttribute(
		"WaveStatus",
		status
	)

	for remaining = seconds, 1, -1 do
		if isMatchEnded() then
			return false
		end

		currentMap:SetAttribute(
			"WaveCountdown",
			remaining
		)

		task.wait(1)
	end

	currentMap:SetAttribute(
		"WaveCountdown",
		0
	)

	return not isMatchEnded()
end

local function spawnWave(
	waveData
): boolean
	if not spawnEnemyHandler then
		warn(
			"[WaveService] Enemy spawn handler is not configured"
		)

		return false
	end

	for _, group in ipairs(waveData) do
		local enemyName =
			group.Enemy

		local amount =
			group.Amount or 1

		local spawnDelay =
			group.SpawnDelay or 1

		for number = 1, amount do
			if isMatchEnded() then
				return false
			end

			spawnEnemyHandler(enemyName)

			if number < amount then
				task.wait(spawnDelay)
			end
		end
	end

	return true
end

local function waitForWaveClear(): boolean
	local folder =
		requireEnemiesFolder()

	while
		not isMatchEnded()
		and #folder:GetChildren() > 0
	do
		task.wait(0.25)
	end

	return not isMatchEnded()
end

function WaveService.SetMap(
	mapInstance: Instance
)
	map = mapInstance
end

function WaveService.SetEnemiesFolder(
	folder: Folder
)
	enemiesFolder = folder
end

function WaveService.SetSpawnEnemyHandler(
	handler: (string) -> any
)
	spawnEnemyHandler = handler
end

function WaveService.SetMatchEndedChecker(
	checker: () -> boolean
)
	matchEndedChecker = checker
end

function WaveService.OnWaveCompleted(
	callback: (number, any) -> ()
)
	waveCompletedCallback = callback
end

function WaveService.OnAllWavesCompleted(
	callback: () -> ()
)
	allWavesCompletedCallback = callback
end

function WaveService.Start()
	if running then
		return
	end

	running = true

	local currentMap =
		requireMap()

	currentMap:SetAttribute(
		"CurrentWave",
		0
	)

	currentMap:SetAttribute(
		"MaxWaves",
		#WaveConfig.Waves
	)

	currentMap:SetAttribute(
		"EnemiesRemaining",
		0
	)

	local survivedStart =
		runCountdown(
			WaveConfig.StartDelay,
			"Preparing"
		)

	if not survivedStart then
		running = false
		return
	end

	for waveNumber, waveData in ipairs(
		WaveConfig.Waves
	) do
		if isMatchEnded() then
			break
		end

		currentMap:SetAttribute(
			"CurrentWave",
			waveNumber
		)

		currentMap:SetAttribute(
			"WaveStatus",
			"Spawning"
		)

		currentMap:SetAttribute(
			"WaveCountdown",
			0
		)

		local spawned =
			spawnWave(waveData)

		if not spawned then
			break
		end

		currentMap:SetAttribute(
			"WaveStatus",
			"Fighting"
		)

		local survivedWave =
			waitForWaveClear()

		if not survivedWave then
			break
		end

		if waveCompletedCallback then
			waveCompletedCallback(
				waveNumber,
				waveData
			)
		end

		if
			waveNumber
			>= #WaveConfig.Waves
		then
			currentMap:SetAttribute(
				"WaveStatus",
				"Complete"
			)

			currentMap:SetAttribute(
				"WaveCountdown",
				0
			)

			if allWavesCompletedCallback then
				allWavesCompletedCallback()
			end

			break
		end

		local survivedIntermission =
			runCountdown(
				WaveConfig.Intermission,
				"Intermission"
			)

		if not survivedIntermission then
			break
		end
	end

	running = false
end

function WaveService.IsRunning(): boolean
	return running
end

return WaveService
