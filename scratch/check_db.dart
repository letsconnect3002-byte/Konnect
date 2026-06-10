import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final client = SupabaseClient(
    'https://gvzblxozqftheowpazvx.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2emJseG96cWZ0aGVvd3BhenZ4Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3OTMzMTA0NCwiZXhwIjoyMDk0OTA3MDQ0fQ.1nBIvX9ZEIChCu9pKW7mq2kW4-ZCCZYyQQHxxCiBUcs'
  );

  try {
    final response = await client.from('profiles').select().limit(1).maybeSingle();
    print("SUCCESS FETCH PROFILES: $response");
    if (response != null) {
      print("COLUMNS: ${response.keys.toList()}");
    }
  } catch (e) {
    print("ERROR FETCHING PROFILES: $e");
  }
}
