from fixtures import raw_orders

from pyspark.sql import functions as F


def test_gold_sales(spark):

    df = spark.createDataFrame(raw_orders())

    silver = (

        df

        .filter(F.col("order_id").isNotNull())

        .withColumn(

            "order_amount",

            F.col("quantity") *

            F.col("unit_price")

        )

    )

    gold = (

        silver

        .groupBy("order_date")

        .agg(

            F.sum("order_amount")

            .alias("sales")

        )

    )

    assert gold.first()["sales"] == 1750

def test_distinct_products(spark):

    df = spark.createDataFrame(raw_orders())

    assert (

        df.select("product_id")

        .distinct()

        .count()

    ) == 3