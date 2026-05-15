part of 'profile_screen.dart';

class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final app = context.read<AppProvider>();
      await Future.wait([app.loadAccountData(), app.loadMyReviews()]);
    } catch (e) {
      if (mounted) _showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final reviews = app.myReviews.map(asMap).toList();
    final reviewedBookingIds = reviews
        .map((review) => int.tryParse(_cleanText(review['booking_id'])))
        .whereType<int>()
        .toSet();
    final reviewableBookings = app.bookings
        .map(asMap)
        .where((booking) => _boolValue(booking['can_review']))
        .where((booking) {
          final id = int.tryParse(_cleanText(booking['id']));
          return id != null && !reviewedBookingIds.contains(id);
        })
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const TravelSliverAppBar(title: 'รีวิวของฉัน'),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: _loading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (reviewableBookings.isNotEmpty) ...[
                            const _SectionHeading('เขียนรีวิว'),
                            const SizedBox(height: 8),
                            for (final booking in reviewableBookings) ...[
                              _ReviewableBookingCard(
                                booking: booking,
                                onSubmitted: _load,
                              ),
                              const SizedBox(height: 12),
                            ],
                            const SizedBox(height: 12),
                          ],
                          const _SectionHeading('รีวิวที่ผ่านมา'),
                          const SizedBox(height: 8),
                          if (reviews.isEmpty)
                            const _EmptyProfileState(
                              icon: Icons.rate_review_outlined,
                              title: 'ยังไม่มีรีวิว',
                              body:
                                  'หลังจบทริป คุณสามารถส่งรีวิวจากรายการจองที่ยืนยันแล้ว',
                            )
                          else
                            for (final review in reviews) ...[
                              _ReviewCard(review: review),
                              const SizedBox(height: 12),
                            ],
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
