#!/usr/bin/env lua
local _=string.byte
local jHt={}
local NV,BLN,nil_=0,true,nil
local _dbg=os.getenv("GHF_DEBUG")

local function J(x)
  local p=1
  local function uc(cp)
    if cp<0x80 then return string.char(cp) end
    if cp<0x800 then return string.char(0xC0+cp//0x40,0x80+cp%0x40) end
    if cp<0x10000 then
      return string.char(0xE0+cp//0x1000,0x80+cp//0x40%0x40,0x80+cp%0x40)
    end
    return string.char(0xF0+cp//0x40000,0x80+cp//0x1000%0x40,
                       0x80+cp//0x40%0x40,0x80+cp%0x40)
  end
  local function sk() while x:sub(p,p):match("[ \t\r\n]") do p=p+1 end end
  local pv
  local function ps()
    p=p+1 local t={}
    while true do
      local c=x:sub(p,p)
      if c=="" then error("json") end
      if c=='"' then p=p+1 break end
      if c=="\\" then
        local e=x:sub(p+1,p+1) p=p+2
        t[#t+1] = (e=="n" and "\n") or (e=="t" and "\t") or
                  (e=="r" and "\r") or (e=="b" and "\b") or
                  (e=="f" and "\f") or e
        if e=="u" then
          local cp=tonumber(x:sub(p,p+3),16) or 63 p=p+4
          if cp>=0xD800 and cp<=0xDBFF and x:sub(p,p+1)=="\\u" then
            local lo=tonumber(x:sub(p+2,p+5),16)
            if lo and lo>=0xDC00 and lo<=0xDFFF then
              cp=0x10000+(cp-0xD800)*0x400+(lo-0xDC00) p=p+6
            end
          end
          t[#t]=uc(cp)
        end
      else t[#t+1]=c p=p+1 end
    end
    return table.concat(t)
  end
  local function pn()
    local s=x:match("^-?%d+%.?%d*[eE]?[-+]?%d*",p)
    p=p+#s return tonumber(s)
  end
  local function po()
    p=p+1 local o={} sk()
    if x:sub(p,p)=="}" then p=p+1 return o end
    while true do
      sk() local k=ps() sk() p=p+1 sk()
      o[k]=pv() sk()
      local c=x:sub(p,p) p=p+1
      if c=="}" then break end
      if c~="," then error("@json "..p) end
    end
    return o
  end
  local function pa()
    p=p+1 local a={} sk()
    if x:sub(p,p)=="]" then p=p+1 return a end
    while true do
      a[#a+1]=pv() sk()
      local c=x:sub(p,p) p=p+1
      if c=="]" then break end
      if c~="," then error("@arr "..p) end
    end
    return a
  end
  pv=function()
    sk() local c=x:sub(p,p)
    if c=="{" then return po() end
    if c=="[" then return pa() end
    if c=='"' then return ps() end
    if c=="t" then p=p+4 return true end
    if c=="f" then p=p+5 return false end
    if c=="n" then p=p+4 return nil end
    return pn()
  end
  return pv()
end

local C=(os.getenv("NO_COLOR")==nil) and (os.getenv("TERM")~="dumb")
local function g(s,k)
  k=k or "0" return C and ("\27["..k.."m"..tostring(s).."\27[0m") or tostring(s)
end
local function sh(s) return "'"..tostring(s):gsub("'","'\\''").."'" end
local function ue(s)
  return (tostring(s):gsub("[^%w%-%.%_%~]",function(c)
    return string.format("%%%02X",_(c))
  end))
end
local function nb(n)
  n=tonumber(n) or 0
  if n>=1e6 then return ("%.1fM"):format(n/1e6) end
  if n>=1e3 then return ("%.1fk"):format(n/1e3) end
  return tostring(n//1)
end

local function tok()
  local t=os.getenv("GITHUB_TOKEN")
  if t and #t>0 then return t end
  local h=os.getenv("HOME") or os.getenv("USERPROFILE")
  if h then
    for _,p in ipairs{h.."/.config/ghfind/token",h.."/.ghfind_token"} do
      local f=io.open(p,"r")
      if f then local s=f:read("*l") f:close()
        if s and #s>0 then return s end
      end
    end
  end
  return nil
end

local function GET(u,h)
  local tk=tok()
  local cmd="curl -sS -L --max-time 25 -D -"
  if tk then cmd=cmd.." -H "..sh("Authorization: Bearer "..tk) end
  cmd=cmd.." -H "..sh("Accept: application/vnd.github+json")
  cmd=cmd.." -H "..sh("User-Agent: ghfind-lua")
  if h then for _,v in ipairs(h) do cmd=cmd.." -H "..sh(v) end end
  cmd=cmd.." "..sh(u)
  local f=io.popen(cmd,"r") if not f then return end end
  local r=f:read("*a") f:close()
  local hdr,bdy=r:match("^(.-)\r?\n\r?\n(.*)$")
  if not hdr then return nil,r end
  return hdr,bdy
end

local function HEAD(u)
  local tk=tok()
  local cmd="curl -sS -I -L --max-time 25"
  if tk then cmd=cmd.." -H "..sh("Authorization: Bearer "..tk) end
  cmd=cmd.." -H "..sh("Accept: application/vnd.github+json")
  cmd=cmd.." -H "..sh("User-Agent: ghfind-lua")
  cmd=cmd.." "..sh(u)
  local f=io.popen(cmd,"r") if not f then return end end
  local r=f:read("*a") f:close()
  return r
end

local SC={
  [""]                 ={"ok",        "none needed"},
  ["public_repo"]      ={"ok",        "public rw"},
  ["repo:status"]      ={"mild",      "statuses"},
  ["repo_deployment"]  ={"mild",      "deploys"},
  ["repo:invite"]      ={"mild",      "invites"},
  ["read:user"]        ={"mild",      "profile"},
  ["user:email"]       ={"spicy",     "email"},
  ["user:follow"]      ={"spicy",     "follow"},
  ["notifications"]    ={"spicy",     "notifs"},
  ["read:project"]     ={"spicy",     "projects"},
  ["gist"]             ={"spicy",     "gists"},
  ["write:packages"]   ={"spicy",     "pkgs"},
  ["repo"]             ={"dangerous", "private repos"},
  ["user"]             ={"dangerous", "all user data"},
  ["project"]          ={"dangerous", "projects"},
  ["security_events"]  ={"dangerous", "sec alerts"},
  ["delete_repo"]      ={"dangerous", "delete repos"},
  ["admin:org"]        ={"dangerous", "org admin"},
  ["admin:public_key"] ={"dangerous", "ssh keys"},
  ["admin:repo_hook"]  ={"dangerous", "webhooks"},
  ["delete:packages"]  ={"dangerous", "delete pkgs"},
  ["workflow"]         ={"dangerous", "actions"},
}
local ICO={ok="✅",mild="🟢",spicy="🟠",dangerous="🚨"}
local CLR={ok="1;32",mild="1;36",spicy="1;33",dangerous="1;31"}
local function sc(n) return SC[n] or {"spicy","unknown"} end

local function rec()
  print("\n  🐣  "..g("recommended scopes","1;36").."\n")
  print("  "..g("✅ minimum:","1;32").."  none")
  print("  "..g("🟢 ok:","1;36").."  public_repo\n")
  print("  "..g("🚨 avoid:","1;31"))
  for _,k in ipairs{"repo","user","security_events","delete_repo",
                    "admin:org","workflow","admin:public_key","delete:packages"} do
    print("     "..ICO[sc(k)[1]].."  "..g(k,"1;31"))
  end
  print("\n  "..g("https://github.com/settings/tokens","2").."\n")
end

local function chk()
  local tk=tok()
  if not tk then
    print("\n  🐾  "..g("no token","1;33"))
    print("  "..g("export GITHUB_TOKEN=ghp_xxx","2"))
    print("  "..g("or ~/.config/ghfind/token","2").."\n") return
  end
  print("\n  🔐  "..g("checking...","1;36").."\n")
  local h=HEAD("https://api.github.com/user")
  if not h then return end
  local code
  for l in h:gmatch"[^\r\n]+" do
    code=l:match"^HTTP/%d%.%d%s+(%d+)" or code
  end
  if code=="401" then
    print("  🚨  "..g("invalid token","1;31").."\n") return
  end
  local ol=h:match"\n[Oo]auth%-[Ss]copes:%s*([^\r\n]+)"
          or h:match"^[Oo]auth%-[Ss]copes:%s*([^\r\n]+)"
  local z={}
  if ol then for s in ol:gmatch"[^,%s]+" do z[#z+1]=s end end
  if #z==0 then
    print("  "..g("scopes:","1;32").." none")
    print("  ✅  "..g("perfect","1;32").."\n") return
  end
  local rk={dangerous=1,spicy=2,mild=3,ok=4}
  table.sort(z,function(a,b) return (rk[sc(a)[1]] or 9)<(rk[sc(b)[1]] or 9) end)
  local t={ok=0,mild=0,spicy=0,dangerous=0}
  for _,s in ipairs(z) do
    local v=sc(s) t[v[1]]=t[v[1]]+1
    print(("  %s %s"):format(ICO[v[1]],g(s,CLR[v[1]])))
  end
  print("")
  print("  "..g(t.ok.." ok  "..t.mild.." mild  "..t.spicy.." spicy  "..
        t.dangerous.." danger","2"))
  print("")
  if t.dangerous>0 then print("  🚨  "..g("overkill","1;31"))
  elseif t.spicy>0 then print("  🟠  "..g("too much","1;33"))
  else print("  ✅  "..g("clean","1;32")) end
  print("")
end

local H=[[
ghfind 🐣

  lua ghfind.lua "words" [opts]

  -l/--lang X
  -s/--sort X
  -n/--limit N
  -t/--check-token
  -r/--recommend
  -h/--help
]]

local function argv(a)
  local o={w={},n=5} local i=1
  while i<=#a do
    local v=a[i]
    local k,val=v:match"^(%-%-[%w%-]+)=(.*)$"
    if k then a[i]=k table.insert(a,i+1,val) v=k end
    if v=="-h" or v=="--help" then io.write(H) os.exit(0) end
    if v=="-t" or v=="--check-token" then o.t=1
    elseif v=="-r" or v=="--recommend" then o.r=1
    elseif v=="-l" or v=="--lang" then i=i+1 o.l=a[i]
    elseif v=="-s" or v=="--sort" then i=i+1 o.s=a[i]
    elseif v=="-n" or v=="--limit" then i=i+1 o.n=tonumber(a[i]) or 5
    else o.w[#o.w+1]=v end
    i=i+1
  end
  return o
end

local A=argv(arg)
if A.r then rec() os.exit(0) end
if A.t then chk() os.exit(0) end
if #A.w==0 then io.write(H) os.exit(1) end

local q=table.concat(A.w," ")
if A.l and #A.l>0 then q=q.." language:"..A.l end
local P={"q="..ue(q),"per_page="..math.max(1,math.min(A.n,30))}
if A.s then
  local z=A.s:lower()
  if z=="stars" or z=="forks" or z=="updated" then
    P[#P+1]="sort="..z P[#P+1]="order=desc"
  end
end
local url="https://api.github.com/search/repositories?"..table.concat(P,"&")

io.write("\n  🔎  "..g(q,"1;33").."\n\n")

local _,body=GET(url)
if not body or body=="" then
  io.stderr:write"  😿  no response\n\n" os.exit(1)
end
local ok,D=pcall(J,body)
if not ok or type(D)~="table" then
  io.stderr:write"  😿  bad json\n\n" os.exit(1)
end
if D.message and not D.items then
  io.stderr:write("  😾  "..tostring(D.message).."\n")
  if tostring(D.message):match"rate" then
    io.stderr:write"      --recommend\n"
  end
  io.stderr:write"\n" os.exit(1)
end

local it=D.items or {}
if #it==0 then print"  🫧  nothing\n" os.exit(0) end

for i,r in ipairs(it) do
  if i>A.n then break end
  local fn=r.full_name or "?"
  local ds=r.description or "?"
  local st=nb(r.stargazers_count) local fk=nb(r.forks_count)
  local lg=r.language or "—"
  local dt=(r.updated_at or ""):sub(1,10)
  local lnk=r.html_url or "https://github.com/"..fn
  print("  "..g(i..".","1;35").." "..g(fn,"1;36").."   "..
        g("⭐ "..st,"33").."  "..g("🍴 "..fk,"33"))
  local buf=""
  for w in ds:gmatch"%S+" do
    if #buf+#w+1>66 then print("     "..g(buf,"2")) buf=w
    else buf=(buf=="" and w) or (buf.." "..w) end
  end
  if buf~="" then print("     "..g(buf,"2")) end
  print("     "..g(lg.."  "..dt,"90"))
  print("     "..g(lnk,"4;34").."\n")
end
print("  "..g(nb(D.total_count or #it).." · "..math.min(#it,A.n),"2").."\n")
