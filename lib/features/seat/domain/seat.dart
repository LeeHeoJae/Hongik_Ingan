import 'package:flutter/foundation.dart';

enum SeatLocation { studentHall, tBuilding, rBuilding }

extension SeatLocationLabel on SeatLocation {
  String get label {
    return switch (this) {
      SeatLocation.studentHall => '학관',
      SeatLocation.tBuilding => 'T동',
      SeatLocation.rBuilding => 'R동',
    };
  }
}

@immutable
class Seat {
  const Seat({
    required this.name,
    required this.totalSeats,
    required this.usedSeats,
    required this.availableSeats,
    required this.usageRate,
  });

  final String name;
  final int totalSeats;
  final int usedSeats;
  final int availableSeats;
  final double usageRate;

  bool get isSummary => name == '계';

  double get availableRate {
    if (totalSeats <= 0) {
      return 0;
    }
    return availableSeats / totalSeats;
  }
}

@immutable
class SeatStatus {
  const SeatStatus({
    required this.location,
    required this.seats,
    required this.updatedAt,
  });

  final SeatLocation location;
  final List<Seat> seats;
  final DateTime updatedAt;

  List<Seat> get rooms {
    return seats.where((seat) => !seat.isSummary).toList(growable: false);
  }

  Seat? get summary {
    for (final seat in seats) {
      if (seat.isSummary) {
        return seat;
      }
    }
    if (seats.isEmpty) {
      return null;
    }

    final total = seats.fold<int>(0, (value, seat) => value + seat.totalSeats);
    final used = seats.fold<int>(0, (value, seat) => value + seat.usedSeats);
    final available = seats.fold<int>(
      0,
      (value, seat) => value + seat.availableSeats,
    );
    return Seat(
      name: '계',
      totalSeats: total,
      usedSeats: used,
      availableSeats: available,
      usageRate: total > 0 ? used / total * 100 : 0,
    );
  }
}
