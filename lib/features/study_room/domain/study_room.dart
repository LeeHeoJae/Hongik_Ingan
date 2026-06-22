import 'package:flutter/foundation.dart';

enum StudyRoomLocation { studentHall, tBuilding, rBuilding }

extension StudyRoomLocationLabel on StudyRoomLocation {
  String get label {
    return switch (this) {
      StudyRoomLocation.studentHall => '학관',
      StudyRoomLocation.tBuilding => 'T동',
      StudyRoomLocation.rBuilding => 'R동',
    };
  }
}

@immutable
class StudyRoomSeat {
  const StudyRoomSeat({
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
class StudyRoomStatus {
  const StudyRoomStatus({
    required this.location,
    required this.seats,
    required this.updatedAt,
  });

  final StudyRoomLocation location;
  final List<StudyRoomSeat> seats;
  final DateTime updatedAt;

  List<StudyRoomSeat> get rooms {
    return seats.where((seat) => !seat.isSummary).toList(growable: false);
  }

  StudyRoomSeat? get summary {
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
    return StudyRoomSeat(
      name: '계',
      totalSeats: total,
      usedSeats: used,
      availableSeats: available,
      usageRate: total > 0 ? used / total * 100 : 0,
    );
  }
}
