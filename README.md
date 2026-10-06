# Table 
- [**Docker based setup of Spark and Airflow**](#docker-based-setup-of-spark-and-airflow)
	- [Architecture](#architecture)
	- [Overview](#overview)
	- [Reference](#reference)
	- [Prerequisites](#prerequisites)
	- [Project Structure](#project-structure)
	- [Dockerfile](#dockerfile)
		- [Airflow Dockerfile](#airflow-dockerfile)
		- [Spark Application Dockerfile](#spark-application-dockerfile)
	- [Docker Compose](#docker-compose)
		- [Key Services](#key-services)
			- [Airflow Components](#airflow-components)
			- [Data Processing Components](#data-processing-components)
		- [One-Time Initialization Service](#one-time-initialization-service)
		- [Networks and Communication](#networks-and-communication)
		- [Volume Mappings](#volume-mappings)
	- [STEP1. Set Up Instructions](#step1-set-up-instructions)
	- [STEP2. Connection Setup on Airflow Web UI](#step2-connection-setup-on-airflow-web-ui)
		- [API](#api)
		- [MinIO](#minio)
		- [Postgres](#postgres)
	- [STEP3. Rebuilding Environment](#step3-rebuilding-environment)
	- [STEP4. Testing DAGs and Tasks](#step4-testing-dags-and-tasks)
		- [DAG: stock\_market](#dag-stock_market)
	- [Updating Code](#updating-code)

# **Docker based setup of Spark and Airflow**
This repository provides a containerized environment for Apache Spark and Apache Airflow using Docker, allowing you to quickly set up a development environment for data engineering tasks.

## Architecture
![Architecture](./doc/architecture.png)

## Overview
This setup enables you to
- Run Apache Airflow for workflow orchestration
- Execute Apache Spark jobs from Airflow
- Process data using Spark within Docker containers
- Test and develop DAGs in an isolated environment

## Reference
Original repository: https://github.com/ankit-rawani/spark-airflow-docker/tree/main

## Prerequisites
- Docker installed on your system
- Git for cloning the repository
- Basic understanding of Airflow and Spark concepts

## Project Structure
- `dags/`: Contains Airflow DAG definitions
- `logs/`: Airflow logs directory
- `plugins/`: Airflow plugins
- `config/`: Configuration files
- `spark/app/`: Spark applications code

## Dockerfile

The project uses two main Dockerfiles:

### Airflow Dockerfile

The `Dockerfile` in the root directory creates a customized Airflow image with all necessary dependencies:

- **Base Image**: Uses `apache/airflow:2.10.5-python3.12` as the foundation
- **Java Installation**: Installs OpenJDK 17 for Spark integration
- **Custom Dependencies**: 
  - Installs packages from `requirements.txt`
  - Adds specific Airflow provider packages for Spark and PostgreSQL
  - Includes PySpark for Spark job development

This image is used for all Airflow services (webserver, scheduler, init) and provides a consistent environment with all the tools needed for data workflow orchestration.

### Spark Application Dockerfile

The `spark/app/stock_transform/Dockerfile` builds a specialized Spark application image:

- **Base Image**: Uses `bitnami/spark:3.5.0` for Spark functionality
- **Python Setup**: Installs Python packages needed for data processing
- **Application Code**: Copies the stock transformation code to the container
- **Environment Configuration**: Sets up connection parameters for MinIO
- **Entry Point**: Configured to run the Spark job via `spark-submit`

This image is used when executing Spark jobs from Airflow DockerOperator, providing a dedicated environment for data processing tasks.

## Docker Compose 
This project uses Docker Compose to orchestrate multiple containers that work together to provide a complete data engineering environment. 
Below is an explanation of the key components in our `docker-compose.yaml` file.

### Key Services
The Docker Compose configuration includes the following services:

#### Airflow Components
- **airflow-webserver**: The Airflow UI, accessible at http://localhost:8080
- **airflow-scheduler**: Schedules and triggers workflow execution
- **airflow-init**: One-time initialization service (runs once to prepare the environment)
- **postgres**: Database for Airflow metadata

#### Data Processing Components
- **spark-master**: Spark master node, with UI at http://localhost:8082, job submission port at spark://spark-master:7077
- **spark-worker**: Spark worker node(s) that execute tasks, with UI at http://localhost:8081
- **minio**: S3-compatible object storage, with UI at http://localhost:9001, API at http://localhost:9000 
- **metabase**: Data visualization tool, accessible at http://localhost:3000
- **docker-proxy**: Allows Airflow to communicate with the Docker daemon

### One-Time Initialization Service

The `airflow-init` service is a special one-time service that:
- Initializes the Airflow database
- Creates the default admin user
- Sets up directory permissions
- Performs environment checks (memory, CPU, disk space)

This service is designed to run once and exit successfully. Other services depend on its successful completion before starting, indicated by the `condition: service_completed_successfully` parameter.

### Networks and Communication

All services are connected through the `default_net` bridge network, allowing them to communicate with each other using their service names as hostnames. 
For example, Spark services can be accessed at `spark-master:7077`.

### Volume Mappings

Key volume mappings include:
- `./dags:/opt/airflow/dags`: DAG definitions
- `./logs:/opt/airflow/logs`: Airflow logs
- `./plugins:/opt/airflow/plugins`: Airflow plugins
- `./spark/app:/usr/local/spark/app`: Spark applications
- `./spark/resources:/usr/local/spark/resources`: Spark resources
- `./plugins/data/minio:/data`: MinIO persistent storage
- `./test:/opt/airflow/test`: Unit Test

## STEP1. Set Up Instructions
To setup the project, follow these steps:

1. Clone this repository to your local machine
2. Run the following commands to initialize the environment:
```bash
# Create required directories and set permissions
mkdir -p ./dags ./logs ./plugins ./config
echo -e "AIRFLOW_UID=$(id -u)" > .env

# Pull Docker images from DockerHub
docker compose pull
# Build the new images from Dockerfile
docker compose build --no-cache

# Initialize Airflow database and users (airflow-init container run once and stopped after command completes)
docker compose up airflow-init
# Start all services (Run containers from images), because other services depend on airflow-init successful completion before starting 
docker compose up -d

# Build the stock-app image for Spark processing
docker build -t airflow/stock-app ./spark/app/stock_transform
```

After running these commands, you can access:
- Airflow webserver at http://localhost:8080 (default credentials: airflow/airflow)
- Spark master UI at http://localhost:8181

## STEP2. Connection Setup on Airflow Web UI
After starting the Airflow web server, set up the connection by navigating to Admin > Connections and creating a new connection with the following parameters:

### API
```bash
Connection Id: stock_api
Connection Type: HTTP
Host: https://query1.finance.yahoo.com/
Extra:
{
	"endpoint":"/v8/finance/chart/",
	"headers": {
		"Content-Type": "application/json",
		"User-Agent": "Mozilla/5.0",
		"Accept": "application/json"
	}
}
```
### MinIO
```bash
Connection Id: minio
Connection: Amazon Web Services
Access Key ID : minio
Secret Access Key: minio123
Extra:
{
  "endpoint_url": "http://minio:9000"
}
```
### Postgres
```bash
Connection Id: postgres
Connection: Postgres
Host: postgres
Login: airflow
Password: airflow
Port: 5432
```

## STEP3. Rebuilding Environment
If you need to completely rebuild your environment:

```bash
# Stop containers and remove volumes
docker-compose down --volumes --remove-orphans
# Remove unused volumes
docker volume prune -f
# Clean up unused Docker resources
docker system prune -f
```
```bash
# Pull Docker images from DockerHub
docker compose pull
# Build the new images from Dockerfile
docker compose build --no-cache

# Initialize Airflow database and users
docker compose up airflow-init
# Start all services (Run containers from images)
docker compose up

# Build the stock-app image for Spark processing
docker build -t airflow/stock-app ./spark/app/stock_transform
```

## STEP4. Testing DAGs and Tasks
To test your Airflow DAGs and individual tasks:

### DAG: stock_market
```bash
# Access the Airflow webserver container
docker exec -it stock-with-cicd-airflow-webserver-1 /bin/sh

# Test entire DAG
airflow dags test stock_market 2025-04-28

# Test individual tasks
airflow tasks test stock_market is_api_available 2025-04-28
airflow tasks test stock_market get_stock_prices 2025-04-28
airflow tasks test stock_market store_prices 2025-04-28
airflow tasks test stock_market format_prices 2025-04-28
airflow tasks test stock_market load_to_dw 2025-04-28
```

## Updating Code
When you make changes to your code (not related to Docker configuration):

```bash
# Restart specific services without rebuilding
docker compose restart airflow-webserver airflow-scheduler
```

This allows for faster development cycles by avoiding a full rebuild of the environment.

---
# 目錄
- [基於 Docker 搭建 Spark 和 Airflow 環境](#基於-docker-搭建-spark-和-airflow-環境)
	- [架構](#架構)
	- [概述](#概述)
	- [參考資料](#參考資料)
	- [前置條件](#前置條件)
	- [專案結構](#專案結構)
	- [Dockerfile](#dockerfile-1)
		- [Airflow Dockerfile](#airflow-dockerfile-1)
		- [Spark Application Dockerfile](#spark-application-dockerfile-1)
	- [Docker Compose](#docker-compose-1)
		- [主要服務](#主要服務)
			- [Airflow 元件](#airflow-元件)
			- [資料處理元件](#資料處理元件)


# **基於 Docker 搭建 Spark 和 Airflow 環境**
本儲存庫利用 Docker 為 Apache Spark 和 Apache Airflow 提供了一個容器化環境，協助您快速建置資料工程任務的開發環境。

## 架構
![架構圖](./doc/architecture.png)

## 概述
透過此配置，您可以：
- 執行 Apache Airflow 進行工作流程編排
- 從 Airflow 執行 Apache Spark 任務
- 在 Docker 容器內，使用 Spark 處理數據
- 在隔離環境中開發和測試 DAG

## 參考資料
原始儲存庫：https://github.com/ankit-rawani/spark-airflow-docker/tree/main

## 前置條件
- 系統中已安裝 Docker
- 已安裝 Git（用於複製儲存庫）
- 對 Airflow 和 Spark 的基本概念有一定了解

## 專案結構
- `dags/`: 包含 Airflow DAG 定義
- `logs/`: Airflow 日誌目錄
- `plugins/`: Airflow 插件
- `config/`: 配置檔
- `spark/app/`: Spark App 程式程式碼

## Dockerfile

本專案主要使用兩個 Dockerfile：

### Airflow Dockerfile

根目錄下的 `Dockerfile` 用於建立包含所有必要依賴的客製化 Airflow Image：

- **基礎 Image**：基於 `apache/airflow:2.10.5-python3.12` 構建
- **Java 安裝**：安裝 OpenJDK 17 以整合 Spark
- **自訂依賴**：
- 安裝 `requirements.txt` 中所列的套件
- 為 Spark 和 PostgreSQL 新增特定的 Airflow 提供者套件（provider packages）
- 包含用於 Spark 任務開發的 PySpark

此 Image 適用於所有 Airflow 服務（webserver、scheduler、init），並提供一個一致的環境，包含資料工作流程編排所需的所有工具。

### Spark Application Dockerfile

`spark/app/stock_transform/Dockerfile` 用來建立一個專用的 Spark App Image：

- **基礎 Image**：使用 `bitnami/spark:3.5.0` 提供 Spark 運作環境
- **Python 設定**：安裝資料處理所需的 Python 套件
- **Application**：將股票資料轉換程式複製到容器中
- **環境配置**：設定 MinIO 的連線參數
- **Entry Point**：透過 `spark-submit` 執行 Spark job

此 Image 用於透過 Airflow 的 DockerOperator 執行 Spark job，為資料處理任務提供專用環境。

## Docker Compose
本專案使用 Docker Compose 編排多個容器，協同建置完整的資料工程環境。
以下是 `docker-compose.yaml` 檔案中主要元件的說明。

### 主要服務
Docker Compose 配置包含以下服務：

#### Airflow 元件
- **airflow-webserver**：Airflow Web 介面，存取位址：http://localhost:8080
- **airflow-scheduler**：負責調度和觸發工作流程執行
- **airflow-init**：一次性初始化服務（僅運行一次以準備環境）
- **postgres**：Airflow metadata 儲存資料庫

#### 資料處理元件
- **spark-master**：Spark Master Node，UI 位址：http://localhost:8082，job 提交 port：spark://spark-master:7077
- **spark-worker**：執行任務的 Spark Worker Node，UI 位址：http://localhost:8081
- **minio**：相容 S3 的物件存儲，UI 位址：http://localhost:9001，API 位址：http://localhost:9000
- **metabase**：資料視覺化工具，存取位址：http://localhost:3000
- **docker-proxy**：允許 Airflow 與 Docker daemon 進行通訊


## 一次初始化服務
`airflow-init` 服務是一項特殊的一次性服務，其功能包括：
- 初始化 Airflow 資料庫
- 建立預設管理員使用者
- 設定目錄權限
- 執行環境檢查（記憶體、CPU、磁碟空間）

該服務設計為僅運行一次並成功退出。其他服務需等待其成功完成後方可啟動，具體啟動條件由 `condition: service_completed_successfully` 參數進行控制。

### 網路與通信

所有服務均透過 bridge network: `default_net` 連接，讓它們可以使用服務名稱作為主機名稱進行相互通訊。
例如，可以透過 `spark-master:7077` 存取 Spark 服務。

### Volume 映射

主要的 Volume 映射包括：
- `./dags:/opt/airflow/dags`：DAG 定義
- `./logs:/opt/airflow/logs`：Airflow 日誌
- `./plugins:/opt/airflow/plugins`：Airflow 插件
- `./spark/app:/usr/local/spark/app`：Spark 應用程式
- `./spark/resources:/usr/local/spark/resources`：Spark 資源
- `./plugins/data/minio:/data`：MinIO 持久化存儲
- `./test:/opt/airflow/test`：單元測試

## 步驟 1. 設定說明
請依照以下步驟設定項目：

1. 將此儲存庫複製到本機
2. 執行以下命令以初始化環境：
```bash
# 建立必要的目錄並設定權限
mkdir -p ./dags ./logs ./plugins ./config
echo -e "AIRFLOW_UID=$(id -u)" > .env

# 從 DockerHub 拉取 Docker Image
docker compose pull
# 根據 Dockerfile 建置新 Image
docker compose build --no-cache

# 初始化 Airflow 資料庫和使用者（airflow-init 容器僅運行一次，指令完成後即停止）
docker compose up airflow-init
# 啟動所有服務（基於 Image 運行容器），因為其他服務需等待 airflow-init 成功完成後才能啟動
docker compose up -d

# 建立用於 Spark 處理的 stock-app Image
docker build -t airflow/stock-app ./spark/app/stock_transform
```

運行這些命令後，您可以訪問：
- Airflow webserver：http://localhost:8080 （預設憑證：airflow/airflow）
- Spark Master UI：http://localhost:8181

## 步驟 2. 在 Airflow Web UI 上設定連線
啟動 Airflow Webserver，請導覽至 **Admin > Connections**（管理 > 連線）並建立新連線，具體參數如下：


### API
```bash
Connection Id: stock_api
Connection Type: HTTP
Host: https://query1.finance.yahoo.com/
Extra:
{
	"endpoint":"/v8/finance/chart/",
	"headers": {
		"Content-Type": "application/json",
		"User-Agent": "Mozilla/5.0",
		"Accept": "application/json"
	}
}
```
### MinIO
```bash
Connection Id: minio
Connection: Amazon Web Services
Access Key ID : minio
Secret Access Key: minio123
Extra:
{
  "endpoint_url": "http://minio:9000"
}
```
### Postgres
```bash
Connection Id: postgres
Connection: Postgres
Host: postgres
Login: airflow
Password: airflow
Port: 5432
```

## 步驟 3. 重建環境
如果需要完全重建環境：

```bash
# 停止容器並移除 volumes 
docker-compose down --volumes --remove-orphans
# 移除未使用的 volumes
docker volume prune -f
# 清理未使用的 Docker 資源
docker system prune -f
```
```bash
# 從 DockerHub 拉取 Docker Image
docker compose pull
# 根據 Dockerfile 建置新 Image
docker compose build --no-cache

# 初始化 Airflow 資料庫和使用者
docker compose up airflow-init
# 啟動所有服務（基於 Image 運行容器）
docker compose up

# 建立用於 Spark 處理的 stock-app Image
docker build -t airflow/stock-app ./spark/app/stock_transform
```

## 步驟 4. 測試 DAG 和任務
測試 Airflow DAG 及各個任務：

### DAG: stock_market
```bash
# 進入 Airflow webserver 容器
docker exec -it stock-with-cicd-airflow-webserver-1 /bin/sh

# 測試整個 DAG
airflow dags test stock_market 2025-04-28

# 測試單一任務
airflow tasks test stock_market is_api_available 2025-04-28
airflow tasks test stock_market get_stock_prices 2025-04-28
airflow tasks test stock_market store_prices 2025-04-28
airflow tasks test stock_market format_prices 2025-04-28
airflow tasks test stock_market load_to_dw 2025-04-28
```

## 更新程式碼
當修改程式碼（且不涉及 Docker 配置變更）時：

```bash
# 重新啟動特定服務，無需重新建構
docker compose restart airflow-webserver airflow-scheduler
```

這樣可以避免完全重建環境，進而加快開發週期。