local logger = require("logger")
local socket_url = require("socket.url")
local type = type
local string = string
local table = table

local m = {}

-- 类型1 (开源阅读 app 型) 的服务端内置账号中间件。
-- 两条通道同时挂上, 互为兜底:
--   1) ?user=&pwd=  —— 服务端 authorized() 直接校验口令 (verifyPassword), 不依赖 token 缓存与登录往返, 最稳
--   2) ?token=<t>   —— 登录换来的会话 token (ServerToken 登录流程的产物)
-- 之前只挂 token: 实测 API 请求根本没带上 token (每次请求重新登录 1495 次, /getBookshelf 仍 401),
-- 故改为凭据直传为主、token 为辅。
function m.call(args, req)
    local app = args.app
    if not app then return function(res) return res end end

    if true == app._need_login and true == app._use_server_token then
        local extra = {}
        local s = app.settings or {}
        local un, pw = s.reader3_un, s.reader3_pwd
        if type(un) == "string" and un ~= "" then
            extra[#extra + 1] = string.format("user=%s&pwd=%s",
                socket_url.escape(un), socket_url.escape(pw or ""))
        end
        local loginSuccess, token = app:ensureLogin()
        if loginSuccess == true and type(token) == "string" and token ~= "" then
            extra[#extra + 1] = string.format("token=%s", token)
        end
        if #extra > 0 then
            local q = table.concat(extra, "&")
            if type(req.env.QUERY_STRING) == "string" and #req.env.QUERY_STRING > 0 then
                req.env.QUERY_STRING = req.env.QUERY_STRING .. "&" .. q
            else
                req.env.QUERY_STRING = q
            end
        end
    end

    return function(res)
        if type(res) == "table" and type(res.body) == "table" and
            res.body.isSuccess == false and app:isNeedLogin(res.body) then
            app.tokenManager:clear()
        end
        return res
    end
end

return m
