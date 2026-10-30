# Locadora de Veículos

Aplicação de linha de comando para apoiar operações básicas de uma locadora de veículos. O programa Python conecta-se a um banco PostgreSQL, consulta a situação e a disponibilidade dos veículos e registra locações e manutenções. As regras de integridade e de conflito entre locações e manutenções são implementadas no banco de dados.

## Tecnologias utilizadas

- **Python** — aplicação CLI.
- **Psycopg 3** — conexão com PostgreSQL, usando `psycopg[binary]`.
- **python-dotenv** — carregamento das variáveis do arquivo `.env`.
- **PostgreSQL** — persistência, validações, triggers, índices e view de situação dos veículos.

O repositório não contém frontend web nem uma API HTTP. Também não foram identificadas integrações com serviços externos; a mensagem de erro do programa menciona o Neon como possível provedor do PostgreSQL, mas não há configuração de provedor no repositório.

## Funcionalidades

O menu principal oferece:

1. Listagem da situação dos veículos por meio da view `vw_situacao_veiculos`.
2. Consulta de disponibilidade por período, considerando filial, locações reservadas/ativas e manutenções agendadas/em andamento.
3. Cadastro de locação, com cálculo do valor total a partir da diária da categoria e confirmação interativa.
4. Cadastro de manutenção, com descrição, tipo, período, custo e status.
5. Listagem de locações por filial.
6. Listagem de manutenções.

As entradas de data usam o formato `AAAA-MM-DD`. O programa valida localmente datas, inteiros positivos, tipos e status de manutenção; validações adicionais são realizadas pelo PostgreSQL.

Não há perfis de usuário, autenticação ou autorização implementados na aplicação.

## Arquitetura e organização

```text
.
├── python/
│   ├── app.py
│   └── requirements.txt
├── sql/
│   ├── 01_estrutura_validacoes.sql
│   └── 02_dados_teste.sql
├── .gitignore
└── README.md
```

- `python/app.py`: conexão com o banco, menu interativo, consultas e operações de locação/manutenção.
- `python/requirements.txt`: dependências Python.
- `sql/01_estrutura_validacoes.sql`: função de validação de CPF, tabelas, relacionamentos, constraints, triggers, índices e view.
- `sql/02_dados_teste.sql`: dados de exemplo.
- `.gitignore`: ignora o arquivo `.env`.

## Pré-requisitos

- Python instalado.
- PostgreSQL acessível pela aplicação.
- Banco PostgreSQL preparado com os scripts SQL do diretório `sql`.

O projeto não fixa uma versão mínima do Python ou do PostgreSQL. As dependências declaradas são:

```text
psycopg[binary]>=3.2,<4
python-dotenv
```

## Configuração e execução

Crie um arquivo `.env` na raiz do projeto:

```env
DATABASE_URL=postgresql://usuario:senha@localhost:5432/locadora
```

`DATABASE_URL` é obrigatória e é usada para abrir a conexão PostgreSQL, com timeout de 15 segundos. O arquivo `.env` é ignorado pelo Git.

Instale as dependências a partir da pasta `python`:

```bash
python -m pip install -r requirements.txt
```

Execute `sql/01_estrutura_validacoes.sql` em um banco PostgreSQL vazio. Opcionalmente, execute depois `sql/02_dados_teste.sql` para inserir registros de exemplo. Os scripts não fornecem um comando de automação de banco.

Inicie a aplicação com:

```bash
python python/app.py
```

## Banco de dados

| Entidade | Responsabilidade |
|---|---|
| `cliente` | Dados cadastrais e CPF dos clientes. |
| `categoria` | Categorias de veículos e valores de diária. |
| `filial` | Filiais, endereços e status de ativação. |
| `veiculo` | Veículos, categoria, filial, placa e quilometragem. |
| `locacao` | Períodos, valores, cliente, veículo, filial e status. |
| `manutencao` | Serviços, períodos, custos, tipo e status. |

`veiculo` referencia `categoria` e `filial`; `locacao` referencia `cliente`, `veiculo` e `filial`; e `manutencao` referencia `veiculo`. Os relacionamentos usam `ON DELETE RESTRICT`.

O script estrutural cria a função `fn_cpf_valido`, triggers que impedem conflitos de período, trigger que valida os valores da locação, índices de consulta e a view `vw_situacao_veiculos`.

## API, integrações e segurança

Não existe API HTTP ou endpoint REST neste repositório. A interface disponível é o menu de terminal de `python/app.py`.

Não foram identificados mecanismos de autenticação ou autorização. O acesso ao banco depende das credenciais presentes em `DATABASE_URL`; credenciais reais não devem ser versionadas nem documentadas.

As medidas observadas incluem consultas parametrizadas, validações de entrada, constraints e triggers no PostgreSQL, locks transacionais para validação de conflitos e exclusão do `.env` pelo `.gitignore`.

## Testes

Não foram encontrados testes automatizados, configuração de framework de testes ou comandos de teste. `sql/02_dados_teste.sql` fornece dados de exemplo, mas não é uma suíte automatizada.

## Observações técnicas

- A aplicação é síncrona e orientada a operações interativas no terminal.
- Os scripts SQL devem ser aplicados antes das operações de consulta ou gravação.
- A aplicação faz `commit` após cadastrar uma locação ou manutenção e executa `rollback` ao capturar erros de banco ou de entrada.
- O repositório contém somente a implementação CLI e a camada SQL; não há frontend, backend web ou autenticação.
