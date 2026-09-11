extends RefCounted

static func compact(value: float) -> String:
	for unit in [[1.0e15, "Q"], [1.0e12, "T"], [1.0e9, "B"], [1.0e6, "M"], [1.0e3, "K"]]:
		if absf(value) >= float(unit[0]):
			return "%s%s" % [decimal(value / float(unit[0])), unit[1]]
	return decimal(value)

static func decimal(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))
	return "%.2f" % value

static func percent(ratio: float) -> String:
	return "%s%%" % decimal(ratio * 100.0)

static func multiplier(value: float) -> String:
	return "×%s" % decimal(value)
