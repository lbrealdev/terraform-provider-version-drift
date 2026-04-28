# Lambda Function Testing Guide

This guide explains how to test the Lambda function in the `lambda-runtime-error` solution.

## Lambda Function Response

The Lambda function now returns a message that includes the Python runtime version:
```
Hello from test lambda using Python 3.12.x
```

The version is dynamically detected using Python's `sys.version_info`, ensuring it always displays the actual runtime version in use.

## Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform resources deployed (run `just apply lambda-runtime-error`)
3. The Lambda function must be deployed and active

## Quick Test Commands

### Using AWS CLI

```bash
# Test the lambda function
aws lambda invoke \
  --function-name test-lambda \
  --payload '{"key": "value"}' \
  response.json

# View the response
cat response.json

# Clean up
rm response.json
```

### Interactive Testing

```bash
# Use AWS CLI to invoke with sample events
aws lambda invoke \
  --function-name test-lambda \
  --cli-binary-format raw-in-base64-out \
  --payload '{"test": "event"}' \
  --log-type Tail \
  response.json

# Get detailed response with logs
aws lambda get-function \
  --function-name test-lambda
```

## Testing in Different Scenarios

### Test with Empty Payload

```bash
aws lambda invoke \
  --function-name test-lambda \
  response.json

# Expected response:
# {"statusCode": 200, "body": "Hello from test lambda using Python 3.12.x"}
cat response.json
```

### Test with JSON Payload

```bash
aws lambda invoke \
  --function-name test-lambda \
  --payload '{"message": "Hello Lambda", "count": 42}' \
  response.json
```

### Test with Synchronous Invocation

```bash
aws lambda invoke \
  --function-name test-lambda \
  --cli-binary-format raw-in-base64-out \
  --payload '{"test": "event"}' \
  --log-type Tail \
  --query 'LogResult' \
  --output text \
  | base64 -d \
  response.json
```

## Monitoring the Lambda

```bash
# Get function configuration
aws lambda get-function-configuration \
  --function-name test-lambda

# List recent invocations
aws lambda get-async-invoke-config \
  --function-name test-lambda

# View CloudWatch Logs
aws logs tail /aws/lambda/test-lambda --follow
```

## Troubleshooting

### If Lambda function is not found:

```bash
# Check Lambda function status
aws lambda list-functions --query "Functions[?FunctionName=='test-lambda']"

# Verify deployment
just show lambda-runtime-error
```

### If invocation fails:

1. Check function status with `aws lambda get-function --function-name test-lambda`
2. Review CloudWatch Logs with `aws logs tail /aws/lambda/test-lambda`
3. Verify IAM role permissions

### Invalid Request Format

The lambda expects a standard Lambda event format. Test with:
- Simple JSON: `{"test": "value"}`
- Empty object: `{}`
- No payload (invoke without --payload)

## Integration Testing Workflow

1. **Deploy resources**:
   ```bash
   just init lambda-runtime-error
   just plan lambda-runtime-error -var="region=us-east-1"
   just apply lambda-runtime-error -var="region=us-east-1"
   ```

2. **Test the function**:
   ```bash
   aws lambda invoke \
     --function-name test-lambda \
     --payload '{}' \
     response.json && cat response.json
   ```

3. **Verify deployment**:
   ```bash
   aws lambda get-function --function-name test-lambda
   aws logs tail /aws/lambda/test-lambda --follow
   ```

4. **Clean up when done**:
   ```bash
   just destroy lambda-runtime-error -var="region=us-east-1"
   rm response.json
   ```