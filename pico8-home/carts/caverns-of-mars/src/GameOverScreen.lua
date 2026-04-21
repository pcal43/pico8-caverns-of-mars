local GameOverScreen = {}

--[[const]] local DELAY_FRAMES  = 3 * FPS

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
    print("\^wgame over", 28, 32, WHITE)
    print("your score  "..score, 32, 50, WHITE)
    print("high score  "..highScore, 32, 60, WHITE)

    -- flashing prompt after delay
    if self.blink_timer > DELAY_FRAMES then
        if self.blink_timer % FPS > (FPS/3) then
            local p = "press ❎ to continue"
            print(p, (128 - #p * 4) \ 2, 112, WHITE)
        end
    end
end
