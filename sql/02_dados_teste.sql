INSERT INTO cliente (nome, cpf, telefone, email) VALUES
('Ana Souza', '52998224725', '(79) 99999-0001', 'ana.souza@email.com'),
('Carlos Lima', '11144477735', '(79) 99999-0002', 'carlos.lima@email.com'),
('Mariana Alves', '93541134780', '(79) 99999-0003', 'mariana.alves@email.com');

INSERT INTO categoria (nome, descricao, valor_diaria) VALUES
('Economico', 'Veiculos compactos para uso urbano', 100.00),
('Intermediario', 'Veiculos de porte medio', 150.00),
('SUV', 'Veiculos utilitarios esportivos', 230.00);

INSERT INTO filial (nome, logradouro, numero, bairro, cidade, estado, telefone) VALUES
('Filial Centro', 'Rua Itabaiana', '100', 'Centro', 'Aracaju', 'SE', '(79) 3211-1000'),
('Filial Jardins', 'Avenida Ministro Geraldo Barreto', '500', 'Jardins', 'Aracaju', 'SE', '(79) 3211-2000');

INSERT INTO veiculo (placa, marca, modelo, ano_fabricacao, cor, quilometragem, id_categoria, id_filial) VALUES
('ABC1D23', 'Fiat', 'Argo', 2023, 'Branco', 25000, 1, 1),
('DEF4G56', 'Chevrolet', 'Onix', 2024, 'Prata', 12000, 1, 1),
('GHI7J89', 'Jeep', 'Compass', 2023, 'Preto', 31000, 3, 2),
('JKL2M34', 'Volkswagen', 'Virtus', 2024, 'Cinza', 18000, 2, 2);

INSERT INTO locacao
(id_cliente, id_veiculo, id_filial, data_inicio, data_fim, valor_diaria, valor_total, status)
VALUES
(1, 1, 1, CURRENT_DATE + 2, CURRENT_DATE + 4, 100.00, 300.00, 'reservada');

INSERT INTO manutencao
(id_veiculo, descricao, tipo, data_inicio, data_fim, custo, status, quilometragem)
VALUES
(3, 'Revisao preventiva programada', 'preventiva',
 CURRENT_DATE + 1, CURRENT_DATE + 2, 350.00, 'agendada', 31000);
