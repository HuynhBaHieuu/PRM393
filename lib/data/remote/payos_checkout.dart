import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart' show FunctionsClient;
import 'package:url_launcher/url_launcher.dart';

import 'package:all_fits/core/errors/app_exceptions.dart';

/// A payOS payment link for one Premium purchase.
typedef PayOSOrder = ({int orderCode, Uri checkoutUrl});

enum PaymentStatus {
  pending,
  paid,
  cancelled,
  expired;

  static PaymentStatus parse(Object? value) => switch (value) {
    'PAID' => paid,
    'CANCELLED' => cancelled,
    'EXPIRED' => expired,
    // PENDING, PROCESSING and anything new: keep waiting.
    _ => pending,
  };
}

/// Buys Premium through payOS. The `payos` Supabase Edge Function holds the
/// payOS keys and starts Premium on the server once the payment arrives;
/// this only creates payment links and asks how they are going.
class PayOSCheckout {
  const PayOSCheckout(this._functions);

  final FunctionsClient _functions;

  static const String _function = 'payos';

  Future<PayOSOrder> create() async {
    final data = await _call('create');
    final url = Uri.tryParse('${data['checkoutUrl']}');
    final orderCode = data['orderCode'];
    if (url == null || orderCode is! int) {
      throw const PaymentException('Payment could not be started.');
    }
    return (orderCode: orderCode, checkoutUrl: url);
  }

  Future<PaymentStatus> status(int orderCode) async => PaymentStatus.parse(
    (await _call('status', {'orderCode': orderCode}))['status'],
  );

  /// Opens the payOS page in the browser, where banking apps can be opened.
  Future<void> open(Uri checkoutUrl) async {
    if (!await launchUrl(checkoutUrl, mode: LaunchMode.externalApplication)) {
      throw const PaymentException('Could not open the payment page.');
    }
  }

  Future<Map<String, dynamic>> _call(String route, [Object? body]) async {
    try {
      final response = await _functions.invoke('$_function/$route', body: body);
      if (response.data case final Map<String, dynamic> data) return data;
    } catch (error) {
      developer.log('payOS $route failed', name: 'payments', error: error);
    }
    throw const PaymentException(
      'Payment service is unavailable. Please try again.',
    );
  }
}
