/****** Ophalen van alle groepslidmaatschappen in Salto Space. 
		Groepen ManagedBySync = 0 worden niet door HelloID gemanaged.******/
SELECT 
	UG.ManagedByDBSync, 
	U.name, 
	U.FirstName, 
	U.LastName, 
	U.Dummy2 ,
	G.name,
	G.type,
	G.status,
	G.Description
FROM 
	tb_Users_Groups as UG
INNER JOIN 
	tb_Users AS U ON U.id_user = UG.id_user
INNER JOIN 
	tb_Groups AS G ON UG.id_group = G.id_group
ORDER BY Dummy2
