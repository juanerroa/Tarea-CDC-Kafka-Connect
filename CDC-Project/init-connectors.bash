## Crear conectores
curl -X POST -H "Content-Type: application/json" --data @source-connector.json http://localhost:8083/connectors
curl -X POST -H "Content-Type: application/json" --data @sink-connector.json http://localhost:8083/connectors

## Eliminar conectores

## curl -X DELETE http://localhost:8083/connectors/postgres-source
## curl -X DELETE http://localhost:8083/connectors/postgres-sink
