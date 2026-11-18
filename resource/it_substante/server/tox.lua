-- it_substante / server/tox.lua - recoltarea probelor biologice (sange, toxicologie) si analiza lor in laborator.
-- Proba retine ce era in corp IN MOMENTUL recoltarii (ca in realitate). Analiza o face it_criminalistica (statia bio)
-- prin exportul AnalyzeTox.

local X = Sub.Tox
local pending = {} -- [collector] = { target, token, at }

local function notify(src, msg, kind) TriggerClientEvent('esx:showNotification', src, msg, kind or 'info', 9000) end

local function canCollect(src)
  local x = ESX.GetPlayerFromId(src)
  if not x or not x.job then return false end
  if x.job.name == X.medicJob then return true, x end
  if x.job.name ~= Sub.Police.job or x.job.onDuty ~= true then return false end
  local c = GetEntityCoords(GetPlayerPed(src))
  for _, p in ipairs(X.places) do
    if #(c - p.coords) <= p.radius then return true, x end
  end
  return false, x, 'Recoltarea se face în laboratorul secției (sau de către un medic).'
end

CreateThread(function()
  MySQL.query.await([[
    CREATE TABLE IF NOT EXISTS `it_probe_tox` (
      `id` INT NOT NULL AUTO_INCREMENT,
      `cod` VARCHAR(24) NULL,
      `subiect_identifier` VARCHAR(64) NOT NULL,
      `subiect_nume` VARCHAR(80) NULL,
      `recoltat_de` VARCHAR(80) NULL,
      `alcool_gl` DECIMAL(4,2) NOT NULL DEFAULT 0,
      `thc` TINYINT NOT NULL DEFAULT 0,
      `meth` TINYINT NOT NULL DEFAULT 0,
      `analizat` TINYINT NOT NULL DEFAULT 0,
      `recoltat_la` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (`id`),
      UNIQUE KEY `cod` (`cod`)
    )
  ]])
end)

lib.callback.register('it_substante:toxRequest', function(src, target)
  target = tonumber(target)
  local ok, x, why = canCollect(src)
  if not ok then return false, why or 'Nu ai voie să recoltezi probe biologice.' end
  local xT = target and ESX.GetPlayerFromId(target)
  if not xT or target == src then return false, 'Persoana nu mai este aici.' end
  local a, b = GetPlayerPed(src), GetPlayerPed(target)
  if #(GetEntityCoords(a) - GetEntityCoords(b)) > 2.5 then return false, 'Apropie-te de persoană.' end
  if pending[src] then return false, 'Ai deja o recoltare în curs.' end

  local token = ('tox-%d-%d-%d'):format(src, target, math.random(100000, 999999))
  pending[src] = { target = target, token = token, at = os.time() }
  TriggerClientEvent('it_substante:consent', target, { token = token, kind = 'sange', officer = x.getName(), seconds = Sub.Tests.consentSeconds })

  -- asteptam raspunsul (consentReply din teste.lua il trimite la noi prin eveniment local)
  local deadline = GetGameTimer() + (Sub.Tests.consentSeconds + 2) * 1000
  while pending[src] and pending[src].token == token and pending[src].answer == nil and GetGameTimer() < deadline do Wait(200) end
  local p = pending[src]
  pending[src] = nil
  if not p or p.token ~= token then return false end
  if p.answer ~= true then
    TriggerClientEvent('it_substante:consentClose', target)
    MySQL.insert('INSERT INTO it_teste_politie (tip, subiect_identifier, subiect_nume, politist_identifier, politist_nume, verdict) VALUES (?, ?, ?, ?, ?, ?)',
      { 'sange', xT.identifier, xT.getName(), x.identifier, x.getName(), 'refuz' })
    notify(target, 'Ai refuzat recoltarea probelor biologice. Refuzul a fost consemnat.', 'error')
    return false, ('%s a REFUZAT recoltarea. %s'):format(xT.getName(), Sub.Legal.refuse)
  end
  return true, token
end)

-- raspunsul persoanei (trimis din teste.lua)
AddEventHandler('it_substante:toxAnswer', function(token, target, accepted)
  for _, p in pairs(pending) do
    if p.token == token and p.target == target then p.answer = accepted == true end
  end
end)

-- dupa animatia de recoltare: proba propriu-zisa
lib.callback.register('it_substante:toxCollect', function(src, target, token)
  target = tonumber(target)
  local ok, x, why = canCollect(src)
  if not ok then return false, why end
  local xT = target and ESX.GetPlayerFromId(target)
  if not xT then return false, 'Persoana nu mai este aici.' end
  if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(target))) > 3.0 then return false, 'Persoana s-a îndepărtat.' end
  if not exports.ox_inventory:CanCarryItem(src, X.item, 1) then return false, 'Nu mai ai loc în inventar.' end

  local b = SubBody(xT.identifier)
  local gl = math.floor((b.bac or 0) * 100 + 0.5) / 100
  local id = MySQL.insert.await('INSERT INTO it_probe_tox (subiect_identifier, subiect_nume, recoltat_de, alcool_gl, thc, meth) VALUES (?, ?, ?, ?, ?, ?)',
    { xT.identifier, xT.getName(), x.getName(), gl, b.thc and 1 or 0, b.meth and 1 or 0 })
  if not id then return false, 'Eroare la înregistrarea probei.' end
  local code = ('TOX-%s-%05d'):format(os.date('%Y'), id)
  MySQL.update.await('UPDATE it_probe_tox SET cod = ? WHERE id = ?', { code, id })

  exports.ox_inventory:AddItem(src, X.item, 1, {
    code = code,
    description = ('%s\nSubiect: %s\nRecoltat: %s de %s\nNeanalizat'):format(code, xT.getName(), os.date('%d.%m.%Y %H:%M'), x.getName()),
  })
  notify(target, 'Ți s-au recoltat probe biologice (sânge) pentru analiza toxicologică.')
  return true, ('Probă recoltată: %s. Du-o la stația de analiză biologică din laborator.'):format(code)
end)

-- ===== analiza (apelata de it_criminalistica, statia bio) =====
exports('AnalyzeTox', function(code)
  local r = MySQL.single.await('SELECT * FROM it_probe_tox WHERE cod = ?', { code })
  if not r then return nil end
  MySQL.update.await('UPDATE it_probe_tox SET analizat = 1 WHERE id = ?', { r.id })
  math.randomseed(r.id * 7919)  -- aceleasi valori la reanaliza aceleiasi probe
  local thcV, methV = math.random(30, 250) / 10, math.random(60, 420)
  math.randomseed(os.time())
  return {
    code = r.cod,
    subject = r.subiect_nume,
    collectedBy = r.recoltat_de,
    collectedAt = r.recoltat_la,
    gl = tonumber(r.alcool_gl) or 0,
    thc = (r.thc == 1 or r.thc == true) and thcV or nil,     -- ng/mL
    meth = (r.meth == 1 or r.meth == true) and methV or nil, -- ng/mL
    legalAlcohol = (tonumber(r.alcool_gl) or 0) > 0.80 and Sub.Legal.breath_crime
      or ((tonumber(r.alcool_gl) or 0) > 0 and Sub.Legal.breath_contr or nil),
    legalDrugs = ((r.thc == 1 or r.thc == true) or (r.meth == 1 or r.meth == true)) and Sub.Legal.drug_pos or nil,
  }
end)

AddEventHandler('playerDropped', function() pending[source] = nil end)
