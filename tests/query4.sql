SELECT ped.idPedido, ped.DataPedido, s.Descricao AS Status
FROM Pedido ped
JOIN Status s ON ped.Status_idStatus = s.idStatus
WHERE ped.Cliente_idCliente = 1;
