local GameOverScreen = {}

local DELAY_FRAMES  = 90   -- 3 seconds at 30fps before prompt appears
local BLINK_ON      = 20   -- frames prompt is visible per blink cycle
local BLINK_PERIOD  = 30   -- total frames per blink cycle

GameOverScreen.new = function()
    local self = {}
    self.isDone      = false
    self.blink_timer = 0
    if score > highScore then
        highScore = score
        dset(0, highScore)
    end
    setmetatable(self, { __index = GameOverScreen })
    return self
end

function GameOverScreen:update()
    self.blink_timer += 1
    if self.blink_timer > DELAY_FRAMES and buttonWasPressed(BUTTON_X) then
        self.isDone = true
    end
end

function GameOverScreen:draw()
    cls(BLACK)

    -- GAME OVER
    local go = "game over"
    print("\^w"..go, (128 - #go * 8) \ 2, 32, WHITE)

    -- scores
    local sc_str = "your score  "..score
    local hi_str = "high score  "..highScore
    print(sc_str, (128 - #sc_str * 4) \ 2, 50, WHITE)
    print(hi_str, (128 - #hi_str * 4) \ 2, 60, WHITE)

    -- flashing prompt after delay
    if self.blink_timer > DELAY_FRAMES then
        if self.blink_timer % BLINK_PERIOD < BLINK_ON then
            local p = "press ❎ to continue"
            print(p, (128 - #p * 4) \ 2, 112, WHITE)
        end
    end
end
