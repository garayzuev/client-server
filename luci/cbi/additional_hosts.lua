--/usr/lib/lua/luci/model/cbi/additional_hosts.lua
local fs = require "nixio.fs"
local sys = require "luci.sys"

m = SimpleForm("additional_hosts", "Additional Hosts Editor")
m.reset = false
m.submit = "Save"

local file_path = "/etc/additional_hosts"

t = m:field(TextValue, "content", "")
t.rows = 25
t.wrap = "off"

function t.cfgvalue()
    if not fs.access(file_path) then
        fs.writefile(file_path, "")
        return ""
    end
    return fs.readfile(file_path) or ""
end

function t.write(self, section, value)
    -- гарантированно создаём файл, даже если его не было
    local ok = fs.writefile(file_path, value)

    if ok then
        sys.call("service getdomains start >/dev/null 2>&1")
    end
end

return m
