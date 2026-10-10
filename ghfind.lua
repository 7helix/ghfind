#!/usr/bin/env lua
local _=string.byte
local jHt={}
local NV,BLN,nil_=0,true,nil
local _dbg=os.getenv("GHF_DEBUG")
local WS = package.config:sub(1,1)=="\\" and "\\" or "/"

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

local function home()
  return os.getenv("HOME") or os.getenv("USERPROFILE") or "."
end
local function cdir()
  local x = os.getenv("XDG_CACHE_HOME") or (home()..WS..".cache")
  return x..WS.."ghfind"
end
local function mk_p(p)
  if WS == "\\" then
    os.execute('if not exist "'..p..'" mkdir "'..p..'" >nul 2>nul')
  else
    os.execute("mkdir -p "..sh(p).." 2>/dev/null")
  end
end
local function hsh(s)
  local h=5381
  for i=1,#s do h=(h*33+s:byte(i))%0xFFFFFFFF end
  return ("%08x"):format(h)
end

local function ld_seen(k)
  local p = cdir()..WS..hsh(k)..".seen"
  local s = {}
  local f = io.open(p,"r")
  if f then
    for l in f:lines() do if #l>0 then s[l]=true end end
    f:close()
  end
  return s, p
end
local function sv_seen(s, p)
  mk_p(cdir())
  local f = io.open(p,"w")
  if not f then return end
  for k in pairs(s) do f:write(k,"\n") end
  f:close()
end
local function clr_seen()
  if WS == "\\" then
    os.execute('del /q "'..cdir()..'\\*.seen" >nul 2>nul')
  else
    os.execute("rm -f "..sh(cdir()).."/*.seen 2>/dev/null")
  end
end

local function tok()
  local t=os.getenv("GITHUB_TOKEN")
  if t and #t>0 then return t end
  local h=home()
  for _,p in ipairs{h.."/.config/ghfind/token",h.."/.ghfind_token"} do
    local f=io.open(p,"r")
    if f then local s=f:read("*l") f:close()
      if s and #s>0 then return s end
    end
  end
  return nil
end

local function GET(u)
  local tk=tok()
  local cmd="curl -sS -L --max-time 25 -D -"
  if tk then cmd=cmd.." -H "..sh("Authorization: Bearer "..tk) end
  cmd=cmd.." -H "..sh("Accept: application/vnd.github+json")
  cmd=cmd.." -H "..sh("User-Agent: ghfind-lua")
  cmd=cmd.." "..sh(u)
  local f=io.popen(cmd,"r") if not f then return end
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
  local f=io.popen(cmd,"r") if not f then return end
  local r=f:read("*a") f:close()
  return r
end

local function opn(u)
  local cmd
  if WS == "\\" then
    cmd = 'start "" '..sh(u)
  else
    cmd = "(command -v open >/dev/null 2>&1 && open "..sh(u)..
          ") || xdg-open "..sh(u)
  end
  os.execute(cmd.." >/dev/null 2>&1 &")
end

local function ntf(t,b)
  if WS == "\\" then return end
  local o = os.getenv("OSTYPE") or ""
  if o:match("darwin") then
    os.execute("osascript -e "..
      sh("display notification "..sh(b).." with title "..sh(t))..
      " 2>/dev/null &")
  else
    os.execute("notify-send "..sh(t).." "..sh(b).." 2>/dev/null &")
  end
end

local function clone_it(u,d)
  local cmd = "git clone "..sh(u)
  if d and #d>0 then cmd = cmd.." "..sh(d) end
  print("  📦  "..g(cmd,"2"))
  os.execute(cmd)
end

local function slp(n)
  if WS == "\\" then
    os.execute("ping -n "..(n+1).." 127.0.0.1 >nul")
  else
    os.execute("sleep "..n)
  end
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

local function build_url(q, o)
  local P = {"q="..ue(q), "per_page="..math.max(1, math.min((o.n or 5)*3, 100))}
  if o.s then
    local z = o.s:lower()
    if z=="stars" or z=="forks" or z=="updated" then
      P[#P+1]="sort="..z P[#P+1]="order=desc"
    end
  end
  return "https://api.github.com/search/repositories?"..table.concat(P,"&")
end

local function one(q, o)
  local _, body = GET(build_url(q, o))
  if not body or body=="" then return nil, "no response" end
  local ok, D = pcall(J, body)
  if not ok or type(D)~="table" then return nil, "bad json" end
  if D.message and not D.items then return nil, D.message end
  return D
end

local function filt(items, o, seen)
  local r = {}
  for _, it in ipairs(items) do
    local keep = true
    if o.ms and (tonumber(it.stargazers_count) or 0) < o.ms then keep=false end
    if seen and seen[it.full_name] then keep=false end
    if keep then r[#r+1] = it end
  end
  return r
end

local function show(items, n, o)
  for i, r in ipairs(items) do
    if i > n then break end
    local fn=r.full_name or "?"
    local ds=r.description or "?"
    local st=nb(r.stargazers_count) local fk=nb(r.forks_count)
    local lg=r.language or "—"
    local dt=(r.updated_at or ""):sub(1,10)
    local lnk=r.html_url or ("https://github.com/"..fn)
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
end

local function js_esc(s)
  if s==nil then return "null" end
  s = tostring(s):gsub('\\','\\\\'):gsub('"','\\"')
                :gsub('\n','\\n'):gsub('\r','\\r'):gsub('\t','\\t')
  return '"'..s..'"'
end
local function dump_json(items)
  local b={"["}
  for i,r in ipairs(items) do
    if i>1 then b[#b+1]="," end
    b[#b+1]='{"full_name":'..js_esc(r.full_name)..
            ',"description":'..js_esc(r.description)..
            ',"stars":'..tostring(r.stargazers_count or 0)..
            ',"forks":'..tostring(r.forks_count or 0)..
            ',"language":'..js_esc(r.language)..
            ',"updated_at":'..js_esc(r.updated_at)..
            ',"url":'..js_esc(r.html_url)..
            ',"clone_url":'..js_esc(r.clone_url)..'}'
  end
  b[#b+1]="]"
  print(table.concat(b))
end

local function append_file(p, items)
  local f = io.open(p, "a")
  if not f then return end
  for _, r in ipairs(items) do
    f:write(r.full_name or "?", "\t", r.html_url or "", "\t",
            tostring(r.stargazers_count or 0), "\n")
  end
  f:close()
end

local function pick_rand(items)
  if #items == 0 then return nil end
  math.randomseed(os.time() + math.floor(os.clock()*1000))
  return items[math.random(1, #items)]
end

local H = [[
ghfind 🐣  — automation edition

  lua ghfind.lua "words" [opts]

search:
  -l/--lang X       language
  -s/--sort X       stars | forks | updated
  -n/--limit N      how many (5)
  --min-stars N     only repos with N+ stars
  --pushed DATE     pushed after YYYY-MM-DD

action:
  -o/--open         open top result in browser
  -c/--clone [DIR]  git clone top result
  --random          pick a random result

automation:
  -w/--watch N      repeat every N seconds, show only new
  -W N              max watch passes
  --seen            skip already-seen (cached in ~/.cache/ghfind)
  --clear-seen      wipe seen cache
  --notify          desktop notification on new (watch mode)
  --save FILE       append results to FILE
  --json            json output (pipe-friendly)

misc:
  -t/--check-token  inspect token scopes
  -r/--recommend    safe scopes
  -h/--help         this

examples:
  lua ghfind.lua "neovim colorscheme" -s stars -o
  lua ghfind.lua "http server" -l lua -c ~/src
  lua ghfind.lua "markdown parser" -w 120 --seen --notify
  lua ghfind.lua "tui fm" --json | jq
]]

local function argv(a)
  local o={w={},n=5} local i=1
  local function nv() i=i+1 return a[i] end
  while i<=#a do
    local v=a[i]
    local k,val=v:match"^(%-%-[%w%-]+)=(.*)$"
    if k then a[i]=k table.insert(a,i+1,val) v=k end
    if     v=="-h" or v=="--help"       then io.write(H) os.exit(0)
    elseif v=="-t" or v=="--check-token" then o.t=1
    elseif v=="-r" or v=="--recommend"   then o.r=1
    elseif v=="-l" or v=="--lang"        then o.l=nv()
    elseif v=="-s" or v=="--sort"        then o.s=nv()
    elseif v=="-n" or v=="--limit"       then o.n=tonumber(nv()) or 5
    elseif v=="-w" or v=="--watch"       then o.ws=tonumber(nv()) or 60
    elseif v=="-W"                       then o.wm=tonumber(nv())
    elseif v=="--min-stars"              then o.ms=tonumber(nv())
    elseif v=="--pushed"                 then o.ph=nv()
    elseif v=="-o" or v=="--open"        then o.op=1
    elseif v=="-c" or v=="--clone" then
      local nx=a[i+1]
      if nx and not nx:match("^%-") then o.cl=nx i=i+1 else o.cl="" end
    elseif v=="--random"                 then o.rd=1
    elseif v=="--seen"                   then o.sn=1
    elseif v=="--clear-seen"             then o.clr=1
    elseif v=="--notify"                 then o.nt=1
    elseif v=="--save"                   then o.sv=nv()
    elseif v=="--json"                   then o.js=1
    else o.w[#o.w+1]=v end
    i=i+1
  end
  return o
end

local A = argv(arg)
if A.clr then clr_seen() print("  🧹  cache cleared") os.exit(0) end
if A.r then rec() os.exit(0) end
if A.t then chk() os.exit(0) end
if #A.w==0 then io.write(H) os.exit(1) end

local q = table.concat(A.w," ")
if A.l and #A.l>0 then q=q.." language:"..A.l end
if A.ph then q=q.." pushed:>"..A.ph end

if A.ws then
  local seen, spath = ld_seen(q)
  local n = 0
  if not A.js then
    io.write("\n  👀  "..g('"'..q..'"',"1;33")..
             "  every "..A.ws.."s")
    if A.wm then io.write("  (max "..A.wm..")") end
    io.write("\n\n")
  end
  while true do
    n = n + 1
    local D, er = one(q, A)
    if not D then
      if not A.js then io.write("  ❌  "..tostring(er).."\n") end
    else
      local fresh = {}
      for _, r in ipairs(D.items or {}) do
        if not seen[r.full_name] then
          fresh[#fresh+1] = r
          seen[r.full_name] = true
        end
      end
      if #fresh > 0 then
        if A.js then
          dump_json(fresh)
        else
          print("  🆕  "..g(tostring(#fresh).." new","1;32")..
                "  ·  pass "..n.."  ·  "..os.date("%H:%M:%S"))
          print("")
          show(fresh, A.n, A)
        end
        sv_seen(seen, spath)
        if A.sv then append_file(A.sv, fresh) end
        if A.nt then ntf("ghfind: "..q, #fresh.." new") end
        if A.op and fresh[1] then opn(fresh[1].html_url) end
        if A.cl and fresh[1] then clone_it(fresh[1].clone_url, A.cl) end
      else
        if not A.js then
          io.write("  ·  pass "..n.."  no change\n")
        end
      end
    end
    if A.wm and n >= A.wm then break end
    slp(A.ws)
  end
  os.exit(0)
end

local D, er = one(q, A)
if not D then
  if A.js then print("[]")
  else io.stderr:write("  😿  "..tostring(er).."\n\n") end
  os.exit(1)
end

local items = D.items or {}
if A.sn then
  local seen, spath = ld_seen(q)
  items = filt(items, A, seen)
  for _, r in ipairs(items) do seen[r.full_name] = true end
  sv_seen(seen, spath)
else
  items = filt(items, A, nil)
end

if #items == 0 then
  if A.js then print("[]") else print("  🫧  nothing\n") end
  os.exit(0)
end

if A.js then dump_json(items) os.exit(0) end

if A.rd then
  local r = pick_rand(items)
  items = r and {r} or {}
  if #items == 0 then print("  🫧  nothing\n") os.exit(0) end
end

if A.op and items[1] then opn(items[1].html_url) end
if A.cl and items[1] then clone_it(items[1].clone_url, A.cl) end
if A.sv then append_file(A.sv, items) end

io.write("\n  🔎  "..g(q,"1;33").."\n\n")
show(items, A.n, A)
print("  "..g(nb(D.total_count or #items).." · "..math.min(#items, A.n),"2").."\n")
