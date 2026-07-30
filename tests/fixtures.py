from pyspark.sql import Row


def raw_orders():

    return [

        Row(
            order_id="1001",
            customer_id="C101",
            product_id="P100",
            quantity=2,
            unit_price=500.0,
            order_status="completed",
            order_date="2026-03-20"
        ),

        Row(
            order_id="1002",
            customer_id="C102",
            product_id="P101",
            quantity=3,
            unit_price=250.0,
            order_status="completed",
            order_date="2026-03-20"
        ),

        Row(
            order_id=None,
            customer_id="C103",
            product_id="P102",
            quantity=1,
            unit_price=100,
            order_status="completed",
            order_date="2026-03-20"
        )

    ]