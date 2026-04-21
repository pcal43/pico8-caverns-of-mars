local TitleScreen = {}

local v = split(VERSION,".")
VERSION_STRING = v[1].."\-f.\-f"..v[2].."\-f.\-f"..v[3]

-- Draws the martian surface scene starting at the given top y coordinate.
-- horizon_y: y where the 16x16 horizon sprites are drawn (craggy skyline)
-- The dirt fill begins at horizon_y+16 and extends to the bottom of the screen.
-- The cavern entrance (3 sprites) is drawn centred at horizon_y+32.
function draw_martian_surface(horizon_y)
    -- craggy horizon: 8 × 16px = 128px wide
    local horizon_sprites = {64,66,68,70,72,74,76,78}
    for i, s in ipairs(horizon_sprites) do
        spr(s, (i-1)*16, horizon_y, 2, 2)
    end
    -- solid pink dirt fill below the horizon sprites
    rectfill(0, horizon_y + 16, 127, 127, PINK)
    -- cavern entrance: 3 × 16px = 48px, centred (black pixels are opaque)
    local entrance_x = (128 - 48) \ 2  -- = 40
    local entrance_y = horizon_y + 16
    palt(0, false)
    spr(100, entrance_x,      entrance_y, 2, 2)
    spr(102, entrance_x + 16, entrance_y, 2, 2)
    spr(104, entrance_x + 32, entrance_y, 2, 2)
    palt()
end

TitleScreen.new = function()
	local self = {}
	self.isDone = false
	self.blink_timer = 0
	music(0)
    setmetatable(self, { __index = TitleScreen })
	return self
end

function TitleScreen:update()
	self.blink_timer += 1
	if buttonWasPressed(BUTTON_X) then
		self.isDone = true
		music(-1, 2000)
	end
end

function TitleScreen:draw()
    cls(BLACK)

    -- title sprite: 60×32px source at sprite 192, doubled to 120×64px, centred
    -- sprite 192 = spritesheet pixel (0, 96)
    sspr(0, 96, 60, 32, (128 - 120) \ 2, 2, 120, 64)

    -- player ship, centred just above the surface
    local ship_x = (128 - SHIP_WIDTH) \ 2
    spr(SPRITE_PLAYER_SHIP, ship_x, 60, SHIP_SPR_W, SHIP_SPR_H)

    -- martian surface starting at y=72
    draw_martian_surface(72)

    -- copyright text below cavern entrance (entrance bottom = 104)
    print("cOPYRIGHT 1981 aTARI", 24, 105, BLACK)

    -- "press X to start" blink and version
    if self.blink_timer % 30 < 20 then
        print("press ❎ to start", 30, 121, BLACK)
    end
    print("pcal", 1, 80, DARK_GRAY)
    print(VERSION_STRING, 112, 80, DARK_GRAY)
end

