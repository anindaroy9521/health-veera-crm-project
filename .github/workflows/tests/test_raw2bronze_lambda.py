import json

import importlib

raw2bronze_module = importlib.import_module("lambda.raw2bronze_processor_function")
lambda_handler = raw2bronze_module.lambda_handler


def test_lambda_response():

    event = {

        "Records": []

    }

    response = lambda_handler(event, None)

    assert response is not None