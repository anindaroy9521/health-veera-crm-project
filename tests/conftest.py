import pytest
from moto import mock_aws

from pyspark.sql import SparkSession

@pytest.fixture
def aws_credentials():

    with mock_aws():
        yield

@pytest.fixture(scope="session")
def spark():

    spark = (

        SparkSession.builder
        .master("local[*]")
        .appName("pytest")

        .getOrCreate()

    )

    yield spark

    spark.stop()