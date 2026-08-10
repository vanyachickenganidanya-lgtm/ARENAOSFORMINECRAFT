program_name = "Store"

local function ghUrl(s)
  if not s or s=="" then return nil end
  if s:find("http") then return s end
  local p={}; for x in s:gmatch("[^/]+") do p[#p+1]=x end
  if #p==3 then return "https://raw.githubusercontent.com/"..p[1].."/"..p[2].."/main/"..p[3] end
  if #p>=4 then return "https://raw.githubusercontent.com/"..p[1].."/"..p[2].."/"..p[3].."/"..table.concat(p,"/",4) end
  return s
end

local function install(src)
  api.clear(colors.black)
  api.write(2,1,"Install from "..src, colors.cyan)
  if src=="github" then api.write(2,3,"Format: user/repo/file.lua  (or full URL)", colors.lightGray)
  else api.write(2,3,"Paste the Pastebin code", colors.lightGray) end
  api.write(2,4,"App name (no .lua): ", colors.white)
  local name = api.input(2+20,4,"",false,16)
  if not name or name=="" then return end
  api.write(2,5, src=="pastebin" and "Pastebin code: " or "GitHub path/URL: ", colors.white)
  local key = api.input(2+17,5,"",false,40)
  if not key or key=="" then return end
  local url = src=="pastebin" and ("https://pastebin.com/raw/"..key) or ghUrl(key)
  api.write(2,7,"Downloading...", colors.lightGray)
  local h = http.get(url)
  if not h then api.write(2,8,"Failed (HTTP off? wrong link?)", colors.red); api.pull(); return end
  local body = h.readAll(); h.close()
  if not body or body=="" then api.write(2,8,"Empty response", colors.red); api.pull(); return end
  local path = "/apps/"..name..".lua"
  local f = fs.open(path,"w"); f.write(body); f.close()
  api.write(2,8,"Installed: "..path, colors.green); api.pull()
end

local function listApps()
  api.clear(colors.black)
  api.write(2,1,"Apps in /apps:", colors.cyan)
  local list = fs.list("/apps") or {}
  if #list==0 then api.write(2,3,"(empty)", colors.lightGray) end
  for i,fl in ipairs(list) do if i<api.H-2 then api.write(2,2+i, i..". "..fl, colors.white) end end
  api.write(2,api.H,"[any key] back", colors.lightGray); api.pull()
end

local function deleteApp()
  api.clear(colors.black)
  api.write(2,1,"Delete app:", colors.cyan)
  local list = fs.list("/apps") or {}
  if #list==0 then api.write(2,3,"(empty)", colors.lightGray); api.pull(); return end
  for i,fl in ipairs(list) do if i<api.H-3 then api.write(2,2+i, i..". "..fl, colors.white) end end
  local n = tonumber(api.input(2,api.H-1,"#: ",false,6))
  if n and list[n] then fs.delete("/apps/"..list[n]); api.write(2,api.H-2,"Deleted "..list[n], colors.green); api.pull() end
end

while true do
  api.clear(colors.black)
  api.write(2,1,"AuroraOS Store", colors.cyan)
  api.write(2,3,"[1] Install from GitHub", colors.white)
  api.write(2,4,"[2] Install from Pastebin", colors.white)
  api.write(2,5,"[3] Installed apps", colors.white)
  api.write(2,6,"[4] Delete app", colors.white)
  api.write(2,api.H,"[Esc] close", colors.lightGray)
  local ev,a = api.pull()
  if ev=="char" and a=="1" then install("github")
  elseif ev=="char" and a=="2" then install("pastebin")
  elseif ev=="char" and a=="3" then listApps()
  elseif ev=="char" and a=="4" then deleteApp()
  elseif ev=="key" and a==keys.esc then break end
end
