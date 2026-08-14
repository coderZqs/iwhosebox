import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/shopify_config.dart';
import '../models/product.dart';

/// Shopify Storefront API Service
class ShopifyService {
  final String _endpoint = ShopifyConfig.graphqlEndpoint;
  final Map<String, String> _headers = {
    'X-Shopify-Storefront-Access-Token': ShopifyConfig.storefrontAccessToken,
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// Execute GraphQL query
  Future<Map<String, dynamic>> _query(String query,
      [Map<String, dynamic>? variables]) async {
    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: _headers,
        body: jsonEncode({
          'query': query,
          'variables': variables ?? {},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['errors'] != null) {
          throw Exception(
            data['errors'].map((e) => e['message']).join(', '),
          );
        }
        return data['data'] as Map<String, dynamic>;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Shopify API Error: $e');
    }
  }

  /// Fetch products with pagination
  Future<List<Product>> getProducts({
    int first = 20,
    String? after,
    String? collectionHandle,
    String? searchQuery,
    String? sortKey,
  }) async {
    String filterClause = '';
    if (collectionHandle != null) {
      filterClause = ', query: "collection:$collectionHandle"';
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      filterClause = ', query: "$searchQuery"';
    }

    final query = '''
    query GetProducts(\$first: Int!, \$after: String) {
      products(first: \$first, after: \$after$filterClause${sortKey != null ? ', sortKey: $sortKey' : ''}) {
        pageInfo {
          hasNextPage
          endCursor
        }
        edges {
          node {
            id
            title
            handle
            description
            tags
            featuredImage {
              url
              altText
            }
            images(first: 5) {
              edges {
                node {
                  url
                  altText
                  width
                  height
                }
              }
            }
            priceRange {
              minVariantPrice {
                amount
                currencyCode
              }
              maxVariantPrice {
                amount
                currencyCode
              }
            }
            variants(first: 20) {
              edges {
                node {
                  id
                  title
                  price {
                    amount
                    currencyCode
                  }
                  compareAtPrice {
                    amount
                    currencyCode
                  }
                  availableForSale
                  image {
                    url
                  }
                }
              }
            }
          }
        }
      }
    }
    ''';

    final data = await _query(query, {
      'first': first,
      'after': after,
    });

    final productsData = data['products'] as Map<String, dynamic>;
    final edges = productsData['edges'] as List<dynamic>;
    return edges
        .map((e) => Product.fromJson(e['node'] as Map<String, dynamic>))
        .toList();
  }

  /// Fetch single product by handle
  Future<Product> getProductByHandle(String handle) async {
    final query = '''
    query GetProduct(\$handle: String!) {
      productByHandle(handle: \$handle) {
        id
        title
        handle
        description
        descriptionHtml
        tags
        featuredImage {
          url
          altText
        }
        images(first: 10) {
          edges {
            node {
              url
              altText
              width
              height
            }
          }
        }
        priceRange {
          minVariantPrice {
            amount
            currencyCode
          }
          maxVariantPrice {
            amount
            currencyCode
          }
        }
        variants(first: 50) {
          edges {
            node {
              id
              title
              price {
                amount
                currencyCode
              }
              compareAtPrice {
                amount
                currencyCode
              }
              availableForSale
              image {
                url
              }
              selectedOptions {
                name
                value
              }
            }
          }
        }
        options {
          name
          values
        }
      }
    }
    ''';

    final data = await _query(query, {'handle': handle});
    return Product.fromJson(
      data['productByHandle'] as Map<String, dynamic>,
    );
  }

  /// Fetch collections (categories)
  Future<List<Map<String, dynamic>>> getCollections({int first = 20}) async {
    final query = '''
    query GetCollections(\$first: Int!) {
      collections(first: \$first) {
        edges {
          node {
            id
            title
            handle
            description
            image {
              url
              altText
            }
          }
        }
      }
    }
    ''';

    final data = await _query(query, {'first': first});
    final collections = data['collections']['edges'] as List<dynamic>;
    return collections
        .map((e) => e['node'] as Map<String, dynamic>)
        .toList();
  }

  /// Create a checkout URL for cart items
  Future<String> createCheckout(List<Map<String, dynamic>> items) async {
    final lineItems = items.map((item) {
      return '''
      {
        variantId: "${item['variantId']}",
        quantity: ${item['quantity']}
      }
      ''';
    }).join(',');

    final query = '''
    mutation CreateCheckout {
      checkoutCreate(input: {
        lineItems: [$lineItems]
      }) {
        checkout {
          id
          webUrl
        }
        checkoutUserErrors {
          code
          field
          message
        }
      }
    }
    ''';

    final data = await _query(query);
    final checkout = data['checkoutCreate']['checkout'];
    if (checkout == null) {
      throw Exception('Failed to create checkout');
    }
    return checkout['webUrl'] as String;
  }

  /// Search products
  Future<List<Product>> searchProducts(String query) async {
    return getProducts(searchQuery: query);
  }
}
