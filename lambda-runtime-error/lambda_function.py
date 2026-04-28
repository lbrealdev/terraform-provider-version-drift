def handler(event, context):
    import sys
    python_version = sys.version_info
    version_str = f"{python_version.major}.{python_version.minor}.{python_version.micro}"
    return {"statusCode": 200, "body": f"Hello from test lambda using Python {version_str}"}
