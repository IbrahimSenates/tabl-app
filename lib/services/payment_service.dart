import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_functions/cloud_functions.dart';

class PaymentService {
  PaymentService._();
  static final PaymentService instance = PaymentService._();

  Future<bool> makePayment(double amount, String currency) async {
    try {
      // 1. Create Payment Intent
      final paymentIntentData = await _createPaymentIntent(
        (amount * 100).toInt(),
        currency,
      );

      if (paymentIntentData == null) {
        return false;
      }

      final clientSecret = paymentIntentData['clientSecret'];

      // 2. Initialize Payment Sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Tabl App',
        ),
      );

      // 3. Present Payment Sheet
      await Stripe.instance.presentPaymentSheet();

      return true;
    } catch (e) {
      debugPrint('Error making payment: $e');
      if (e is StripeException) {
        debugPrint('Stripe Error: ${e.error.localizedMessage}');
      }
      return false;
    }
  }

  Future<Map<String, dynamic>?> _createPaymentIntent(
    int amount,
    String currency,
  ) async {
    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        'createStripePayment',
      );
      final result = await callable.call(<String, dynamic>{
        'amount': amount,
        'currency': currency,
      });
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      debugPrint('Error creating payment intent: $e');
      return null;
    }
  }
}
