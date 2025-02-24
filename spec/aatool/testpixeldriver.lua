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
	luaunit.assertEquals(newDriver.driverXY, { 0, 0 }, "Position not initialized to { 0, 0 }")
	luaunit.assertEquals(newDriver.borderWeb, { }, "Border web not initialized to empty list")
	luaunit.assertEquals(newDriver.webCluster, { }, "Web cluster not initialized to empty list")
	luaunit.assertEquals(newDriver.visitedPixels, { }, "Visited pixels not initialized to empty list")
	luaunit.assertEquals(newDriver.boundSelection, selection, "Selection not initialized to provided dummy")
end

os.exit(luaunit.LuaUnit.run())
