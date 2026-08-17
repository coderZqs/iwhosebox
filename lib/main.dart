import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'models/cart.dart';
import 'services/notification_service.dart';
import 'services/shopify_service.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shimmer/shimmer.dart';
import 'models/product.dart';
import 'widgets/product_card.dart';
import 'screens/product_detail_screen.dart';
import 'screens/home_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Run app immediately to show UI without waiting for network/Firebase
  runApp(const IWhoseboxApp());

  // Firebase and push notifications - initialized asynchronously in background
  if (!kIsWeb) {
    _initServices();
  }
}

Future<void> _initServices() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 3));
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('Firebase/Notification initialization non-fatal error: $e');
  }
}

class IWhoseboxApp extends StatelessWidget {
  const IWhoseboxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CartModel(),
      child: MaterialApp(
        title: 'iwhosebox',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF2563EB),
          scaffoldBackgroundColor: const Color(0xFFF8FAFC),
          brightness: Brightness.light,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Color(0xFF0F172A),
            centerTitle: false,
            elevation: 0,
            scrolledUnderElevation: 0.5,
          ),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: Colors.white,
            indicatorColor: const Color(0xFF2563EB).withValues(alpha: 0.12),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2563EB),
                );
              }
              return const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              );
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(color: Color(0xFF2563EB));
              }
              return const IconThemeData(color: Color(0xFF64748B));
            }),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFFF1F5F9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF3B82F6),
          brightness: Brightness.dark,
          appBarTheme: const AppBarTheme(
            centerTitle: false,
            elevation: 0,
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        themeMode: ThemeMode.system,
        home: const MainShell(),
        routes: {
          '/cart': (context) => const CartScreen(),
        },
      ),
    );
  }
}

/// Navigation shell with bottom tab bar
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const CategoriesView(),
    const CartScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          height: 64,
          elevation: 0,
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() => _currentIndex = index);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront_rounded),
              label: 'Shop',
            ),
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: 'Categories',
            ),
            NavigationDestination(
              icon: Icon(Icons.shopping_bag_outlined),
              selectedIcon: Icon(Icons.shopping_bag_rounded),
              label: 'Cart',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

/// Categories view with real Shopify Collections data
class CategoriesView extends StatefulWidget {
  const CategoriesView({super.key});

  @override
  State<CategoriesView> createState() => _CategoriesViewState();
}

class _CategoriesViewState extends State<CategoriesView> with WidgetsBindingObserver {
  final ShopifyService _shopifyService = ShopifyService();
  List<Map<String, dynamic>> _collections = [];
  bool _isLoading = true;
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCollections();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _collections.isEmpty && !_isLoading) {
      _loadCollections();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadCollections({bool isSilentRetry = false}) async {
    if (!isSilentRetry) {
      setState(() => _isLoading = true);
    }
    try {
      final collections = await _shopifyService.getCollections();
      if (mounted) {
        setState(() {
          _collections = collections;
          _isLoading = false;
          _retryCount = 0;
        });
      }
    } catch (e) {
      if (mounted) {
        if (_collections.isEmpty && _retryCount < 3) {
          _retryCount++;
          await Future.delayed(Duration(milliseconds: 1500 * _retryCount));
          if (mounted && _collections.isEmpty) {
            _loadCollections(isSilentRetry: true);
            return;
          }
        }
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Categories',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)),
            )
          : RefreshIndicator(
              onRefresh: _loadCollections,
              color: const Color(0xFF2563EB),
              child: _collections.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.category_outlined, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            'No categories found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 1.1,
                      ),
                      itemCount: _collections.length,
                      itemBuilder: (context, index) {
                        final collection = _collections[index];
                        final rawTitle = collection['title'] as String? ?? 'Category';
                        final handle = collection['handle'] as String?;
                        String title = rawTitle;
                        if (title == '主页' || handle == 'frontpage' || title.contains('主页')) {
                          title = 'Featured';
                        } else if (RegExp(r'[\u4e00-\u9fa5]').hasMatch(title)) {
                          if (handle != null && handle.isNotEmpty && !RegExp(r'[\u4e00-\u9fa5]').hasMatch(handle)) {
                            title = handle.replaceAll('-', ' ').split(' ').map((s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '').join(' ');
                          } else {
                            title = 'Collection';
                          }
                        }
                        final imageUrl = collection['image']?['url'] as String?;

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                final handle = collection['handle'] as String?;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CategoryProductsScreen(
                                      title: title,
                                      handle: handle,
                                    ),
                                  ),
                                );
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: Container(
                                      color: const Color(0xFFF8FAFC),
                                      child: imageUrl != null && imageUrl.isNotEmpty
                                          ? Image.network(
                                              imageUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const Center(
                                                child: Icon(
                                                  Icons.category_outlined,
                                                  color: Color(0xFF94A3B8),
                                                  size: 32,
                                                ),
                                              ),
                                            )
                                          : const Center(
                                              child: Icon(
                                                Icons.inventory_2_outlined,
                                                color: Color(0xFF2563EB),
                                                size: 36,
                                              ),
                                            ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    color: Colors.white,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF0F172A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          color: Color(0xFFCBD5E1),
                                          size: 13,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

/// Category products list screen
class CategoryProductsScreen extends StatefulWidget {
  final String title;
  final String? handle;

  const CategoryProductsScreen({
    super.key,
    required this.title,
    this.handle,
  });

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  final ShopifyService _shopifyService = ShopifyService();
  final ScrollController _scrollController = ScrollController();

  List<Product> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final products = await _shopifyService.getProducts(
        collectionHandle: widget.handle,
      );
      if (mounted) {
        setState(() {
          _products = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load products: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1E293B),
              size: 16,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          Consumer<CartModel>(
            builder: (_, cart, __) => Material(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CartScreen()),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.shopping_bag_outlined,
                        color: Color(0xFF1E293B),
                        size: 20,
                      ),
                      if (cart.itemCount > 0)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '${cart.itemCount}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
        ],
      ),
      body: _isLoading
          ? _buildShimmerGrid()
          : RefreshIndicator(
              onRefresh: _loadProducts,
              color: const Color(0xFF2563EB),
              child: _products.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No products in this category',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : MasonryGridView.count(
                      controller: _scrollController,
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      itemCount: _products.length,
                      itemBuilder: (context, index) {
                        final product = _products[index];
                        return ProductCard(
                          product: product,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductDetailScreen(
                                handle: product.handle,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildShimmerGrid() {
    return MasonryGridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      itemCount: 6,
      itemBuilder: (_, __) => _buildShimmerCard(),
    );
  }

  Widget _buildShimmerCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[200]!,
      highlightColor: Colors.grey[50]!,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
            width: 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 14,
                    width: 90,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        height: 18,
                        width: 60,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Container(
                        height: 28,
                        width: 28,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
