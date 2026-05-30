--/usr/lib/lua/luci/controller/additional_hosts.lua
module("luci.controller.additional_hosts", package.seeall)

function index()
    entry(
        {"admin", "services", "additional_hosts"},
        form("additional_hosts"),
        "Additional Hosts",
        90
    ).dependent = true
end
