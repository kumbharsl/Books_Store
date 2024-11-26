// lib/screens/category_screen.dart
import 'package:book_store/bottom_navigation_bar.dart';
import 'package:book_store/main.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

enum SortOption { priceHighToLow, priceLowToHigh, rating, newest, bestselling }

final sortOptionProvider =
    StateProvider<SortOption>((ref) => SortOption.bestselling);

class CategoryScreen extends HookConsumerWidget {
  final String category;

  const CategoryScreen({
    required this.category,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(booksProvider);
    final selectedSort = ref.watch(sortOptionProvider);
    final isGridView = useState(true);
    final priceRange = useState(const RangeValues(0.0, 100.0));
    final ratingFilter = useState(0.0);
    final isLoading = useState(false);

    // Filter books by category and apply sorting
    final filteredBooks = useMemoized(() {
      List<Book> filtered = books
          .where((book) =>
              book.category == category &&
              book.price >= priceRange.value.start &&
              book.price <= priceRange.value.end &&
              book.rating >= ratingFilter.value)
          .toList();

      switch (selectedSort) {
        case SortOption.priceHighToLow:
          filtered.sort((a, b) => b.price.compareTo(a.price));
          break;
        case SortOption.priceLowToHigh:
          filtered.sort((a, b) => a.price.compareTo(b.price));
          break;
        case SortOption.rating:
          filtered.sort((a, b) => b.rating.compareTo(a.rating));
          break;
        case SortOption.newest:
          // Assuming we add a dateAdded field to Book model
          // filtered.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
          break;
        case SortOption.bestselling:
          filtered.sort((a, b) => b.reviews.compareTo(a.reviews));
          break;
      }
      return filtered;
    }, [books, category, selectedSort, priceRange.value, ratingFilter.value]);

    return Scaffold(
      appBar: AppBar(
        title: Text(category),
        actions: [
          // Toggle view
          IconButton(
            icon: Icon(isGridView.value ? Icons.list : Icons.grid_view),
            onPressed: () => isGridView.value = !isGridView.value,
          ),
          // Filter button
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterBottomSheet(
              context,
              priceRange,
              ratingFilter,
            ),
          ),
          // Sort button
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort),
            onSelected: (SortOption result) {
              ref.read(sortOptionProvider.notifier).state = result;
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: SortOption.bestselling,
                child: Text('Bestselling'),
              ),
              const PopupMenuItem(
                value: SortOption.priceHighToLow,
                child: Text('Price: High to Low'),
              ),
              const PopupMenuItem(
                value: SortOption.priceLowToHigh,
                child: Text('Price: Low to High'),
              ),
              const PopupMenuItem(
                value: SortOption.rating,
                child: Text('Average Rating'),
              ),
              const PopupMenuItem(
                value: SortOption.newest,
                child: Text('Newest Arrivals'),
              ),
            ],
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Category Header
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${filteredBooks.length} Books',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      // Active filters chips
                      if (ratingFilter.value > 0)
                        Chip(
                          label: Text('${ratingFilter.value}+ Stars'),
                          onDeleted: () => ratingFilter.value = 0,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Price range indicator
                  if (priceRange.value.start > 0 || priceRange.value.end < 100)
                    Chip(
                      label: Text(
                        '\$${priceRange.value.start.toStringAsFixed(0)} - \$${priceRange.value.end.toStringAsFixed(0)}',
                      ),
                      onDeleted: () {
                        priceRange.value = const RangeValues(0, 100);
                      },
                    ),
                ],
              ),
            ),
          ),

          // Books Grid/List
          isLoading.value
              ? const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              : filteredBooks.isEmpty
                  ? const SliverFillRemaining(
                      child: Center(
                        child: Text('No books found'),
                      ),
                    )
                  : isGridView.value
                      ? SliverPadding(
                          padding: const EdgeInsets.all(16),
                          sliver: SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount:
                                  MediaQuery.of(context).size.width > 1200
                                      ? 6
                                      : MediaQuery.of(context).size.width > 800
                                          ? 4
                                          : 2,
                              childAspectRatio: 0.95,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => BookCard(
                                book: filteredBooks[index],
                              ),
                              childCount: filteredBooks.length,
                            ),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => BookListTile(
                              book: filteredBooks[index],
                            ),
                            childCount: filteredBooks.length,
                          ),
                        ),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }

  void _showFilterBottomSheet(
    BuildContext context,
    ValueNotifier<RangeValues> priceRange,
    ValueNotifier<double> ratingFilter,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => FilterBottomSheet(
        initialPriceRange: priceRange.value,
        initialRating: ratingFilter.value,
        onApply: (newPriceRange, newRating) {
          priceRange.value = newPriceRange;
          ratingFilter.value = newRating;
          Navigator.pop(context);
        },
      ),
    );
  }
}

// Book List Tile Widget
class BookListTile extends ConsumerWidget {
  final Book book;

  const BookListTile({
    required this.book,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        onTap: () => context.push('/book/${book.id}'),
        contentPadding: const EdgeInsets.all(8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4), // Rounded corners
          child: CachedNetworkImage(
            imageUrl: book.image, // Image URL
            width: 60, // Fixed width for the image
            height: 90, // Fixed height for the image
            fit: BoxFit
                .cover, // Ensures the image covers the space proportionally
            placeholder: (context, url) => Container(
              width: 60,
              height: 90,
              color: Colors.grey[200], // Background color while loading
              child: Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2), // Loading indicator
              ),
            ),
            errorWidget: (context, url, error) => Container(
              width: 60,
              height: 90,
              color: Colors.grey[300], // Background color for error
              child: const Icon(
                Icons.image_not_supported, // Fallback icon
                color: Colors.white,
              ),
            ),
          ),
        ),
        title: Text(
          book.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(book.author),
            const SizedBox(height: 4),
            Row(
              children: [
                const SizedBox(width: 8),
                Text('(${book.reviews})'),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '\$${book.price}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_shopping_cart),
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
      ),
    );
  }
}

// Filter Bottom Sheet
class FilterBottomSheet extends HookWidget {
  final RangeValues initialPriceRange;
  final double initialRating;
  final Function(RangeValues, double) onApply;

  const FilterBottomSheet({
    required this.initialPriceRange,
    required this.initialRating,
    required this.onApply,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final priceRange = useState(initialPriceRange);
    final rating = useState(initialRating);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filters',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Price Range Filter
          const Text(
            'Price Range',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          RangeSlider(
            values: priceRange.value,
            min: 0,
            max: 100,
            divisions: 20,
            labels: RangeLabels(
              '\$${priceRange.value.start.toStringAsFixed(0)}',
              '\$${priceRange.value.end.toStringAsFixed(0)}',
            ),
            onChanged: (RangeValues values) {
              priceRange.value = values;
            },
          ),

          const SizedBox(height: 24),

          // Rating Filter
          const Text(
            'Minimum Rating',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Slider(
            value: rating.value,
            min: 0,
            max: 5,
            divisions: 5,
            label: rating.value.toStringAsFixed(1),
            onChanged: (value) {
              rating.value = value;
            },
          ),

          const SizedBox(height: 24),

          // Apply Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => onApply(priceRange.value, rating.value),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Apply Filters'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
