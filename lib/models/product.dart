/// Product Model - parsed from Shopify Storefront API response
class Product {
  final String id;
  final String title;
  final String handle;
  final String? description;
  final String? featuredImage;
  final List<ProductImage> images;
  final List<ProductVariant> variants;
  final double minPrice;
  final double maxPrice;
  final String currencyCode;
  final List<String> tags;
  final String? collectionTitle;

  Product({
    required this.id,
    required this.title,
    required this.handle,
    this.description,
    this.featuredImage,
    this.images = const [],
    this.variants = const [],
    required this.minPrice,
    required this.maxPrice,
    this.currencyCode = 'USD',
    this.tags = const [],
    this.collectionTitle,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final imagesEdges = json['images']?['edges'] as List<dynamic>? ?? [];
    final variantsEdges = json['variants']?['edges'] as List<dynamic>? ?? [];
    
    final images = imagesEdges.map((e) {
      final node = e['node'] as Map<String, dynamic>;
      return ProductImage(
        url: node['url'] as String? ?? '',
        altText: node['altText'] as String?,
        width: (node['width'] as num?)?.toInt(),
        height: (node['height'] as num?)?.toInt(),
      );
    }).toList();

    final variants = variantsEdges.map((e) {
      final node = e['node'] as Map<String, dynamic>;
      return ProductVariant(
        id: node['id'] as String? ?? '',
        title: node['title'] as String? ?? '',
        price: double.tryParse(
          (node['price']?['amount'] as String?) ?? '0',
        ) ?? 0.0,
        compareAtPrice: double.tryParse(
          (node['compareAtPrice']?['amount'] as String?) ?? '0',
        ),
        available: node['availableForSale'] as bool? ?? false,
        image: node['image']?['url'] as String?,
      );
    }).toList();

    final tags = (json['tags'] as List<dynamic>?)
            ?.map((t) => t.toString())
            .toList() ??
        [];

    return Product(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      handle: json['handle'] as String? ?? '',
      description: json['description'] as String?,
      featuredImage: json['featuredImage']?['url'] as String?,
      images: images,
      variants: variants,
      minPrice: double.tryParse(
        (json['priceRange']?['minVariantPrice']?['amount'] as String?) ?? '0',
      ) ?? 0.0,
      maxPrice: double.tryParse(
        (json['priceRange']?['maxVariantPrice']?['amount'] as String?) ?? '0',
      ) ?? 0.0,
      currencyCode:
          json['priceRange']?['minVariantPrice']?['currencyCode'] as String? ??
              'USD',
      tags: tags,
    );
  }

  String get priceDisplay {
    if (minPrice == maxPrice) {
      return '\$${minPrice.toStringAsFixed(2)}';
    }
    return '\$${minPrice.toStringAsFixed(2)} - \$${maxPrice.toStringAsFixed(2)}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'handle': handle,
        'featuredImage': featuredImage,
        'minPrice': minPrice,
        'maxPrice': maxPrice,
        'currencyCode': currencyCode,
      };
}

class ProductImage {
  final String url;
  final String? altText;
  final int? width;
  final int? height;

  ProductImage({
    required this.url,
    this.altText,
    this.width,
    this.height,
  });
}

class ProductVariant {
  final String id;
  final String title;
  final double price;
  final double? compareAtPrice;
  final bool available;
  final String? image;

  ProductVariant({
    required this.id,
    required this.title,
    required this.price,
    this.compareAtPrice,
    required this.available,
    this.image,
  });

  String get priceDisplay => '\$${price.toStringAsFixed(2)}';

  bool get onSale => compareAtPrice != null && compareAtPrice! > price;
}
