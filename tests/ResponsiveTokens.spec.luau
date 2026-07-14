--!strict

local ResponsiveTokens = require("../src/client/director/ResponsiveTokens")

local assertions = 0
local function expect(condition: boolean, message: string)
	assertions += 1
	assert(condition, message)
end

local phone = ResponsiveTokens.forWidth(390)
local tablet = ResponsiveTokens.forWidth(820)
local desktop = ResponsiveTokens.forWidth(1440)
expect(phone.class == "Phone" and phone.buttonHeight >= 44, "phone tokens preserve touch targets")
expect(
	tablet.class == "Tablet" and tablet.margin > phone.margin,
	"tablet tokens add breathing room"
)
expect(
	desktop.class == "Desktop" and desktop.maxContentWidth == 960,
	"desktop content width is bounded"
)

local x, y, width, height = ResponsiveTokens.contentBounds(1440, 900)
expect(x == 240 and width == 960, "desktop content remains centered")
expect(y == 20 and height == 860, "desktop safe margins are applied")

local phoneX, _, phoneWidth = ResponsiveTokens.contentBounds(390, 844)
expect(phoneX == 12 and phoneWidth == 366, "phone layout uses compact safe margins")

print(`PASS ResponsiveTokens.spec ({assertions} assertions)`)
