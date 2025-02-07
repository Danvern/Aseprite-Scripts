luaunit = require('luaunit')

function testPass()
	luaunit.assertEquals({ 1, 2, 3 }, { 1, 2, 3 })
end

function testFail()
	luaunit.assertEquals({ 1, 2, 3 }, { 1, 2, 6 })
end

os.exit(luaunit.LuaUnit.run())
