SELECT p.Nome, e.UF, c.Descricao
FROM Produto p
JOIN Categoria c ON p.Categoria_idCategoria = c.idCategoria
JOIN Pedido_has_Produto pp ON p.idProduto = pp.Produto_idProduto
JOIN Pedido ped ON pp.Pedido_idPedido = ped.idPedido
JOIN Endereco e ON ped.Cliente_idCliente = e.Cliente_idCliente
WHERE c.Descricao = 'Eletrônicos' AND e.UF = 'CE';
