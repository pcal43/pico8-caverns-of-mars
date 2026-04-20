local CavernDescentScreen = {}

CavernDescentScreen.new = function()
    local self = {}
    self.isDone = false
    self.ship_y = MARTIAN_SHIP_HOVER_Y  -- starts at hover, descends into cavern
    sfx(SOUND_HUM_FIRST, SOUND_HUM_CHANNEL, 0, -1)
    setmetatable(self, { __index = CavernDescentScreen })
    return self
end

function CavernDescentScreen:update()
    self.ship_y += 1
    if self.ship_y >= MARTIAN_CAVERN_LIP + 4 then
        sfx(-1, SOUND_HUM_CHANNEL)
        self.isDone = true
    end
end

function CavernDescentScreen:draw()
    cls(BLACK)
    draw_martian_surface(MARTIAN_HORIZON_Y)
    local ship_x = (128 - SHIP_WIDTH) \ 2
    clip(0, 0, 128, MARTIAN_CAVERN_LIP)
    spr_outlined(SPRITE_PLAYER_SHIP, ship_x, self.ship_y, SHIP_SPR_W, SHIP_SPR_H)
    clip()
end
