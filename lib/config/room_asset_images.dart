/// Local room photo assignments used by the student available-rooms page.
///
/// Add images to assets/images/rooms/, register them in pubspec.yaml, then add
/// their asset paths to the matching room key below.
class RoomAssetImages {
  RoomAssetImages._();

  static const byRoom = <String, List<String>>{
  'indra|101': [
    'assets/images/rooms/H1.webp',
    'assets/images/rooms/H2.webp',
  ],
  'fairy hostel|1': [
    'assets/images/rooms/GirlsHostel1.webp',
    'assets/images/rooms/H6.webp',
  ],
  'usa|10': [
    'assets/images/rooms/H16.webp',
    'assets/images/rooms/H17.webp',
  ],
  'haripriya|501': [
    'assets/images/rooms/H4.webp',
    'assets/images/rooms/H6.webp',
  ],
};

  static const fallback = <String>[
    'assets/images/rooms/H2.webp',
    'assets/images/rooms/H3.webp',
    'assets/images/rooms/H4.webp',
    'assets/images/rooms/H6.webp',
    'assets/images/rooms/H16.webp',
    'assets/images/rooms/H17.webp',
    'assets/images/rooms/BGF.webp',
    'assets/images/rooms/GirlsHostel1.webp',
  ];

  static List<String> forRoom(Map<String, dynamic> room) {
    final building = room['building']?.toString().trim().toLowerCase() ?? '';
    final roomNo = room['roomNo']?.toString().trim().toLowerCase() ?? '';
    final key = '$building|$roomNo';
    return byRoom[key] ?? fallback;
  }
}
