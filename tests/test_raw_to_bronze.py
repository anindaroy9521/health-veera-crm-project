from fixtures import raw_orders


def test_raw_to_bronze(spark):

    df = spark.createDataFrame(raw_orders())

    assert df.count() == 3

    assert "order_id" in df.columns

    assert "customer_id" in df.columns

    assert "product_id" in df.columns

def test_null_order_exists(spark):

    df = spark.createDataFrame(raw_orders())

    null_count = df.filter(df.order_id.isNull()).count()

    assert null_count == 1