--[[const]] RIGHT = 1
--[[const]] LEFT  = 2
--[[const]] UP    = 4
--[[const]] DOWN  = 8

DX       = {[RIGHT]=1,   [LEFT]=-1, [UP]=0,    [DOWN]=0  }
DY       = {[RIGHT]=0,   [LEFT]=0,  [UP]=-1,   [DOWN]=1  }
OPPOSITE = {[RIGHT]=LEFT, [LEFT]=RIGHT, [UP]=DOWN, [DOWN]=UP}
CLOCKWISE = {[RIGHT]=DOWN, [LEFT]=UP, [UP]=RIGHT, [DOWN]=LEFT}

function dirDromDxDy(dx, dy)
    if dx > 0 then return RIGHT
    elseif dx < 0 then return LEFT
    elseif dy > 0 then return DOWN
    else return UP
    end
end
