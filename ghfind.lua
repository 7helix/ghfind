#!/usr/bin/env lua

local W = package.config:sub(1,1)=="\\" and "\\" or "/"
local C = (os.getenv("NO_COLOR")==nil)
local HOME = os.getenv("HOME") or os.getenv("USERPROFILE") or "."
local CFG = HOME..W..".config"..W.."ghfind"
local ISWIN = (W == "\\")
if ISWIN then os.execute("chcp 65001 >nul 2>nul") end

local function g(s,k)
  if not C then return tostring(s) end
  return "\27["..(k or "0").."m"..tostring(s).."\27[0m"
end
local function ask(p)
  io.write(p) io.flush()
  return io.read("*l") or ""
end
local function clr()
  os.execute(ISWIN and "cls" or "clear")
end
local function sh(s)
  s = tostring(s)
  if ISWIN then
    return '"'..s:gsub('"','\\"')..'"'
  else
    return "'"..s:gsub("'","'\\''").."'"
  end
end
local function ue(s)
  return (tostring(s):gsub("[^%w%-%.%_%~]",function(c)
    return string.format("%%%02X",c:byte())
  end))
end
local function nb(n)
  n=tonumber(n) or 0
  if n>=1e6 then return ("%.1fM"):format(n/1e6) end
  if n>=1e3 then return ("%.1fk"):format(n/1e3) end
  return tostring(n)
end
local function fsize(kb)
  kb = tonumber(kb) or 0
  if kb >= 1024*1024 then return ("%.1f GB"):format(kb/1024/1024) end
  if kb >= 1024 then return ("%.1f MB"):format(kb/1024) end
  return kb.." KB"
end
local function mkdir(p)
  if ISWIN then
    os.execute('if not exist "'..p..'" mkdir "'..p..'" >nul 2>nul')
  else
    os.execute("mkdir -p "..sh(p).." 2>/dev/null")
  end
end
local function exists(p)
  local f=io.open(p,"r")
  if f then f:close() return true end
  return false
end
local function slp(n)
  if ISWIN then
    os.execute("ping -n "..(n+1).." 127.0.0.1 >nul")
  else
    os.execute("sleep "..n)
  end
end
local function notif(title,body)
  if ISWIN then return end
  local o=os.getenv("OSTYPE") or ""
  if o:match("darwin") then
    os.execute("osascript -e "..sh("display notification "..sh(body)..
      " with title "..sh(title)).." 2>/dev/null &")
  else
    os.execute("notify-send "..sh(title).." "..sh(body).." 2>/dev/null &")
  end
end
local function open_url(u)
  if ISWIN then
    os.execute('rundll32 url.dll,FileProtocolHandler '..sh(u))
  elseif (os.getenv("OSTYPE") or ""):match("darwin") then
    os.execute("open "..sh(u).." &")
  else
    os.execute("xdg-open "..sh(u).." >/dev/null 2>&1 &")
  end
end
local function trim(s)
  return (tostring(s):gsub("^%s+",""):gsub("%s+$",""))
end
local function hline(w)
  print(g(string.rep("-",w or 66),"2"))
end
local function wrap(text, width)
  width = width or 66
  local lines = {}
  local buf = ""
  for w in tostring(text):gmatch("%S+") do
    if #buf + #w + 1 > width then
      lines[#lines+1] = buf
      buf = w
    else
      if buf == "" then buf = w else buf = buf.." "..w end
    end
  end
  if buf ~= "" then lines[#lines+1] = buf end
  if #lines == 0 then lines[1] = "" end
  return lines
end

local function cfgpath() return CFG..W.."config.txt" end

local function load_cfg()
  local c={}
  local p=cfgpath()
  if not exists(p) then return c end
  local f=io.open(p,"r")
  for l in f:lines() do
    if #l>0 and l:sub(1,1)~="#" then
      local k,v=l:match("^([^=]+)=(.*)$")
      if k then c[trim(k)]=v end
    end
  end
  f:close()
  return c
end
local function save_cfg(c)
  mkdir(CFG)
  local f=io.open(cfgpath(),"w")
  if not f then return end
  for k,v in pairs(c) do
    f:write(k,"=",v,"\n")
  end
  f:close()
end

local function tok()
  local t=os.getenv("GITHUB_TOKEN")
  if t and #t>0 then return t end
  local p=CFG..W.."token"
  if exists(p) then
    local f=io.open(p,"r")
    local s=f:read("*l") f:close()
    if s and #s>0 then return s end
  end
  return nil
end

local function get(u)
  local tk=tok()
  local cmd="curl -sS -L --max-time 25"
  if tk then cmd=cmd.." -H "..sh("Authorization: Bearer "..tk) end
  cmd=cmd.." -H "..sh("Accept: application/vnd.github+json")
  cmd=cmd.." -H "..sh("User-Agent: ghfind-lua")
  cmd=cmd.." "..sh(u)
  local f=io.popen(cmd,"r")
  if not f then return nil end
  local r=f:read("*a") f:close()
  return r
end
local function head(u)
  local tk=tok()
  local cmd="curl -sS -I -L --max-time 25"
  if tk then cmd=cmd.." -H "..sh("Authorization: Bearer "..tk) end
  cmd=cmd.." -H "..sh("Accept: application/vnd.github+json")
  cmd=cmd.." "..sh(u)
  local f=io.popen(cmd,"r")
  if not f then return nil end
  local r=f:read("*a") f:close()
  return r
end

local function grabstr(s,key)
  if not s then return nil end
  local pat = '"'..key..'"%s*:%s*"'
  local p = s:find(pat)
  if not p then return nil end
  local start = s:find('"',p+#key+2)
  if not start then return nil end
  start = start + 1
  local i = start
  while i<=#s do
    local c=s:sub(i,i)
    if c=='\\' then i=i+2
    elseif c=='"' then break
    else i=i+1 end
  end
  local v=s:sub(start,i-1)
  v=v:gsub('\\n','\n'):gsub('\\t','\t'):gsub('\\r','\r')
  v=v:gsub('\\"','"'):gsub('\\/','/')
  v=v:gsub('\\\\','\\')
  return v
end
local function grabnum(s,key)
  if not s then return 0 end
  local v=s:match('"'..key..'"%s*:%s*(%-?%d+)')
  return tonumber(v) or 0
end
local function grabbool(s,key)
  if not s then return false end
  local v=s:match('"'..key..'"%s*:%s*(%w+)')
  return v == "true"
end
local function grabtopics(chunk)
  local block = chunk:match('"topics"%s*:%s*%[(.-)%]')
  if not block then return {} end
  local topics = {}
  for t in block:gmatch('"([^"]+)"') do
    topics[#topics+1] = t
  end
  return topics
end

local function extract_items(body)
  local items = {}
  if not body then return items end
  local start = body:find('"items"%s*:%s*%[')
  if not start then return items end
  start = body:find('%[', start) + 1
  local depth = 0
  local i = start
  local item_start = nil
  while i <= #body do
    local c = body:sub(i,i)
    if c == '"' then
      i = i + 1
      while i <= #body do
        local cc = body:sub(i,i)
        if cc == '\\' then i = i + 2
        elseif cc == '"' then break
        else i = i + 1 end
      end
    elseif c == '{' then
      if depth == 0 then item_start = i end
      depth = depth + 1
    elseif c == '}' then
      depth = depth - 1
      if depth == 0 and item_start then
        items[#items+1] = body:sub(item_start, i)
        item_start = nil
      end
    elseif c == ']' and depth == 0 then
      break
    end
    i = i + 1
  end
  return items
end

local F = { lang="", sort="", stars="", age="", limit=5 }

local function reset_f()
  F.lang=""
  F.sort=""
  F.stars=""
  F.age=""
  F.limit=5
end

local function build_q(q)
  local s=q
  if F.lang~="" then s=s.." language:"..F.lang end
  if F.stars~="" then s=s.." stars:>="..F.stars end
  if F.age~="" then
    local d=os.date("*t")
    local t=os.time({year=d.year,month=d.month,day=d.day})
    t=t-tonumber(F.age)*86400
    s=s.." pushed:>"..os.date("%Y-%m-%d",t)
  end
  return s
end

local function run(q)
  local u="https://api.github.com/search/repositories?q="
  u=u..ue(build_q(q))
  u=u.."&per_page="..math.min(F.limit*3,100)
  if F.sort~="" then u=u.."&sort="..F.sort.."&order=desc" end
  local body=get(u)
  if not body then return nil,"no response" end
  if body:match('"message"') and not body:match('"items"') then
    local m=body:match('"message"%s*:%s*"([^"]+)"')
    return nil,m or "github said no"
  end
  local chunks = extract_items(body)
  local items = {}
  for _,chunk in ipairs(chunks) do
    local fn=grabstr(chunk,"full_name")
    if fn then
      local owner = fn:match("^([^/]+)/") or "-"
      local name  = fn:match("/([^/]+)$") or fn
      items[#items+1]={
        fn=fn,
        owner=owner,
        name=name,
        url="https://github.com/"..fn,
        clone="https://github.com/"..fn..".git",
        ds=grabstr(chunk,"description") or "",
        lg=grabstr(chunk,"language") or "-",
        st=grabnum(chunk,"stargazers_count"),
        fk=grabnum(chunk,"forks_count"),
        iss=grabnum(chunk,"open_issues_count"),
        wat=grabnum(chunk,"watchers_count"),
        sz=grabnum(chunk,"size"),
        dt_created=(grabstr(chunk,"created_at") or ""):sub(1,10),
        dt_updated=(grabstr(chunk,"updated_at") or ""):sub(1,10),
        dt_pushed=(grabstr(chunk,"pushed_at") or ""):sub(1,10),
        homepage=grabstr(chunk,"homepage") or "",
        defbranch=grabstr(chunk,"default_branch") or "main",
        license=grabstr(chunk,"spdx_id") or "-",
        archived=grabbool(chunk,"archived"),
        fork=grabbool(chunk,"fork"),
        topics=grabtopics(chunk)
      }
    end
  end
  local total=tonumber(body:match('"total_count"%s*:%s*(%d+)')) or #items
  return items,total
end

local function show_one(r, i)
  local title = tostring(i)..". "..r.fn
  print("  "..g(title,"1;36"))
  if r.archived then
    print("     "..g("[archived]","1;31"))
  end
  if r.fork then
    print("     "..g("[fork]","2"))
  end
  hline(66)
  if r.ds and r.ds ~= "" then
    for _,ln in ipairs(wrap(r.ds, 66)) do
      print("  "..g(ln,"0"))
    end
  else
    print("  "..g("(no description)","2"))
  end
  print("")
  print("  "..g("language:","1;33").."   "..(r.lg ~= "-" and r.lg or g("-","2")))
  print("  "..g("stars:","1;33").."      "..g(nb(r.st),"1;32")..
        "    "..g("forks:","1;33").."  "..g(nb(r.fk),"1;32")..
        "    "..g("issues:","1;33").."  "..g(nb(r.iss),"1;32"))
  print("  "..g("watchers:","1;33").."   "..nb(r.wat)..
        "    "..g("size:","1;33").."   "..fsize(r.sz)..
        "    "..g("license:","1;33").."  "..r.license)
  print("  "..g("created:","1;33").."    "..r.dt_created..
        "    "..g("updated:","1;33").." "..r.dt_updated)
  print("  "..g("pushed:","1;33").."     "..r.dt_pushed..
        "    "..g("branch:","1;33").."  "..r.defbranch)
  if r.homepage ~= "" then
    print("  "..g("homepage:","1;33").."   "..g(r.homepage,"4;34"))
  end
  if r.topics and #r.topics > 0 then
    print("  "..g("topics:","1;33").."     "..g(table.concat(r.topics, ", "),"1;35"))
  end
  print("  "..g("repo:","1;33").."       "..g(r.url,"4;34"))
  print("  "..g("clone:","1;33").."      "..g(r.clone,"90"))
  print("")
end

local function show(items, n)
  if not items or #items == 0 then
    print("  "..g("nothing found","2"))
    return
  end
  for i, r in ipairs(items) do
    if i > n then break end
    show_one(r, i)
  end
end

local function banner()
  print("")
  print("  "..g("ghfind","1;36").."  "..g("repo searcher","2"))
  print("")
end

local function hist_push(q)
  mkdir(CFG)
  local f=io.open(CFG..W.."history.txt","a")
  if f then f:write(q,"\n") f:close() end
end

local function do_search()
  clr()
  banner()
  local q=ask("  "..g("query","1;36").." > ")
  if q=="" then return end
  print("")
  print("  "..g("searching...","2"))
  local items,total=run(q)
  if not items then
    print("  "..g("error: "..tostring(total),"1;31"))
    ask("  [enter]")
    return
  end
  hist_push(q)
  clr()
  banner()
  print("  "..g("query","2").."  "..g(q,"1;33"))
  print("  "..g(nb(total).." total results, showing "..math.min(#items,F.limit),"2"))
  print("")
  show(items,F.limit)
  print("  "..g("actions:","1;33").."  "..
        "o=open  c=clone  f=fav  s=save preset  "..
        "1-9=detail  enter=back")
  print("")
  local a=ask("  "..g(">","1;36").." ")
  if a=="o" and items[1] then
    open_url(items[1].url)
    print("  "..g("opened in browser","1;32"))
    slp(1)
  elseif a=="c" and items[1] then
    local d=ask("  clone to (blank=cwd) > ")
    local cmd="git clone "..sh(items[1].clone)
    if d~="" then cmd=cmd.." "..sh(d) end
    print("  "..g(cmd,"2"))
    os.execute(cmd)
    ask("  [enter]")
  elseif a=="f" then
    local n=tonumber(ask("  number to save > "))
    if n and items[n] then
      mkdir(CFG)
      local f=io.open(CFG..W.."favs.txt","a")
      if f then
        f:write(items[n].fn,"\t",items[n].url,"\n")
        f:close()
        print("  "..g("saved "..items[n].fn,"1;32"))
        slp(1)
      end
    end
  elseif a=="s" then
    local name=ask("  preset name > ")
    if name~="" then
      local c=load_cfg()
      local idx="preset_"..name
      c[idx.."_q"]=q
      c[idx.."_lang"]=F.lang
      c[idx.."_sort"]=F.sort
      c[idx.."_stars"]=F.stars
      c[idx.."_age"]=F.age
      c[idx.."_limit"]=tostring(F.limit)
      save_cfg(c)
      print("  "..g("preset saved: "..name,"1;32"))
      slp(1)
    end
  else
    local n=tonumber(a)
    if n and items[n] then
      clr()
      banner()
      show_one(items[n], n)
      ask("  [enter]")
    end
  end
end

local function do_filters()
  while true do
    clr()
    banner()
    print("  "..g("filters","1;36"))
    hline()
    local l1 = F.lang~="" and F.lang or "-"
    local l2 = F.sort~="" and F.sort or "-"
    local l3 = F.stars~="" and F.stars or "-"
    local l4 = F.age~="" and (F.age.."d") or "-"
    print("  language  "..g(l1,"1;33"))
    print("  sort      "..g(l2,"1;33"))
    print("  min stars "..g(l3,"1;33"))
    print("  max age   "..g(l4,"1;33"))
    print("  limit     "..g(tostring(F.limit),"1;33"))
    print("")
    print("  "..g("1","1;33").."  language")
    print("  "..g("2","1;33").."  sort")
    print("  "..g("3","1;33").."  min stars")
    print("  "..g("4","1;33").."  max age (days)")
    print("  "..g("5","1;33").."  limit")
    print("  "..g("6","1;33").."  reset")
    print("  "..g("0","1;33").."  back")
    print("")
    local c=ask("  "..g(">","1;36").." ")
    if c=="0" then return end
    if c=="1" then
      F.lang=ask("  language > ")
    elseif c=="2" then
      local s=ask("  sort (stars/forks/updated) > ")
      if s=="stars" or s=="forks" or s=="updated" then
        F.sort=s
      else
        F.sort=""
      end
    elseif c=="3" then
      F.stars=ask("  min stars > ")
    elseif c=="4" then
      F.age=ask("  max age (days) > ")
    elseif c=="5" then
      F.limit=tonumber(ask("  limit > ")) or 5
    elseif c=="6" then
      reset_f()
    end
  end
end

local function do_presets()
  while true do
    clr()
    banner()
    local c=load_cfg()
    local names={}
    for k,v in pairs(c) do
      local n=k:match("^preset_(.+)_q$")
      if n then names[#names+1]=n end
    end
    table.sort(names)
    print("  "..g("presets","1;36").."  ("..#names..")")
    hline()
    if #names==0 then
      print("  "..g("no presets yet","2"))
      print("  "..g("save one from a search result with [s]","2"))
    else
      for i,n in ipairs(names) do
        local q=c["preset_"..n.."_q"] or ""
        local lg=c["preset_"..n.."_lang"] or ""
        local so=c["preset_"..n.."_sort"] or ""
        local tag=""
        if lg~="" then tag=tag.." ["..lg.."]" end
        if so~="" then tag=tag.." ["..so.."]" end
        print("  "..g(tostring(i)..".","1;35").." "..
              g(n,"1;36")..g(tag,"2"))
        print("     "..g(q,"90"))
      end
    end
    print("")
    print("  "..g("r","1;33").."  run #   "..
          g("d","1;33").."  delete   "..
          g("0","1;33").."  back")
    print("")
    local a=ask("  "..g(">","1;36").." ")
    if a=="0" then return end
    if a=="r" then
      local i=tonumber(ask("  number > "))
      if i and names[i] then
        local n=names[i]
        F.lang=c["preset_"..n.."_lang"] or ""
        F.sort=c["preset_"..n.."_sort"] or ""
        F.stars=c["preset_"..n.."_stars"] or ""
        F.age=c["preset_"..n.."_age"] or ""
        F.limit=tonumber(c["preset_"..n.."_limit"]) or 5
        local q=c["preset_"..n.."_q"] or ""
        clr() banner()
        print("  "..g(q,"1;36"))
        print("")
        local items,total=run(q)
        if items then
          show(items,F.limit)
          print("  "..g(nb(total).." total","2"))
          print("")
        else
          print("  "..g("error","1;31"))
        end
        ask("  [enter]")
      end
    elseif a=="d" then
      local i=tonumber(ask("  number > "))
      if i and names[i] then
        local n=names[i]
        c["preset_"..n.."_q"]=nil
        c["preset_"..n.."_lang"]=nil
        c["preset_"..n.."_sort"]=nil
        c["preset_"..n.."_stars"]=nil
        c["preset_"..n.."_age"]=nil
        c["preset_"..n.."_limit"]=nil
        save_cfg(c)
      end
    end
  end
end

local function do_watch()
  clr()
  banner()
  local q=ask("  query > ")
  if q=="" then return end
  local secs=tonumber(ask("  every how many seconds? > ")) or 60
  local maxp=tonumber(ask("  max passes (blank=forever) > "))
  local nyn=ask("  desktop notifications? [y/N] > ")
  local notify = nyn:lower()=="y"
  local seen={}
  local sp=CFG..W.."seen_"..tostring(q:gsub("%W","_"))..".txt"
  if exists(sp) then
    local f=io.open(sp,"r")
    for l in f:lines() do if #l>0 then seen[l]=true end end
    f:close()
  end
  local n=0
  print("")
  print("  "..g("watching - ctrl-c to stop","1;36"))
  while true do
    n=n+1
    local items,er=run(q)
    if not items then
      print("  "..g("error: "..tostring(er),"1;31"))
    else
      local fresh={}
      for _,r in ipairs(items) do
        if not seen[r.fn] then
          fresh[#fresh+1]=r
          seen[r.fn]=true
        end
      end
      if #fresh>0 then
        print("")
        print("  "..g(#fresh.." new","1;32")..
              "  pass "..n.."  "..os.date("%H:%M:%S"))
        show(fresh,F.limit)
        mkdir(CFG)
        local sf=io.open(sp,"a")
        if sf then
          for _,r in ipairs(fresh) do
            sf:write(r.fn,"\n")
          end
          sf:close()
        end
        if notify then notif("ghfind: "..q,#fresh.." new") end
      else
        io.write("  pass "..n.."  no change\n")
      end
    end
    if maxp and n>=maxp then break end
    slp(secs)
  end
  ask("  [enter]")
end

local function do_favs()
  while true do
    clr()
    banner()
    local list={}
    local fp=CFG..W.."favs.txt"
    if exists(fp) then
      local f=io.open(fp,"r")
      for l in f:lines() do
        if #l>0 then
          local nm,u=l:match("^(.-)\t(.*)$")
          if nm then list[#list+1]={n=nm,u=u or ""} end
        end
      end
      f:close()
    end
    print("  "..g("favorites","1;36").."  ("..#list..")")
    hline()
    if #list==0 then
      print("  "..g("empty","2"))
    else
      for i,fv in ipairs(list) do
        print("  "..g(tostring(i)..".","1;35").." "..g(fv.n,"1;36"))
      end
    end
    print("")
    print("  "..g("o","1;33").."  open #   "..
          g("d","1;33").."  delete   "..
          g("c","1;33").."  clear   "..
          g("0","1;33").."  back")
    print("")
    local c=ask("  "..g(">","1;36").." ")
    if c=="0" then return end
    if c=="o" then
      local i=tonumber(ask("  number > "))
      if i and list[i] then
        open_url(list[i].u)
        print("  "..g("opened","1;32"))
        slp(1)
      end
    elseif c=="d" then
      local i=tonumber(ask("  number > "))
      if i and list[i] then
        table.remove(list,i)
        local wf=io.open(fp,"w")
        if wf then
          for _,fv in ipairs(list) do
            wf:write(fv.n,"\t",fv.u,"\n")
          end
          wf:close()
        end
      end
    elseif c=="c" then
      os.remove(fp)
    end
  end
end

local function do_hist()
  while true do
    clr()
    banner()
    local list={}
    local p=CFG..W.."history.txt"
    if exists(p) then
      local f=io.open(p,"r")
      for l in f:lines() do
        if #l>0 and #list<30 then list[#list+1]=l end
      end
      f:close()
    end
    print("  "..g("history","1;36").."  ("..#list..")")
    hline()
    if #list==0 then
      print("  "..g("empty","2"))
    else
      for i,h in ipairs(list) do
        print("  "..g(tostring(i)..".","1;35").." "..g(h,"1;36"))
      end
    end
    print("")
    print("  "..g("r","1;33").."  rerun   "..
          g("c","1;33").."  clear   "..
          g("0","1;33").."  back")
    print("")
    local c=ask("  "..g(">","1;36").." ")
    if c=="0" then return end
    if c=="c" then os.remove(p)
    elseif c=="r" then
      local i=tonumber(ask("  number > "))
      if i and list[i] then
        clr() banner()
        local items,total=run(list[i])
        if items then
          show(items,F.limit)
          print("  "..g(nb(total).." total","2"))
          print("")
        end
        ask("  [enter]")
      end
    end
  end
end

local function do_token()
  while true do
    clr()
    banner()
    print("  "..g("token","1;36"))
    hline()
    local t=tok()
    if t then
      print("  status  "..g("set","1;32").."  "..g(t:sub(1,8).."...","2"))
    else
      print("  status  "..g("not set","1;33"))
    end
    print("")
    print("  "..g("1","1;33").."  paste token")
    print("  "..g("2","1;33").."  check token")
    print("  "..g("3","1;33").."  remove token")
    print("  "..g("4","1;33").."  recommended scopes")
    print("  "..g("0","1;33").."  back")
    print("")
    local c=ask("  "..g(">","1;36").." ")
    if c=="0" then return end
    if c=="1" then
      local v=ask("  token > ")
      if v~="" then
        mkdir(CFG)
        local f=io.open(CFG..W.."token","w")
        if f then f:write(v,"\n") f:close() end
        if not ISWIN then
          os.execute("chmod 600 "..sh(CFG..W.."token").." 2>/dev/null")
        end
        print("  "..g("saved","1;32"))
        ask("  [enter]")
      end
    elseif c=="2" then
      local h=head("https://api.github.com/user")
      if h then
        local code
        for l in h:gmatch("[^\r\n]+") do
          local m=l:match("^HTTP/%d%.%d%s+(%d+)")
          if m then code=m end
        end
        if code=="401" then
          print("  "..g("invalid","1;31"))
        else
          local ol=h:match("Oauth%-Scopes:%s*([^\r\n]+)")
          if not ol then ol=h:match("oauth%-scopes:%s*([^\r\n]+)") end
          if not ol or ol=="" then
            print("  scopes: none")
            print("  "..g("perfect","1;32"))
          else
            for s in ol:gmatch("[^,%s]+") do
              local bad = false
              if s=="repo" then bad=true end
              if s=="user" then bad=true end
              if s=="security_events" then bad=true end
              if s=="delete_repo" then bad=true end
              if s=="admin:org" then bad=true end
              if s=="workflow" then bad=true end
              if bad then
                print("  "..g("[!!] "..s,"1;31"))
              else
                print("  "..g("[ok] "..s,"1;32"))
              end
            end
          end
        end
        ask("  [enter]")
      end
    elseif c=="3" then
      os.remove(CFG..W.."token")
      print("  "..g("removed","1;32"))
      ask("  [enter]")
    elseif c=="4" then
      clr() banner()
      print("  "..g("recommended","1;36"))
      hline()
      print("  "..g("none","1;32").."  classic token, zero boxes")
      print("  "..g("public_repo","1;36").."  if you insist")
      print("")
      print("  "..g("avoid these:","1;31"))
      print("  repo  user  security_events  delete_repo")
      print("  admin:org  workflow  admin:public_key")
      print("")
      print("  "..g("https://github.com/settings/tokens","2"))
      ask("  [enter]")
    end
  end
end

local function do_settings()
  while true do
    clr()
    banner()
    local c=load_cfg()
    print("  "..g("settings","1;36"))
    hline()
    local dl = c.default_limit or "-"
    local nf = c.notify or "off"
    local ao = c.auto_open or "off"
    local dlang = c.default_lang or "-"
    print("  default limit   "..g(dl,"1;33"))
    print("  notify          "..g(nf,"1;33"))
    print("  auto-open       "..g(ao,"1;33"))
    print("  default lang    "..g(dlang,"1;33"))
    print("")
    print("  "..g("1","1;33").."  default limit")
    print("  "..g("2","1;33").."  toggle notify")
    print("  "..g("3","1;33").."  toggle auto-open top result")
    print("  "..g("4","1;33").."  default language")
    print("  "..g("5","1;33").."  wipe seen caches")
    print("  "..g("6","1;33").."  reset all settings")
    print("  "..g("0","1;33").."  back")
    print("")
    local k=ask("  "..g(">","1;36").." ")
    if k=="0" then return end
    if k=="1" then
      local v=tonumber(ask("  limit > "))
      if v then
        c.default_limit=tostring(v)
        save_cfg(c)
        F.limit=v
      end
    elseif k=="2" then
      if c.notify=="on" then c.notify="off" else c.notify="on" end
      save_cfg(c)
    elseif k=="3" then
      if c.auto_open=="on" then c.auto_open="off" else c.auto_open="on" end
      save_cfg(c)
    elseif k=="4" then
      c.default_lang=ask("  language > ")
      save_cfg(c)
    elseif k=="5" then
      if ISWIN then
        os.execute('del /q "'..CFG..'\\seen_*.txt" >nul 2>nul')
      else
        os.execute("rm -f "..sh(CFG).."/seen_*.txt 2>/dev/null")
      end
      print("  "..g("wiped","1;32"))
      slp(1)
    elseif k=="6" then
      save_cfg({})
      reset_f()
      print("  "..g("reset","1;32"))
      slp(1)
    end
  end
end

local function do_help()
  clr()
  banner()
  print("  "..g("help","1;36"))
  hline()
  print("")
  print("  "..g("search","1;33").."  type words, hit enter")
  print("  "..g("filters","1;33").."  language, sort, stars, age, limit")
  print("  "..g("presets","1;33").."  saved searches, run with one key")
  print("  "..g("watch","1;33").."  loop + notify on new")
  print("  "..g("favorites","1;33").."  saved repos")
  print("  "..g("history","1;33").."  last 30 searches")
  print("  "..g("token","1;33").."  paste one to raise rate limit")
  print("  "..g("settings","1;33").."  defaults + cache control")
  print("")
  print("  "..g("files","1;33"))
  print("  "..CFG..W.."token")
  print("  "..CFG..W.."config.txt")
  print("  "..CFG..W.."history.txt")
  print("  "..CFG..W.."favs.txt")
  print("  "..CFG..W.."seen_*.txt")
  print("")
  print("  "..g("license","1;33").."  MIT")
  print("")
  ask("  [enter]")
end

local c0=load_cfg()
if c0.default_limit then
  local v=tonumber(c0.default_limit)
  if v then F.limit=v end
end
if c0.default_lang and c0.default_lang~="" then
  F.lang=c0.default_lang
end

while true do
  clr()
  banner()
  print("  "..g("1","1;33").."  search")
  print("  "..g("2","1;33").."  filters")
  print("  "..g("3","1;33").."  presets")
  print("  "..g("4","1;33").."  watch")
  print("  "..g("5","1;33").."  favorites")
  print("  "..g("6","1;33").."  history")
  print("  "..g("7","1;33").."  token")
  print("  "..g("8","1;33").."  settings")
  print("  "..g("9","1;33").."  help")
  print("  "..g("c","1;33").."  clear screen")
  print("  "..g("0","1;33").."  exit")
  print("")
  local k=ask("  "..g(">","1;36").." ")
  if k=="0" or k=="q" then
    clr() print("  bye") print("") break
  elseif k=="1" then do_search()
  elseif k=="2" then do_filters()
  elseif k=="3" then do_presets()
  elseif k=="4" then do_watch()
  elseif k=="5" then do_favs()
  elseif k=="6" then do_hist()
  elseif k=="7" then do_token()
  elseif k=="8" then do_settings()
  elseif k=="9" then do_help()
  elseif k=="c" then clr()
  end
end
