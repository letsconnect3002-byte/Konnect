import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final client = SupabaseClient(
    'https://gvzblxozqftheowpazvx.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2emJseG96cWZ0aGVvd3BhenZ4Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3OTMzMTA0NCwiZXhwIjoyMDk0OTA3MDQ0fQ.1nBIvX9ZEIChCu9pKW7mq2kW4-ZCCZYyQQHxxCiBUcs'
  );

  try {
    final response = await client
        .from('connection_notifications')
        .select('*, other_user:profiles!other_user_id(name), recipient:profiles!user_id(name)')
        .order('created_at', ascending: false)
        .limit(10);
    
    print("SUCCESS FETCH NOTIFICATIONS:");
    for (var n in response) {
      print("ID: ${n['id']}, user_id (${n['recipient']?['name']}): ${n['user_id']}, other_user_id (${n['other_user']?['name']}): ${n['other_user_id']}, type: ${n['type']}, note: ${n['note']}");
    }
  } catch (e) {
    print("ERROR FETCHING NOTIFICATIONS: $e");
  }
}
