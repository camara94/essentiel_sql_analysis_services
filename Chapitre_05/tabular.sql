USE PachadataFormationTabular;
GO

-- nettoyage
DROP TABLE IF EXISTS dbo.Inscription;
DROP TABLE IF EXISTS dbo.Session;
DROP TABLE IF EXISTS dbo.Contact;
GO

CREATE TABLE dbo.Session (
	SessionId int not null primary key,
	LangueLocal varchar(50) not null,
	LangueFrancais varchar(50) not null,
	DateDebut date not null,
	Categorie char(2) not null,
	Domaine char(2) not null,
	Prix decimal(8,2) not null,
	note tinyint not null default(0),
	Duree tinyint not null,
	FormateurId int null,
	NomFormateur varchar(101) not null DEFAULT ('N/A'),
	SocieteFormateurId int null,
	NomSocieteFormateur varchar(50) not null DEFAULT ('N/A'),
	NomVilleSocieteFormateur varchar(255) not null DEFAULT ('N/A'),
	NomSalleFormation varchar(20) not null DEFAULT ('N/A'),
	NomLieuFormation varchar(30) not null DEFAULT ('N/A'),
	NomVilleFormation varchar(20) not null DEFAULT ('N/A')
)
GO

CREATE TABLE dbo.Contact (
	ContactId int not null primary key,
	Nom varchar(50) not null,
	Prenom varchar(50) null,
	Email varchar(150) null,
	Sexe char(1) not null DEFAULT ('?'),
	Ville varchar(255) null,
	CodeDepartement char(2) null,
	NomDepartement varchar(50) null,
	CodePays char(2) null,
	NomPaysFrancais varchar(50) null,
	NomPaysAnglais varchar(50) null,
	SocieteId int null,
	NomSociete varchar(60) null
)
GO

CREATE TABLE dbo.Inscription (
	InscriptionId int not null primary key,
	SessionId int not null foreign key references dbo.Session (SessionId),
	DateSession date not null,
	ContactId int not null foreign key references dbo.Contact (ContactId),
	MontantHT decimal(7, 2) not null default (0),
	DateFacture date not null,
	ReferenceCommande varchar(100) null
) WITH (DATA_COMPRESSION=ROW)
GO

-- alimentation
INSERT INTO PachadataFormationTabular.dbo.Contact
	(ContactId, Nom, Prenom, Email, Sexe, Ville, CodeDepartement, 
	 NomDepartement, CodePays, NomPaysFrancais, NomPaysAnglais, 
	 SocieteId, NomSociete)
SELECT 
	c.ContactId, c.Nom, c.Prenom, c.Email, COALESCE(c.Sexe, '?'),
	v.NomVille, r.CodeDepartement, r.NomDepartement, p.Code2,
	p.NomFrancais, p.NomAnglais, s.SocieteId, s.Nom
FROM PachaDataFormation.Contact.Contact c
LEFT JOIN PachaDataFormation.Contact.Adresse a ON c.AdressePostaleId = a.AdresseId
LEFT JOIN PachaDataFormation.Reference.ville v ON a.VilleId = v.VilleId
LEFT JOIN PachaDataFormation.Reference.Region r ON LEFT(RIGHT('00000' + LTRIM([CodePostal]), 5), 2) = r.CodeDepartement
	-- il manque la Corse, 2A et 2B, la Poste reste ? 20...
LEFT JOIN PachaDataFormation.Reference.Pays p ON r.PaysCD = p.PaysCD
LEFT JOIN PachaDataFormation.Contact.Societe s ON c.SocieteId = s.SocieteId
GO

INSERT INTO PachadataFormationTabular.dbo.Session (
	SessionId, LangueLocal, LangueFrancais, DateDebut, Categorie, Domaine,
	Prix, note, Duree, FormateurId, NomFormateur,
	SocieteFormateurId, NomSocieteFormateur,
	NomVilleSocieteFormateur, NomSalleFormation,
	NomLieuFormation, NomVilleFormation
)
SELECT
	s.SessionId, l.NomLocal, l.NomFrancais, s.DateDebut, st.Categorie, st.Domaine,
	s.Prix, COALESCE(s.Note, 0), s.Duree, f.FormateurId, CONCAT(cf.Prenom + ' ', cf.Nom), 
	sf.SocieteFormateurId, sf.Nom,
	vsf.NomVille, COALESCE(salle.Nom, 'N/A'),
	COALESCE(lieu.Nom, 'N/A'), COALESCE(lieu.Ville, 'N/A')
	 --COALESCE(Formateur, 'N/A')
FROM PachaDataFormation.Stage.Session s
JOIN PachaDataFormation.Stage.StageLangue sl ON s.StageId = sl.StageId AND s.LangueCd = sl.LangueCd
JOIN PachaDataFormation.Stage.Langue l ON sl.LangueCd = l.LangueCd
JOIN PachaDataFormation.Stage.Stage st ON sl.StageId = st.StageId
JOIN PachaDataFormation.Formateur.Formateur f ON s.FormateurId = f.FormateurId
JOIN PachaDataFormation.Contact.Contact cf ON f.ContactId = cf.ContactId
JOIN PachaDataFormation.Formateur.SocieteFormateur sf ON f.SocieteFormateurId = sf.SocieteFormateurId
JOIN PachaDataFormation.Contact.Adresse asf ON sf.AdresseFormateurId = asf.AdresseId
JOIN PachaDataFormation.Reference.ville vsf ON asf.VilleId = vsf.VilleId
LEFT JOIN PachaDataFormation.Reference.SalleFormation salle ON s.SalleFormationId = salle.SalleFormationId
LEFT JOIN PachaDataFormation.Reference.LieuFormation lieu ON salle.LieuFormationId = lieu.LieuFormationId
WHERE s.Statut IS NULL OR s.Statut <> 'A'
GO

INSERT INTO PachadataFormationTabular.dbo.Inscription
	(InscriptionId, SessionId, DateSession, 
	 ContactId, MontantHT, DateFacture, ReferenceCommande)
SELECT 
	i.InscriptionId, i.SessionId, ds.DateDebut,
	i.ContactId, SUM(f.MontantHT), MIN(f.DateFacture),
	i.ReferenceCommande
FROM PachaDataFormation.Inscription.Inscription i
JOIN PachadataFormationTabular.dbo.Session ds ON i.SessionId = ds.SessionId
JOIN PachadataFormationTabular.dbo.Contact dc ON i.ContactId = dc.ContactId
JOIN PachaDataFormation.Inscription.InscriptionFacture inf ON i.InscriptionId = inf.InscriptionId
JOIN PachaDataFormation.Inscription.Facture f ON inf.FactureCd = f.FactureCd
-- seulement les factures
GROUP BY i.InscriptionId, i.SessionId, ds.DateDebut, i.ContactId, i.ReferenceCommande;
GO

-- table de dates
CREATE TABLE Temps (
	Jour date not null primary key,
	NumeroMois as MONTH(Jour) PERSISTED,
	Annee as YEAR(Jour) PERSISTED,
	NomMois as DATENAME(month, Jour),
	NomJourSemaine as DATENAME(weekday, Jour)
)
GO

INSERT INTO Temps
SELECT DATEADD(day, ROW_NUMBER() OVER (ORDER BY InscriptionId), '19991231')
FROM PachaDataFormation.Inscription.Inscription
ORDER BY InscriptionId;
GO

SELECT * FROM Temps