## Indicium Code Challenge - Meltano Pipeline

Como este trabalho foi produzido:

### 🏗️ 1. Organização do Projeto
 - Criação das pastas do projeto.
 - Clone do repositório [Indicium Code Challenge](https://github.com/techindicium/code-challenge).
 - Criação do **virtualenv**.
 - Instalação do **Meltano**.

---

### 📂 2. Extração do CSV e Exportação em JSONL (v1)

Vamos iniciar o desafio gerando o CSV a partir de order_details.csv para a pasta destino
/data/csv/yyyy-mm-dd/file.jsonl

O modelo de arquivo escolhido foi jsonl pela facilidade de debugging das informações exportadas,
bem como por ser um formato bem conhecido pelos desenvolvedores e amplamente suportado pelo meltano
e outros ambientes de ETL.

#### 🛠️ Instalação dos Plugins
```bash
meltano add extractor tap-csv
meltano add loader target-jsonl
meltano add loader target-jsonl --as target-jsonl-csv
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
meltano config target-jsonl-csv set destination_path 'output/data/csv/$DATE'
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


### 📂 3. Extração do banco de dados e Exportação em JSONL (v2)

A próxima etapa envolve extrair os dados de northwind.sql para a pasta destino
/data/postgres/{table}/yyyy-mm-dd/file.jsonl.

#### 🛠️ Inicialização do banco de dados

A partir do docker-file.yml fornecido no projeto do desafio, vamos iniciar o banco. Na pasta res:

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
    
    meltano add loader "$LOADER_NAME" --inherit-from target-jsonl
    meltano config "$LOADER_NAME" set destination_path "output/data/postgres/$TABLE/\$DATE"
    meltano config "$LOADER_NAME" set custom_name "$TABLE"
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






### 📂 4. Execução do pipeline em um orquestrador/scheduler (v2)

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
meltano invoke airflow webserver
```

#### 📤 Para testar o usuário na UI do Airflow e checar resultado da configuração:
```bash
meltano invoke airflow webserver
```

### b) Agendar execução diária:

#### ⚙️ Configuração de um meltano job para executar no Airflow scheduler:
```bash
meltano job add csv-to-json --tasks "tap-csv target-jsonl"
meltano schedule add daily-csv-to-json --job csv-to-json --interval "@daily"
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
