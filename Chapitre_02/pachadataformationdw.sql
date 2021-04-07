USE PachadataFormationDM;
GO

-- nettoyage
DROP TABLE IF EXISTS dbo.FactInscription;
DROP TABLE IF EXISTS dbo.DimInscription;
DROP TABLE IF EXISTS dbo.DimSession;
DROP TABLE IF EXISTS dbo.DimContact;
GO

CREATE TABLE dbo.DimInscription (
	DimInscriptionSk bigint not null primary key identity(1,1),
	InscriptionId int not null,
	ReferenceCommande varchar(100) null
)
GO

CREATE TABLE dbo.DimSession (
	DimSessionSk bigint not null primary key identity(1,1),
	SessionId int not null,
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

CREATE TABLE dbo.DimContact (
	DimContactSk bigint not null primary key identity(1,1),
	ContactId int not null,
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

CREATE TABLE dbo.FactInscription (
	FactInscriptionSk bigint not null primary key identity(1,1),
	DimInscriptionSk bigint not null foreign key references dbo.DimInscription (DimInscriptionSk),
	DimSessionSk bigint not null foreign key references dbo.DimSession (DimSessionSk),
	DateSession date not null,
	DimContactSk bigint not null foreign key references dbo.DimContact (DimContactSk),
	MontantHT decimal(7, 2) not null default (0),
	DateFacture date not null
) WITH (DATA_COMPRESSION=ROW)
GO


-- alimentation
INSERT INTO PachadataFormationDM.dbo.DimInscription 
	(InscriptionId, ReferenceCommande)
SELECT InscriptionId, ReferenceCommande
FROM PachaDataFormation.Inscription.Inscription
GO

INSERT INTO PachadataFormationDM.dbo.DimContact
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
	-- il manque la Corse, 2A et 2B, la Poste reste à 20...
LEFT JOIN PachaDataFormation.Reference.Pays p ON r.PaysCD = p.PaysCD
LEFT JOIN PachaDataFormation.Contact.Societe s ON c.SocieteId = s.SocieteId
GO

INSERT INTO PachadataFormationDM.dbo.DimSession (
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

INSERT INTO PachadataFormationDM.dbo.FactInscription
	(DimInscriptionSk, DimSessionSk, DateSession, 
	 DimContactSk, MontantHT, DateFacture)
SELECT 
	di.DimInscriptionSk, ds.DimSessionSk, ds.DateDebut,
	dc.DimContactSk, SUM(f.MontantHT), MIN(f.DateFacture)
FROM PachaDataFormation.Inscription.Inscription i
JOIN PachadataFormationDM.dbo.DimInscription di ON i.InscriptionId = di.InscriptionId
JOIN PachadataFormationDM.dbo.DimSession ds ON i.SessionId = ds.SessionId
JOIN PachadataFormationDM.dbo.DimContact dc ON i.ContactId = dc.ContactId
JOIN PachaDataFormation.Inscription.InscriptionFacture inf ON i.InscriptionId = inf.InscriptionId
JOIN PachaDataFormation.Inscription.Facture f ON inf.FactureCd = f.FactureCd
-- seulement les facturés
GROUP BY di.DimInscriptionSk, ds.DimSessionSk, ds.DateDebut, dc.DimContactSk;
GO