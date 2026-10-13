import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../providers/app_provider.dart';
import '../providers/wishlist_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/travel_widgets.dart';
import 'trip_detail_screen.dart' show TripDetailScreen;

class WishlistScreen extends StatelessWidget {
  /// เปิดจากแท็บ "ถูกใจ" ในแถบเมนูล่าง — ส่งมาแล้วหน้าว่างจะมีปุ่มพาไปหน้าทริป
  /// (เปิดจากเมนูบัญชีไม่ส่ง เพราะกดย้อนกลับก็กลับไปที่เดิมได้อยู่แล้ว)
  final VoidCallback? onBrowseTrips;

  const WishlistScreen({super.key, this.onBrowseTrips});

  @override
  Widget build(BuildContext context) {
    final wishlist = context.watch<WishlistProvider>();
    final items = wishlist.items;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: CustomScrollView(
        slivers: [
          const TravelSliverAppBar(title: 'ทริปที่ชอบ'),
          if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(onBrowseTrips: onBrowseTrips),
            )
          else
            SliverPadding(
              // เป็นแท็บหลักได้ — แถบเมนูล่างลอยทับเนื้อหา (extendBody) จึงต้อง
              // เผื่อระยะล่างตาม MediaQuery ไม่งั้นการ์ดใบสุดท้ายจมใต้แถบ
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                32 + MediaQuery.paddingOf(context).bottom,
              ),
              sliver: SliverList.separated(
                itemBuilder: (_, index) => _WishlistTile(item: items[index]),
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemCount: items.length,
              ),
            ),
        ],
      ),
    );
  }
}

class _WishlistTile extends StatelessWidget {
  final Map<String, dynamic> item;

  const _WishlistTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final slug = item['slug']?.toString() ?? '';
    final image = ApiConfig.mediaUrl(
      item['thumbnail_image']?.toString().isNotEmpty == true
          ? item['thumbnail_image']
          : item['cover_image'],
    );
    final price = item['price_per_person'];
    final priceLabel = price == null
        ? null
        : NumberFormat.currency(
            locale: 'th_TH',
            symbol: '฿',
            decimalDigits: 0,
          ).format(price is num ? price : num.tryParse(price.toString()) ?? 0);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        onTap: () async {
          if (slug.isEmpty) return;
          // Trip detail needs an AppProvider-loaded trip object, so load on tap.
          final app = context.read<AppProvider>();
          try {
            final trip = await app.trip(slug);
            if (!context.mounted) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TripDetailScreen(slug: slug),
              ),
            );
            // ignore: unused_local_variable
            final _ = trip;
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.toString())),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: image.isEmpty
                      ? Container(color: AppTheme.subtleSurface(context))
                      : CachedNetworkImage(
                          imageUrl: image,
                          fit: BoxFit.cover,
                          placeholder: (_, _) =>
                              Container(color: AppTheme.subtleSurface(context)),
                          errorWidget: (_, _, _) => Container(
                            color: AppTheme.subtleSurface(context),
                            child: const Icon(Icons.landscape_rounded),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item['title']?.toString() ?? '-',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: appFont(
                        color: AppTheme.onSurface(context),
                        fontSize: AppText.sizeSubtitle,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['location']?.toString() ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: appFont(
                        color: AppTheme.mutedText(context),
                        fontSize: AppText.sizeLabel,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (priceLabel != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '$priceLabel / คน',
                        style: appFont(
                          color: AppTheme.primaryColor,
                          fontSize: AppText.sizeBody,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'นำออก',
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: AppTheme.mutedText(context),
                ),
                onPressed: () =>
                    context.read<WishlistProvider>().remove(slug),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback? onBrowseTrips;

  const _EmptyState({this.onBrowseTrips});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          32,
          32,
          32,
          32 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_border_rounded,
              color: AppTheme.mutedText(context),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'ยังไม่มีทริปที่บันทึกไว้',
              style: appFont(
                color: AppTheme.onSurface(context),
                fontSize: AppText.sizeSubtitle,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'เมื่อเจอทริปที่สนใจ กดรูปหัวใจเพื่อบันทึกไว้ดูอีกครั้งภายหลัง',
              textAlign: TextAlign.center,
              style: appFont(
                color: AppTheme.mutedText(context),
                fontSize: AppText.sizeLabel,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (onBrowseTrips != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onBrowseTrips,
                icon: const Icon(Icons.explore_rounded, size: 18),
                label: Text(
                  'ดูทริปทั้งหมด',
                  style: appFont(
                    fontSize: AppText.sizeBody,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
