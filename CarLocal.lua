local player = game.Players.LocalPlayer

local UIS = game:GetService("UserInputService")

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
local maxBrake = 230000
local lockThrottle = false
local maxAcceleration = script.MaxAcceleration.Value
local maxVelocity = script.MaxVelocity.Value
local accelDeriv = script.AccelDeriv.Value
local mass = script.Mass.Value

function throttle(percent)
	if not lockThrottle then
		percent = percent or 50
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
	brake(0)
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
		local turnmodif = (math.abs(turn) * mass * math.pow(math.abs(velocity),2) / 200000000)
		local massmodif = mass/13500
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
		BAV.AngularVelocity = Vector3.new(0,.5,0) * turn * math.pow(math.abs(velocity),1/2)
	end
end)

--Forward collision check
spawn(function()
	while wait() do
		local ray = Ray.new(primaryPart.Position,primaryPart.CFrame.lookVector*1000)
		local partAhead, position = game.Workspace:FindPartOnRayWithIgnoreList(ray,{car})
		
		if partAhead then
			local distance = (position - primaryPart.Position).magnitude
			local brakeTime = distance/velocity
			if brakeTime < 20 then
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

local inputBegan = {
	[Enum.KeyCode.A] = turnLeft,
	[Enum.KeyCode.D] = turnRight,
	[Enum.KeyCode.S] = deaccel,
	[Enum.KeyCode.W] = accel,
}

local inputEnd = {
	[Enum.KeyCode.A] = endTurn,
	[Enum.KeyCode.D] = endTurn,
	[Enum.KeyCode.S] = stopAccel,
	[Enum.KeyCode.W] = stopAccel,
}

UIS.InputBegan:Connect(function(input,processed)
	if not processed and inputEnd[input.KeyCode] then
		inputBegan[input.KeyCode]()
	end
end)

UIS.InputEnded:Connect(function(input,processed)
	if not processed and inputEnd[input.KeyCode] then
		inputEnd[input.KeyCode]()
	end
end)


game.Workspace.CurrentCamera.CameraSubject = primaryPart
wait(1)
game.Workspace.CurrentCamera.CameraType = Enum.CameraType.Follow