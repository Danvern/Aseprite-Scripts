luaunit = require('luaunit')
pixeldriver = require("src.aatool.pixeldriver")

local function getDummySelection()
	return { 0, 0 }
end

TestCreateDriver = {}
function testInitiation()
	local selection = getDummySelection()
	luaunit.assertNotIsNil(pixeldriver, "Import Failed")
	local newDriver = pixeldriver.createDriver(selection)

	luaunit.assertEquals(newDriver.facing, 1, "Facing not initialized to 1")
	luaunit.assertEquals(newDriver.spinDirection, 0, "Facing not initialized to 0 (no inherent spin)")
	luaunit.assertEquals(newDriver.driverXY, { x=0, y=0 }, "Position not initialized to { 0, 0 }")
	luaunit.assertEquals(newDriver.borderWeb, { }, "Border web not initialized to empty list")
	luaunit.assertEquals(newDriver.webCluster, { }, "Web cluster not initialized to empty list")
	luaunit.assertEquals(newDriver.visitedPixels, { }, "Visited pixels not initialized to empty list")
	luaunit.assertEquals(newDriver.boundSelection, selection, "Selection not initialized to provided dummy")
end

function testFacingAhead()
	local selection = getDummySelection()
	local newDriver = pixeldriver.createDriver(selection)

	luaunit.assertEquals(newDriver:getAheadImFacing(), { x=0, y=-1}, "Facing not initialized to 1")
	newDriver.facing = 2; --//TODO: Test local functions???
	luaunit.assertEquals(newDriver:getAheadImFacing(), { x=1, y=-1 }, "Facing not reading properly from ahead after set")
	newDriver.facing = 3; --//TODO: Test local functions???
	luaunit.assertEquals(newDriver:getAheadImFacing(), { x=1, y=0 }, "Facing not reading properly from ahead after set")
	newDriver.facing = 4; --//TODO: Test local functions???
	luaunit.assertEquals(newDriver:getAheadImFacing(), { x=1, y=1 }, "Facing not reading properly from ahead after set")
	newDriver.facing = 5; --//TODO: Test local functions???
	luaunit.assertEquals(newDriver:getAheadImFacing(), { x=0, y=1 }, "Facing not reading properly from ahead after set")
	newDriver.facing = 6; --//TODO: Test local functions???
	luaunit.assertEquals(newDriver:getAheadImFacing(), { x=-1, y=1 }, "Facing not reading properly from ahead after set")
	newDriver.facing = 7; --//TODO: Test local functions???
	luaunit.assertEquals(newDriver:getAheadImFacing(), { x=-1, y=0 }, "Facing not reading properly from ahead after set")
	newDriver.facing = 8; --//TODO: Test local functions???
	luaunit.assertEquals(newDriver:getAheadImFacing(), { x=-1, y=-1 }, "Facing not reading properly from ahead after set")

	--//TODO: Do this test moving the position.
end
os.exit(luaunit.LuaUnit.run())
