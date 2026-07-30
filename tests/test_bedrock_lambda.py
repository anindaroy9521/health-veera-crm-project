import importlib

bedrock_module = importlib.import_module("lambda.bedrock_processor_function")
lambda_handler = bedrock_module.lambda_handler

def test_bedrock():

    event = {

        "dq_score":95

    }

    response = lambda_handler(event,None)

    assert response is not None