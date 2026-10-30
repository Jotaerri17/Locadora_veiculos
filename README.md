# Locadora de Veiculos

Projeto de terminal com PostgreSQL e Python.

## Requisitos

- PostgreSQL 14 ou superior
- Python 3.10 ou superior
- `psql` disponivel no terminal

## 1. Criar o banco

```bash
createdb -U postgres locadora_veiculos
```

Se `createdb` nao estiver no PATH:

```bash
psql -U postgres -c "CREATE DATABASE locadora_veiculos;"
```

## 2. Criar tabelas, restricoes, triggers e indices

Na pasta raiz do projeto:

```bash
psql -U postgres -d locadora_veiculos -v ON_ERROR_STOP=1 -f sql/01_estrutura_validacoes.sql
```

## 3. Inserir dados demonstrativos

```bash
psql -U postgres -d locadora_veiculos -v ON_ERROR_STOP=1 -f sql/02_dados_teste.sql
```

Os dados de teste sao opcionais. Se executar novamente, os registros podem duplicar ou violar restricoes unicas.

## 4. Instalar a dependencia Python

Linux/macOS:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r python/requirements.txt
```

Windows PowerShell:

```powershell
py -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r python/requirements.txt
```

## 5. Configurar conexao

O programa usa estas variaveis:

- `DB_HOST` (padrao: localhost)
- `DB_PORT` (padrao: 5432)
- `DB_NAME` (padrao: locadora_veiculos)
- `DB_USER` (padrao: postgres)
- `DB_PASSWORD` (padrao: vazio)

Linux/macOS:

```bash
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=locadora_veiculos
export DB_USER=postgres
export DB_PASSWORD='sua_senha'
python3 python/app.py
```

Windows PowerShell:

```powershell
$env:DB_HOST="localhost"
$env:DB_PORT="5432"
$env:DB_NAME="locadora_veiculos"
$env:DB_USER="postgres"
$env:DB_PASSWORD="sua_senha"
py python/app.py
```

## Funcoes do menu

1. Listar situacao dos veiculos
2. Consultar disponibilidade em uma filial e periodo
3. Cadastrar locacao
4. Cadastrar manutencao
5. Listar locacoes por filial
6. Listar manutencoes

As regras de integridade ficam no PostgreSQL. O Python solicita os dados, executa as operacoes e apresenta os resultados. Conflitos de datas, CPFs, placas, valores e relacionamentos sao validados pelo banco.

## Estrutura

```text
locadora_terminal/
  sql/
    01_estrutura_validacoes.sql
    02_dados_teste.sql
  python/
    app.py
    requirements.txt
  README.md
```
