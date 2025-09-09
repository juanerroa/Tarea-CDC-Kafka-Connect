
# 📖 Change Data Capture con SQL Server → Kafka → PostgreSQL

## 🎯 Introducción y Propósito

Este proyecto demuestra cómo replicar cambios en tiempo real desde una base de datos **SQL Server** hacia **PostgreSQL** utilizando **Apache Kafka** y **Kafka Connect**.

El caso de uso principal es la replicación de datos transaccionales, como una tabla de clientes de un sistema bancario, hacia un destino analítico o un data warehouse para su posterior procesamiento sin afectar la base de datos de producción.

### Beneficios del Enfoque

  * ⚡ **Captura de Cambios en Tiempo Real:** Los datos se replican con baja latencia a medida que se producen.
  * 🛠 **Escalabilidad y Desacoplamiento:** Los sistemas de origen y destino no están directamente acoplados, lo que permite un mantenimiento y escalado independientes.
  * 🔌 **Fácil Integración:** Kafka actúa como un bus central de eventos, facilitando la conexión de múltiples sistemas adicionales (consumidores o productores) en el futuro.

-----

## 📁 Estructura del Proyecto

El repositorio está organizado de la siguiente manera para facilitar el despliegue y la configuración:

```
CDC-Project/
├─ docker-compose.yml        # Define y orquesta todos los servicios en contenedores.
├─ db.init/                  # Guarda las tablas necesarias a crear en las bases de datos
│  ├─ sqlserver.sql          # Tablas de SQL a crear para usar como fuente de datos par ala demostración
├─ connectors/
│  ├─ sqlserver-source.json  # Configuración del conector de origen (SQL Server).
│  └─ postgres-sink.json     # Configuración del conector de destino (PostgreSQL).
├─ init-connectors.bash      # Script para registrar los conectores en la API de Kafka Connect.
├─ postman_collection.json   # Colección de postman para gestionar los conectores (opcionalmente si no se usa Curl)
└─ README.md                 # Doc
```

Se incluye un archivo `.gitignore` para excluir archivos innecesarios y sensibles del control de versiones, tales como:

  * Datos de volúmenes de Docker.
  * Logs generados por las aplicaciones.
  * Archivos temporales del sistema.
  * Configuraciones locales del IDE.
  * Archivos de credenciales como `.env`.

-----

## 🏛️ Arquitectura Técnica Detallada

### Componentes del Sistema

  * 🖥 **SQL Server 2022:** Base de datos relacional que actúa como la fuente de datos transaccionales.
  * ⚡ **Apache Kafka:** Plataforma de streaming de eventos que funciona como bus de mensajes.
  * 🔗 **Kafka Connect:** Framework para conectar Kafka con sistemas externos de forma fiable y escalable.
  * 🐘 **PostgreSQL:** Base de datos relacional de código abierto que actúa como destino de los datos.

### Flujo de Datos Paso a Paso

El flujo de datos sigue una secuencia lógica y desacoplada a través de los componentes:

```
1. SQL Server (Tabla 'Clients')
        │
        ▼
2. Kafka Connect Source Connector (JDBC)
        │ (Lee cambios basados en una columna incremental)
        ▼
3. Kafka Topic: 'SQLServer_Clients'
        │ (Los cambios se publican como mensajes)
        ▼
4. Kafka Connect Sink Connector (JDBC)
        │ (Consume mensajes del topic)
        ▼
5. PostgreSQL (Tabla 'clients_new')
```

-----

## ⚙️ Requisitos del Sistema

### Software

  * **Docker y Docker Compose:** Versión `3.9` o superior.
  * **Puertos Disponibles:**
      * `1433` → SQL Server
      * `5432` → PostgreSQL
      * `9092` → Kafka Broker
      * `8083` → Kafka Connect REST API

### Hardware (Mínimo)

  * **RAM:** 4GB
  * **CPU:** 2 núcleos

-----

## 🚀 Despliegue Express (5 minutos)

Sigue estos pasos para levantar toda la infraestructura y el pipeline.

1.  **Levantar todos los servicios con Docker Compose:**

    ```bash
    docker compose up -d
    ```

2.  **Verificar que todos los contenedores estén activos:**

    ```bash
    docker ps
    ```

3.  **Revisar los logs de Kafka Connect** para asegurar que se ha iniciado correctamente:

    ```bash
    docker logs -f tarea-1-kafka-connect-1
    ```

    *Busca un mensaje que indique que la API REST está escuchando en el puerto `8083`.*

-----

## 📋 Configuración de Conectores

Los conectores se definen en archivos JSON y se registran a través de la API REST de Kafka Connect.

### Source Connector – SQL Server

Este conector lee la tabla `Clients` en modo incremental usando la columna `ClientId`.

`connectors/sqlserver-source.json`

```json
{
  "name": "sqlserver-source",
  "config": {
    "connector.class": "io.confluent.connect.jdbc.JdbcSourceConnector",
    "tasks.max": "1",
    "connection.url": "jdbc:sqlserver://sqlserver:1433;databaseName=BankingCore",
    "connection.user": "sa",
    "connection.password": "DummyPass123!",
    "mode": "incrementing",
    "incrementing.column.name": "ClientId",
    "table.whitelist": "Clients",
    "topic.prefix": "SQLServer_",
    "poll.interval.ms": 5000
  }
}
```

### Sink Connector – PostgreSQL

Este conector consume los mensajes del topic `SQLServer_Clients` y los inserta en una nueva tabla llamada `clients_new`.

`connectors/postgres-sink.json`

```json
{
  "name": "postgres-sink",
  "config": {
    "connector.class": "io.confluent.connect.jdbc.JdbcSinkConnector",
    "tasks.max": "1",
    "connection.url": "jdbc:postgresql://postgres-sink:5432/postgres",
    "connection.user": "sa",
    "connection.password": "DummyPass123!",
    "auto.create": "true",
    "auto.evolve": "true",
    "delete.enabled": "false",
    "topics": "SQLServer_Clients",
    "table.name.format": "clients_new"
  }
}
```

### Registrar los Conectores

Ejecutar el script para enviar las configuraciones a la API de Kafka Connect:

```bash
./init-connectors.bash
```

-----

## 🧪 Pruebas de Integración

Para validar que el pipeline funciona de extremo a extremo:

1.  **Insertar datos de prueba en SQL Server:**
    Se puede usar un cliente SQL o ejecutar el siguiente comando a través de Docker:

    ```sql
    INSERT INTO Clients (FirstName, LastName, Email) VALUES ('Juan', 'Perez', 'juan.perez@example.com');
    ```

2.  **Verificar que los datos llegaron a PostgreSQL:**
    Conéctarse a la base de datos de PostgreSQL y ejecuta una consulta:

    ```sql
    SELECT * FROM clients_new;
    ```

    *Se deberia ver el registro de 'Juan Perez' después de unos segundos (según el `poll.interval.ms`).*

-----

## 🔍 Verificación y Monitoreo

Usar la API REST de Kafka Connect para verificar el estado de los conectores:

```bash
# Listar todos los conectores activos
curl http://localhost:8083/connectors

# Verificar el estado del conector de origen
curl http://localhost:8083/connectors/sqlserver-source/status

# Verificar el estado del conector de destino
curl http://localhost:8083/connectors/postgres-sink/status
```

Para depuración, los logs del contenedor de Kafka Connect la principal fuente de información:

```bash
docker logs -f tarea-1-kafka-connect-1
```

-----

## 🔧 Problemas Comunes

  * **`InvalidReplicationFactorException`:** Ocurre si solo tienes un broker de Kafka. Asegúrate de que las variables de entorno para los topics internos de Connect (`CONNECT_CONFIG_STORAGE_REPLICATION_FACTOR`, etc.) estén configuradas en `1`.
  * **Puerto REST no accesible:** Revisa la variable `CONNECT_REST_ADVERTISED_HOST_NAME` en tu `docker-compose.yml` para asegurarte de que es accesible desde tu host.
  * **Datos no replicados:** Verifica que la columna `incrementing.column.name` existe y sus valores aumentan. Revisa también el `poll.interval.ms` por si la latencia es mayor de la esperada.

-----

## 🔒 Seguridad

  * **No subir credenciales:** Nunca incluyas contraseñas directamente en los archivos de configuración en un repositorio público.
  * **Usar `.env`:** Almacena credenciales y datos sensibles en un archivo `.env` y referéncialo desde tu `docker-compose.yml`.
  * **Limitar acceso:** En un entorno de producción, restringe el acceso a la API REST de Kafka Connect a través de un firewall o una red privada.

-----

## ⚡ Optimización y Buenas Prácticas

  * **Memoria de Kafka Connect:** Ajusta la memoria de la JVM para Kafka Connect usando la variable de entorno `HEAP_OPTS` para manejar cargas de trabajo más grandes.
  * **Ajuste del `poll.interval.ms`:** Un intervalo más bajo reduce la latencia pero aumenta la carga en la base de datos de origen. Ajústalo según tus necesidades.
  * **Monitoreo:** Implementa herramientas de monitoreo para supervisar el rendimiento (throughput, latencia) y configurar alertas para logs de errores.
