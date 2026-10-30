

CREATE OR REPLACE FUNCTION fn_cpf_valido(p_cpf text)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v text;
    soma integer;
    digito integer;
    i integer;
BEGIN
    IF p_cpf IS NULL
       OR p_cpf !~ '^[0-9]{11}$'
       OR p_cpf ~ '^([0-9])\1{10}$' THEN
        RETURN false;
    END IF;

    v := p_cpf;
    soma := 0;

    FOR i IN 1..9 LOOP
        soma := soma + substring(v, i, 1)::integer * (11 - i);
    END LOOP;

    digito := (soma * 10) % 11;
    IF digito = 10 THEN
        digito := 0;
    END IF;

    IF digito <> substring(v, 10, 1)::integer THEN
        RETURN false;
    END IF;

    soma := 0;

    FOR i IN 1..10 LOOP
        soma := soma + substring(v, i, 1)::integer * (12 - i);
    END LOOP;

    digito := (soma * 10) % 11;
    IF digito = 10 THEN
        digito := 0;
    END IF;

    RETURN digito = substring(v, 11, 1)::integer;
END;
$$;



CREATE TABLE cliente (
    id_cliente bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome varchar(120) NOT NULL,
    cpf char(11) NOT NULL UNIQUE,
    telefone varchar(20),
    email varchar(150),
    data_cadastro timestamp NOT NULL DEFAULT current_timestamp,

    CONSTRAINT ck_cliente_nome
        CHECK (length(trim(nome)) >= 3),

    CONSTRAINT ck_cliente_cpf
        CHECK (fn_cpf_valido(cpf)),

    CONSTRAINT ck_cliente_telefone
        CHECK (telefone IS NULL OR telefone ~ '^[0-9()+ .-]{8,20}$'),

    CONSTRAINT ck_cliente_email
        CHECK (
            email IS NULL
            OR email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'
        )
);

CREATE TABLE categoria (
    id_categoria bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome varchar(60) NOT NULL UNIQUE,
    descricao varchar(250),
    valor_diaria numeric(10,2) NOT NULL,
    ativa boolean NOT NULL DEFAULT true,

    CONSTRAINT ck_categoria_nome
        CHECK (length(trim(nome)) >= 3),

    CONSTRAINT ck_categoria_valor
        CHECK (valor_diaria > 0)
);

CREATE TABLE filial (
    id_filial bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome varchar(100) NOT NULL,
    logradouro varchar(150) NOT NULL,
    numero varchar(15),
    bairro varchar(80),
    cidade varchar(80) NOT NULL,
    estado char(2) NOT NULL,
    telefone varchar(20),
    ativa boolean NOT NULL DEFAULT true,

    CONSTRAINT uq_filial_nome_cidade
        UNIQUE (nome, cidade),

    CONSTRAINT ck_filial_nome
        CHECK (length(trim(nome)) >= 3),

    CONSTRAINT ck_filial_cidade
        CHECK (length(trim(cidade)) >= 2),

    CONSTRAINT ck_filial_estado
        CHECK (estado ~ '^[A-Z]{2}$'),

    CONSTRAINT ck_filial_telefone
        CHECK (telefone IS NULL OR telefone ~ '^[0-9()+ .-]{8,20}$')
);

CREATE TABLE veiculo (
    id_veiculo bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    placa varchar(7) NOT NULL UNIQUE,
    marca varchar(50) NOT NULL,
    modelo varchar(70) NOT NULL,
    ano_fabricacao smallint NOT NULL,
    cor varchar(30),
    quilometragem integer NOT NULL DEFAULT 0,
    id_categoria bigint NOT NULL
        REFERENCES categoria(id_categoria) ON DELETE RESTRICT,
    id_filial bigint NOT NULL
        REFERENCES filial(id_filial) ON DELETE RESTRICT,
    ativo boolean NOT NULL DEFAULT true,

    CONSTRAINT ck_veiculo_placa
        CHECK (
            placa = upper(placa)
            AND placa ~ '^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$'
        ),

    CONSTRAINT ck_veiculo_marca
        CHECK (length(trim(marca)) >= 2),

    CONSTRAINT ck_veiculo_modelo
        CHECK (length(trim(modelo)) >= 1),

    CONSTRAINT ck_veiculo_ano
        CHECK (
            ano_fabricacao BETWEEN 1950
            AND extract(year FROM current_date)::integer + 1
        ),

    CONSTRAINT ck_veiculo_km
        CHECK (quilometragem >= 0)
);

CREATE TABLE locacao (
    id_locacao bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_cliente bigint NOT NULL
        REFERENCES cliente(id_cliente) ON DELETE RESTRICT,
    id_veiculo bigint NOT NULL
        REFERENCES veiculo(id_veiculo) ON DELETE RESTRICT,
    id_filial bigint NOT NULL
        REFERENCES filial(id_filial) ON DELETE RESTRICT,
    data_inicio date NOT NULL,
    data_fim date NOT NULL,
    valor_diaria numeric(10,2) NOT NULL,
    valor_total numeric(12,2) NOT NULL,
    status varchar(15) NOT NULL DEFAULT 'reservada',
    observacao varchar(500),
    data_criacao timestamp NOT NULL DEFAULT current_timestamp,

    CONSTRAINT ck_locacao_periodo
        CHECK (data_fim >= data_inicio),

    CONSTRAINT ck_locacao_valor_diaria
        CHECK (valor_diaria > 0),

    CONSTRAINT ck_locacao_valor_total
        CHECK (valor_total > 0),

    CONSTRAINT ck_locacao_status
        CHECK (status IN ('reservada', 'ativa', 'concluida', 'cancelada')),

    CONSTRAINT ck_locacao_observacao
        CHECK (observacao IS NULL OR length(trim(observacao)) > 0)
);

CREATE TABLE manutencao (
    id_manutencao bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_veiculo bigint NOT NULL
        REFERENCES veiculo(id_veiculo) ON DELETE RESTRICT,
    descricao varchar(500) NOT NULL,
    tipo varchar(15) NOT NULL,
    data_inicio date NOT NULL,
    data_fim date,
    custo numeric(12,2) NOT NULL DEFAULT 0,
    status varchar(15) NOT NULL DEFAULT 'agendada',
    quilometragem integer,
    observacao varchar(500),
    data_criacao timestamp NOT NULL DEFAULT current_timestamp,

    CONSTRAINT ck_manutencao_descricao
        CHECK (length(trim(descricao)) >= 3),

    CONSTRAINT ck_manutencao_tipo
        CHECK (tipo IN ('preventiva', 'corretiva')),

    CONSTRAINT ck_manutencao_periodo
        CHECK (data_fim IS NULL OR data_fim >= data_inicio),

    CONSTRAINT ck_manutencao_custo
        CHECK (custo >= 0),

    CONSTRAINT ck_manutencao_status
        CHECK (status IN ('agendada', 'em_andamento', 'concluida', 'cancelada')),

    CONSTRAINT ck_manutencao_km
        CHECK (quilometragem IS NULL OR quilometragem >= 0),

    CONSTRAINT ck_manutencao_concluida
        CHECK (status <> 'concluida' OR data_fim IS NOT NULL)
);



CREATE OR REPLACE FUNCTION fn_validar_locacao()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_conflito boolean;
BEGIN
    -- Bloqueia o veiculo durante a verificacao da operacao.
    -- Em atualizacao que troca o veiculo, bloqueia os dois IDs
    -- em ordem crescente para reduzir risco de deadlock.
    IF TG_OP = 'UPDATE' AND OLD.id_veiculo <> NEW.id_veiculo THEN
        IF OLD.id_veiculo < NEW.id_veiculo THEN
            PERFORM pg_advisory_xact_lock(OLD.id_veiculo);
            PERFORM pg_advisory_xact_lock(NEW.id_veiculo);
        ELSE
            PERFORM pg_advisory_xact_lock(NEW.id_veiculo);
            PERFORM pg_advisory_xact_lock(OLD.id_veiculo);
        END IF;
    ELSE
        PERFORM pg_advisory_xact_lock(NEW.id_veiculo);
    END IF;

    IF NEW.status IN ('reservada', 'ativa') THEN

        -- Verifica se o veiculo, sua categoria e sua filial atual estao ativos.
        IF NOT EXISTS (
            SELECT 1
            FROM veiculo v
            JOIN categoria c ON c.id_categoria = v.id_categoria
            JOIN filial f ON f.id_filial = v.id_filial
            WHERE v.id_veiculo = NEW.id_veiculo
              AND v.ativo = true
              AND c.ativa = true
              AND f.ativa = true
        ) THEN
            RAISE EXCEPTION
                'Veiculo inativo ou vinculado a filial/categoria inativa.';
        END IF;

        -- Verifica se a filial responsavel pela locacao esta ativa.
        IF NOT EXISTS (
            SELECT 1
            FROM filial
            WHERE id_filial = NEW.id_filial
              AND ativa = true
        ) THEN
            RAISE EXCEPTION
                'A filial responsavel pela locacao esta inativa.';
        END IF;

        -- Verifica conflito com outra locacao ativa ou reservada.
        SELECT EXISTS (
            SELECT 1
            FROM locacao l
            WHERE l.id_veiculo = NEW.id_veiculo
              AND l.status IN ('reservada', 'ativa')
              AND l.data_inicio <= NEW.data_fim
              AND l.data_fim >= NEW.data_inicio
              AND (
                    TG_OP = 'INSERT'
                    OR l.id_locacao <> NEW.id_locacao
              )
        )
        INTO v_conflito;

        IF v_conflito THEN
            RAISE EXCEPTION
                'Locacao recusada: o veiculo ja possui locacao/reserva nesse periodo.';
        END IF;

        -- Verifica conflito com manutencao agendada ou em andamento.
        SELECT EXISTS (
            SELECT 1
            FROM manutencao m
            WHERE m.id_veiculo = NEW.id_veiculo
              AND m.status IN ('agendada', 'em_andamento')
              AND m.data_inicio <= NEW.data_fim
              AND (
                    m.data_fim IS NULL
                    OR m.data_fim >= NEW.data_inicio
              )
        )
        INTO v_conflito;

        IF v_conflito THEN
            RAISE EXCEPTION
                'Locacao recusada: existe manutencao no periodo informado.';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validar_locacao
BEFORE INSERT OR UPDATE OF
    id_veiculo, id_filial, data_inicio, data_fim, status
ON locacao
FOR EACH ROW
EXECUTE FUNCTION fn_validar_locacao();



CREATE OR REPLACE FUNCTION fn_validar_manutencao()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_conflito boolean;
BEGIN
    IF TG_OP = 'UPDATE' AND OLD.id_veiculo <> NEW.id_veiculo THEN
        IF OLD.id_veiculo < NEW.id_veiculo THEN
            PERFORM pg_advisory_xact_lock(OLD.id_veiculo);
            PERFORM pg_advisory_xact_lock(NEW.id_veiculo);
        ELSE
            PERFORM pg_advisory_xact_lock(NEW.id_veiculo);
            PERFORM pg_advisory_xact_lock(OLD.id_veiculo);
        END IF;
    ELSE
        PERFORM pg_advisory_xact_lock(NEW.id_veiculo);
    END IF;

    IF NEW.status IN ('agendada', 'em_andamento') THEN

        IF NOT EXISTS (
            SELECT 1
            FROM veiculo
            WHERE id_veiculo = NEW.id_veiculo
              AND ativo = true
        ) THEN
            RAISE EXCEPTION
                'Nao e permitido agendar manutencao para veiculo inativo.';
        END IF;

        -- Verifica conflito com outra manutencao.
        SELECT EXISTS (
            SELECT 1
            FROM manutencao m
            WHERE m.id_veiculo = NEW.id_veiculo
              AND m.status IN ('agendada', 'em_andamento')
              AND m.data_inicio <= COALESCE(NEW.data_fim, 'infinity'::date)
              AND COALESCE(m.data_fim, 'infinity'::date) >= NEW.data_inicio
              AND (
                    TG_OP = 'INSERT'
                    OR m.id_manutencao <> NEW.id_manutencao
              )
        )
        INTO v_conflito;

        IF v_conflito THEN
            RAISE EXCEPTION
                'Manutencao recusada: ja existe manutencao no periodo informado.';
        END IF;

        -- Verifica conflito com locacao reservada ou ativa.
        SELECT EXISTS (
            SELECT 1
            FROM locacao l
            WHERE l.id_veiculo = NEW.id_veiculo
              AND l.status IN ('reservada', 'ativa')
              AND l.data_inicio <= COALESCE(NEW.data_fim, 'infinity'::date)
              AND l.data_fim >= NEW.data_inicio
        )
        INTO v_conflito;

        IF v_conflito THEN
            RAISE EXCEPTION
                'Manutencao recusada: existe locacao reservada/ativa no periodo.';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validar_manutencao
BEFORE INSERT OR UPDATE OF
    id_veiculo, data_inicio, data_fim, status
ON manutencao
FOR EACH ROW
EXECUTE FUNCTION fn_validar_manutencao();



CREATE OR REPLACE FUNCTION fn_validar_valor_locacao()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_diaria_categoria numeric(10,2);
    v_total_esperado numeric(12,2);
BEGIN
    SELECT c.valor_diaria
    INTO v_diaria_categoria
    FROM veiculo v
    JOIN categoria c ON c.id_categoria = v.id_categoria
    WHERE v.id_veiculo = NEW.id_veiculo;

    IF v_diaria_categoria IS NULL THEN
        RAISE EXCEPTION 'Veiculo/categoria nao encontrado.';
    END IF;

    IF TG_OP = 'INSERT' THEN
        NEW.valor_diaria := v_diaria_categoria;
    END IF;

    v_total_esperado :=
        (NEW.data_fim - NEW.data_inicio + 1) * NEW.valor_diaria;

    IF NEW.valor_total IS DISTINCT FROM v_total_esperado THEN
        RAISE EXCEPTION
            'Valor total incorreto. Esperado: %, informado: %.',
            v_total_esperado,
            NEW.valor_total;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validar_valor_locacao
BEFORE INSERT OR UPDATE OF
    id_veiculo, data_inicio, data_fim, valor_diaria, valor_total
ON locacao
FOR EACH ROW
EXECUTE FUNCTION fn_validar_valor_locacao();



CREATE INDEX idx_veiculo_filial_ativo
    ON veiculo(id_filial, ativo);

CREATE INDEX idx_veiculo_categoria
    ON veiculo(id_categoria);

CREATE INDEX idx_locacao_cliente
    ON locacao(id_cliente);

CREATE INDEX idx_locacao_filial_inicio
    ON locacao(id_filial, data_inicio);

CREATE INDEX idx_locacao_veiculo_periodo
    ON locacao(id_veiculo, data_inicio, data_fim);

CREATE INDEX idx_manutencao_veiculo_data
    ON manutencao(id_veiculo, data_inicio);

CREATE INDEX idx_manutencao_status
    ON manutencao(status);



CREATE OR REPLACE VIEW vw_situacao_veiculos AS
SELECT
    v.id_veiculo,
    v.placa,
    v.marca,
    v.modelo,
    c.nome AS categoria,
    f.nome AS filial,
    CASE
        WHEN NOT v.ativo THEN 'inativo'

        WHEN EXISTS (
            SELECT 1
            FROM manutencao m
            WHERE m.id_veiculo = v.id_veiculo
              AND m.status IN ('agendada', 'em_andamento')
              AND CURRENT_DATE >= m.data_inicio
              AND (
                    m.data_fim IS NULL
                    OR CURRENT_DATE <= m.data_fim
              )
        ) THEN 'em manutencao'

        WHEN EXISTS (
            SELECT 1
            FROM locacao l
            WHERE l.id_veiculo = v.id_veiculo
              AND l.status IN ('reservada', 'ativa')
              AND CURRENT_DATE BETWEEN l.data_inicio AND l.data_fim
        ) THEN 'locado/reservado'

        ELSE 'disponivel'
    END AS situacao
FROM veiculo v
JOIN categoria c ON c.id_categoria = v.id_categoria
JOIN filial f ON f.id_filial = v.id_filial;


