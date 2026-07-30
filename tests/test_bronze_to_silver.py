from fixtures import raw_orders

from pyspark.sql import functions as F


def test_remove_null_orders(spark):

    df = spark.createDataFrame(raw_orders())

    silver = df.filter(

        F.col("order_id").isNotNull()

    )

    assert silver.count() == 2

def test_no_duplicate_orders(spark):

    df = spark.createDataFrame(raw_orders())

    duplicate_count = (

        df.groupBy("order_id")

        .count()

        .filter("count > 1")

        .count()

    )

    assert duplicate_count == 0

def test_order_amount(spark):

    df = spark.createDataFrame(raw_orders())

    silver = df.withColumn(

        "order_amount",

        F.col("quantity") *

        F.col("unit_price")

    )

    assert silver.first()["order_amount"] == 1000