local utility = {}

function utility.clamp(maximum, number, minimum)
	return math.max(math.min(maximum, number), minimum)
end

return utility