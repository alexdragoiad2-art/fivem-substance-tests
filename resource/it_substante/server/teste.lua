-- it_substante / server/teste.lua - etilotest + drugtest.
-- Politistul in tura foloseste aparatul -> persoana cea mai apropiata (max Sub.Tests.maxDistance) e intrebata
-- daca accepta. Nu raspunde / refuza = refuz (infractiune, art. 337 C. pen.), inregistrat. Accepta -> masurare
-- pe server (din "corp"), rezultat aratat pe aparat la amandoi si salvat in it_teste_politie (pentru cazier).
-- Cine nu e politist in tura isi face testul singur (aparat personal), fara inregistrare.

local T, L = Sub.Tests, Sub.Legal
local sessions = {}   -- [officer] = { target, kind, token, stage }
local lastUse = {}

local function notify(src, msg, kind)
  TriggerClientEvent('esx:showNotification', src, msg, kind or 'info', 9000)
end

local function isOfficer(x)
  return x and x.job and x.job.name == Sub.Police.job and x.job.onDuty == true
end

local function nearestPlayer(src)
  local myPed = GetPlayerPed(src)
  if myPed == 0 then return nil end
  local my = GetEntityCoords(myPed)
  local best, bestD = nil, T.maxDistance + 0.001
  for _, p in ipairs(GetPlayers()) do
    p = tonumber(p)
    if p ~= src then
      local ped = GetPlayerPed(p)
      if ped ~= 0 then
        local d = #(GetEntityCoords(ped) - my)
        if d < bestD then best, bestD = p, d end
      end
    end
  end
  return best
end

local function near(a, b, max)
  local pa, pb = GetPlayerPed(a), GetPlayerPed(b)
  return pa ~= 0 and pb ~= 0 and #(GetEntityCoords(pa) - GetEntityCoords(pb)) <= max
end

CreateThread(function()
  MySQL.query.await([[
    CREATE TABLE IF NOT EXISTS `it_teste_politie` (
      `id` INT NOT NULL AUTO_INCREMENT,
      `tip` VARCHAR(16) NOT NULL,
      `subiect_identifier` VARCHAR(64) NOT NULL,
      `subiect_nume` VARCHAR(80) NULL,
      `politist_identifier` VARCHAR(64) NULL,
      `politist_nume` VARCHAR(80) NULL,
      `valoare` DECIMAL(5,2) NULL,
      `rezultat` TEXT NULL,
      `verdict` VARCHAR(16) NOT NULL,
      `x` FLOAT NULL, `y` FLOAT NULL, `z` FLOAT NULL,
      `creat_la` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (`id`),
      KEY `subiect` (`subiect_identifier`)
    )
  ]])
end)

local function record(kind, xT, xO, value, result, verdict)
  local c = GetEntityCoords(GetPlayerPed(xT.source))
  MySQL.insert('INSERT INTO it_teste_politie (tip, subiect_identifier, subiect_nume, politist_identifier, politist_nume, valoare, rezultat, verdict, x, y, z) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
    kind, xT.identifier, xT.getName(), xO and xO.identifier or nil, xO and xO.getName() or nil,
    value, result and json.encode(result) or nil, verdict, c.x, c.y, c.z,
  })
end

-- ===== masurarea =====
local function measureBreath(identifier)
  local b = SubBody(identifier)
  local mg = 0.0
  if b.bac > 0.005 then
    mg = b.bac / T.breathRatio + (math.random() * 2 - 1) * T.breathNoise
  end
  mg = math.max(0.0, math.floor(mg * 100 + 0.5) / 100)
  local verdict, legal = 'negativ', L.breath_neg
  if mg >= T.breathCrime then verdict, legal = 'infractiune', L.breath_crime
  elseif mg >= T.breathNegative then verdict, legal = 'contraventie', L.breath_contr
  else mg = 0.0 end
  return { mg = mg, gl = math.floor(mg * T.breathRatio * 100 + 0.5) / 100, verdict = verdict, legal = legal }
end

local function measureDrugs(identifier)
  local b = SubBody(identifier)
  local panel = {
    { code = 'THC', label = 'Cannabis', pos = b.thc },
    { code = 'MET', label = 'Metamfetamină', pos = b.meth },
    { code = 'AMP', label = 'Amfetamine', pos = b.meth },
    { code = 'COC', label = 'Cocaină', pos = false },
    { code = 'OPI', label = 'Opiacee', pos = false },
    { code = 'BZO', label = 'Benzodiazepine', pos = false },
  }
  local positive = b.thc or b.meth
  return { panel = panel, verdict = positive and 'pozitiv' or 'negativ', legal = positive and L.drug_pos or L.drug_neg }
end

-- ===== desfasurarea testului =====
local function runTest(officer, target, kind, xO, xT)
  local seconds = kind == 'alcool' and T.blowSeconds or T.drugReadSeconds
  local who = { officer = officer, target = target }
  TriggerClientEvent('it_substante:testStart', officer, { kind = kind, role = 'officer', other = target, seconds = seconds, name = xT and xT.getName() or nil })
  if target ~= officer then
    TriggerClientEvent('it_substante:testStart', target, { kind = kind, role = 'subject', other = officer, seconds = seconds })
  end
  Wait(seconds * 1000 + 500)

  if target ~= officer and not near(officer, target, T.maxDistance + 1.5) then
    for _, s in pairs(who) do TriggerClientEvent('it_substante:testAbort', s, 'Testul a fost întrerupt (persoana s-a îndepărtat).') end
    return
  end

  local res = kind == 'alcool' and measureBreath(xT.identifier) or measureDrugs(xT.identifier)
  res.kind = kind
  res.subject = xT.getName()
  res.time = os.date('%d.%m.%Y %H:%M')
  res.official = xO ~= nil
  for _, s in pairs(who) do TriggerClientEvent('it_substante:testResult', s, res) end
  if xO then
    record(kind, xT, xO, res.mg, res, res.verdict)
    notify(officer, ('%s: %s'):format(xT.getName(), res.legal), res.verdict == 'negativ' and 'success' or 'error')
  end
end

local function useDevice(src, kind)
  local x = ESX.GetPlayerFromId(src)
  if not x then return end
  local item = kind == 'alcool' and T.items.breath or T.items.drug
  local has = x.getInventoryItem(item)
  if not has or (has.count or 0) < 1 then return end
  local now = os.time()
  if lastUse[src] and now - lastUse[src] < T.cooldownSeconds then
    return notify(src, 'Aparatul se pregătește pentru o nouă măsurare. Mai așteaptă câteva secunde.', 'error')
  end
  -- plasa de siguranta: o sesiune mai veche de 60 s e considerata terminata
  if sessions[src] and now - (sessions[src].at or 0) > 60 then sessions[src] = nil end
  for o, s in pairs(sessions) do
    if now - (s.at or 0) > 60 then sessions[o] = nil end
  end
  if sessions[src] then return notify(src, 'Ai deja un test în desfășurare.', 'error') end

  -- aparat personal: cine nu e politist in tura se testeaza singur, fara inregistrare
  if not isOfficer(x) then
    lastUse[src] = now
    if kind == 'droguri' then x.removeInventoryItem(item, 1) end
    local s = { target = src, kind = kind, at = now }
    sessions[src] = s
    CreateThread(function()
      local ok, err = pcall(runTest, src, src, kind, nil, x)
      if not ok then print(('^1[it_substante] eroare la testul personal: %s^0'):format(tostring(err))) end
      if sessions[src] == s then sessions[src] = nil end
    end)
    return
  end

  local target = nearestPlayer(src)
  if not target then return notify(src, 'Nu este nicio persoană lângă tine.', 'error') end
  local xT = ESX.GetPlayerFromId(target)
  if not xT then return end
  for _, s in pairs(sessions) do
    if s.target == target then return notify(src, 'Persoana este deja testată.', 'error') end
  end

  lastUse[src] = now
  local token = ('%d-%d-%d'):format(src, target, math.random(100000, 999999))
  sessions[src] = { target = target, kind = kind, token = token, stage = 'consent', at = now }
  notify(src, ('I-ai cerut lui %s să se supună testării %s.'):format(xT.getName(), kind == 'alcool' and 'alcoolscopice' or 'antidrog'))
  TriggerClientEvent('it_substante:consent', target, { token = token, kind = kind, officer = x.getName(), seconds = T.consentSeconds })

  SetTimeout(T.consentSeconds * 1000 + 1500, function()
    local s = sessions[src]
    if s and s.token == token and s.stage == 'consent' then
      sessions[src] = nil
      TriggerClientEvent('it_substante:consentClose', target)
      local xT2 = ESX.GetPlayerFromId(target)
      if xT2 then record(kind, xT2, ESX.GetPlayerFromId(src), nil, nil, 'refuz') end
      notify(src, ('%s nu a răspuns - se consideră REFUZ. %s'):format(xT.getName(), L.refuse), 'error')
      notify(target, 'Nu ai răspuns: se consideră refuz de testare.', 'error')
    end
  end)
end

RegisterNetEvent('it_substante:consentReply', function(token, accepted)
  local target = source
  -- 18 nov: raspunsul la recoltarea de sange merge la server/tox.lua
  if type(token) == 'string' and token:sub(1, 4) == 'tox-' then
    TriggerEvent('it_substante:toxAnswer', token, target, accepted)
    return
  end
  for officer, s in pairs(sessions) do
    if s.token == token and s.target == target and s.stage == 'consent' then
      local xO, xT = ESX.GetPlayerFromId(officer), ESX.GetPlayerFromId(target)
      if not xO or not xT or not isOfficer(xO) then sessions[officer] = nil return end
      if not accepted then
        sessions[officer] = nil
        record(s.kind, xT, xO, nil, nil, 'refuz')
        notify(officer, ('%s a REFUZAT testarea. %s'):format(xT.getName(), L.refuse), 'error')
        notify(target, 'Ai refuzat testarea. Refuzul este infracțiune și a fost consemnat.', 'error')
        return
      end
      if not near(officer, target, T.maxDistance + 1.0) then
        sessions[officer] = nil
        return notify(officer, 'Persoana nu mai este lângă tine.', 'error')
      end
      if s.kind == 'droguri' then
        local it = xO.getInventoryItem(T.items.drug)
        if not it or (it.count or 0) < 1 then sessions[officer] = nil return notify(officer, 'Nu mai ai kituri de drugtest.', 'error') end
        xO.removeInventoryItem(T.items.drug, 1)
      end
      s.stage = 'running'
      CreateThread(function()
        -- 18 nov: sesiunea se elibereaza ORICUM (si la eroare), altfel aparatul ramanea "blocat" la a doua folosire
        local ok, err = pcall(runTest, officer, target, s.kind, xO, xT)
        if not ok then
          print(('^1[it_substante] eroare la test (%s): %s^0'):format(s.kind, tostring(err)))
          notify(officer, 'Testul a eșuat (eroare). Încearcă din nou.', 'error')
        end
        if sessions[officer] == s then sessions[officer] = nil end
      end)
      return
    end
  end
end)

CreateThread(function()
  while not ESX or not ESX.RegisterUsableItem do Wait(250) end
  ESX.RegisterUsableItem(T.items.breath, function(src) useDevice(src, 'alcool') end)
  ESX.RegisterUsableItem(T.items.drug, function(src) useDevice(src, 'droguri') end)
end)

AddEventHandler('playerDropped', function()
  local src = source
  sessions[src], lastUse[src] = nil, nil
end)

-- pentru cazier / alte resurse
exports('GetTests', function(identifier, limit)
  return MySQL.query.await('SELECT tip, valoare, verdict, politist_nume, creat_la FROM it_teste_politie WHERE subiect_identifier = ? ORDER BY id DESC LIMIT ?', { identifier, tonumber(limit) or 20 })
end)
