--!strict
-- Display formatting shared by every UI.

local Format = {}

local function withCommas(n: number): string
	local s = tostring(math.floor(math.abs(n)))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return (if n < 0 then "-" else "") .. out
end

local SUFFIXES = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" } }

-- "$950", "$12,800", "$1.25M", "$34.8M"
function Format.money(n: number): string
	for _, s in SUFFIXES do
		if math.abs(n) >= s[1] then
			local short = ("%.2f"):format(n / s[1]):gsub("%.?0+$", "")
			return "$" .. short .. s[2]
		end
	end
	return "$" .. withCommas(n)
end

return Format
