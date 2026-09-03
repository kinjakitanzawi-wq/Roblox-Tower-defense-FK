--!strict

local UnitService = require(
	script.Parent:WaitForChild("UnitService")
)

local UnitAIService = {}

local THINK_RATE = 0.20
local WAYPOINT_REACHED_DISTANCE = 4

local unitsFolder = workspace:WaitForChild("Units")
local alliesFolder = unitsFolder:WaitForChild("Allies")
local enemiesFolder = unitsFolder:WaitForChild("Enemies")

local waypoints: { Instance } = {}

local registeredUnits: {
	[Model]: boolean
} = {}

local damageBaseHandler: ((string, number) -> ())? = nil
local matchEndedChecker: (() -> boolean)? = nil

local function getWaypointPosition(
	waypoint: Instance
): Vector3?
	if waypoint:IsA("BasePart") then
		return waypoint.Position
	end

	if waypoint:IsA("Model") then
		return waypoint:GetPivot().Position
	end

	if waypoint:IsA("Attachment") then
		return waypoint.WorldPosition
	end

	return nil
end

local function isMatchEnded(): boolean
	if matchEndedChecker then
		return matchEndedChecker()
	end

	return false
end

local function getOpponentFolder(
	unit: Model
): Folder
	if unit:GetAttribute("Team") == "Ally" then
		return enemiesFolder
	end

	return alliesFolder
end

local function isValidTarget(
	target: Instance
): boolean
	if not target:IsA("Model") then
		return false
	end

	local humanoid =
		UnitService.GetHumanoid(target)

	local root =
		UnitService.GetRoot(target)

	return humanoid ~= nil
		and root ~= nil
		and humanoid.Health > 0
end

local function findTarget(
	unit: Model
): Model?
	local root =
		UnitService.GetRoot(unit)

	if not root then
		return nil
	end

	local range =
		unit:GetAttribute("Range")

	if typeof(range) ~= "number" then
		range = 6
	end

	local opponentFolder =
		getOpponentFolder(unit)

	local nearestTarget: Model? = nil
	local nearestDistance = math.huge

	for _, candidate in ipairs(
		opponentFolder:GetChildren()
	) do
		if not isValidTarget(candidate) then
			continue
		end

		local target = candidate :: Model

		local targetRoot =
			UnitService.GetRoot(target)

		if not targetRoot then
			continue
		end

		local distance =
			(root.Position - targetRoot.Position).Magnitude

		if
			distance <= range
			and distance < nearestDistance
		then
			nearestTarget = target
			nearestDistance = distance
		end
	end

	return nearestTarget
end

local function faceTarget(
	unit: Model,
	target: Model
)
	local root =
		UnitService.GetRoot(unit)

	local targetRoot =
		UnitService.GetRoot(target)

	if not root or not targetRoot then
		return
	end

	local lookPosition = Vector3.new(
		targetRoot.Position.X,
		root.Position.Y,
		targetRoot.Position.Z
	)

	if
		(lookPosition - root.Position).Magnitude
		<= 0.01
	then
		return
	end

	root.CFrame = CFrame.lookAt(
		root.Position,
		lookPosition
	)
end

local function performBasicAttack(
	unit: Model,
	target: Model
)
	local humanoid =
		UnitService.GetHumanoid(unit)

	local targetHumanoid =
		UnitService.GetHumanoid(target)

	if not humanoid or not targetHumanoid then
		return
	end

	if
		humanoid.Health <= 0
		or targetHumanoid.Health <= 0
	then
		return
	end

	local cooldown =
		unit:GetAttribute("AttackCooldown")

	-- Units without a basic-attack cooldown can still stop
	-- and face enemies while another system handles abilities.
	if typeof(cooldown) ~= "number" then
		return
	end

	if
		cooldown <= 0
		or cooldown == math.huge
	then
		return
	end

	local damage =
		unit:GetAttribute("Damage")

	if typeof(damage) ~= "number" then
		damage = 10
	end

	local lastAttack =
		unit:GetAttribute("LastAttack")

	if typeof(lastAttack) ~= "number" then
		lastAttack = 0
	end

	local now =
		workspace:GetServerTimeNow()

	if now - lastAttack < cooldown then
		return
	end

	unit:SetAttribute(
		"LastAttack",
		now
	)

	targetHumanoid:TakeDamage(damage)
end

local function damageEnemyBase(
	unit: Model
)
	if not damageBaseHandler then
		warn(
			"[UnitAIService] Base damage handler is not registered"
		)

		return
	end

	local damage =
		unit:GetAttribute("BaseDamage")

	if typeof(damage) ~= "number" then
		damage = 100
	end

	local team =
		unit:GetAttribute("Team")

	if team == "Ally" then
		damageBaseHandler(
			"Enemy",
			damage
		)
	else
		damageBaseHandler(
			"Ally",
			damage
		)
	end
end

local function getInitialMovement(
	team: string
): (number, number)
	if team == "Ally" then
		return 1, 1
	end

	return #waypoints, -1
end

function UnitAIService.SetWaypoints(
	newWaypoints: { Instance }
)
	table.clear(waypoints)

	for _, waypoint in ipairs(newWaypoints) do
		table.insert(
			waypoints,
			waypoint
		)
	end

	table.sort(
		waypoints,
		function(a, b)
			local aNumber =
				tonumber(a.Name)

			local bNumber =
				tonumber(b.Name)

			if not aNumber or not bNumber then
				return a.Name < b.Name
			end

			return aNumber < bNumber
		end
	)
end

function UnitAIService.SetBaseDamageHandler(
	handler: (string, number) -> ()
)
	damageBaseHandler = handler
end

function UnitAIService.SetMatchEndedChecker(
	checker: () -> boolean
)
	matchEndedChecker = checker
end

function UnitAIService.RegisterUnit(
	unit: Model
)
	if registeredUnits[unit] then
		return
	end

	if #waypoints == 0 then
		warn(
			"[UnitAIService] No waypoints have been configured"
		)

		return
	end

	local humanoid =
		UnitService.GetHumanoid(unit)

	local root =
		UnitService.GetRoot(unit)

	if not humanoid or not root then
		return
	end

	local team =
		unit:GetAttribute("Team")

	if
		team ~= "Ally"
		and team ~= "Enemy"
	then
		return
	end

	registeredUnits[unit] = true

	task.spawn(function()
		local normalSpeed =
			unit:GetAttribute("WalkSpeed")

		if typeof(normalSpeed) ~= "number" then
			normalSpeed = 8
		end

		local waypointIndex, direction =
			getInitialMovement(team)

		local currentMoveWaypoint: number? = nil
		local fighting = false

		while
			unit.Parent
			and humanoid.Health > 0
			and not isMatchEnded()
		do
			task.wait(THINK_RATE)

			local target =
				findTarget(unit)

			if target then
				if not fighting then
					fighting = true
					currentMoveWaypoint = nil

					humanoid.WalkSpeed = 0

					humanoid:MoveTo(
						root.Position
					)
				end

				faceTarget(
					unit,
					target
				)

				performBasicAttack(
					unit,
					target
				)

				continue
			end

			if fighting then
				fighting = false
				currentMoveWaypoint = nil
				humanoid.WalkSpeed = normalSpeed
			end

			local waypoint =
				waypoints[waypointIndex]

			if not waypoint then
				damageEnemyBase(unit)

				if unit.Parent then
					unit:Destroy()
				end

				break
			end

			local waypointPosition =
				getWaypointPosition(waypoint)

			if not waypointPosition then
				waypointIndex += direction
				currentMoveWaypoint = nil
				continue
			end

			if
				currentMoveWaypoint
				~= waypointIndex
			then
				currentMoveWaypoint =
					waypointIndex

				humanoid:MoveTo(
					waypointPosition
				)
			end

			local distance =
				(
					root.Position
					- waypointPosition
				).Magnitude

			if
				distance
				<= WAYPOINT_REACHED_DISTANCE
			then
				waypointIndex += direction
				currentMoveWaypoint = nil
			end
		end

		registeredUnits[unit] = nil
	end)
end

function UnitAIService.UnregisterUnit(
	unit: Model
)
	registeredUnits[unit] = nil
end

function UnitAIService.StopAll()
	for _, folder in ipairs({
		alliesFolder,
		enemiesFolder,
	}) do
		for _, instance in ipairs(
			folder:GetChildren()
		) do
			if not instance:IsA("Model") then
				continue
			end

			local humanoid =
				UnitService.GetHumanoid(instance)

			local root =
				UnitService.GetRoot(instance)

			if humanoid then
				humanoid.WalkSpeed = 0
			end

			if humanoid and root then
				humanoid:MoveTo(
					root.Position
				)
			end
		end
	end
end

return UnitAIService
