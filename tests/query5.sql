SELECT cli.Nome, e.Logradouro, e.Cidade, tc.Descricao AS Tipo_Cliente
FROM Cliente cli
JOIN TipoCliente tc ON cli.TipoCliente_idTipoCliente = tc.idTipoCliente
JOIN Endereco e ON e.Cliente_idCliente = cli.idCliente
WHERE tc.Descricao = 'VIP';
