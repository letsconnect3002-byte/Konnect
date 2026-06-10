import urllib.request
import json

url = "https://gvzblxozqftheowpazvx.supabase.co/rest/v1/"
req = urllib.request.Request(url)
req.add_header("apikey", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2emJseG96cWZ0aGVvd3BhenZ4Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3OTMzMTA0NCwiZXhwIjoyMDk0OTA3MDQ0fQ.1nBIvX9ZEIChCu9pKW7mq2kW4-ZCCZYyQQHxxCiBUcs")

try:
    with urllib.request.urlopen(req) as response:
        data = json.loads(response.read().decode())
        paths = data.get("paths", {})
        rpcs = [path for path in paths.keys() if path.startswith("/rpc/")]
        print("EXPOSED RPCS:")
        for rpc in rpcs:
            print(rpc)
except Exception as e:
    print("Error:", e)
