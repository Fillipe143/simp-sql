SELECT p.Nome, pp.Quantidade, pp.PrecoUnitario
FROM Pedido_has_Produto pp
JOIN Produto p ON pp.Produto_idProduto = p.idProduto
WHERE pp.Pedido_idPedido = 10;
