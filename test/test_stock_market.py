import pytest
import json
from unittest.mock import MagicMock 
from airflow.sensors.base import PokeReturnValue
from airflow.hooks.base import BaseHook

# 儲存原始的 get_connection 函數
original_get_connection = BaseHook.get_connection
# 簡單替換為一個始終返回 MagicMock 的函數
BaseHook.get_connection = MagicMock(return_value=MagicMock())
# 現在安全地導入 DAG
from plugins.stock_market.tasks import _get_stock_prices, _store_prices, _get_formatted_csv
from dags.stock_market import stock_market   

"""
Creates a mock for the Yahoo Finance API connection.
This fixture simulates the connection object returned by Airflow's BaseHook.
"""
@pytest.fixture
def fake_stock_api_conn(mocker):
    return mocker.MagicMock(
        host='https://query1.finance.yahoo.com/',
        extra_dejson={
            'endpoint': '/v8/finance/chart/',
            'headers': {
                'Content-Type': 'application/json',
                'User-Agent': 'Mozilla/5.0',
                'Accept': 'application/json'
            }
        }
    )

# Fixture to mock the MinIO connection
@pytest.fixture
def fake_minio_conn(mocker):
    return mocker.MagicMock(
        login='minio',
        password='minio123',
        extra_dejson={'endpoint_url': 'http://minio:9000'}
    )

# Fixture to provide sample stock data response
@pytest.fixture
def stock_response():
    return {
        "chart": {
            "result": [{
                "meta": {"symbol": "NVDA"},
                "timestamp": [1625097600, 1625184000],
                "indicators": {
                    "quote": [{
                        "close": [100.0, 102.5],
                        "open": [99.0, 100.5]
                    }]
                }
            }]
        }
    }

"""
測試函數 the is_api_available: checks if the Yahoo Finance API is accessible.

This test mocks:
1. The BaseHook.get_connection to return our fake API connection
2. The requests.get response to simulate a successful API connection

It then verifies that:
- The PokeReturnValue indicates success (is_done=True)
- The correct API URL is returned via xcom
- The request was made with the correct headers
"""
def test_is_api_available(mocker, fake_stock_api_conn):
    # 1. Mock 行為: 設置模擬對象
    # 1-1. 模擬 BaseHook.get_connection
    mocker.patch('dags.stock_market.BaseHook.get_connection', return_value=fake_stock_api_conn)
    # 1-2. 模擬 requests.get
    mock_response = mocker.MagicMock()
    mock_response.json.return_value = {"finance": {"result": None}}
    mock_get = mocker.patch("dags.stock_market.requests.get", return_value=mock_response)
    
    # 執行測試
    dag = stock_market()
    task = dag.task_dict['is_api_available']  # is_api_available
    result = task.python_callable()
    
    # 驗證結果
    expected_url = f"{fake_stock_api_conn.host}{fake_stock_api_conn.extra_dejson['endpoint']}" # 'https://query1.finance.yahoo.com//v8/finance/chart/'
    assert result.is_done is True
    assert result.xcom_value == expected_url
    mock_get.assert_called_once_with(
        expected_url, 
        headers=fake_stock_api_conn.extra_dejson['headers']
    )

"""
測試函數 _get_stock_prices: retrieves stock price data from Yahoo Finance API.

This test mocks:
1. The BaseHook.get_connection to return our fake API connection
2. The requests.get response to return sample stock data

It then verifies that:
- The function returns a string (serialized JSON)
- The data contains the correct stock symbol
"""
def test_get_stock_prices(mocker, fake_stock_api_conn, stock_response):
    # 設置模擬對象
    mocker.patch('plugins.stock_market.tasks.BaseHook.get_connection', return_value=fake_stock_api_conn)
    mock_get = mocker.patch('plugins.stock_market.tasks.requests.get')
    mock_get.return_value.json.return_value = stock_response
    
    # 執行測試
    result = _get_stock_prices("https://query1.finance.yahoo.com/v8/finance/chart/", "NVDA")
    
    # 驗證結果
    assert isinstance(result, str)
    result_json = json.loads(result)
    assert result_json["meta"]["symbol"] == "NVDA"

"""
測試函數: _store_prices function which stores stock data in MinIO.

This test mocks:
1. The BaseHook.get_connection to return our fake MinIO connection
2. The Minio client and its methods

It then verifies that:
- The function returns the correct bucket path
- make_bucket was called if the bucket doesn't exist
- put_object was called to store the data
"""
def test_store_prices(mocker, fake_minio_conn):
    # 設置模擬對象
    mocker.patch('plugins.stock_market.tasks.BaseHook.get_connection', return_value=fake_minio_conn)
    mock_minio = mocker.patch('plugins.stock_market.tasks.Minio')
    mock_minio_instance = mocker.MagicMock()
    mock_minio_instance.bucket_exists.return_value = False
    mock_minio_instance.put_object.return_value = mocker.MagicMock(bucket_name="stock-market")
    mock_minio.return_value = mock_minio_instance
    
    # 準備測試數據
    stock_data = json.dumps({"meta": {"symbol": "NVDA"}, "data": []})
    
    # 執行測試
    result = _store_prices(stock_data)
    
    # 驗證結果
    assert "stock-market/NVDA" in result
    mock_minio_instance.make_bucket.assert_called_once_with("stock-market")
    mock_minio_instance.put_object.assert_called_once()

def test_format_prices_docker_operator(mocker):

    dag = stock_market()
    task = dag.task_dict['format_prices']

    # 驗證基本屬性
    assert task.image == 'airflow/stock-app'
    assert task.container_name == 'format_prices'
    assert task.docker_url == 'tcp://docker-proxy:2375'
    assert task.network_mode == 'stock-with-cicd_default_net'
    assert task.environment['SPARK_APPLICATION_ARGS'] == '{{ ti.xcom_pull(task_ids="store_prices") }}'

"""
測試函數: _get_formatted_csv function which retrieves formatted CSV files from MinIO.

This test mocks:
1. The BaseHook.get_connection to return our fake MinIO connection
2. The Minio client and its list_objects method

It then verifies that:
- The function returns the correct CSV file path
"""
def test_get_formatted_csv(mocker, fake_minio_conn):
    # 設置模擬對象
    mocker.patch('plugins.stock_market.tasks.BaseHook.get_connection', return_value=fake_minio_conn)
    mock_minio = mocker.patch('plugins.stock_market.tasks.Minio')
    mock_minio_instance = mocker.MagicMock()
    mock_minio_instance.list_objects.return_value = [
        mocker.MagicMock(object_name="NVDA/formatted_prices/data.csv")
    ]
    mock_minio.return_value = mock_minio_instance
    
    # 執行測試
    result = _get_formatted_csv("stock-market/NVDA")
    
    # 驗證結果
    assert result == "NVDA/formatted_prices/data.csv"