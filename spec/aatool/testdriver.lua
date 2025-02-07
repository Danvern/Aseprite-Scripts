LUAunit = require("luaunit")
TestGroup = {}

function TestGroup:testTrue()
	LUAunit.assertTrue(false)
end

os.exit( LUAunit.LuaUnit.run() )

