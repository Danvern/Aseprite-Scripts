local math = {}

function math.clamp(maximum, number, minimum)
	return math.max(math.min(maximum, number), minimum)
end

return math