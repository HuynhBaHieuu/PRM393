import 'package:flutter_test/flutter_test.dart';

import 'package:all_fits/data/remote/supabase_backend.dart';

void main() {
  test('Supabase is used only when both URL and key are set', () {
    expect(
      supabaseConfigFrom(
        '{"SUPABASE_URL": " https://x.supabase.co ", '
        '"SUPABASE_PUBLISHABLE_KEY": "key"}',
      ),
      (url: 'https://x.supabase.co', key: 'key'),
    );
    expect(
      supabaseConfigFrom('{"SUPABASE_URL": "https://x.supabase.co"}'),
      isNull,
    );
    expect(
      supabaseConfigFrom(
        '{"SUPABASE_URL": "", "SUPABASE_PUBLISHABLE_KEY": ""}',
      ),
      isNull,
    );
    expect(supabaseConfigFrom('{}'), isNull);
    expect(supabaseConfigFrom('not json'), isNull);
  });
}
