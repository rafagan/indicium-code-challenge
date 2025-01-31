
meltano add extractor tap-csv
meltano add loader target-jsonl
meltano config tap-csv set files '[{
  "entity": "order_details",
  "path": "../../res/data/order_details.csv",
  "keys": ["order_id", "product_id", "unit_price", "quantity", "discount"]
}]'
meltano config target-jsonl set destination_path output
meltano el tap-csv target-jsonl