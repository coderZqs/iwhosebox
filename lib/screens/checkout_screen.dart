import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/cart.dart';
import '../config/shopify_config.dart';

class CheckoutScreen extends StatefulWidget {
  final List<CartItem> cartItems;

  const CheckoutScreen({super.key, required this.cartItems});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late final String _cartUrl;

  @override
  void initState() {
    super.initState();
    final items = widget.cartItems.map((item) {
      final variantId = item.variant.id.split('/').last;
      return '$variantId:${item.quantity}';
    }).toList();
    _cartUrl = '${ShopifyConfig.storeUrl}/cart/${items.join(',')}';
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return _buildWebCheckout();
    return _buildMobileWebView();
  }

  Widget _buildWebCheckout() {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout'), elevation: 0),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shopping_cart_checkout, size: 80, color: Colors.blue),
              const SizedBox(height: 24),
              const Text(
                'Continue checkout in browser',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => launchUrl(Uri.parse(_cartUrl),
                    mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open Shopify Checkout', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileWebView() {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(_cartUrl));

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout'), elevation: 0),
      body: WebViewWidget(controller: controller),
    );
  }
}