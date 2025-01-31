
Schema of the original Northwind Database: 

![image](https://user-images.githubusercontent.com/49417424/105997621-9666b980-608a-11eb-86fd-db6b44ece02a.png)

Your challenge is to build a pipeline that extracts the data everyday from both sources and write the data first to local disk, and second to a PostgreSQL database. For this challenge, the CSV file and the database will be static, but in any real world project, both data sources would be changing constantly.

Its important that all writing steps (writing data from inputs to local filesystem and writing data from local filesystem to PostgreSQL database) are isolated from each other, you shoud be able to run any step without executing the others.

For the first step, where you write data to local disk, you should write one file for each table. This pipeline will run everyday, so there should be a separation in the file paths you will create for each source(CSV or Postgres), table and execution day combination, e.g.:

```
/data/postgres/{table}/2024-01-01/file.format
/data/postgres/{table}/2024-01-02/file.format
/data/csv/2024-01-02/file.format
```

You are free to chose the naming and the format of the file you are going to save.

At step 2, you should load the data from the local filesystem, which you have created, to the final database.

The final goal is to be able to run a query that shows the orders and its details. The Orders are placed in a table called **orders** at the postgres Northwind database. The details are placed at the csv file provided, and each line has an **order_id** field pointing the **orders** table.

## Solution Diagram

The solution should be based on the diagrams below:
![image](docs/diagrama_embulk_meltano.jpg)


### Requirements

- All tasks should be idempotent, you should be able to run the pipeline everyday and, in this case where the data is static, the output shold be the same.
- Step 2 depends on both tasks of step 1, so you should not be able to run step 2 for a day if the tasks from step 1 did not succeed.
- You should extract all the tables from the source database, it does not matter that you will not use most of them for the final step.
- You should be able to tell where the pipeline failed clearly, so you know from which step you should rerun the pipeline.
- You have to provide clear instructions on how to run the whole pipeline. The easier the better.
- You must provide evidence that the process has been completed successfully, i.e. you must provide a csv or json with the result of the query described above.
- Your pipeline should be prepared to run for past days, meaning you should be able to pass an argument to the pipeline with a day from the past, and it should reprocess the data for that day. Since the data for this challenge is static, the only difference for each day of execution will be the output paths.
