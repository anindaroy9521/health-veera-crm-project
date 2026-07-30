import importlib

# importlib is used because 'lambda' is a reserved keyword and cannot be used
# in a normal from ... import statement even if the package folder is named 'lambda'
raw2sqs_module = importlib.import_module('lambda.raw2SQS_processor_function')
lambda_handler = raw2sqs_module.lambda_handler


def test_consumer_lambda():
    event = {"Records": []}
    response = lambda_handler(event, None)
    assert response is not None