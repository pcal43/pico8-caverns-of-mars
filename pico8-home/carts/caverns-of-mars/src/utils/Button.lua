--[[const]] BUTTON_LEFT = 0
--[[const]] BUTTON_RIGHT = 1
--[[const]] BUTTON_UP = 2
--[[const]] BUTTON_DOWN = 3
--[[const]] BUTTON_O = 4
--[[const]] BUTTON_X = 5

BUTTON_DX = {-1, 1, 0, 0}
BUTTON_DY = {0, 0, -1, 1}

BUTTON_PREVIOUS_STATE = {}

function buttonWasPressed(button)
	local buttonState = btn(button) and 1 or 0
	local pressed = (buttonState == 1 and (BUTTON_PREVIOUS_STATE[button] or 0) == 0)
	BUTTON_PREVIOUS_STATE[button] = buttonState
	return pressed
end

function waitForButtonPress(button)
	while not (buttonWasPressed(button)) do
		yield()
	end
end
