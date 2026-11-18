-- Schema bazei de date (MariaDB / MySQL). Tabelele se creeaza si automat la pornirea resursei
-- (CREATE TABLE IF NOT EXISTS in server/teste.lua si server/tox.lua); fisierul e aici pentru referinta.

-- Fiecare test facut de politie (etilotest, drugtest, recoltare) + refuzurile.
CREATE TABLE IF NOT EXISTS `it_teste_politie` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `tip` VARCHAR(16) NOT NULL,                 -- alcool | droguri | sange
  `subiect_identifier` VARCHAR(64) NOT NULL,
  `subiect_nume` VARCHAR(80) NULL,
  `politist_identifier` VARCHAR(64) NULL,
  `politist_nume` VARCHAR(80) NULL,
  `valoare` DECIMAL(5,2) NULL,                -- mg/L aer expirat (etilotest)
  `rezultat` TEXT NULL,                       -- rezultatul complet (JSON)
  `verdict` VARCHAR(16) NOT NULL,             -- negativ | contraventie | infractiune | pozitiv | refuz
  `x` FLOAT NULL, `y` FLOAT NULL, `z` FLOAT NULL,
  `creat_la` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `subiect` (`subiect_identifier`)
);

-- Probele de sange pentru toxicologie: retin starea corpului IN MOMENTUL recoltarii.
CREATE TABLE IF NOT EXISTS `it_probe_tox` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `cod` VARCHAR(24) NULL,                     -- TOX-AAAA-NNNNN
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
);

-- Exemplu de raport: istoricul unei persoane, cele mai noi primele.
-- SELECT tip, valoare, verdict, politist_nume, creat_la
--   FROM it_teste_politie WHERE subiect_identifier = ? ORDER BY id DESC LIMIT 20;

-- Exemplu de statistica: cate teste pozitive / refuzuri pe zi, ultimele 7 zile.
-- SELECT DATE(creat_la) AS zi,
--        SUM(verdict IN ('contraventie','infractiune','pozitiv')) AS pozitive,
--        SUM(verdict = 'refuz') AS refuzuri, COUNT(*) AS total
--   FROM it_teste_politie WHERE creat_la >= NOW() - INTERVAL 7 DAY
--   GROUP BY DATE(creat_la) ORDER BY zi;
