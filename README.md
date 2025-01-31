## Indicium Code Challenge - Meltano Pipeline

# TODO: Instruções gerais de como rodar os pipelines

Como este trabalho foi produzido:

### 🏗️ 1. Organização do Projeto
 - Criação das pastas do projeto.
 - Clone do repositório [Indicium Code Challenge](https://github.com/techindicium/code-challenge).
 - Criação do **virtualenv**.
 - Instalação do **Meltano**.

---

### 📂 2. Etapa 1: Extração do CSV e Exportação em JSONL (v1)

Vamos iniciar o desafio gerando o CSV a partir de order_details.csv para a pasta destino
/data/csv/yyyy-mm-dd/file.format

O modelo de arquivo escolhido foi jsonl pela facilidade de debugging das informações exportadas,
bem como por ser um formato bem conhecido pelos desenvolvedores e amplamente suportado pelo meltano
e outros ambientes de ETL. A versão singer conserva dados de schema que facilitam a posterior insersão no loader
de banco de dados.

#### 🛠️ Instalação dos Plugins
```bash
meltano add extractor tap-csv
meltano add loader target-singer-jsonl
meltano add loader target-singer-jsonl --as target-jsonl-csv
```

#### ⚙️ Configuração do tap-csv (Leitura do CSV order_details.csv)
```bash
meltano config tap-csv set files '[{
  "entity": "order_details",
  "path": "../../res/data/order_details.csv",
  "keys": ["order_id", "product_id", "unit_price", "quantity", "discount"]
}]'
```

#### ⚙️ Configuração do target-jsonl-csv (Escrita do JSONL do CSV)
```bash
meltano config target-jsonl-csv set destination "local"
meltano config target-jsonl-csv set local.folder "output/data/csv/$DATE"
```

#### 🚀 Criação do job de execução dos ETL
```bash
meltano job add csv-to-json --tasks 'tap-csv target-jsonl-csv'
```

#### 🚀 Execução do pipeline
```bash
DATE='2025-01-31' meltano run csv-to-json
```

---


### 📂 3. Etapa 1: Extração do banco de dados e Exportação em JSONL (v2)

A próxima etapa envolve extrair os dados de northwind.sql para a pasta destino
/data/postgres/{table}/yyyy-mm-dd/file.format.

#### 🛠️ Inicialização do banco de dados

A partir do docker-file.yml fornecido no projeto do desafio, vamos iniciar o banco. Na pasta res:

#### 🛠️ Instalação banco de dados e definição das tabelas
```bash
docker compose up -d

TABLES=(
    'categories'
    'customer_customer_demo'
    'customer_demographics'
    'customers'
    'employee_territories'
    'employees'
    'orders'
    'products'
    'region'
    'shippers'
    'suppliers'
    'territories'
    'us_states'
)
```

#### ⚙️ Configuração do psql (Leitura do banco de dados northwind.sql)
```bash
meltano add extractor tap-postgres
meltano config tap-postgres set host "localhost"
meltano config tap-postgres set port "5432"
meltano config tap-postgres set database "northwind"
meltano config tap-postgres set user "northwind_user"
meltano config tap-postgres set password "thewindisblowing"
meltano config tap-postgres set state "enabled"
meltano config tap-postgres set state_id_suffix "latest"
meltano config tap-postgres set filter_schemas '["public"]'

STREAMS_JSON=$(printf '["%s"]' "$(IFS=','; echo "${TABLES[*]}" | sed 's/,/","/g')")
meltano config tap-postgres set selected_streams "$STREAMS_JSON"
```

#### ⚙️ Configuração do target-jsonl-psql-{table} (Escrita dos JSONL das tabelas)
```bash
for TABLE in "${TABLES[@]}"; do
    LOADER_NAME="target-jsonl-psql-$TABLE"
    
    meltano add loader "$LOADER_NAME" --inherit-from target-singer-jsonl
    meltano config "$LOADER_NAME" set destination "local"
    meltano config "$LOADER_NAME" set local.folder "output/data/postgres/$TABLE/\$DATE"
done

```

#### 🚀 Criação do job de execução dos ETL
```bash
TASKS_JSON="["
for TABLE in "${TABLES[@]}"; do
    TASKS_JSON+="\"tap-postgres target-jsonl-psql-$TABLE\", "
done

TASKS_JSON="${TASKS_JSON%, }]"
meltano job add psql-to-json --tasks "$TASKS_JSON"
```

#### 🚀 Execução do pipeline
```bash
DATE='2025-01-31' meltano run psql-to-json
```

---

### 📂 4. Etapa 2: Importação dos dados do filesystem no psql (v3)

Agora que todos os dados, tanto do CSV como do psql foram exportados para o filesystem (etapa 1),
respeitando uma estrutura de pastas. A etapa 2 então consiste em importar os dados dos arquivos
para tabelas de um novo banco de dados

#### 🛠️ Instalação e configuração loader psql
```bash
meltano add loader target-postgres
meltano config target-postgres set host "localhost"
meltano config target-postgres set port "5432"
meltano config target-postgres set database "northwind2"
meltano config target-postgres set user "northwind_user"
meltano config target-postgres set password "thewindisblowing"
meltano config target-postgres set default_target_schema public
```

#### ⚙️ Criação tabela loader psql (no banco de dados)
```SQL
-- PGPASSWORD=thewindisblowing psql -h localhost -U northwind_user -d postgres
CREATE DATABASE northwind2;
```

#### 🛠️ Instalação e configuração extractor jsonl
```bash
meltano add extractor tap-singer-jsonl
meltano config tap-singer-jsonl set source local

JSON_FOLDERS="[
  \"output/data/postgres\",
  \"output/data/csv\"
]"

meltano config tap-singer-jsonl set local.recursive true
meltano config tap-singer-jsonl set local.folders "$JSON_FOLDERS"
```

#### 🚀 Criação do job de escrita no banco de dados psql do filesystem
```bash
meltano job add json-to-psql --tasks "tap-singer-jsonl target-postgres"
```

#### 🚀 Execução do pipeline
```bash
DATE='2025-01-31' meltano run json-to-psql
```

#### 📤 Para testar se a importação foi bem sucedida:
```bash
PGPASSWORD=thewindisblowing psql -h localhost -U northwind_user -d northwind2
northwind2-# \dt
northwind2=# SELECT * FROM orders LIMIT 10;
northwind2=# SELECT * FROM order_details LIMIT 10;

# Checar idempotência
SELECT COUNT(*) FROM orders;
SELECT COUNT(*) FROM order_details;
```

---

### 📂 4. Execução do pipeline em um orquestrador/scheduler (v4)

Seguindo os requisitos do trabalho, foi configurado o Apache Airflow para
executar o pipeline diariamente.

### a) Instalação Airflow:

#### 🛠️ **Instalação da utility Airflow**
```bash
meltano add utility airflow
meltano invoke airflow:initialize
```

#### ⚙️ Configuração de um usuário Airflow
```bash
meltano invoke airflow users create -u admin -p admin --role Admin -e admin@admin.com -f admin -l admin
```

#### 📤 Para testar o usuário na UI do Airflow e checar resultado da configuração:
```bash
meltano invoke airflow webserver
```

### b) Agendar execução diária:

#### ⚙️ Configuração de um meltano job para executar no Airflow scheduler:
```bash

TASKS=('"tap-csv target-jsonl-csv"')
for TABLE in "${TABLES[@]}"; do
    TASKS+=("\"tap-postgres target-jsonl-psql-${TABLE}\"")
done
TASKS+=('"tap-singer-jsonl target-postgres"')

TASKS_STR="[$(IFS=,; echo "${TASKS[*]}")]"
meltano job add filesystem-to-psql --tasks "$TASKS_STR"

meltano schedule add daily-filesystem-to-psql --job filesystem-to-psql --interval "@daily"
```

#### 🚀 Iniciar scheduler para execução de eventos agendados
```bash
MELTANO_ENVIRONMENT=dev meltano invoke airflow scheduler
```

#### 🚀 Ou execução manual e imediata do job
```bash
meltano run csv-to-json
```

---

### 📂 5. Query validando resultado final alcançado

Vamos gerar um arquivo CSV a partir do psql que mostre as orders e seus detalhes (order_details)

#### 📤 Acessar banco de dados:
```bash
PGPASSWORD=thewindisblowing psql -h localhost -U northwind_user -d northwind2
```

#### 📤 Gerar arquivo:
```sql
\COPY (
    SELECT * from orders AS o 
    JOIN order_details AS d 
    ON o.order_id = CAST(d.order_id AS bigint)
) TO '/path/to/indicium/out/result.csv' WITH CSV HEADER;
```
