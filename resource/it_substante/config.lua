-- it_substante (18 nov 2026)
-- Un singur loc pentru tot ce se consuma: mancare, bauturi, alcool, droguri.
-- Serverul tine "corpul" fiecarui personaj (alcoolemie in g/l = ‰, THC, metamfetamina), si dupa relogare.
-- Pe el se bazeaza efectele (client) si testele politiei (etilotest / drugtest).

Sub = {}

-- ===== consumabile =====
-- kind: food | drink | alcohol | drug
-- hunger / thirst: cat adauga in esx_status (1000000 = plin)
-- bac: cat adauga la alcoolemie (‰ = g/l sange), absorbit treptat
-- drug: 'thc' | 'meth'
-- anim: eat | drink | bottle | glass | joint | pipe
Sub.Items = {
  bread          = { kind = 'food',  label = 'pâine',          hunger = 200000, anim = 'eat',   prop = 'prop_food_burg2' },
  burger         = { kind = 'food',  label = 'burger',         hunger = 250000, anim = 'eat',   prop = 'prop_cs_burger_01' },
  sandwich       = { kind = 'food',  label = 'sandviș',        hunger = 200000, anim = 'eat',   prop = 'prop_sandwich_01' },
  taco_chicken   = { kind = 'food',  label = 'taco cu pui',    hunger = 230000, anim = 'eat',   prop = 'prop_taco_01' },
  pizza_ham      = { kind = 'food',  label = 'pizza cu șuncă', hunger = 300000, anim = 'eat',   prop = 'prop_pizza_box_01' },
  honey_jar      = { kind = 'food',  label = 'miere',          hunger = 120000, anim = 'eat',   prop = 'prop_food_cb_cups01' },

  water          = { kind = 'drink', label = 'apă',            thirst = 300000, anim = 'drink', prop = 'prop_ld_flow_bottle' },
  sprunk         = { kind = 'drink', label = 'Sprunk',         thirst = 220000, anim = 'drink', prop = 'prop_ecola_can' },
  coffee         = { kind = 'drink', label = 'cafea',          thirst = 150000, anim = 'drink', prop = 'p_amb_coffeecup_01' },

  beer           = { kind = 'alcohol', label = 'bere',         thirst = 90000, bac = 0.20, anim = 'bottle', prop = 'prop_beer_bottle' },
  blackberry_ale = { kind = 'alcohol', label = 'bere de mure', thirst = 90000, bac = 0.22, anim = 'bottle', prop = 'prop_beer_bottle' },
  wine           = { kind = 'alcohol', label = 'vin',          thirst = 70000, bac = 0.25, anim = 'glass',  prop = 'prop_drink_redwine' },

  cannabis       = { kind = 'drug', label = 'cannabis',        drug = 'thc',  dose = 1.0, anim = 'joint', prop = 'p_cs_joint_02' },
  marijuana      = { kind = 'drug', label = 'marijuana',       drug = 'thc',  dose = 1.0, anim = 'joint', prop = 'p_cs_joint_02' },
  meth           = { kind = 'drug', label = 'metamfetamină',   drug = 'meth', dose = 1.0, anim = 'pipe',  prop = 'prop_cs_crackpipe' },
}

-- ===== alcool =====
Sub.Alcohol = {
  absorbPerMin  = 0.10,  -- ‰ pe minut trecute din stomac in sange (o bere urca in ~2 minute)
  eliminPerMin  = 0.01,  -- ‰ pe minut eliminate (0.1‰ la 10 minute)
  max           = 4.0,   -- plafon
  -- praguri efecte (‰)
  tiers = { 0.20, 0.50, 0.80, 1.50, 2.50 },
  blackout      = 3.00,  -- peste: lesin
}

-- ===== droguri (minute, timp real) =====
Sub.Drugs = {
  thc  = { label = 'THC (cannabis)',  detectMin = 120, effectMin = 8, extraPerDose = 2, maxEffectMin = 15 },
  meth = { label = 'Metamfetamină',  detectMin = 60,  effectMin = 6, extraPerDose = 2, maxEffectMin = 12, crashMin = 4 },
}

-- ===== teste politie =====
Sub.Police = { job = 'police' }
Sub.Tests = {
  maxDistance = 2.5,
  consentSeconds = 25,     -- cat are persoana sa accepte; nimic = refuz
  cooldownSeconds = 20,
  -- etilotest: aer expirat, mg/l (in Romania 0.40 mg/l aer = 0.80 g/l sange)
  breathRatio = 2.0,       -- ‰ sange / mg/l aer
  breathNoise = 0.02,      -- eroare de masurare ± mg/l
  breathNegative = 0.05,   -- sub: "0.00" / negativ
  breathCrime = 0.40,      -- de la: infractiune
  blowSeconds = 6,
  drugReadSeconds = 9,
  items = { breath = 'etilotest', drug = 'drugtest' },
}

-- ===== recoltare probe biologice (toxicologie) =====
-- Dupa etilotest/drugtest pozitiv. Politistul in tura doar in laboratorul sectiei; medicul oriunde.
-- Refuzul = art. 337 (ca la teste). Proba (item proba_tox) se analizeaza la statia "bio" din it_criminalistica.
Sub.Tox = {
  item = 'proba_tox',
  ms = 9000,
  places = {
    { coords = vec3(484.6, -988.7, 30.7), radius = 9.0, label = 'Laborator MRPD' },
  },
  medicJob = 'ambulance',
}

-- textele legale (afisate politistului)
Sub.Legal = {
  breath_neg   = 'Negativ.',
  breath_contr = 'Contravenție: conducere sub influența alcoolului (sub 0,40 mg/l). Amendă și suspendarea permisului 90 de zile.',
  breath_crime = 'Infracțiune: art. 336 alin. (1) C. pen. - conducere cu peste 0,80 g/l alcool în sânge. Se recoltează probe biologice.',
  drug_pos     = 'Infracțiune: art. 336 alin. (2) C. pen. - conducere sub influența substanțelor psihoactive. Se recoltează probe biologice.',
  drug_neg     = 'Negativ.',
  refuse       = 'Infracțiune: art. 337 C. pen. - refuzul sau sustragerea de la testare/recoltarea probelor biologice.',
}
