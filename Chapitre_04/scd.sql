USE PachadataFormationDM;
GO

SELECT * 
FROM dbo.FactInscription
WHERE FactInscriptionSk IN (2626, 5761);
GO

SELECT *
FROM dbo.DimContact
WHERE DimContactSk = 11243;
GO

SELECT v.NomVille, r.CodeDepartement, r.NomDepartement
FROM PachaDataFormation.Reference.ville v
JOIN PachaDataFormation.Reference.Region r ON LEFT(v.CodePostal, 2) = r.CodeDepartement
WHERE v.NomVille = 'Noirétable'
GO

INSERT INTO dbo.DimContact
	(ContactId, Nom, Prenom, Email, Sexe, 
	 Ville, CodeDepartement, NomDepartement, 
	 CodePays, NomPaysFrancais, NomPaysAnglais, 
	 SocieteId, NomSociete)
SELECT 
	ContactId, Nom, Prenom, Email, Sexe, 
	 'Noirétable', 42, 'Loire', 
	 CodePays, NomPaysFrancais, NomPaysAnglais, 
	 SocieteId, NomSociete
FROM dbo.DimContact
WHERE DimContactSk = 11243;

SELECT SCOPE_IDENTITY();
GO

UPDATE dbo.FactInscription
SET DimContactSk = 20084
WHERE FactInscriptionSk = 5761;
GO

SELECT * 
FROM dbo.FactInscription
WHERE FactInscriptionSk = 5761;
GO
