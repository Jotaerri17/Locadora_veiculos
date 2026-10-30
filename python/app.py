import os
import sys
from datetime import date
from decimal import Decimal, InvalidOperation

import psycopg
from psycopg.rows import dict_row

from dotenv import load_dotenv
load_dotenv()



def conectar():
    database_url = os.getenv("DATABASE_URL")

    if not database_url:
        raise RuntimeError(
            "DATABASE_URL nao encontrada. Verifique o arquivo .env."
        )

    return psycopg.connect(
        database_url,
        row_factory=dict_row,
        connect_timeout=15
    )


def ler_data(mensagem):
    while True:
        valor = input(mensagem).strip()
        try:
            return date.fromisoformat(valor)
        except ValueError:
            print("Data invalida. Use AAAA-MM-DD.")


def ler_inteiro(mensagem):
    while True:
        try:
            valor = int(input(mensagem).strip())
            if valor <= 0:
                raise ValueError
            return valor
        except ValueError:
            print("Informe um numero inteiro positivo.")


def mostrar_linhas(linhas):
    if not linhas:
        print("\nNenhum registro encontrado.")
        return
    for linha in linhas:
        print("-" * 65)
        for chave, valor in linha.items():
            print(f"{chave}: {valor}")
    print("-" * 65)


def listar_veiculos(conn):
    with conn.cursor() as cur:
        cur.execute("""
            SELECT id_veiculo, placa, marca, modelo, categoria, filial, situacao
            FROM vw_situacao_veiculos
            ORDER BY filial, placa
        """)
        mostrar_linhas(cur.fetchall())


def consultar_disponibilidade(conn):
    id_filial = ler_inteiro("ID da filial: ")
    inicio = ler_data("Data inicial (AAAA-MM-DD): ")
    fim = ler_data("Data final (AAAA-MM-DD): ")

    if fim < inicio:
        print("A data final nao pode ser anterior a inicial.")
        return

    with conn.cursor() as cur:
        cur.execute("""
            SELECT v.id_veiculo, v.placa, v.marca, v.modelo,
                   c.nome AS categoria, f.nome AS filial
            FROM veiculo v
            JOIN categoria c ON c.id_categoria = v.id_categoria
            JOIN filial f ON f.id_filial = v.id_filial
            WHERE v.id_filial = %s
              AND v.ativo = TRUE
              AND c.ativa = TRUE
              AND f.ativa = TRUE
              AND NOT EXISTS (
                  SELECT 1
                  FROM locacao l
                  WHERE l.id_veiculo = v.id_veiculo
                    AND l.status IN ('reservada', 'ativa')
                    AND daterange(l.data_inicio, l.data_fim + 1, '[)')
                        && daterange(%s, %s + 1, '[)')
              )
              AND NOT EXISTS (
                  SELECT 1
                  FROM manutencao m
                  WHERE m.id_veiculo = v.id_veiculo
                    AND m.status IN ('agendada', 'em_andamento')
                    AND daterange(
                        m.data_inicio,
                        CASE WHEN m.data_fim IS NULL THEN NULL ELSE m.data_fim + 1 END,
                        '[)'
                    ) && daterange(%s, %s + 1, '[)')
              )
            ORDER BY v.modelo
        """, (id_filial, inicio, fim, inicio, fim))
        mostrar_linhas(cur.fetchall())


def cadastrar_locacao(conn):
    id_cliente = ler_inteiro("ID do cliente: ")
    id_veiculo = ler_inteiro("ID do veiculo: ")
    id_filial = ler_inteiro("ID da filial responsavel: ")
    inicio = ler_data("Data inicial (AAAA-MM-DD): ")
    fim = ler_data("Data final (AAAA-MM-DD): ")

    if fim < inicio:
        print("A data final nao pode ser anterior a inicial.")
        return

    with conn.cursor() as cur:
        cur.execute("""
            SELECT c.valor_diaria
            FROM veiculo v
            JOIN categoria c ON c.id_categoria = v.id_categoria
            WHERE v.id_veiculo = %s
        """, (id_veiculo,))
        registro = cur.fetchone()
        if not registro:
            print("Veiculo nao encontrado.")
            return

        diaria = registro["valor_diaria"]
        total = diaria * Decimal((fim - inicio).days + 1)
        print(f"Valor da diaria: R$ {diaria:.2f}")
        print(f"Valor total: R$ {total:.2f}")

        confirmar = input("Confirmar locacao? (s/n): ").strip().lower()
        if confirmar != "s":
            print("Operacao cancelada.")
            return

        cur.execute("""
            INSERT INTO locacao
                (id_cliente, id_veiculo, id_filial, data_inicio, data_fim,
                 valor_diaria, valor_total, status)
            VALUES (%s, %s, %s, %s, %s, %s, %s, 'reservada')
            RETURNING id_locacao
        """, (id_cliente, id_veiculo, id_filial, inicio, fim, diaria, total))
        novo_id = cur.fetchone()["id_locacao"]
    conn.commit()
    print(f"Locacao {novo_id} cadastrada com sucesso.")


def cadastrar_manutencao(conn):
    id_veiculo = ler_inteiro("ID do veiculo: ")
    descricao = input("Descricao: ").strip()
    tipo = input("Tipo (preventiva/corretiva): ").strip().lower()
    inicio = ler_data("Data inicial (AAAA-MM-DD): ")
    fim_texto = input("Data final (AAAA-MM-DD) ou vazio se nao definida: ").strip()
    fim = date.fromisoformat(fim_texto) if fim_texto else None

    if tipo not in ("preventiva", "corretiva"):
        print("Tipo invalido.")
        return
    if fim is not None and fim < inicio:
        print("A data final nao pode ser anterior a inicial.")
        return

    try:
        custo = Decimal(input("Custo: R$ ").replace(",", ".").strip())
        if custo < 0:
            raise InvalidOperation
    except (InvalidOperation, ValueError):
        print("Custo invalido.")
        return

    status = input("Status (agendada/em_andamento): ").strip().lower()
    if status not in ("agendada", "em_andamento"):
        print("Para novo agendamento, use agendada ou em_andamento.")
        return

    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO manutencao
                (id_veiculo, descricao, tipo, data_inicio, data_fim, custo, status)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            RETURNING id_manutencao
        """, (id_veiculo, descricao, tipo, inicio, fim, custo, status))
        novo_id = cur.fetchone()["id_manutencao"]
    conn.commit()
    print(f"Manutencao {novo_id} cadastrada com sucesso.")


def listar_locacoes_filial(conn):
    id_filial = ler_inteiro("ID da filial: ")
    with conn.cursor() as cur:
        cur.execute("""
            SELECT l.id_locacao, c.nome AS cliente, v.placa, v.modelo,
                   f.nome AS filial, l.data_inicio, l.data_fim,
                   l.valor_total, l.status
            FROM locacao l
            JOIN cliente c ON c.id_cliente = l.id_cliente
            JOIN veiculo v ON v.id_veiculo = l.id_veiculo
            JOIN filial f ON f.id_filial = l.id_filial
            WHERE l.id_filial = %s
            ORDER BY l.data_inicio DESC
        """, (id_filial,))
        mostrar_linhas(cur.fetchall())


def listar_manutencoes(conn):
    with conn.cursor() as cur:
        cur.execute("""
            SELECT m.id_manutencao, v.placa, v.modelo, m.descricao,
                   m.tipo, m.data_inicio, m.data_fim, m.custo, m.status
            FROM manutencao m
            JOIN veiculo v ON v.id_veiculo = m.id_veiculo
            ORDER BY m.data_inicio DESC
        """)
        mostrar_linhas(cur.fetchall())


def menu():
    print("""
========== LOCADORA DE VEICULOS ==========
1 - Listar situacao dos veiculos
2 - Consultar disponibilidade por periodo
3 - Cadastrar locacao
4 - Cadastrar manutencao
5 - Listar locacoes por filial
6 - Listar manutencoes
0 - Sair
""")


def main():
    try:
        conn = conectar()
    except (psycopg.Error, RuntimeError) as erro:
        print(f"Nao foi possivel conectar ao banco: {erro}")
        print("Confira a DATABASE_URL e as configuracoes de acesso do Neon.")
        sys.exit(1)

    print("Conexao com o banco estabelecida.")
    try:
        while True:
            menu()
            opcao = input("Escolha: ").strip()
            try:
                if opcao == "1":
                    listar_veiculos(conn)
                elif opcao == "2":
                    consultar_disponibilidade(conn)
                elif opcao == "3":
                    cadastrar_locacao(conn)
                elif opcao == "4":
                    cadastrar_manutencao(conn)
                elif opcao == "5":
                    listar_locacoes_filial(conn)
                elif opcao == "6":
                    listar_manutencoes(conn)
                elif opcao == "0":
                    break
                else:
                    print("Opcao invalida.")
            except (psycopg.Error, ValueError) as erro:
                conn.rollback()
                print(f"Operacao nao realizada: {erro}")
            except KeyboardInterrupt:
                conn.rollback()
                print("\nOperacao interrompida.")
    finally:
        conn.close()
        print("Conexao encerrada.")


if __name__ == "__main__":
    main()
