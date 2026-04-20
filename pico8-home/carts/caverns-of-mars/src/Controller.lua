
-- top-level controller, manages overall flow of the game between screens

local currentScreen = nil
local flow = nil

function _init()
	cartdata(CART_ID)
	HIGH_SCORE = dget(0)
	flow = cocreate(function()
		while true do
			CURRENT_CAVERN = 1
			currentScreen = TitleScreen.new()
			while not currentScreen.isDone do
				yield()
			end
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
					currentScreen = GameOverScreen.new(currentScreen.score)
					while not currentScreen.isDone do
						yield()
					end
					keep_playing = false
				elseif currentScreen.isEscaped then
					currentScreen = EscapeEndScreen.new()
					while not currentScreen.isDone do
						yield()
					end
					if CURRENT_CAVERN > NUM_CAVERNS then
						keep_playing = false
					end
				end
			end
		end
	end)	
end

function _update()
	if (currentScreen) currentScreen:update()
	assert(coresume(flow))
end
    
function _draw()
	if (currentScreen) currentScreen:draw()
end
