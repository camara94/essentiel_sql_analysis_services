USE PachadataFormationDM
GO

ALTER TABLE dbo.DimSession
ADD NomDeFamilleFormateur varchar(50) NOT NULL DEFAULT ('');
GO

UPDATE s
SET s.NomDeFamilleFormateur = c.Nom
--SELECT c.Nom
FROM dbo.DimSession s 
JOIN PachaDataFormation.Formateur.Formateur f 
	ON s.FormateurId = f.FormateurId
JOIN PachaDataFormation.Contact.Contact c 
	ON f.ContactId = c.ContactId