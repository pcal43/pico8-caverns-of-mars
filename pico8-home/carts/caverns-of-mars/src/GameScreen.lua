-- =============================================
-- GameScreen – Caverns of Mars prototype, step 2
-- Scrolling cavern terrain, player + bullets,
-- wall collision detection.
-- =============================================

-- game states
local STATE_PLAYING  = 1
local STATE_DYING    = 2   -- ship destroyed; showing explosion animation
local STATE_CRASHED  = 3   -- game over (no lives left)
local STATE_ESCAPE   = 4   -- reactor hit; ticker intro playing
local STATE_ESCAPING = 5   -- active reverse scroll; player must reach level top
local STATE_ESCAPE_FLY_OFF = 6  -- terrain stopped; ship flies off top of screen
local STATE_ROCKET_WAVE    = 7  -- rocket wave: rockets fly at player from below


-- score awarded per target ttype; TTYPE_WAVE entries are keyed by wave_spr
local SCORE_BY_TTYPE = {
    [TTYPE_FUEL]   = SCORE_FUEL_TANK,
    [TTYPE_NODE]   = SCORE_RADAR,
    [TTYPE_ROCKET] = SCORE_ROCKET,
}

GameScreen = {}

function GameScreen.new()
    local self = {}
    setmetatable(self, { __index = GameScreen })
    self:init()
    return self
end

-- Full initialisation – called by new() and on game-over restart.
-- Resets everything including terrain, score, and lives.
function GameScreen:init()
    self.isDone     = false
    self.isEscaped  = false
    self.isGameOver = false
    self.hum_snd    = -1
    self.state  = STATE_PLAYING
    self.lives  = PLAYER_LIVES
    self.bullets    = {}
    self.targets    = {}   -- alive target objects placed by section rules
    self.explosions = {}   -- active target explosion animations
    self.frame      = 0    -- global frame counter for synced animations
    self.respawn_wy = 0    -- world-y of the last crossed checkpoint
    self.escapeTime = 0
    self.escape_tick = 0
    self:respawnPlayer()
    self:initTerrain()
    speedFactor = DESCENT_SPEED_FACTOR
end

-- Respawn the player in place – called after a death when lives remain.
function GameScreen:respawn()
    self.bullets    = {}
    self.explosions = {}
    if self.died_while_rocketwave then
        self:triggerRocketWave()
        speedFactor = DESCENT_SPEED_FACTOR
        self:respawnPlayer()
    elseif self.died_while_escaping then
        -- during escape: checkpoint row sits at the bottom of the screen
        local wy = max(0, self.respawn_wy - GAMEPLAY_H)
        self:resetTerrainAt(wy)
        self:prepareEscapeTargets()

        self.escapeTime  = self.levelDef.escape_time
        self.escape_tick = 0
        self.state = STATE_ESCAPING
        speedFactor = ESCAPE_SPEED_FACTOR
        self:respawnPlayer()
        self.player.x = (128 - SHIP_WIDTH) \ 2
        self.player.y = GAMEPLAY_H - SHIP_HEIGHT
        -- set esc_cp_idx to the checkpoint just before respawn_wy
        self.esc_cp_idx = 0
        for i = 1, #self.checkpoints do
            if self.checkpoints[i] == self.respawn_wy then
                self.esc_cp_idx = i - 1
                break
            end
        end
    else
        -- during descent: checkpoint row sits at the top of the screen
        self:resetTerrainAt(self.respawn_wy)
        self.state = STATE_PLAYING
        speedFactor = DESCENT_SPEED_FACTOR
        self:respawnPlayer()
    end
end

-- Reset just the player ship fields (shared by init and respawn).
function GameScreen:respawnPlayer()
    self.player = {
        x        = PLAYER_START_X,
        y        = PLAYER_START_Y,
        cooldown = 0,
    }
    self.fuel         = PLAYER_FUEL_MAX
    self.fuel_wy_last = self.terrain_base_wy or 0
end



-- =============================================
-- Tile-based terrain engine
-- =============================================
-- buildCavern() (Level.lua) produces a flat array of row arrays, each 16 sprite IDs.
-- The engine indexes into that array, wrapping at the end, and maintains a
-- rolling pixel-row buffer (TERRAIN_SLICES deep) for drawing and collision.
-- Each buffered entry: {sprites={s1..s16}, spr_phase=0..7}
--   spr_phase – pixel offset within the 8-px band (0=top of sprite, trigger draw).

function GameScreen:initTerrain()
    self.scroll_frac     = 0
    self.reverse_frac    = 0
    self.terrain_base_wy = 0
    self.levelDef = buildCavern(difficulty, currentCavern)
    self.level_rows      = self.levelDef.rows
    self:extractTargets()
    -- save pristine target list so resetTerrainAt can restore targets
    self.target_defs = {}
    for _, t in ipairs(self.targets) do
        add(self.target_defs, {spr=t.spr, spr_w=t.spr_w, ttype=t.ttype, x=t.x, world_y=t.world_y})
    end
    -- stop scrolling when the last authored row reaches screen-y 0
    self.scroll_stop_wy  = (#self.level_rows - 1) * 8
    -- copy authored checkpoints (row index → world-y pixel)
    self.checkpoints = {}
    for _, ri in ipairs(self.levelDef.checkpoints) do
        add(self.checkpoints, ri * 8)
    end
    self.next_cp_idx = 1
    self.rw_wave_triggers = {}
    for _, ri in ipairs(self.levelDef.rocket_waves) do
        add(self.rw_wave_triggers, ri * 8)
    end
    self.next_rw_idx = 1
    self.esc_cp_idx  = 0
    self.terrain = {}
    self.gen = {
        row_idx = 1,   -- index into level_rows (wraps)
        row_py  = 0,   -- pixel y within current authored row (0..7)
        next_wy = 0,   -- world-y of the next pixel row to generate
    }
    for _ = 1, TERRAIN_SLICES do
        add(self.terrain, self:nextRowFromGen())
    end
end

-- Restart the terrain engine from world-y wy (must be a checkpoint boundary).
-- Rebuilds level_rows and targets from scratch; preserves checkpoints and scroll_stop_wy.
function GameScreen:resetTerrainAt(wy)
    self.scroll_frac     = 0
    self.reverse_frac    = 0
    self.terrain_base_wy = wy
    -- terrain (level_rows, scroll_stop_wy) is immutable — no rebuild needed
    -- targets must be reset so destroyed ones reappear on respawn
    self.targets = {}
    for _, def in ipairs(self.target_defs) do
        add(self.targets, {spr=def.spr, spr_w=def.spr_w, ttype=def.ttype, x=def.x, world_y=def.world_y, alive=true})
    end
    -- reset next_cp_idx and advance past checkpoints already behind wy
    self.next_cp_idx = 1
    while self.next_cp_idx <= #self.checkpoints and
          self.checkpoints[self.next_cp_idx] <= wy do
        self.next_cp_idx += 1
    end
    -- reset next_rw_idx and advance past wave triggers already behind wy
    self.next_rw_idx = 1
    while self.next_rw_idx <= #self.rw_wave_triggers and
          self.rw_wave_triggers[self.next_rw_idx] <= wy do
        self.next_rw_idx += 1
    end
    local row_idx = flr(wy / 8) + 1
    self.gen = {
        row_idx = row_idx,
        row_py  = 0,
        next_wy = wy,
    }
    self.terrain = {}
    for _ = 1, TERRAIN_SLICES do
        add(self.terrain, self:nextRowFromGen())
    end
end

-- Pull one pixel row from level_rows. Each authored row occupies 8 pixel ticks.
function GameScreen:nextRowFromGen()
    local g  = self.gen
    g.next_wy += 1
    if g.row_idx > #self.level_rows then
        return {sprites=nil, spr_phase=0}
    end
    local row       = self.level_rows[g.row_idx]
    local spr_phase = g.row_py
    g.row_py += 1
    if g.row_py >= 8 then
        g.row_py  = 0
        g.row_idx += 1
    end
    return {sprites=row, spr_phase=spr_phase}
end

-- Scroll terrain backwards (level played in reverse: terrain moves DOWN).
-- Each pixel tick: drop the last (bottom) buffer row, prepend a new row
-- from level_rows at the top, decrement terrain_base_wy.
-- Note: scroll_frac is intentionally left at 0 during reverse scroll.
-- Using it here causes the draw functions to drift terrain upward (wrong
-- direction), producing a blurry doubled appearance.  reverse_frac tracks
-- the sub-pixel accumulation for commit rate only.
function GameScreen:scrollTerrainReverse()
    if self.terrain_base_wy <= 0 then return end
    self.reverse_frac += SCROLL_SPEED * speedFactor
    while self.reverse_frac >= 1 do
        self.reverse_frac    -= 1
        self.terrain_base_wy -= 1
        -- update escape respawn checkpoint when its row reaches the screen bottom
        while self.esc_cp_idx >= 1 and
              self.terrain_base_wy + GAMEPLAY_H <= self.checkpoints[self.esc_cp_idx] do
            self.respawn_wy = self.checkpoints[self.esc_cp_idx]
            self.esc_cp_idx -= 1
        end
        local row_idx = flr(self.terrain_base_wy /ROW_HEIGHT) + 1
        if self.terrain_base_wy % ROW_HEIGHT == 0 then
            score += SCORE_PER_ROW
        end
        local phase   = self.terrain_base_wy % ROW_HEIGHT
        local sprites = (row_idx >= 1 and row_idx <= #self.level_rows)
                        and self.level_rows[row_idx] or nil
        deli(self.terrain, #self.terrain)
        add(self.terrain, {sprites=sprites, spr_phase=phase}, 1)
        if self.terrain_base_wy <= 0 then
            self.scroll_frac = 0
            break
        end
    end
end

-- Advance scroll_frac by SCROLL_SPEED.
-- Stops once the last authored row has reached screen-y 0.
function GameScreen:scrollTerrain()
    if self.terrain_base_wy >= self.scroll_stop_wy then return end
    self.scroll_frac += SCROLL_SPEED * speedFactor
    while self.scroll_frac >= 1 do
        self.scroll_frac     -= 1
        self.terrain_base_wy += 1
        if self.terrain_base_wy % 8 == 0 then
            score += SCORE_PER_ROW
        end
        -- advance the respawn checkpoint when the player's world-y crosses it
        while self.next_cp_idx <= #self.checkpoints and
              self.terrain_base_wy + self.player.y >= self.checkpoints[self.next_cp_idx] do
            self.respawn_wy  = self.checkpoints[self.next_cp_idx]
            self.next_cp_idx += 1
        end
        -- trigger rocket wave when trigger row reaches the bottom of the screen
        while self.next_rw_idx <= #self.rw_wave_triggers and
              self.terrain_base_wy + GAMEPLAY_H >= self.rw_wave_triggers[self.next_rw_idx] do
            self:triggerRocketWave()
            self.next_rw_idx += 1
        end
        if self.state == STATE_ROCKET_WAVE then
            self.scroll_frac = 0
            break
        end
        deli(self.terrain, 1)
        add(self.terrain, self:nextRowFromGen())
        if self.terrain_base_wy >= self.scroll_stop_wy then
            self.scroll_frac = 0
            break
        end
    end
end

-- Return the terrain row for screen-y sy.
function GameScreen:rowAt(sy)
    local idx = -flr(-sy - self.scroll_frac - 1)
    if idx >= 1 and idx <= #self.terrain then
        return self.terrain[idx]
    end
    return nil
end

-- Return true if pixel (cx, cy) within an 8×8 tile is solid for sprite sid.
-- cx, cy are 0-7 where (0,0) is the top-left corner of the sprite.
-- Full tiles are always solid; half-bricks cover their respective 4px column;
-- corner tiles use diagonal geometry.
local function is_tile_collision(sid, cx, cy)
    if not sid or sid == 0 then return false end
    if sid == SPRITE_BASE_BRICK_LEFT  then return cx < 4 end
    if sid == SPRITE_BASE_BRICK_RIGHT then return cx >= 4 end
    if sid == SPRITE_CORNER_LOWER_RIGHT then return cx + cy >= 7 end
    if sid == SPRITE_CORNER_LOWER_LEFT  then return cx <= cy end
    if sid == SPRITE_CORNER_UPPER_RIGHT then return cx >= cy end
    if sid == SPRITE_CORNER_UPPER_LEFT  then return cx + cy <= 7 end
    return true
end

-- Return true if pixel x falls on a solid tile in row r.
local function tile_solid(r, px)
    if not r or not r.sprites then return false end
    local sid = r.sprites[flr(px / 8) + 1]
    return is_tile_collision(sid, px % 8, r.spr_phase)
end

-- =============================================
-- Player movement (dpad) and shooting (X)
-- =============================================

-- btn() is checked every frame for held input → smooth continuous motion.
-- mid() clamps so the ship never exits the 128×128 screen.
function GameScreen:movePlayer()
    local p = self.player
    if btn(BUTTON_LEFT)  then p.x -= PLAYER_SPEED_X * speedFactor end
    if btn(BUTTON_RIGHT) then p.x += PLAYER_SPEED_X * speedFactor end
    if btn(BUTTON_UP)    then p.y -= PLAYER_SPEED_Y * speedFactor end
    if btn(BUTTON_DOWN)  then p.y += PLAYER_SPEED_Y * speedFactor end
    p.x = mid(0, p.x, 128 - SHIP_WIDTH)
    p.y = mid(0, p.y, GAMEPLAY_H - SHIP_HEIGHT)
end

-- Two bullets spawn simultaneously from the bottom-left and bottom-right
-- edges of the ship sprite. Player cannot fire again until both bullets expire.
function GameScreen:handleShooting()
    local p = self.player
    if btn(BUTTON_X) and #self.bullets == 0 then
        local by = p.y + BULLET_SPAWN_Y
        add(self.bullets, {x = p.x + BULLET_LEFT_X,  y = by})
        add(self.bullets, {x = p.x + BULLET_RIGHT_X, y = by})
        sfx(SOUND_SHOOT, SOUND_SHOOT_CHANNEL)
    end
end

-- Spawn a target explosion at the given world position.
local function spawn_explosion(explosions, x, world_y, vy)
    add(explosions, { x=x, world_y=world_y, vy=vy or 0 })
    sfx(SOUND_EXPLOSION, SOUND_EXPLOSION_CHANNEL)
end

function GameScreen:updateBullets()
    local live = {}
    local bwy = self.terrain_base_wy
    local sf  = self.scroll_frac
    local is_wave = self.state == STATE_ROCKET_WAVE
    for b in all(self.bullets) do
        b.y += BULLET_SPEED
        if b.y < GAMEPLAY_H and (is_wave or not tile_solid(self:rowAt(b.y), b.x)) then
            local hit = false
            if is_wave then
                for tgt in all(self.rw_targets) do
                    if tgt.alive and b.x >= tgt.x and b.x < tgt.x + tgt.spr_w * 8
                    and b.y >= tgt.y and b.y < tgt.y + 8 then
                        tgt.alive = false
                        local s = tgt.spr == SPRITE_FUEL_ROCKET and SCORE_WAVE_FUEL or SCORE_WAVE_ROCKET
                        score += s
                        if tgt.spr == SPRITE_FUEL_ROCKET then
                            self.fuel = mid(0, self.fuel + 25, PLAYER_FUEL_MAX)
                        end
                        spawn_explosion(self.explosions, tgt.x + tgt.spr_w * 4, tgt.y + bwy, ROCKET_WAVE_SCROLL_SPEED)
                        hit = true
                        break
                    end
                end
            else
                for tgt in all(self.targets) do
                    if tgt.alive then
                        local tsy = flr((tgt.world_y - bwy) - sf)
                        local hw  = tgt.spr_w == 2 and TARGET_SPR_OX_LG or TARGET_SPR_OX_SM
                        if b.x >= tgt.x - hw and b.x <= tgt.x + hw - 1
                        and b.y >= tsy - TARGET_SPR_OY and b.y <= tsy then
                            tgt.alive  = false
                            score += SCORE_BY_TTYPE[tgt.ttype] or 0
                            if tgt.ttype == TTYPE_FUEL then
                                self.fuel = mid(0, self.fuel + 25, PLAYER_FUEL_MAX)
                            end
                            spawn_explosion(self.explosions, tgt.x, tgt.world_y)
                            hit = true
                            break
                        end
                    end
                end
            end
            if not hit then add(live, b) end
        end
    end
    self.bullets = live
end

-- Scan level_rows for target-tile sprites, register them in self.targets,
-- and zero them out so they don't render as solid terrain.
function GameScreen:extractTargets()
    for i = 1, #self.level_rows do
        local row = self.level_rows[i]
        for j = 1, 16 do
            local s = row[j]
            if s and is_target_tile(s) and s != 19 and s != 21 then
                local ttype, spr_w
                if     s == SPRITE_ROCKET then ttype = TTYPE_ROCKET ; spr_w = 1
                elseif s == SPRITE_RADAR then ttype = TTYPE_NODE   ; spr_w = 1
                elseif s == SPRITE_FUEL_TANK then ttype = TTYPE_FUEL ; spr_w = 2
                end
                if ttype then
                    local hw = spr_w == 2 and TARGET_SPR_OX_LG or TARGET_SPR_OX_SM
                    local x_off = spr_w == 1 and 4 or 0
                    add(self.targets, {
                        spr     = s,
                        spr_w   = spr_w,
                        ttype   = ttype,
                        x       = (j-1)*8 + hw + x_off,
                        world_y = (i-1)*8 + 7,
                        alive   = true,
                    })
                    local clean = {}
                    for k = 1, 16 do clean[k] = row[k] end
                    clean[j] = 0
                    if spr_w == 2 and j < 16 and (row[j+1] == s+1) then
                        clean[j+1] = 0
                    end
                    self.level_rows[i] = clean
                    row = clean
                end
            end
        end
    end
end

function GameScreen:updateEngineHum()
    local num_sounds = SOUND_HUM_LAST - SOUND_HUM_FIRST + 1
    if self.state == STATE_PLAYING
    or self.state == STATE_ESCAPE
    or self.state == STATE_ESCAPING
    or self.state == STATE_ESCAPE_FLY_OFF
    or self.state == STATE_ROCKET_WAVE then
        -- divide GAMEPLAY_H into equal bands; clamp ship y to [0, GAMEPLAY_H-1]
        local band = flr(mid(0, self.player.y, GAMEPLAY_H - 1) / GAMEPLAY_H * num_sounds)
        local snd  = SOUND_HUM_FIRST + band
        if snd != self.hum_snd then
            self.hum_snd = snd
            sfx(snd, SOUND_HUM_CHANNEL, 0, -1)  -- loop until replaced
        end
    else
        if self.hum_snd != -1 then
            self.hum_snd = -1
            sfx(-1, SOUND_HUM_CHANNEL)  -- stop hum
        end
    end
end


function GameScreen:checkPlayerCollision()
    local p = self.player
    for _, probe in ipairs(SHIP_PROBES) do
        local sx = p.x + probe[1]
        local sy = p.y + probe[2]
        local r  = self:rowAt(sy)
        if r and r.sprites then
            local sid = r.sprites[flr(sx / 8) + 1]
            if is_tile_collision(sid, sx % 8, r.spr_phase) then
                if is_reactor_tile(sid) and self.state == STATE_PLAYING then
                    self:triggerEscape()
                elseif not is_reactor_tile(sid) then
                    self:shipDestroyed()
                end
                return
            end
        end
    end
end

-- Check whether the player's padded bounding box overlaps any alive target sprite.
-- Wide targets (TTYPE_FUEL, 16-px-wide wave sprites) use TARGET_SPR_OX_LG; all others
-- use TARGET_SPR_OX_SM.  Vertically, every target sprite is bottom-aligned to its row
-- via TARGET_SPR_OY so the sprite occupies rows [tsy-TARGET_SPR_OY .. tsy].
function GameScreen:checkTargetCollision()
    local p   = self.player
    local sx1 = p.x
    local sx2 = p.x + SHIP_WIDTH  - 1
    local sy1 = p.y
    local sy2 = p.y + SHIP_HEIGHT - 1
    local bwy = self.terrain_base_wy
    local sf  = self.scroll_frac
    for tgt in all(self.targets) do
        if tgt.alive then
            local hw  = ((tgt.ttype == TTYPE_FUEL)
                         or (tgt.ttype == TTYPE_WAVE and tgt.wave_spr_w == 2))
                        and TARGET_SPR_OX_LG or TARGET_SPR_OX_SM
            local tsy = flr((tgt.world_y - bwy) - sf)
            if sx1 <= tgt.x + hw - 1
            and sx2 >= tgt.x - hw
            and sy1 <= tsy
            and sy2 >= tsy - TARGET_SPR_OY then
                self:shipDestroyed()
                return
            end
        end
    end
end

-- Consume fuel based on descent distance (world pixels scrolled since last check).
-- Every FUEL_DESCENT_RATE pixels burns 1 unit. Fuel is clamped to [0, PLAYER_FUEL_MAX].
-- Reaching zero destroys the ship via the normal lives/respawn flow.
function GameScreen:updateFuel()
    local traveled = abs(self.terrain_base_wy - self.fuel_wy_last)
    local burn = flr(traveled / FUEL_DESCENT_RATE)
    if burn > 0 then
        -- advance fuel_wy_last in direction of travel
        if self.terrain_base_wy >= self.fuel_wy_last then
            self.fuel_wy_last += burn * FUEL_DESCENT_RATE
        else
            self.fuel_wy_last -= burn * FUEL_DESCENT_RATE
        end
        self.fuel = mid(0, self.fuel - burn, PLAYER_FUEL_MAX)
        if self.fuel == 0 then
            -- treat fuel exhaustion as a crash: reuse lives/respawn logic
            self:shipDestroyed()
        end
    end
end

-- =============================================
-- Update
-- =============================================

-- Called whenever the ship is destroyed (wall, fuel, etc.).
-- Decrements lives, records death position, and enters the dying animation state.
-- Actual respawn or game-over is deferred until the animation timer expires.
function GameScreen:shipDestroyed()
    sfx(SOUND_EXPLOSION, SOUND_EXPLOSION_CHANNEL)
    if not INVULNERABILITY then
        self.lives -= 1
        self.death_x            = self.player.x
        self.death_y            = self.player.y
        self.death_timer        = DEATH_PAUSE_FRAMES
        self.died_while_escaping   = (self.state == STATE_ESCAPING)
        self.died_while_rocketwave = (self.state == STATE_ROCKET_WAVE)
        self.state              = STATE_DYING
    end
end

-- Reactor collision: freeze scrolling and input, begin escape sequence.
function GameScreen:triggerEscape()
    self.state        = STATE_ESCAPE
    -- scroll_frac is intentionally NOT zeroed here. Zeroing it causes an
    -- abrupt 1-row rendering shift (buffer row 1 jumps to screen y=0) which
    -- produces an intermittent black line depending on t[1].spr_phase.
    -- scrollTerrainReverse uses reverse_frac exclusively, so scroll_frac can
    -- safely remain at its current sub-pixel value throughout the escape.
    self.reverse_frac = 0
    self.ticker_msgs = {
        "enemy destroyed",
        "bomb timer set",
        "escape time "..self.levelDef.escape_time,
    }
    self.ticker_idx   = 1
    self.ticker_x     = 128
    self.ticker_hold  = 0
    sfx(SOUND_ALARM, SOUND_ALARM_CHANNEL, 0, -1)

    speedFactor = ESCAPE_SPEED_FACTOR
end

-- Freeze terrain and begin the rocket wave immediately.
function GameScreen:triggerRocketWave()
    self.state         = STATE_ROCKET_WAVE
    self.rw_scroll     = 0
    self.rw_wave_idx   = 1
    self.rw_wave_pass  = 1
    self.rw_targets    = {}
    self.rw_next_spawn = ROCKET_WAVE_SPACING
    self.rw_fuel_frac  = 0
end

-- Scroll rockets upward, spawn new ones from ROCKET_WAVE, check collisions.
function GameScreen:updateRocketWave()
    self.rw_scroll += ROCKET_WAVE_SCROLL_SPEED
    local advance = flr(self.rw_scroll)
    self.rw_scroll -= advance
    -- move all rockets upward
    for tgt in all(self.rw_targets) do
        tgt.y -= advance
    end
    -- spawn the next entry when enough virtual pixels have traveled
    self.rw_next_spawn -= advance
    while self.rw_next_spawn <= 0 and self.rw_wave_idx <= #ROCKET_WAVE do
        self:spawnRocketWaveTarget(ROCKET_WAVE[self.rw_wave_idx])
        self.rw_wave_idx   += 1
        self.rw_next_spawn += ROCKET_WAVE_SPACING
        if self.rw_wave_idx > #ROCKET_WAVE and self.rw_wave_pass < 2 then
            self.rw_wave_pass += 1
            self.rw_wave_idx   = 1
        end
    end
    -- wall collision
    local p = self.player
    if p.x < 8 or p.x + SHIP_WIDTH > 120 then
        self:shipDestroyed()
        return
    end
    -- player vs rocket AABB collision
    local sx2 = p.x + SHIP_WIDTH  - 1
    local sy2 = p.y + SHIP_HEIGHT - 1
    for tgt in all(self.rw_targets) do
        if tgt.alive
        and p.x  <= tgt.x + tgt.spr_w * 8 - 1 and sx2 >= tgt.x
        and p.y  <= tgt.y + 7               and sy2 >= tgt.y then
            self:shipDestroyed()
            return
        end
    end
    -- end wave once all rockets spawned and scrolled off the top
    if self.rw_wave_idx > #ROCKET_WAVE then
        local any = false
        for tgt in all(self.rw_targets) do
            if tgt.alive and tgt.y + 7 >= 0 then any = true; break end
        end
        if not any then self.state = STATE_PLAYING end
    end
    -- consume fuel at the same rate as descent (terrain is frozen so updateFuel
    -- can't measure distance; use a virtual pixel accumulator instead)
    self.rw_fuel_frac += SCROLL_SPEED * speedFactor
    local burn = flr(self.rw_fuel_frac / FUEL_DESCENT_RATE)
    if burn > 0 then
        self.rw_fuel_frac -= burn * FUEL_DESCENT_RATE
        self.fuel = mid(0, self.fuel - burn, PLAYER_FUEL_MAX)
        if self.fuel == 0 then
            self:shipDestroyed()
            return
        end
    end
end

-- Spawn one ROCKET_WAVE entry at the bottom of the screen.
-- v > 0 → SPRITE_ROCKET at column v+2 (1-based).
-- v < 0 → SPRITE_FUEL_ROCKET at column -v+1 (1-based, 2-wide).
function GameScreen:spawnRocketWaveTarget(v)
    if v == 0 then return end
    local x, sprite, spr_w
    if v > 0 then
        local j = v + 2
        if j < 2 or j > 15 then return end
        x      = (v + 1) * 8
        sprite = SPRITE_ROCKET
        spr_w  = 1
    else
        local j = -v + 1
        if j < 2 or j > 14 then return end
        x      = (-v) * 8
        sprite = SPRITE_FUEL_ROCKET
        spr_w  = 2
    end
    add(self.rw_targets, { x=x, y=GAMEPLAY_H, spr=sprite, spr_w=spr_w, alive=true })
end

-- Prepare targets for escape mode:
-- TTYPE_NODE (radar) targets are all restored alive; all other types are removed.
function GameScreen:prepareEscapeTargets()
    local kept = {}
    for tgt in all(self.targets) do
        if tgt.ttype == TTYPE_NODE then
            tgt.alive = true
            add(kept, tgt)
        end
    end
    self.targets = kept
end

function GameScreen:update()    
    if self.state == STATE_PLAYING then
        self:movePlayer()
        self:handleShooting()
        self:updateBullets()
        self:updateExplosions()
        self:scrollTerrain()
        self:checkPlayerCollision()
        self:checkTargetCollision()
        self:updateFuel()
        self.frame += 1
    elseif self.state == STATE_DYING then
        -- count down the death pause; then respawn or end the game
        self.death_timer -= 1
        if self.death_timer <= 0 then
            if self.lives > 0 then
                self:respawn()
            else
                self.isGameOver = true
                self.state  = STATE_CRASHED
                self.isDone = true
            end
        end
    elseif self.state == STATE_ESCAPE then
        -- scrolling frozen, player input ignored
        self:updateExplosions()
        -- multi-message ticker: each message scrolls to centre, holds, then advances
        local msg  = self.ticker_msgs[self.ticker_idx]
        local centre_x = (128 - #msg * 8) \ 2
        if self.ticker_x > centre_x then
            self.ticker_x = max(centre_x, self.ticker_x - TICKER_SPEED)
        else
            self.ticker_hold += 1
            if self.ticker_hold >= 40 then
                self.ticker_idx  += 1
                self.ticker_x    = 128
                self.ticker_hold = 0
                if self.ticker_idx > #self.ticker_msgs then
                    -- all messages shown: start escaping
                    sfx(-1, SOUND_ALARM_CHANNEL)
                    self.hum_snd = -1  -- force updateEngineHum to restart hum immediately
                    self:prepareEscapeTargets()
                    self.escapeTime  = self.levelDef.escape_time
                    self.escape_tick = 0
                    self.esc_cp_idx  = self.next_cp_idx - 1
                    self.state = STATE_ESCAPING
                end
            end
        end
        self.frame += 1
    elseif self.state == STATE_ESCAPING then
        -- reverse scroll: terrain moves down, player must reach level top
        self.escape_tick += 1
        if self.escape_tick >= FPS then
            self.escape_tick = 0
            self.escapeTime = max(0, self.escapeTime - 1)
        end
        self:movePlayer()
        self:updateBullets()
        self:updateExplosions()
        self:scrollTerrainReverse()
        self:checkPlayerCollision()
        if self.terrain_base_wy <= 0 then
            self.state = STATE_ESCAPE_FLY_OFF
        end
        self.frame += 1
    elseif self.state == STATE_ESCAPE_FLY_OFF then
        -- terrain is frozen; ship flies straight up until fully off screen
        self.player.y -= PLAYER_SPEED_Y * speedFactor
        if self.player.y + SHIP_HEIGHT <= 0 then
            self.isEscaped = true
            self.isDone    = true
        end
        self.frame += 1
    elseif self.state == STATE_ROCKET_WAVE then
        self:movePlayer()
        self:handleShooting()
        self:updateBullets()
        self:updateExplosions()
        self:updateRocketWave()
        self.frame += 1
    end
    self:updateEngineHum()
end

function GameScreen:draw()
    cls(BLACK)
    if self.state == STATE_ROCKET_WAVE
    or (self.state == STATE_DYING and self.died_while_rocketwave) then
        self:drawRocketWave()
    else
        self:drawTerrain()
        self:drawTileOutlines()
        self:drawTargets()
    end
    self:drawExplosions()
    self:drawBullets()
    self:drawShip()
    self:drawStatusBar()
end

-- Draw the rocket wave: left/right wall columns and all active rocket targets.
function GameScreen:drawRocketWave()
    clip(0, 0, 128, GAMEPLAY_H)
    local flash = flr(time() * 8)
    if flash % 2 == 0 then pal(YELLOW, WHITE) end
    for y = 0, GAMEPLAY_H - 1, 8 do
        spr(SPRITE_WALL, 0, y)
        spr(SPRITE_WALL, 120, y)
    end
    line(7, 0, 7, GAMEPLAY_H - 1, WALL_EDGE_COLOR)
    line(120, 0, 120, GAMEPLAY_H - 1, WALL_EDGE_COLOR)
    for tgt in all(self.rw_targets) do
        if tgt.alive and tgt.y < GAMEPLAY_H and tgt.y + 7 >= 0 then
            local draw_spr = tgt.spr
            if tgt.spr == SPRITE_FUEL_ROCKET and flr(self.frame / 5) % 2 == 1 then
                draw_spr = SPRITE_FUEL_ROCKET2
            end
            spr(draw_spr, tgt.x, tgt.y, tgt.spr_w, 1)
        end
    end
    pal()
    clip()
end

-- Advance explosion animations and remove any that have scrolled off the top.
function GameScreen:updateExplosions()
    local bwy  = self.terrain_base_wy
    local sf   = self.scroll_frac
    local live = {}
    for e in all(self.explosions) do
        if e.vy ~= 0 then e.world_y -= e.vy end
        local sy = flr((e.world_y - bwy) - sf)
        if sy > -16 then
            add(live, e)
        end
    end
    self.explosions = live
end

-- Draw active explosions: 16x16, centered horizontally, bottom-aligned to target.
-- All explosions share the same animation frame, normalised to 30fps so the
-- animation speed is unchanged when FPS changes.
function GameScreen:drawExplosions()
    local bwy = self.terrain_base_wy
    local sf  = self.scroll_frac
    local pos = flr(self.frame * 30 / FPS) % 15
    local fi  = pos < 8 and pos + 1 or 15 - pos + 1
    local s   = SPRITE_EXPLOSION[fi]
    for e in all(self.explosions) do
        local sy = flr((e.world_y - bwy) - sf)
        spr(s, e.x - 8, sy - 15, 2, 2)
    end
end

function GameScreen:drawTargets()
    local bwy = self.terrain_base_wy
    local sf  = self.scroll_frac
    clip(0, 0, 128, GAMEPLAY_H)
    local flash = flr(time()*8)
    if self.state == STATE_ESCAPE or self.state == STATE_ESCAPING then
        local phase = flash % 4
        if     phase == 0 then pal(YELLOW, BROWN)
        elseif phase == 1 then pal(YELLOW, ORANGE)
        elseif phase == 3 then pal(YELLOW, ORANGE) end
    elseif flash % 2 == 0 then
        pal(YELLOW, WHITE)
    end
    for tgt in all(self.targets) do
        if tgt.alive then
            local tsy = flr((tgt.world_y - bwy) - sf)
            if tsy >= 0 and tsy - TARGET_SPR_OY < GAMEPLAY_H then
                local ox = tgt.spr_w == 2 and TARGET_SPR_OX_LG or TARGET_SPR_OX_SM
                local draw_spr = tgt.spr
                if tgt.spr == SPRITE_FUEL_ROCKET and flr(self.frame / 5) % 2 == 1 then
                    draw_spr = SPRITE_FUEL_ROCKET2
                end
                spr(draw_spr, tgt.x - ox, tsy - TARGET_SPR_OY, tgt.spr_w, 1)
            end
        end
    end
    pal()
    clip()
end

-- Draw 1px blue outlines on the edges of SQUARE_TILES that face an empty tile.
-- Iterates over sprite bands (spr_phase==0 entries); for each empty tile checks
-- its 4 orthogonal neighbours. Lines extend 1px beyond the tile boundary each
-- end so that corners meet cleanly.
-- Draw 1px outlines on SQUARE_TILES edges that face empty (sprite-0) space.
-- Iterates spr_phase==0 band-top entries. For each solid SQUARE_TILE checks
-- all 4 neighbours; draws into the empty neighbour's pixel (not the solid tile).
function GameScreen:drawTileOutlines()
    local t  = self.terrain
    local sf = self.scroll_frac
    for i = 1, #t do
        local r = t[i]
        if (r.spr_phase == 0 or i == 1) and r.sprites then
            local sy = flr((i - 1) - sf) - r.spr_phase  -- band top y
            if sy >= GAMEPLAY_H then break end
            -- sprites of the row above (spr_phase 7 of prev band) and below
                local asp = (i > 1)     and t[i-1].sprites or nil
                local bsp = (i+8 <= #t) and t[i+8].sprites or nil
                for j = 0, 15 do
                    local s = r.sprites[j+1]
                    if s and s != 0 and is_square_tile(s) then
                        local x = j * 8
                        -- right face → rightmost pixel column of solid tile
                        local rn = (j < 15) and (r.sprites[j+2] or 0) or -1
                        if rn == 0 then
                            line(x+7, sy, x+7, sy+7, TILE_OUTLINE_COLOR)
                        end
                        -- left face → leftmost pixel column of solid tile
                        local ln = (j > 0) and (r.sprites[j] or 0) or -1
                        if ln == 0 then
                            line(x, sy, x, sy+7, TILE_OUTLINE_COLOR)
                        end
                        -- top face → top pixel row of solid tile
                        local an = asp and (asp[j+1] or 0) or -1
                        if an == 0 then
                            line(x, sy, x+7, sy, TILE_OUTLINE_COLOR)
                        end
                        -- bottom face → bottom pixel row of solid tile
                        local bn = bsp and (bsp[j+1] or 0) or -1
                        if bn == 0 then
                            line(x, sy+7, x+7, sy+7, TILE_OUTLINE_COLOR)
                        end
                    end
                end
        end
    end
end

-- Draw the tile grid. Each 8×8 sprite is drawn once at the top of its pixel band
-- (spr_phase==0). Empty (sprite 0) tiles are skipped.
function GameScreen:drawTerrain()
    local t  = self.terrain
    local sf = self.scroll_frac
    -- flash: normal = yellow↔white; escape = brown/orange/yellow/orange 4-way cycle
    local flash = flr(time()*8)
    if self.state == STATE_ESCAPE or self.state == STATE_ESCAPING then
        local phase = flash % 4
        if     phase == 0 then pal(YELLOW, BROWN)
        elseif phase == 1 then pal(YELLOW, ORANGE)
        elseif phase == 3 then pal(YELLOW, ORANGE) end
    elseif flash % 2 == 0 then
        pal(YELLOW, WHITE)
    end
    for i = 1, #t do
        local sy = flr((i - 1) - sf)
        if sy >= GAMEPLAY_H then break end
        local r = t[i]
        -- draw_y: top-left y of this sprite band
        local draw_y = sy - r.spr_phase
        -- draw when the band top enters the buffer (spr_phase==0), or when i==1
        -- and the band started above the buffer top (spr_phase!=0, partially cut off)
        if (r.spr_phase == 0 or i == 1) and draw_y >= -7 and r.sprites then
            for j = 0, 15 do
                local sid = r.sprites[j + 1]
                if sid and sid != 0 then
                    spr(sid, j * 8, draw_y)
                end
            end
        end
    end
    pal()
end

function GameScreen:drawShip()
    local p = self.player
    if self.state == STATE_DYING then
        -- draw explosion sprite at death position with random flips each frame
        spr(SPRITE_SHIP_EXPLOSION, self.death_x, self.death_y,
            SHIP_SPR_W, SHIP_SPR_H, rnd(1) > 0.5, rnd(1) > 0.5)
    else
        spr(SPRITE_PLAYER_SHIP, p.x, p.y, SHIP_SPR_W, SHIP_SPR_H)
    end
end

function GameScreen:drawBullets()
    for b in all(self.bullets) do
        pset(b.x, b.y, YELLOW)
    end
end

-- Draw status bar.  Always called last so it sits in the foreground.
-- Layout (all values from Global.lua):
--   Left  – one SPRITE_LIFE_REMAINING icon per remaining life, horizontally spaced
--   Centre – score on the first text line, fuel on the second
function GameScreen:drawStatusBar()
    -- solid white background spanning the full width of the reserved strip
    rectfill(0, GAMEPLAY_H, 127, 127, STATUS_BAR_COLOR)

    -- lives: icons left-aligned on the bottom row
    for i = 1, self.lives -1 do
        spr(SPRITE_LIFE_REMAINING,
            1 + (i - 1) * STATUS_LIFE_GAP,
            STATUS_LIFE_SPR_Y)
    end

    local score_str = "SCORE:" .. score
    print(score_str, (128 - #score_str * 4) \ 2, STATUS_SCORE_Y, BLACK)
    -- cavern number: flag icons right-aligned on bottom row
    for i = 1, currentCavern - 1 do
        spr(SPRITE_FLAG, 127 - i * 6, STATUS_LIFE_SPR_Y)
    end

    if self.state == STATE_ESCAPE then
        -- ticker: show current message, hide fuel, keep score
        if self.ticker_msgs then
            local msg = self.ticker_msgs[self.ticker_idx]
            if msg then
                print("\^w"..msg, self.ticker_x, STATUS_FUEL_Y, BLACK)
            end
        end
    elseif self.state == STATE_ESCAPING or self.state == STATE_ESCAPE_FLY_OFF then
        -- keep "escape time N" centred and live during the escape
        local cdown = "escape time "..self.escapeTime
        print("\^w"..cdown, (128 - #cdown * 8) \ 2, STATUS_FUEL_Y, BLACK)
    else
        -- fuel centred on top row; score centred on bottom row
        local fuel_str  = "FUEL:"  .. self.fuel
        print(fuel_str,  (128 - #fuel_str  * 4) \ 2, STATUS_FUEL_Y,  BLACK)
    end
end

