// lib/main.dart
import 'package:book_store/bottom_navigation_bar.dart';
import 'package:book_store/new.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  runApp(
    const ProviderScope(
      child: BookstoreApp(),
    ),
  );
}

class BookstoreApp extends ConsumerWidget {
  const BookstoreApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      routerConfig: router,
      title: 'Modern Bookstore',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
    );
  }
}

// lib/config/theme.dart

class AppTheme {
  static final light = ThemeData(
    useMaterial3: true,
    primarySwatch: Colors.blue,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: Colors.white,
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      centerTitle: false,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      elevation: 8,
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.grey,
    ),
  );

  static final dark = ThemeData.dark().copyWith(
    primaryColor: Colors.blue,
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      backgroundColor: Colors.grey[900],
      foregroundColor: Colors.white,
      centerTitle: false,
    ),
  );
}

final routerProvider = Provider((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/search',
        name: 'search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/book/:id',
        name: 'book-details',
        builder: (context, state) {
          final bookId = int.parse(state.pathParameters['id'] ?? '0');
          return BookDetailScreen(bookId: bookId);
        },
      ),
      GoRoute(
        path: '/category/:category',
        name: 'category',
        builder: (context, state) {
          final category = state.pathParameters['category'] ?? '';
          return CategoryScreen(category: category);
        },
      ),
    ],
  );
});

// lib/models/book.dart
class Book {
  final int id;
  final String title;
  final String author;
  final double price;
  final String image;
  final String category;
  final String description;
  final double rating;
  final int reviews;
  final bool isAvailable;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.price,
    required this.image,
    required this.category,
    this.description = '',
    this.rating = 0,
    this.reviews = 0,
    this.isAvailable = true,
  });

  Book copyWith({
    String? title,
    String? author,
    double? price,
    String? image,
    String? category,
    String? description,
    double? rating,
    int? reviews,
    bool? isAvailable,
  }) {
    return Book(
      id: this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      price: price ?? this.price,
      image: image ?? this.image,
      category: category ?? this.category,
      description: description ?? this.description,
      rating: rating ?? this.rating,
      reviews: reviews ?? this.reviews,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}

// lib/models/cart_item.dart

class CartItem {
  final Book book;
  final int quantity;

  CartItem({
    required this.book,
    this.quantity = 1,
  });

  CartItem copyWith({
    Book? book,
    int? quantity,
  }) {
    return CartItem(
      book: book ?? this.book,
      quantity: quantity ?? this.quantity,
    );
  }

  double get total => book.price * quantity;
}

final booksProvider = StateNotifierProvider<BooksNotifier, List<Book>>((ref) {
  return BooksNotifier();
});

class BooksNotifier extends StateNotifier<List<Book>> {
  BooksNotifier() : super(initialBooks); // initialBooks from books_data.dart

  void filterByCategory(String category) {
    if (category == 'All Books') {
      state = initialBooks;
      return;
    }
    state = initialBooks
        .where((book) => book.category.toLowerCase() == category.toLowerCase())
        .toList();
  }

  void filterBySearch(String query) {
    if (query.isEmpty) {
      state = initialBooks;
      return;
    }
    state = initialBooks
        .where((book) =>
            book.title.toLowerCase().contains(query.toLowerCase()) ||
            book.author.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  Book? getBookById(int id) {
    try {
      return state.firstWhere((book) => book.id == id);
    } catch (e) {
      return null;
    }
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier();
});

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  void addToCart(Book book) {
    final existingIndex = state.indexWhere((item) => item.book.id == book.id);

    if (existingIndex >= 0) {
      state = [
        ...state.sublist(0, existingIndex),
        CartItem(
          book: book,
          quantity: state[existingIndex].quantity + 1,
        ),
        ...state.sublist(existingIndex + 1),
      ];
    } else {
      state = [...state, CartItem(book: book)];
    }
  }

  void removeFromCart(int bookId) {
    state = state.where((item) => item.book.id != bookId).toList();
  }

  void updateQuantity(int bookId, int quantity) {
    if (quantity <= 0) {
      removeFromCart(bookId);
      return;
    }

    state = state
        .map((item) =>
            item.book.id == bookId ? item.copyWith(quantity: quantity) : item)
        .toList();
  }

  void clearCart() {
    state = [];
  }

  double get total => state.fold(0, (sum, item) => sum + item.total);
}

// lib/services/payment_service.dart

class PaymentService {
  static const String MERCHANT_ID = "PGTESTPAYUAT";
  static const String SALT_KEY = "099eb0cd-02cf-4e2a-8aca-3e6c6aff0399";
  static const String SALT_INDEX = "1";

  static Future<void> initPhonePe() async {
    try {
      bool environment = true; // true for production, false for sandbox
      String appId = environment ? "PROD_APP_ID" : "SANDBOX_APP_ID";
    } catch (e) {
      print("PhonePe initialization failed: $e");
    }
  }
}

// lib/data/books_data.dart

// lib/data/books_data.dart

final initialBooks = [
  Book(
    id: 1,
    title: "The Great Gatsby",
    author: "F. Scott Fitzgerald",
    price: 12.99,
    image: "https://images.unsplash.com/photo-1544947950-fa07a98d237f",
    category: "Fiction",
    description:
        "A story of the fabulously wealthy Jay Gatsby and his love for the beautiful Daisy Buchanan, set against the backdrop of the roaring twenties.",
    rating: 4.5,
    reviews: 2547,
  ),
  Book(
    id: 2,
    title: "1984",
    author: "George Orwell",
    price: 14.99,
    image: "https://images.unsplash.com/photo-1541963463532-d68292c34b19",
    category: "Fiction",
    description:
        "A dystopian social science fiction novel that follows Winston Smith's rebellion against a totalitarian regime.",
    rating: 4.8,
    reviews: 3256,
  ),
  Book(
    id: 3,
    title: "To Kill a Mockingbird",
    author: "Harper Lee",
    price: 11.99,
    image: "https://images.unsplash.com/photo-1543002588-bfa74002ed7e",
    category: "Fiction",
    description:
        "A story of racial injustice and the loss of innocence in the American South, told through the eyes of young Scout Finch.",
    rating: 4.7,
    reviews: 2980,
  ),
  Book(
    id: 4,
    title: "A Brief History of Time",
    author: "Stephen Hawking",
    price: 18.99,
    image: "https://images.unsplash.com/photo-1546521343-4eb2c9aa8454",
    category: "Science",
    description:
        "An exploration of cosmology, from the Big Bang to black holes, written for the general reader.",
    rating: 4.6,
    reviews: 1875,
  ),
  Book(
    id: 5,
    title: "Pride and Prejudice",
    author: "Jane Austen",
    price: 9.99,
    image: "https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c",
    category: "Romance",
    description:
        "The tale of Elizabeth Bennet and Mr. Darcy, as they overcome their pride and prejudices in Regency-era England.",
    rating: 4.4,
    reviews: 2156,
  ),
  Book(
    id: 6,
    title: "The Da Vinci Code",
    author: "Dan Brown",
    price: 15.99,
    image: "https://images.unsplash.com/photo-1589829085413-56de8ae18c73",
    category: "Mystery",
    description:
        "A thrilling mystery that follows Robert Langdon as he uncovers religious conspiracies in modern-day Europe.",
    rating: 4.2,
    reviews: 3421,
  ),
  Book(
    id: 7,
    title: "The Sapiens",
    author: "Yuval Noah Harari",
    price: 21.99,
    image: "https://images.unsplash.com/photo-1544947950-fa07a98d237f",
    category: "Non-Fiction",
    description:
        "A brief history of humankind, exploring how we became the dominant species on Earth.",
    rating: 4.8,
    reviews: 4521,
  ),
  Book(
    id: 8,
    title: "The Alchemist",
    author: "Paulo Coelho",
    price: 13.99,
    image: "https://images.unsplash.com/photo-1589829085413-56de8ae18c73",
    category: "Fiction",
    description:
        "A philosophical novel about a young shepherd who dreams of finding treasure in Egypt.",
    rating: 4.6,
    reviews: 3254,
  ),
  Book(
    id: 9,
    title: "Artificial Intelligence Basics",
    author: "Tom Taulli",
    price: 24.99,
    image: "https://images.unsplash.com/photo-1546521343-4eb2c9aa8454",
    category: "Technology",
    description:
        "An introduction to AI and its applications in modern technology.",
    rating: 4.3,
    reviews: 890,
  ),
  Book(
    id: 10,
    title: "The Silent Patient",
    author: "Alex Michaelides",
    price: 16.99,
    image: "https://images.unsplash.com/photo-1543002588-bfa74002ed7e",
    category: "Thriller",
    description:
        "A psychological thriller about a woman's act of violence against her husband.",
    rating: 4.5,
    reviews: 2876,
  ),
  Book(
    id: 11,
    title: "Steve Jobs",
    author: "Walter Isaacson",
    price: 19.99,
    image: "https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c",
    category: "Biography",
    description: "The exclusive biography of Apple's innovative co-founder.",
    rating: 4.7,
    reviews: 3421,
  ),
  Book(
    id: 12,
    title: "The Quantum World",
    author: "Kenneth W. Ford",
    price: 22.99,
    image: "https://images.unsplash.com/photo-1589829085413-56de8ae18c73",
    category: "Science",
    description:
        "An accessible introduction to quantum physics and its mysteries.",
    rating: 4.4,
    reviews: 756,
  ),
  Book(
    id: 13,
    title: "The Sherlock Holmes Collection",
    author: "Arthur Conan Doyle",
    price: 25.99,
    image: "https://images.unsplash.com/photo-1544947950-fa07a98d237f",
    category: "Mystery",
    description: "Complete collection of Sherlock Holmes adventures.",
    rating: 4.9,
    reviews: 5234,
  ),
  Book(
    id: 14,
    title: "Clean Code",
    author: "Robert C. Martin",
    price: 29.99,
    image: "https://images.unsplash.com/photo-1546521343-4eb2c9aa8454",
    category: "Technology",
    description: "A handbook of agile software craftsmanship.",
    rating: 4.8,
    reviews: 2345,
  ),
  Book(
    id: 15,
    title: "The Love Hypothesis",
    author: "Ali Hazelwood",
    price: 14.99,
    image: "https://images.unsplash.com/photo-1543002588-bfa74002ed7e",
    category: "Romance",
    description: "A contemporary romance set in the world of academia.",
    rating: 4.3,
    reviews: 1567,
  ),
  // Continue with more books...
  Book(
    id: 16,
    title: "Gone Girl",
    author: "Gillian Flynn",
    price: 15.99,
    image: "https://images.unsplash.com/photo-1589829085413-56de8ae18c73",
    category: "Thriller",
    description:
        "A gripping psychological thriller about a missing woman and her suspicious husband.",
    rating: 4.6,
    reviews: 4231,
  ),
  // Add remaining books with similar pattern
];

class BookCard extends ConsumerWidget {
  final Book book;

  const BookCard({
    required this.book,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.pushNamed(
          'book-details',
          pathParameters: {'id': book.id.toString()},
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section with fixed height
            SizedBox(
              height: 160, // Fixed height for image
              width: double.infinity,
              child: CachedNetworkImage(
                imageUrl: book.image, // URL of the image
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: const Icon(
                    Icons.image_not_supported,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            // Content Section
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    // Author
                    Text(
                      book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const Spacer(),
                    // Price and Cart Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\$${book.price.toStringAsFixed(2)}',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.add_shopping_cart, size: 20),
                          onPressed: () {
                            ref.read(cartProvider.notifier).addToCart(book);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${book.title} added to cart'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryChips extends HookConsumerWidget {
  const CategoryChips({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = [
      'All Books',
      'Fiction',
      'Non-Fiction',
      'Mystery',
      'Science Fiction',
      'Romance',
      'Thriller',
      'Biography',
      'History',
      'Science',
      'Technology'
    ];
    final selectedCategory = useState('All Books');

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              selected: selectedCategory.value == category,
              label: Text(category),
              onSelected: (selected) {
                selectedCategory.value = category;
                ref.read(booksProvider.notifier).filterByCategory(category);
              },
              selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
              checkmarkColor: Theme.of(context).primaryColor,
              labelStyle: TextStyle(
                color: selectedCategory.value == category
                    ? Theme.of(context).primaryColor
                    : Colors.black87,
              ),
            ),
          );
        },
      ),
    );
  }
}

// lib/widgets/bottom_nav_bar.dart

// lib/screens/home_screen.dart
class HomeScreen extends HookConsumerWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(booksProvider);
    final isLoading = useState(true);

    useEffect(() {
      Future.delayed(const Duration(seconds: 2), () {
        isLoading.value = false;
      });
      PaymentService.initPhonePe();
      return null;
    }, const []);

    return Scaffold(
      appBar: AppBar(
        title: const Text('📚 Modern Bookstore'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.go('/search'),
          ),
          Consumer(
            builder: (context, ref, child) {
              final cartItemCount = ref.watch(cartProvider).length;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart),
                    onPressed: () => context.go('/profile'),
                  ),
                  if (cartItemCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$cartItemCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          isLoading.value = true;
          await Future.delayed(const Duration(seconds: 1));
          isLoading.value = false;
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: CategoryChips(),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(8.0),
              sliver: isLoading.value
                  ? SliverToBoxAdapter(child: ShimmerLoader())
                  : books.isEmpty
                      ? const SliverToBoxAdapter(
                          child: Center(
                            child: Text('No books found'),
                          ),
                        )
                      : SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount:
                                MediaQuery.of(context).size.width > 1200
                                    ? 4
                                    : MediaQuery.of(context).size.width > 800
                                        ? 6
                                        : 2,
                            childAspectRatio: 0.65, // Adjusted ratio
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => BookCard(book: books[index]),
                            childCount: books.length,
                          ),
                        ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }
}

// lib/widgets/shimmer_loader.dart
class ShimmerLoader extends StatelessWidget {
  const ShimmerLoader({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 1200
            ? 6
            : MediaQuery.of(context).size.width > 600
                ? 4
                : 2,
        childAspectRatio: 0.57,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: 12,
      itemBuilder: (context, index) => Card(
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 3 / 4,
              child: Container(
                color: Colors.grey[300],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 16,
                    width: double.infinity,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: 100,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 24,
                    width: 80,
                    color: Colors.grey[300],
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

// lib/widgets/payment_bottom_sheet.dart
class PaymentBottomSheet extends StatelessWidget {
  final double amount;

  const PaymentBottomSheet({
    required this.amount,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Complete Payment',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Text(
            'Total Amount: \$${amount.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Pay with PhonePe'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }
}

class SearchScreen extends HookConsumerWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchController = useTextEditingController();
    final books = ref.watch(booksProvider);
    final recentSearches = useState<List<String>>([]);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search books or authors...',
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      searchController.clear();
                      ref.read(booksProvider.notifier).filterBySearch('');
                    },
                  )
                : null,
          ),
          onChanged: (value) {
            ref.read(booksProvider.notifier).filterBySearch(value);
          },
          onSubmitted: (value) {
            if (value.isNotEmpty && !recentSearches.value.contains(value)) {
              recentSearches.value = [...recentSearches.value, value]
                ..take(5).toList();
            }
          },
        ),
      ),
      body: Column(
        children: [
          // Quick Filters
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                'Fiction',
                'Non-Fiction',
                'Science',
                'History',
                'Romance',
                'Mystery',
                'Biography'
              ]
                  .map((category) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FilterChip(
                          label: Text(category),
                          selected: false,
                          onSelected: (bool selected) {
                            ref
                                .read(booksProvider.notifier)
                                .filterByCategory(category);
                          },
                        ),
                      ))
                  .toList(),
            ),
          ),

          // Recent Searches
          if (searchController.text.isEmpty && recentSearches.value.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Searches',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      TextButton(
                        onPressed: () => recentSearches.value = [],
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: recentSearches.value
                        .map((search) => Chip(
                              label: Text(search),
                              onDeleted: () {
                                recentSearches.value = recentSearches.value
                                    .where((s) => s != search)
                                    .toList();
                              },
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),

          // Search Results
          Expanded(
            child: books.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          searchController.text.isEmpty
                              ? 'Search for books by title or author'
                              : 'No books found',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: MediaQuery.of(context).size.width > 1200
                          ? 6
                          : MediaQuery.of(context).size.width > 800
                              ? 4
                              : 2,
                      childAspectRatio: 0.65, // Adjusted ratio
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                    ),
                    itemCount: books.length,
                    itemBuilder: (context, index) {
                      final book = books[index];
                      return BookCard(book: book);
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }
}

// lib/screens/profile_screen.dart
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final cartTotal = ref.read(cartProvider.notifier).total;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          if (cart.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _showClearCartDialog(context, ref),
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(context),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // User Profile Section
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundImage: NetworkImage(
                      'https://placekitten.com/200/200', // Replace with actual user image
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'John Doe',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'john.doe@example.com',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatColumn('Wishlist', '12'),
                      _buildStatColumn('Orders', '8'),
                      _buildStatColumn('Reviews', '24'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Shopping Cart Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Shopping Cart',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ),

          if (cart.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text('Your cart is empty'),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = cart[index];
                  return Dismissible(
                    key: Key(item.book.id.toString()),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      child: const Icon(
                        Icons.delete,
                        color: Colors.white,
                      ),
                    ),
                    onDismissed: (_) {
                      ref
                          .read(cartProvider.notifier)
                          .removeFromCart(item.book.id);
                    },
                    child: Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: ListTile(
                        leading: CachedNetworkImage(
                          imageUrl: item.book.image,
                          width: 50,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => SizedBox(
                            width: 50,
                            height: 50,
                            child: Center(
                                child:
                                    CircularProgressIndicator()), // Loading spinner
                          ),
                          errorWidget: (context, url, error) => SizedBox(
                            width: 50,
                            height: 50,
                            child: Icon(Icons.error,
                                color: Colors.red), // Error icon
                          ),
                        ),
                        title: Text(item.book.title),
                        subtitle: Text('\$${item.book.price}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: () {
                                if (item.quantity > 1) {
                                  ref
                                      .read(cartProvider.notifier)
                                      .updateQuantity(
                                          item.book.id, item.quantity - 1);
                                } else {
                                  ref
                                      .read(cartProvider.notifier)
                                      .removeFromCart(item.book.id);
                                }
                              },
                            ),
                            Text(
                              '${item.quantity}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () {
                                ref.read(cartProvider.notifier).updateQuantity(
                                    item.book.id, item.quantity + 1);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: cart.length,
              ),
            ),
        ],
      ),
      bottomSheet: cart.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total:',
                            style: TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            '\$${cartTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _showCheckoutSheet(context, cartTotal),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                      child: const Text('Checkout'),
                    ),
                  ],
                ),
              ),
            )
          : null,
      bottomNavigationBar: const BottomNavBar(),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  void _showClearCartDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cart'),
        content: const Text('Are you sure you want to clear your cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(cartProvider.notifier).clearCart();
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Settings'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              // Handle profile settings
              Navigator.pop(context);
            },
            child: const Text('Edit Profile'),
          ),
          SimpleDialogOption(
            onPressed: () {
              // Handle notification settings
              Navigator.pop(context);
            },
            child: const Text('Notifications'),
          ),
          SimpleDialogOption(
            onPressed: () {
              // Handle payment methods
              Navigator.pop(context);
            },
            child: const Text('Payment Methods'),
          ),
          SimpleDialogOption(
            onPressed: () {
              // Handle address settings
              Navigator.pop(context);
            },
            child: const Text('Addresses'),
          ),
        ],
      ),
    );
  }

  void _showCheckoutSheet(BuildContext context, double total) {
    showModalBottomSheet(
      context: context,
      builder: (context) => PaymentBottomSheet(amount: total),
    );
  }
}

// lib/screens/book_detail_screen.dart
class BookDetailScreen extends ConsumerWidget {
  final int bookId;

  const BookDetailScreen({
    required this.bookId,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.read(booksProvider.notifier).getBookById(bookId);

    if (book == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text('Book not found'),
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'book_image_${book.id}',
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SizedBox(
                      height: 160, // Fixed height for the image
                      width: double.infinity, // Full width of the parent
                      child: CachedNetworkImage(
                        imageUrl: book.image, // Image URL
                        fit: BoxFit.cover, // Ensures the image covers the area
                        placeholder: (context, url) => Center(
                          child:
                              CircularProgressIndicator(), // Loading spinner while the image loads
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors
                              .grey[300], // Background for error container
                          child: const Icon(
                            Icons
                                .image_not_supported, // Icon when the image fails to load
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'by ${book.author}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Price and Rating Section
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '\$${book.price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const SizedBox(width: 8),
                              Text(
                                '${book.rating} (${book.reviews} reviews)',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          ref.read(cartProvider.notifier).addToCart(book);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Added to cart'),
                              action: SnackBarAction(
                                label: 'View Cart',
                                onPressed: () => context.go('/profile'),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add_shopping_cart),
                        label: const Text('Add to Cart'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Book Details
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category Chip
                      Wrap(
                        spacing: 8,
                        children: [
                          Chip(
                            label: Text(book.category),
                            avatar: const Icon(Icons.category),
                          ),
                          // Add more chips for tags if needed
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Description Section
                      const Text(
                        'About this book',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        book.description,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Book Details Table
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Book Details',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildDetailRow('Author', book.author),
                            _buildDetailRow('Category', book.category),
                            _buildDetailRow('Rating', '${book.rating}/5.0'),
                            _buildDetailRow('Reviews', book.reviews.toString()),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Similar Books Section
                      const Text(
                        'Similar Books',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: Consumer(
                          builder: (context, ref, child) {
                            final similarBooks = ref
                                .watch(booksProvider)
                                .where((b) =>
                                    b.category == book.category &&
                                    b.id != book.id)
                                .take(5)
                                .toList();

                            return ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: similarBooks.length,
                              itemBuilder: (context, index) {
                                final similarBook = similarBooks[index];
                                return SizedBox(
                                  width: 120,
                                  child: Card(
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: () {
                                        context.go('/book/${similarBook.id}');
                                      },
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          CachedNetworkImage(
                                            imageUrl:
                                                similarBook.image, // Image URL
                                            height: 120, // Fixed height
                                            width: double
                                                .infinity, // Full width of the container
                                            fit: BoxFit
                                                .cover, // Ensures the image covers the space
                                            placeholder: (context, url) =>
                                                Center(
                                              child:
                                                  CircularProgressIndicator(), // Loading indicator while fetching the image
                                            ),
                                            errorWidget:
                                                (context, url, error) =>
                                                    Container(
                                              color: Colors.grey[
                                                  300], // Background color for error
                                              child: const Icon(
                                                Icons
                                                    .image_not_supported, // Icon displayed on error
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  similarBook.title,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  '\$${similarBook.price}',
                                                  style: TextStyle(
                                                    color: Theme.of(context)
                                                        .primaryColor,
                                                    fontWeight: FontWeight.bold,
                                                  ),
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
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Reviews Section (Preview)
                      const Text(
                        'Reviews',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildReviewPreview(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewPreview(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundImage: NetworkImage('https://picsum.photos/200'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'John Doe',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          ...List.generate(
                            5,
                            (index) => Icon(
                              index < 4 ? Icons.star : Icons.star_border,
                              size: 16,
                              color: Colors.amber,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '4.0',
                            style: TextStyle(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  '2 days ago',
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Great book! The story is captivating and well-written. '
              'I couldn\'t put it down once I started reading.',
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                // Show all reviews
              },
              child: const Text('See all reviews'),
            ),
          ],
        ),
      ),
    );
  }
}
