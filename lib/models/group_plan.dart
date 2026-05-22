/// Client-side view of a group trip plan, mirroring `GroupPlanPresenter` on the
/// backend. Used both for REST responses and the realtime `group.updated`
/// broadcast payload — the two share an identical shape.
class GroupPlan {
  final int id;
  final String inviteCode;
  final String? name;
  final String status; // open | booked | cancelled | expired
  final bool isOpen;
  final int seatCount;
  final int hostUserId;
  final bool isHost;
  final String? bookingRef;
  final DateTime? expiresAt;
  final List<String> claimedSeatIds;
  final GroupSchedule? schedule;
  final GroupTrip? trip;
  final List<GroupPlanMember> members;

  const GroupPlan({
    required this.id,
    required this.inviteCode,
    required this.name,
    required this.status,
    required this.isOpen,
    required this.seatCount,
    required this.hostUserId,
    required this.isHost,
    required this.bookingRef,
    required this.expiresAt,
    required this.claimedSeatIds,
    required this.schedule,
    required this.trip,
    required this.members,
  });

  bool get isBooked => status == 'booked';

  int get readyCount =>
      members.where((m) => m.status == 'ready' && m.seatId != null).length;

  GroupPlanMember? memberFor(int userId) {
    for (final m in members) {
      if (m.userId == userId) return m;
    }
    return null;
  }

  factory GroupPlan.fromJson(Map<String, dynamic> json) {
    return GroupPlan(
      id: int.tryParse('${json['id']}') ?? 0,
      inviteCode: json['invite_code']?.toString() ?? '',
      name: json['name']?.toString(),
      status: json['status']?.toString() ?? 'open',
      isOpen: json['is_open'] == true,
      seatCount: int.tryParse('${json['seat_count']}') ?? 1,
      hostUserId: int.tryParse('${json['host_user_id']}') ?? 0,
      isHost: json['is_host'] == true,
      bookingRef: json['booking_ref']?.toString(),
      expiresAt: DateTime.tryParse('${json['expires_at']}'),
      claimedSeatIds: (json['claimed_seat_ids'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      schedule: json['schedule'] is Map
          ? GroupSchedule.fromJson(Map<String, dynamic>.from(json['schedule']))
          : null,
      trip: json['trip'] is Map
          ? GroupTrip.fromJson(Map<String, dynamic>.from(json['trip']))
          : null,
      members: (json['members'] as List?)
              ?.whereType<Map>()
              .map((e) => GroupPlanMember.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
    );
  }
}

class GroupPlanMember {
  final int id;
  final int userId;
  final bool isHost;
  final bool isMe;
  final String status; // joined | ready | left
  final String? seatId;
  final String? passengerName;
  final String displayName;
  final String? avatarUrl;

  const GroupPlanMember({
    required this.id,
    required this.userId,
    required this.isHost,
    required this.isMe,
    required this.status,
    required this.seatId,
    required this.passengerName,
    required this.displayName,
    required this.avatarUrl,
  });

  bool get isReady => status == 'ready' && seatId != null;

  factory GroupPlanMember.fromJson(Map<String, dynamic> json) {
    return GroupPlanMember(
      id: int.tryParse('${json['id']}') ?? 0,
      userId: int.tryParse('${json['user_id']}') ?? 0,
      isHost: json['is_host'] == true,
      isMe: json['is_me'] == true,
      status: json['status']?.toString() ?? 'joined',
      seatId: json['seat_id']?.toString(),
      passengerName: json['passenger_name']?.toString(),
      displayName: json['display_name']?.toString() ?? 'สมาชิก',
      avatarUrl: json['avatar_url']?.toString(),
    );
  }
}

class GroupSchedule {
  final int id;
  final String? departureDate;
  final String? returnDate;
  final double effectivePrice;
  final int availableSeats;

  const GroupSchedule({
    required this.id,
    required this.departureDate,
    required this.returnDate,
    required this.effectivePrice,
    required this.availableSeats,
  });

  factory GroupSchedule.fromJson(Map<String, dynamic> json) {
    return GroupSchedule(
      id: int.tryParse('${json['id']}') ?? 0,
      departureDate: json['departure_date']?.toString(),
      returnDate: json['return_date']?.toString(),
      effectivePrice:
          double.tryParse('${json['effective_price']}') ?? 0,
      availableSeats: int.tryParse('${json['available_seats']}') ?? 0,
    );
  }
}

class GroupTrip {
  final int id;
  final String title;
  final String slug;
  final String? location;
  final String? thumbnailImage;
  final String? coverImage;

  const GroupTrip({
    required this.id,
    required this.title,
    required this.slug,
    required this.location,
    required this.thumbnailImage,
    required this.coverImage,
  });

  String get image =>
      (coverImage?.isNotEmpty == true ? coverImage : thumbnailImage) ?? '';

  factory GroupTrip.fromJson(Map<String, dynamic> json) {
    return GroupTrip(
      id: int.tryParse('${json['id']}') ?? 0,
      title: json['title']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      location: json['location']?.toString(),
      thumbnailImage: json['thumbnail_image']?.toString(),
      coverImage: json['cover_image']?.toString(),
    );
  }
}
