
-- top-level controller, manages overall flow of the game between screens

local currentScreen = nil
local flow = nil

function _init()
	cartdata(CART_ID)
	highScore = dget(0)
	flow = cocreate(function()
		while true do
			currentCavern = 1
			currentScreen = TitleScreen.new()
			while not currentScreen.isDone do
				yield()
			end	
			score = 0
			local keep_playing = true
			while keep_playing do
				currentScreen = CavernDescentScreen.new()
				while not currentScreen.isDone do
					yield()
				end
				currentScreen = GameScreen.new()
				while not currentScreen.isDone do
					yield()
				end
				if currentScreen.isGameOver then
					currentScreen = GameOverScreen.new()
					while not currentScreen.isDone do
						yield()
					end
					keep_playing = false
				elseif currentScreen.isEscaped then
					currentScreen = EscapeEndScreen.new()
					while not currentScreen.isDone do
						yield()
					end
					if currentCavern > NUM_CAVERNS then
						keep_playing = false
					end
				end
			end
		end
	end)	
end

function _update60()
	if (currentScreen) currentScreen:update()
	assert(coresume(flow))
end
    
function _draw()
	if (currentScreen) currentScreen:draw()
end
