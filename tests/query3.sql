SELECT p.Nome, c.Descricao AS Categoria
FROM Produto p
JOIN Categoria c ON p.Categoria_idCategoria = c.idCategoria;
