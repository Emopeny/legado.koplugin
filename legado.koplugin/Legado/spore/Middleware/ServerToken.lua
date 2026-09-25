local logger = require("logger")
local type = type
local string = string

local m = {}

-- 类型1 (开源阅读 app 型) 的服务端内置账号中间件。
-- 我们的 headless 服务端在 WebApi.authorized() 里接受 ?token=<token> 查询参数兜底
-- (WebSocket 握手无法自定义请求头), 故与 Legado3Auth 同形, 只把参数名换成 token。
function m.call(args, req)
    local app = args.app
    if not app then return function(res) return res end end

    if true == app._need_login and true == app._use_server_token then
        local loginSuccess, token = app:ensureLogin()
        if loginSuccess == true and type(token) == 'string' and token ~= '' then
            local query_token = string.format("token=%s", token)
            if type(req.env.QUERY_STRING) == 'string' and #req.env.QUERY_STRING > 0 then
                req.env.QUERY_STRING = req.env.QUERY_STRING .. '&' .. query_token
            else
                req.env.QUERY_STRING = query_token
            end
        else
            logger.warn('ServerToken', '登录失败', token or 'nil')
        end
    end

    return function(res)
        if type(res) == 'table' and type(res.body) == 'table' and
            res.body.isSuccess == false and app:isNeedLogin(res.body) then
            app.tokenManager:clear()
        end
        return res
    end
end

return m
