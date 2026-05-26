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
                          const _SectionHeading('รีวิวที่ผ่านมา'),
                          const SizedBox(height: 8),
                          if (reviews.isEmpty)
                            const _EmptyProfileState(
                              icon: Icons.rate_review_outlined,
                              title: 'ยังไม่มีรีวิว',
                              body: 'รีวิวของคุณจะปรากฏที่นี่',
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
