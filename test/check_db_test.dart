import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('inspect specific notification note runtimeType', () async {
    final client = SupabaseClient(
      'https://gvzblxozqftheowpazvx.supabase.co',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2emJseG96cWZ0aGVvd3BhenZ4Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3OTMzMTA0NCwiZXhwIjoyMDk0OTA3MDQ0fQ.1nBIvX9ZEIChCu9pKW7mq2kW4-ZCCZYyQQHxxCiBUcs'
    );

    try {
      final n = await client
          .from('connection_notifications')
          .select('note')
          .eq('id', '5b0cdd39-e465-400a-8a7e-df353e0f557d')
          .maybeSingle();
      
      print("SUCCESS FETCH SPECIFIC NOTIFICATION:");
      if (n != null) {
        final noteVal = n['note'];
        print("Note Value: $noteVal, RuntimeType: ${noteVal.runtimeType}");
      } else {
        print("Notification not found");
      }
    } catch (e) {
      print("ERROR: $e");
    }
  });
}
