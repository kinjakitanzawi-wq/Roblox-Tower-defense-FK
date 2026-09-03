--!strict

local MatchService = {}

local BASE_MAX_HEALTH = 2000

local map: Instance? = nil
local matchEnded = false

local stopUnitsHandler: (() -> ())? = nil
local matchEndedCallbacks = {}

local function requireMap(): Instance
	if not map then
		error(
			"[MatchService] Map has not been configured"
		)
	end

	return map
end

local function getHealthAttribute(
	team: string
): string?
	if team == "Ally" then
		return "AllyBaseHealth"
	end

	if team == "Enemy" then
		return "EnemyBaseHealth"
	end

	return nil
end

local function getMaxHealthAttribute(
	team: string
): string?
	if team == "Ally" then
		return "AllyBaseMaxHealth"
	end

	if team == "Enemy" then
		return "EnemyBaseMaxHealth"
	end

	return nil
end

local function runMatchEndedCallbacks(
	winner: string
)
	for _, callback in ipairs(
		matchEndedCallbacks
	) do
		local success, message =
			pcall(
				callback,
				winner
			)

		if not success then
			warn(
				"[MatchService] Match-ended callback failed:",
				message
			)
		end
	end
end

function MatchService.SetMap(
	mapInstance: Instance
)
	map = mapInstance
end

function MatchService.SetStopUnitsHandler(
	handler: () -> ()
)
	stopUnitsHandler = handler
end

function MatchService.OnMatchEnded(
	callback: (string) -> ()
)
	table.insert(
		matchEndedCallbacks,
		callback
	)
end

function MatchService.IsEnded(): boolean
	return matchEnded
end

function MatchService.GetWinner(): string
	local currentMap = requireMap()

	local winner =
		currentMap:GetAttribute("Winner")

	if typeof(winner) == "string" then
		return winner
	end

	return ""
end

function MatchService.GetBaseHealth(
	team: string
): number
	local currentMap = requireMap()

	local attribute =
		getHealthAttribute(team)

	if not attribute then
		return 0
	end

	local health =
		currentMap:GetAttribute(attribute)

	if typeof(health) ~= "number" then
		return 0
	end

	return health
end

function MatchService.GetBaseMaxHealth(
	team: string
): number
	local currentMap = requireMap()

	local attribute =
		getMaxHealthAttribute(team)

	if not attribute then
		return 0
	end

	local maximum =
		currentMap:GetAttribute(attribute)

	if typeof(maximum) ~= "number" then
		return 0
	end

	return maximum
end

function MatchService.EndMatch(
	winner: string
)
	if matchEnded then
		return
	end

	if
		winner ~= "Ally"
		and winner ~= "Enemy"
	then
		warn(
			"[MatchService] Invalid winner:",
			winner
		)

		return
	end

	matchEnded = true

	local currentMap = requireMap()

	currentMap:SetAttribute(
		"Winner",
		winner
	)

	if winner == "Ally" then
		currentMap:SetAttribute(
			"WaveStatus",
			"Victory"
		)
	else
		currentMap:SetAttribute(
			"WaveStatus",
			"Defeat"
		)
	end

	currentMap:SetAttribute(
		"WaveCountdown",
		0
	)

	if stopUnitsHandler then
		stopUnitsHandler()
	end

	runMatchEndedCallbacks(winner)
end

function MatchService.DamageBase(
	team: string,
	damage: number
)
	if matchEnded then
		return
	end

	if
		team ~= "Ally"
		and team ~= "Enemy"
	then
		return
	end

	if damage <= 0 then
		return
	end

	local currentMap = requireMap()

	local attribute =
		getHealthAttribute(team)

	if not attribute then
		return
	end

	local health =
		MatchService.GetBaseHealth(team)

	local remaining =
		math.max(
			0,
			health - damage
		)

	currentMap:SetAttribute(
		attribute,
		remaining
	)

	if remaining > 0 then
		return
	end

	if team == "Ally" then
		MatchService.EndMatch("Enemy")
	else
		MatchService.EndMatch("Ally")
	end
end

function MatchService.Reset(
	baseMaxHealth: number?
)
	local currentMap = requireMap()

	local maximum =
		baseMaxHealth
		or BASE_MAX_HEALTH

	maximum = math.max(
		1,
		maximum
	)

	matchEnded = false

	currentMap:SetAttribute(
		"AllyBaseMaxHealth",
		maximum
	)

	currentMap:SetAttribute(
		"EnemyBaseMaxHealth",
		maximum
	)

	currentMap:SetAttribute(
		"AllyBaseHealth",
		maximum
	)

	currentMap:SetAttribute(
		"EnemyBaseHealth",
		maximum
	)

	currentMap:SetAttribute(
		"Winner",
		""
	)

	currentMap:SetAttribute(
		"WaveStatus",
		"Preparing"
	)

	currentMap:SetAttribute(
		"WaveCountdown",
		0
	)
end

function MatchService.Init()
	if not map then
		error(
			"[MatchService] Call SetMap() before Init()"
		)
	end

	MatchService.Reset()
end

return MatchService
