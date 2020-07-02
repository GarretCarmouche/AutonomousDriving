local player = game.Players.LocalPlayer

local UIS = game:GetService("UserInputService")

local Roads = game.Workspace.Roads

local car = script.Car.Value
local primaryPart = car.PrimaryPart
local BV = car.PrimaryPart.BodyVelocity
local BF = car.PrimaryPart.BodyForce
local BAV = car.PrimaryPart.BodyAngularVelocity

local turn = 0
local currentThrottle = 0
local currentBrake = 0
local acceleration = 0
local velocity = 0
local maxBrake = 23000
local turnSpeed = 1
local lockThrottle = false
local maxAcceleration = script.MaxAcceleration.Value
local maxVelocity = script.MaxVelocity.Value
local accelDeriv = script.AccelDeriv.Value
local mass = script.Mass.Value

local currentRoad
local lastVisited
local secondLastVisited

local moveToPart = Instance.new("Part")
moveToPart.Color = Color3.new(1,0,0)
moveToPart.CanCollide = false
moveToPart.Anchored = true
moveToPart.Parent = game.Workspace

function throttle(percent)
	brake(0)
	if not lockThrottle then
		percent = percent or 75
		if velocity < (maxVelocity-.5) or percent == 0 then
			currentThrottle = percent
		end
	end
end

function brake(percent)
	percent = percent or 60
	currentThrottle = 0
	currentBrake = percent
end

function accel()
	throttle()
end

function deaccel()
	brake()
end

function stopAccel()
	brake(0)
	throttle(0)
end

function turnRight(percent)
	percent = percent or 100
	turn = -1 * percent/100
end

function turnLeft(percent)
	percent = percent or 100
	turn = 1 * percent/100
end

function endTurn()
	turn = 0
end

--Acceleration loop
local lastPos = primaryPart.Position * Vector3.new(1,0,1)
local currentPos
spawn(function()
	while wait() do
		--Forward motion
		local lookVector = primaryPart.CFrame.lookVector
		
		if velocity > maxVelocity then
			currentThrottle =  (currentThrottle > 0 and currentThrottle - 1) or 0
		end
		local base = accelDeriv*currentThrottle/100
		local turnmodif = (math.abs(turn) * mass * math.pow(math.abs(velocity),2) / 1500000000)
		local massmodif = mass/50000
		acceleration = math.clamp(acceleration + base - massmodif - turnmodif,0,maxAcceleration)
		if velocity <= 0 and acceleration < 0 then
			acceleration = 0
		end
		
		local brakeForce = (currentBrake/100)*maxBrake
		if brakeForce == 0 then
			BV.Velocity = lookVector * acceleration
			BV.MaxForce = Vector3.new(0,0,0)
		else
			BV.Velocity = Vector3.new(0,0,0)
			BV.MaxForce = Vector3.new(brakeForce,0,brakeForce)
		end
		
		currentPos = primaryPart.Position * Vector3.new(1,0,1)
		local diff = currentPos-lastPos
		BF.Force = ((lookVector * Vector3.new(1,0,1)) * acceleration * mass) - diff * 100
		
		velocity = diff.magnitude
		if diff.X * lookVector.X < 0 and diff.Z * lookVector.Z < 0 then
			--velocity = velocity * -1
			velocity = 0
		end
		
		lastPos = currentPos
		
		--Turning
		BAV.AngularVelocity = Vector3.new(0,turnSpeed,0) * turn * math.pow(math.abs(velocity),1/2)
	end
end)

--Forward collision check
spawn(function()
	while wait(.1) do
		local ray = Ray.new(primaryPart.Position,primaryPart.CFrame.lookVector*1000)
		local partAhead, position = game.Workspace:FindPartOnRayWithIgnoreList(ray,{car})
		
		if partAhead then
			local distance = (position - primaryPart.Position).magnitude
			local brakeTime = distance/velocity
			if brakeTime < 0 then
				lockThrottle = true
				brake(100)
				print("BRAKE")
				wait(1)
				brake(0)
				lockThrottle = false
			end
		end
	end
end)

function linearNavigateTo(position)
	local moveToPosition
	
	if lastVisited then
		local part1
		local position1
		for _,part in pairs(currentRoad:GetChildren()) do
			if part.Position ~= lastVisited and part.Position ~= secondLastVisited then
				if not part1 then
					part1 = part
					position1 = part.Position
				else
					if (part.Position - primaryPart.Position).magnitude < (position1 - primaryPart.Position).magnitude then
						part1 = part
						position1 = position
					end
				end
			end
		end
		moveToPosition = part1.Position
	else
		local part1
		local part2
		local position1
		local position2
		
		for _,part in pairs(currentRoad:GetChildren()) do
			if part.Position ~= lastVisited then
				if not part1 then
					part1 = part
					position1 = part.Position
				elseif not part2 then
					part2 = part
					position2 = part.Position
				else
					local dist = (part.Position - primaryPart.Position).magnitude
					if dist < (position1 - primaryPart.Position).magnitude then
						part1 = part
						position1 = part.Position
					elseif dist < (position2 - primaryPart.Position).magnitude then
						part2 = part
						position2 = part.Position
					end
				end
			end
		end
		
		local dist1 = (position1 - position).magnitude
		local dist2 = (position2 - position).magnitude
		
		if dist1 < dist2 then
			moveToPosition = position1
		else
			moveToPosition = position2
		end
	end
	
	if (primaryPart.Position - moveToPosition).magnitude > 1 then
		moveTo(moveToPosition)
	end
	if moveToPosition ~= position then
		linearNavigateTo(position)
	end
end

--Travels to location
function moveTo(position)
	spawn(function()
		moveToPart.Transparency = 0
		moveToPart.CFrame = CFrame.new(position)
	end)
	
	
	local clear
	local pos = primaryPart.Position
	local diff = position - pos
	
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.FilterDescendantsInstances = {car,Roads}
	params.IgnoreWater = false
	
	local result = game.Workspace:Raycast(pos,diff,params)
	if result and result.Instance then
		clear = false
	else
		clear = true
	end
	
	if clear then
		local distance = (primaryPart.Position - position).magnitude
		local targetSpeed = 0
		
		while distance > 3 do
			wait()
			if lockThrottle then
				continue
			end
			distance = (primaryPart.Position - position).magnitude
			targetSpeed = distance/100 + .75 - (.5 * math.abs(turn))
			if velocity < targetSpeed then
				accel()
			else
				if targetSpeed - velocity > 10 then
					deaccel()
				else
					brake(0)
				end
				
			end
			
			local frontDiff = (primaryPart.CFrame.LookVector * distance) - position
			local right = (primaryPart.Position + primaryPart.CFrame.RightVector + primaryPart.CFrame.LookVector)
			local left = (primaryPart.Position - primaryPart.CFrame.RightVector + primaryPart.CFrame.LookVector)
			if frontDiff.magnitude > 0 then
				if (right - position).magnitude > (left - position).magnitude then
					turn = math.clamp(turn + .1, 0, 100)
				else
					turn = math.clamp(turn - .1, -100, 0)
				end
			else
				turn = 0
			end
		end
		currentThrottle = 0
		secondLastVisited = lastVisited
		lastVisited = position
		moveToPart.Transparency = 1
	else
		
	end
	
end

--Moves the car to the nearest road
function moveToNearestRoad()
	local pos = primaryPart.Position
	local nearestPart
	local nearestPosition
	local neareastRoad
	for _,road in pairs(Roads:GetChildren()) do
		for _,part in pairs(road:GetChildren()) do
			if not nearestPosition or (part.Position - pos).magnitude < (nearestPosition - pos).magnitude then
				nearestPart = part
				nearestPosition = part.Position
				neareastRoad = road
			end
		end
	end
	
	currentRoad = neareastRoad
	moveTo(nearestPosition)
end

--Offroad check
--If offroad, move onroad
function checkOnRoad()
	local pos = primaryPart.Position
	for _,road in pairs(Roads:GetChildren()) do
		for _,part in pairs(road:GetChildren()) do
			if (part.Position - pos).magnitude < 5 then
				return true
			end
		end
	end
	
	return false
end

--On road loop
spawn(function()
	while wait(5) do
		local onRoad = checkOnRoad()
		if not onRoad then
			moveToNearestRoad()
		end
		lastVisited = nil
		secondLastVisited = nil
		linearNavigateTo(Vector3.new(482.15, 0.5, 213.5))
		lastVisited = nil
		secondLastVisited = nil
		linearNavigateTo(Vector3.new(733.05, 0.5, -109.6))
	end
end)