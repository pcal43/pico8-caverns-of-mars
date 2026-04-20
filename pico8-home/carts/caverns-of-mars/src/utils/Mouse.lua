
mousePreviousButtonState = 0
mousePreviousX = -1
mousePreviousY = -1

 -- enable mouse support
function mouseEnable()
	poke(0x5f2d, 1)

    mousePreviousX = stat(32)
    mousePreviousY = stat(33)
    mousePreviousButtonState = stat(34)	
end

function mouseCoordinates()
	return stat(32), stat(33)
end

function mouseWasMoved()
	local newX, newY = mouseCoordinates()
	if newX != mousePreviousX or newY != mousePreviousY then
        mousePreviousX, mousePreviousY = newX, newY
		return true
	else
		return false
	end
end

-- return true if the mouse is down now but wasn't the last time
-- wasClicked() was called (i.e., it's been clicked since then)
function mouseWasClicked()
	if stat(34) == 0 then
	    mousePreviousButtonState = 0		
	elseif mousePreviousButtonState == 0 then
	    mousePreviousButtonState = 1		
		return true
	end
	return false
end