local plugin = {
  PRIORITY = 1000,
  VERSION = "0.1",
}

local complianceHeaders = {
  ["Content-Type"] = "application/json"
}

local compliancePayload = {}
local reqData = {}

-- handles more initialization, but AFTER the worker process has been forked/created.
-- It runs in the 'init_worker_by_lua_block'
function plugin:init_worker()
  -- your custom code here
  kong.log.debug("saying hi from the 'init_worker' handler")
end

-- runs in the 'access_by_lua_block'
function plugin:access(plugin_conf)
  -- your custom code here
  kong.log.inspect(plugin_conf)   -- check the logs for a pretty-printed config!
  -- kong.service.request.set_header(plugin_conf.request_header, "this is on a request")
end

function plugin:response(plugin_conf)
  -- kong.response.set_header(plugin_conf.response_header, "this is on the response")

  if(plugin_conf.target ~= "undefined" and plugin_conf.key ~= "undefined" and plugin_conf.workspaceId ~= "undefined")
  then
    local resData = {}
    local json = require "cjson"
    local http = require "resty.http"
    local client = http.new()

    -- Request Data
    local headerParams = kong.request.get_headers()
    if(headerParams["content-type"] ~= nil)
    then
      -- kong.response.set_header("REQH-Before", headerParams["content-type"])
      local contentType = headerParams["content-type"]
      headerParams["content-type"] = nil
      headerParams["Content-Type"] = contentType
    end
    -- kong.response.set_header("REQ-H", json.encode(headerParams))

    local queryParams = kong.request.get_query()
    local formParams = {}

    local scheme = kong.request.get_scheme()
    local host = kong.request.get_host()
    local port = kong.request.get_port()
    local verb = kong.request.get_method()
    local path = kong.request.get_path()
    local hostname = kong.request.get_host()

    local requestBody = kong.request.get_body()
    if(requestBody ~= nil)
    then
      requestBody = json.encode(requestBody)
    end

    reqData.headerParams = headerParams
    reqData.queryParams = queryParams
    reqData.formParams = formParams
    reqData.hostname = hostname
    reqData.verb = verb
    reqData.path = path
    reqData.requestBody = requestBody

    compliancePayload.request = reqData

    --Response Data
    local resData = {}
    local resHeaders = kong.response.get_headers()

    if(resHeaders["content-type"] ~= nil)
    then
      -- kong.response.set_header("RESH-Before", resHeaders["content-type"])
      local contentType = resHeaders["content-type"]
      resHeaders["content-type"] = nil
      resHeaders["Content-Type"] = contentType
    end
    -- kong.response.set_header("RES-H", json.encode(resHeaders))

    local resBody = kong.service.response.get_body()
    local statusCode = kong.response.get_status()
    resData.headerParams = resHeaders
    resData.responseBody = tostring(json.encode(resBody))
    resData.statusCode = tostring(statusCode)

    compliancePayload.response = resData

    kong.response.set_header("Comp-Req-Payload", json.encode(compliancePayload))

    complianceHeaders["workspace-id"] = plugin_conf.workspaceId
    complianceHeaders["x-apikey"] = plugin_conf.key

    local res, err = client:request_uri(plugin_conf.target,{
      method = "POST",
      headers = complianceHeaders,
      body = json.encode(compliancePayload)
    })

    kong.response.set_header("service-callout-response", json.encode(res.body))
    if client then client:close() end
    
  end
end


-- return our plugin object
return plugin