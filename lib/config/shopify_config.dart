/// Shopify Storefront API Configuration
class ShopifyConfig {
  // Your Shopify store domain (without https://)
  static const String storeDomain = 'xrctgi-v1.myshopify.com';
  
  // Storefront API version
  static const String apiVersion = '2024-10';
  
  // Public Storefront API Token (safe for app distribution, configure via env or replace)
  static const String storefrontAccessToken = String.fromEnvironment(
    'SHOPIFY_STOREFRONT_TOKEN',
    defaultValue: 'YOUR_SHOPIFY_STOREFRONT_ACCESS_TOKEN',
  );
  
  // Admin API Token (server-side only, DO NOT commit real token to repo)
  static const String adminAccessToken = String.fromEnvironment(
    'SHOPIFY_ADMIN_TOKEN',
    defaultValue: 'YOUR_SHOPIFY_ADMIN_ACCESS_TOKEN',
  );
  
  // GraphQL endpoint
  static String get graphqlEndpoint =>
      'https://$storeDomain/api/$apiVersion/graphql.json';
  
  // Store URL for WebView checkout
  static String get storeUrl => 'https://$storeDomain';
  
  // Admin API REST endpoint
  static String get adminEndpoint =>
      'https://$storeDomain/admin/api/$apiVersion';
}
