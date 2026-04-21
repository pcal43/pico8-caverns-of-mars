local EscapeEndScreen = {}

MARTIAN_HORIZON_Y      = 72
MARTIAN_CAVERN_LIP     = 101   -- entrance_y(88) + 12px visual bottom of the 16px entrance sprite
MARTIAN_SHIP_HOVER_Y   = 60    -- ship resting hover position above the surface

local DURATION          = 9 * FPS  -- 9 seconds
local SHAKE_FRAMES      = 0.10 * FPS  -- how long each shake lasts
local TEXT_START_FRAME  = 4 * FPS  -- 4 seconds in: stop explosions, show text

EscapeEndScreen.new = function()
    local self = {}
    self.isDone         = false
    self.timer          = 0
    self.ship_y         = MARTIAN_CAVERN_LIP  -- starts hidden behind cavern lip
    self.shake_timer    = 0
    self.flicker_color  = WHITE
    self.next_explosion = flr(rnd(10)) + 5
    self.cavern_incremented = false
    setmetatable(self, { __index = EscapeEndScreen })
    return self
end

function EscapeEndScreen:update()
    self.timer += 1
    if self.timer >= DURATION then
        self.isDone = true
        return
    end
    -- move ship up until it reaches its hover position
    if self.ship_y > MARTIAN_SHIP_HOVER_Y then
        self.ship_y -= PLAYER_SPEED_Y * speedFactor
    end
    -- count down current shake
    if self.shake_timer > 0 then
        self.shake_timer -= 1
    end
    -- only run explosions once ship has finished emerging and before text phase
    if self.ship_y <= MARTIAN_SHIP_HOVER_Y and self.timer < TEXT_START_FRAME then
        -- countdown to next explosion
        self.next_explosion -= 1
        if self.next_explosion <= 0 then
            self.shake_timer   = SHAKE_FRAMES
            sfx(SOUND_EXPLOSION, SOUND_EXPLOSION_CHANNEL)
            self.flicker_color = (rnd(2) < 1) and WHITE or YELLOW
            self.next_explosion = flr(rnd(24)) + 8
        end
    end
end

function EscapeEndScreen:draw()
    cls(BLACK)
    local shaking = self.shake_timer > 0
    local shake_y = shaking and -2 or 0
    -- remap BROWN → flicker colour on the cavern entrance during a shake
    if shaking then
        pal(BROWN, self.flicker_color)
    end
    draw_martian_surface(MARTIAN_HORIZON_Y + shake_y)
    pal()
    -- draw ship clipped to above the cavern lower lip so it appears to emerge from it
    local ship_x = (128 - SHIP_WIDTH) \ 2
    clip(0, 0, 128, MARTIAN_CAVERN_LIP + shake_y)
    spr_outlined(SPRITE_PLAYER_SHIP, ship_x, self.ship_y, SHIP_SPR_W, SHIP_SPR_H)
    clip()

    -- congratulations text phase
    if self.timer >= TEXT_START_FRAME then
        if not self.cavern_incremented then
            currentCavern += 1
            self.cavern_incremented = true
        end
        local t1 = "congratulations"
        local t2 = "cavern destroyed"
        local t3 = "you are entering"
        local t4 = "cavern "..currentCavern
        print("\^w"..t1, (128 - #t1 * 8) \ 2,  8, YELLOW)
        print("\^w"..t2, (128 - #t2 * 8) \ 2, 20, BLUE)
        print("\^w"..t3, (128 - #t3 * 8) \ 2, 36, PINK)
        print("\^w"..t4, (128 - #t4 * 8) \ 2, 44, PINK)
    end
end
