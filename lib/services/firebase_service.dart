import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'api_service.dart';
import 'session_service.dart';

/// Central Firebase data/service layer for the Hostel Management System.
///
/// Design goals:
/// - Keep Firebase access in one place.
/// - Keep Firestore/Auth errors consistent.
/// - Preserve the existing collection/field names used by the UI.
/// - Keep fee streams reusable and predictable.
/// - Validate admin access before admin operations.
/// - Keep backwards compatibility with existing ISO date strings while
///   accepting Firestore Timestamp/DateTime values when reading old/new data.
class FirebaseService {
  FirebaseService._();

  static FirebaseAuth get _auth => FirebaseAuth.instance;
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // COMMON CONSTANTS
  // ---------------------------------------------------------------------------

  static const _defaultAppSettings = <String, dynamic>{
    'notifications': true,
    'complaintAlerts': true,
    'visitorAlerts': true,
    'feeAlerts': true,
    'maintenanceMode': false,
  };

  static const _defaultAdminPreferences = <String, dynamic>{
    'emailNotifications': false,
    'autoLogout': true,
    'themeMode': 'system',
    'language': 'en',
  };

  // ---------------------------------------------------------------------------
  // AUTHENTICATION
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String gender,
    required String age,
    required String phone,
  }) async {
    final normalizedEmail = _normalizeEmail(email);

    if (name.trim().isEmpty) {
      throw ApiException('Name is required');
    }
    if (normalizedEmail.isEmpty) {
      throw ApiException('Email is required');
    }
    if (password.length < 6) {
      throw ApiException('Password must contain at least 6 characters');
    }

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final uid = credential.user?.uid;
      if (uid == null || uid.isEmpty) {
        throw ApiException('Unable to create user account');
      }

      final userData = <String, dynamic>{
        'id': uid,
        'name': name.trim(),
        'email': normalizedEmail,
        'gender': gender.trim(),
        'age': age.trim(),
        'phone': phone.trim(),
        'address': '',
        'parentName': '',
        'parentPhone': '',
        'parentOccupation': '',
        'role': 'student',
        'createdAt': _now(),
      };

      try {
        final now = DateTime.now();
        final feeMonth =
            '${now.year}-${now.month.toString().padLeft(2, '0')}';
        final feeRef = _db
            .collection('dues')
            .doc('signup_${uid}_$feeMonth');
        final batch = _db.batch();
        batch.set(_db.collection('users').doc(uid), userData);
        batch.set(feeRef, {
          'studentId': uid,
          'student': name.trim(),
          'roomId': null,
          'room': '',
          'amount': 5000,
          'amountPaid': 0,
          'remainingAmount': 5000,
          'feeType': 'Hostel Fee',
          'status': 'pending',
          'paid': false,
          'paidAt': null,
          'dueDate': DateTime(now.year, now.month + 1, 10).toIso8601String(),
          'feeMonth': feeMonth,
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        });
        await batch.commit();
      } catch (e) {
        // Do not silently leave an Auth account without a profile.
        try {
          await credential.user?.delete();
        } catch (_) {}
        rethrow;
      }

      return _buildAuthResponse(userData, message: 'Registration successful');
    } on FirebaseAuthException catch (e) {
      throw ApiException(_authErrorMessage(e));
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = _normalizeEmail(email);

    if (normalizedEmail.isEmpty) {
      throw ApiException('Email is required');
    }
    if (password.isEmpty) {
      throw ApiException('Password is required');
    }

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final uid = credential.user?.uid;
      if (uid == null || uid.isEmpty) {
        throw ApiException('Unable to sign in');
      }

      final userData = await _fetchUserProfile(uid);
      return _buildAuthResponse(userData);
    } on FirebaseAuthException catch (e) {
      throw ApiException(_authErrorMessage(e));
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  static Future<String> forgotPassword(String email) async {
    final normalizedEmail = _normalizeEmail(email);

    if (normalizedEmail.isEmpty) {
      throw ApiException('Email is required');
    }

    try {
      await _auth.sendPasswordResetEmail(email: normalizedEmail);
      return 'Password reset email sent. Check your inbox.';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return 'No user found with that email.';
      }
      throw ApiException(_authErrorMessage(e));
    }
  }

  // ---------------------------------------------------------------------------
  // CONTACTS
  // ---------------------------------------------------------------------------

  static Future<String> submitContact({
    required String name,
    required String phone,
    required String email,
    required String message,
  }) async {
    if (name.trim().isEmpty) throw ApiException('Name is required');
    if (email.trim().isEmpty) throw ApiException('Email is required');
    if (message.trim().isEmpty) throw ApiException('Message is required');

    try {
      await _db.collection('contacts').add({
        'name': name.trim(),
        'phone': phone.trim(),
        'email': _normalizeEmail(email),
        'message': message.trim(),
        'createdAt': _now(),
      });
      return 'Contact form submitted successfully';
    } catch (e) {
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  // ---------------------------------------------------------------------------
  // ADMISSIONS
  // ---------------------------------------------------------------------------

  static Future<String> submitAdmission({
    required String fullName,
    required String collegeId,
    required String email,
    required String phone,
    required String course,
    required String yearOfStudy,
    required String department,
    required String hostelType,
    required String roomType,
  }) async {
    if (fullName.trim().isEmpty) throw ApiException('Full name is required');
    if (email.trim().isEmpty) throw ApiException('Email is required');

    try {
      await _db.collection('admissions').add({
        'fullName': fullName.trim(),
        'collegeId': collegeId.trim(),
        'email': _normalizeEmail(email),
        'phone': phone.trim(),
        'course': course.trim(),
        'yearOfStudy': yearOfStudy.trim(),
        'department': department.trim(),
        'hostelType': hostelType.trim(),
        'roomType': roomType.trim(),
        'createdAt': _now(),
      });
      return 'Admission form submitted successfully';
    } catch (e) {
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  // ---------------------------------------------------------------------------
  // COMPLAINTS
  // ---------------------------------------------------------------------------

  static Future<void> submitComplaint({
  required String title,
  required String description,
  String category = 'Other',
  String priority = 'medium',
}) async {
  final uid = _requireAuthUid();

  final cleanTitle = title.trim();
  final cleanDescription = description.trim();
  final cleanCategory =
      category.trim().isEmpty ? 'Other' : category.trim();

  final cleanPriority = priority.trim().toLowerCase();

  if (cleanTitle.isEmpty) {
    throw ApiException('Complaint title is required');
  }

  if (cleanDescription.isEmpty) {
    throw ApiException('Complaint description is required');
  }

  const allowedPriorities = {
    'low',
    'medium',
    'high',
    'urgent',
  };

  if (!allowedPriorities.contains(cleanPriority)) {
    throw ApiException('Invalid complaint priority');
  }

  try {
    // ------------------------------------------------------------
    // LOAD CURRENT USER
    // ------------------------------------------------------------

    final userSnapshot = await _db
        .collection('users')
        .doc(uid)
        .get();

    final userData = userSnapshot.exists
        ? _docToMap(userSnapshot)
        : <String, dynamic>{};

    final roomId = _stringValue(userData['roomId']);

    final roomNumber = _stringValue(
      userData['roomNumber'] ??
          userData['roomNo'],
    );

    // ------------------------------------------------------------
    // CREATE COMPLAINT
    // ------------------------------------------------------------

    final complaintRef =
        _db.collection('complaints').doc();

    final now = _now();

    final complaintData = <String, dynamic>{
      'userId': uid,
      'title': cleanTitle,
      'description': cleanDescription,
      'category': cleanCategory,
      'priority': cleanPriority,
      'status': 'open',
      'createdAt': now,
      'updatedAt': now,
      'resolvedAt': null,
      'rating': null,
      'feedback': null,
      'ratedAt': null,
    };

    if (roomId.isNotEmpty) {
      complaintData['roomId'] = roomId;
    }

    if (roomNumber.isNotEmpty) {
      complaintData['roomNumber'] = roomNumber;
    }

    // ------------------------------------------------------------
    // IMPORTANT:
    // Create the complaint FIRST.
    //
    // Do NOT create the complaint and timeline in the same
    // batch because the timeline security rule uses get()
    // against the complaint document.
    // ------------------------------------------------------------

    await complaintRef.set(complaintData);

    // ------------------------------------------------------------
    // CREATE INITIAL TIMELINE EVENT
    // ------------------------------------------------------------

    final timelineRef = complaintRef
        .collection('timeline')
        .doc();

    await timelineRef.set({
      'type': 'created',
      'message': 'Complaint submitted',
      'status': 'open',
      'createdAt': now,
      'createdBy': uid,
    });
  } catch (e) {
    if (e is ApiException) {
      rethrow;
    }

    throw ApiException(_firebaseErrorMessage(e));
  }
}

static Stream<List<Map<String, dynamic>>> myComplaintsStream() {
  final uid = _requireAuthUid();

  return _db
      .collection('complaints')
      .where('userId', isEqualTo: uid)
      .snapshots()
      .map((snapshot) {
    final complaints =
        snapshot.docs.map(_docToMap).toList();

    _sortDescending(
      complaints,
      'createdAt',
    );

    return complaints;
  })
      .handleError((error) {
    throw ApiException(
      _firebaseErrorMessage(error),
    );
  });
}

  static Future<List<Map<String, dynamic>>> myComplaints() async {
    final uid = _requireAuthUid();

    try {
      final snapshot = await _db
          .collection('complaints')
          .where('userId', isEqualTo: uid)
          .get();

      final complaints = snapshot.docs.map(_docToMap).toList();
      _sortDescending(complaints, 'createdAt');
      return complaints;
    } catch (e) {
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  // ---------------------------------------------------------------------------
  // CHECK-INS / ROOMS FOR STUDENTS
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> myCheckins() async {
    final uid = _requireAuthUid();

    try {
      final checkinsSnapshot = await _db
          .collection('checkins')
          .where('userId', isEqualTo: uid)
          .get();

      final roomsSnapshot = await _db.collection('rooms').get();

      final roomsById = <String, Map<String, dynamic>>{
        for (final doc in roomsSnapshot.docs) doc.id: _docToMap(doc),
      };

      final checkins = <Map<String, dynamic>>[];

      for (final doc in checkinsSnapshot.docs) {
        final checkin = _docToMap(doc);
        final roomId = _stringValue(checkin['roomId']);
        final room = roomsById[roomId];

        if (room != null) {
          checkin['room'] = room;
        }

        checkins.add(checkin);
      }

      _sortDescending(checkins, 'checkInAt');
      return checkins;
    } catch (e) {
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  static Future<Map<String, dynamic>> myRoom() async {
  final uid = _requireAuthUid();

  try {
    // ------------------------------------------------------------
    // Get current student's profile
    // ------------------------------------------------------------

    final userDoc =
        await _db.collection('users').doc(uid).get();

    if (!userDoc.exists) {
      throw ApiException('Student profile not found');
    }

    final user = _docToMap(userDoc);

    final roomId = _stringValue(
      user['roomId'],
    );

    // ------------------------------------------------------------
    // No room assigned
    // ------------------------------------------------------------

    if (roomId.isEmpty) {
      return {
        'activeCheckin': null,
        'room': null,
        'roommates': <Map<String, dynamic>>[],
        'occupancy': 0,
        'capacity': 0,
        'availableBeds': 0,
        'assignmentDate': null,
      };
    }

    // ------------------------------------------------------------
    // Get room
    // ------------------------------------------------------------

    final roomDoc =
        await _db.collection('rooms').doc(roomId).get();

    if (!roomDoc.exists) {
      return {
        'activeCheckin': null,
        'room': null,
        'roommates': <Map<String, dynamic>>[],
        'occupancy': 0,
        'capacity': 0,
        'availableBeds': 0,
        'assignmentDate': null,
      };
    }

    final room = _docToMap(roomDoc);

    // ------------------------------------------------------------
    // Get room occupants
    //
    // IMPORTANT:
    // We use the occupants subcollection instead of querying
    // the entire users collection.
    //
    // This is allowed by the Firestore rules because the student
    // can read occupants of their assigned room.
    // ------------------------------------------------------------

    final occupantsSnapshot = await roomDoc.reference
        .collection('occupants')
        .get();

    final roommates = <Map<String, dynamic>>[];

    // ------------------------------------------------------------
    // Occupancy
    //
    // Each occupant document represents one assigned student.
    // Firestore document IDs are unique, so this count is unique.
    // ------------------------------------------------------------

    final occupancy = occupantsSnapshot.docs.length;

    // ------------------------------------------------------------
    // Capacity
    // ------------------------------------------------------------

    final capacity = _intValue(
      room['capacity'],
      fallback: 0,
    );

    final availableBeds = capacity > occupancy
        ? capacity - occupancy
        : 0;

    // ------------------------------------------------------------
    // Build roommates
    //
    // Current student is excluded from roommate list.
    // ------------------------------------------------------------

    for (final doc in occupantsSnapshot.docs) {
      final occupant = _docToMap(doc);

      final occupantUserId =
          _stringValue(occupant['userId']);

      // Some older occupant documents may use the document ID
      // instead of userId.
      final studentId = occupantUserId.isEmpty
          ? doc.id
          : occupantUserId;

      // Do not show yourself as a roommate.
      if (studentId == uid) {
        continue;
      }

      final name = _stringValue(
        occupant['name'],
      );

      final status = _stringValue(
        occupant['status'],
      );

      roommates.add({
        'userId': studentId,
        'name': name.isEmpty
            ? 'Student'
            : name,
        'role': _stringValue(
          occupant['role'],
        ).isEmpty
            ? 'student'
            : _stringValue(
                occupant['role'],
              ),
        'status': status.isEmpty
            ? 'Not checked in'
            : status,
        'checkInAt': occupant['checkInAt'],
        'isCurrentUser': false,
      });
    }

    // ------------------------------------------------------------
    // Sort roommates alphabetically
    // ------------------------------------------------------------

    roommates.sort((a, b) {
      return _stringValue(
        a['name'],
      ).compareTo(
        _stringValue(
          b['name'],
        ),
      );
    });

    // ------------------------------------------------------------
    // Get current student's active check-in
    // ------------------------------------------------------------

    final checkinsSnapshot = await _db
        .collection('checkins')
        .where(
          'userId',
          isEqualTo: uid,
        )
        .get();

    Map<String, dynamic>? activeCheckin;

    for (final doc in checkinsSnapshot.docs) {
      final checkin = _docToMap(doc);

      final checkOutAt =
          checkin['checkOutAt'];

      final isActive =
          checkOutAt == null ||
          checkOutAt.toString().trim().isEmpty;

      if (isActive) {
        activeCheckin = checkin;
        break;
      }
    }

    // ------------------------------------------------------------
    // Assignment date
    // ------------------------------------------------------------

    final assignmentDate =
        activeCheckin?['checkInAt'];

    // ------------------------------------------------------------
    // Return
    // ------------------------------------------------------------

    return {
      'activeCheckin': activeCheckin,
      'room': room,
      'roommates': roommates,
      'occupancy': occupancy,
      'capacity': capacity,
      'availableBeds': availableBeds,
      'assignmentDate': assignmentDate,
    };
  } catch (e) {
    if (e is ApiException) {
      rethrow;
    }

    throw ApiException(
      _firebaseErrorMessage(e),
    );
  }
}

  // ---------------------------------------------------------------------------
  // ADMIN DASHBOARD
  // ---------------------------------------------------------------------------

  

static Future<Map<String, dynamic>> adminDashboard() async {
  await _requireAdmin();

  try {
    // ------------------------------------------------------------
    // Load dashboard collections
    // ------------------------------------------------------------
    final usersSnapshot = await _db.collection('users').get();
    final roomsSnapshot = await _db.collection('rooms').get();
    final checkinsSnapshot = await _db.collection('checkins').get();
    final complaintsSnapshot = await _db.collection('complaints').get();

    // ------------------------------------------------------------
    // USERS
    // ------------------------------------------------------------
    var students = 0;
    var admins = 0;

    for (final doc in usersSnapshot.docs) {
      final user = _docToMap(doc);
      final role = _stringValue(user['role']).toLowerCase();

      if (role == 'admin') {
        admins++;
      } else {
        students++;
      }
    }

    // ------------------------------------------------------------
    // ROOMS
    // ------------------------------------------------------------
    var rooms = 0;
    var totalCapacity = 0;
    var occupiedBeds = 0;

    for (final doc in roomsSnapshot.docs) {
      final room = _docToMap(doc);

      rooms++;

      final capacity = _intValue(room['capacity']);
      final occupied = _intValue(room['occupiedCount']);

      totalCapacity += capacity;
      occupiedBeds += occupied;
    }

    // Prevent invalid values if old room data has
    // occupiedCount greater than capacity.
    if (occupiedBeds > totalCapacity) {
      occupiedBeds = totalCapacity;
    }

    final availableBeds =
        (totalCapacity - occupiedBeds).clamp(0, totalCapacity);

    final occupancyPercentage = totalCapacity > 0
        ? (occupiedBeds / totalCapacity) * 100
        : 0.0;

    // ------------------------------------------------------------
    // CHECK-INS
    // ------------------------------------------------------------
    var activeCheckins = 0;

    for (final doc in checkinsSnapshot.docs) {
      final checkin = _docToMap(doc);

      final checkOutAt = checkin['checkOutAt'];

      if (checkOutAt == null ||
          checkOutAt.toString().trim().isEmpty) {
        activeCheckins++;
      }
    }

    // ------------------------------------------------------------
    // COMPLAINTS
    // ------------------------------------------------------------
    var openComplaints = 0;
    var inProgressComplaints = 0;
    var resolvedComplaints = 0;
    var closedComplaints = 0;

    for (final doc in complaintsSnapshot.docs) {
      final complaint = _docToMap(doc);

      final status =
          _stringValue(complaint['status']).toLowerCase().trim();

      switch (status) {
        case 'in_progress':
        case 'in progress':
          inProgressComplaints++;
          break;

        case 'resolved':
          resolvedComplaints++;
          break;

        case 'closed':
          closedComplaints++;
          break;

        case 'open':
        default:
          openComplaints++;
          break;
      }
    }

    // ------------------------------------------------------------
    // RETURN DASHBOARD DATA
    // ------------------------------------------------------------
    return {
      'students': students,
      'admins': admins,
      'rooms': rooms,

      'totalCapacity': totalCapacity,
      'occupiedBeds': occupiedBeds,
      'availableBeds': availableBeds,
      'occupancyPercentage': occupancyPercentage,

      'activeCheckins': activeCheckins,

      'totalComplaints': complaintsSnapshot.docs.length,
      'openComplaints': openComplaints,
      'inProgressComplaints': inProgressComplaints,
      'resolvedComplaints': resolvedComplaints,
      'closedComplaints': closedComplaints,
    };
  } catch (e) {
    throw ApiException(_firebaseErrorMessage(e));
  }
}

static Future<List<Map<String, dynamic>>> complaintTimeline(
  String complaintId,
) async {
  final uid = _requireAuthUid();

  final normalizedId = complaintId.trim();

  if (normalizedId.isEmpty) {
    throw ApiException('Complaint ID is required');
  }

  try {
    final complaintRef =
        _db.collection('complaints').doc(normalizedId);

    final complaintDoc = await complaintRef.get();

    if (!complaintDoc.exists) {
      throw ApiException('Complaint not found');
    }

    final complaint = _docToMap(complaintDoc);

    if (_stringValue(complaint['userId']) != uid) {
      throw ApiException(
        'You can only view your own complaint timeline',
      );
    }

    final snapshot = await complaintRef
        .collection('timeline')
        .orderBy('createdAt', descending: false)
        .get();

    return snapshot.docs.map(_docToMap).toList();
  } catch (e) {
    if (e is ApiException) rethrow;

    throw ApiException(
      _firebaseErrorMessage(e),
    );
  }
}

  // ---------------------------------------------------------------------------
  // ADMIN USERS
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> adminListUsers() async {
    await _requireAdmin();

    try {
      final snapshot = await _db.collection('users').get();
      return snapshot.docs.map((doc) => _safeUser(_docToMap(doc))).toList();
    } catch (e) {
      throw ApiException(_firebaseErrorMessage(e));
    }
  }


  /// Returns a complete hostel-management view of every student.
  ///
  /// The result combines:
  /// Student -> Current Room -> Wing/Block -> Fee Status ->
  /// Check-in Status -> Complaint Count -> Visitor Count.
  ///
  /// This intentionally performs the joins in the service layer so the
  /// Admin Students page does not need to know the Firestore schema.
  static Future<List<Map<String, dynamic>>> adminStudentManagementData() async {
  await _requireAdmin();

  try {
    final results = await Future.wait([
      _db.collection('users').get(),
      _db.collection('rooms').get(),
      _db.collection('checkins').get(),
      _db.collection('dues').get(),
      _db.collection('complaints').get(),
      _db.collection('visitors').get(),
    ]);

    final usersSnapshot = results[0];
    final roomsSnapshot = results[1];
    final checkinsSnapshot = results[2];
    final duesSnapshot = results[3];
    final complaintsSnapshot = results[4];
    final visitorsSnapshot = results[5];

    final roomsById = <String, Map<String, dynamic>>{
      for (final doc in roomsSnapshot.docs) doc.id: _docToMap(doc),
    };

    // Only the latest active check-in is relevant to "Current Room".
    final activeCheckinByStudentId =
        <String, Map<String, dynamic>>{};

    for (final doc in checkinsSnapshot.docs) {
      final checkin = _docToMap(doc);
      final studentId = _stringValue(checkin['userId']);

      if (studentId.isEmpty) continue;
      if (_stringValue(checkin['checkOutAt']).isNotEmpty) continue;

      final existing =
          activeCheckinByStudentId[studentId];

      if (existing == null ||
          _dateValue(checkin['checkInAt'])
              .isAfter(
                _dateValue(existing['checkInAt']),
              )) {
        activeCheckinByStudentId[studentId] = checkin;
      }
    }

      final duesByStudentId = <String, List<Map<String, dynamic>>>{};

      for (final doc in duesSnapshot.docs) {
        final due = _docToMap(doc);
        final studentId = _stringValue(due['studentId']);

        if (studentId.isEmpty) continue;

        duesByStudentId.putIfAbsent(studentId, () => <Map<String, dynamic>>[]);
        duesByStudentId[studentId]!.add(due);
      }

      final complaintCountByStudentId = <String, int>{};

      for (final doc in complaintsSnapshot.docs) {
        final complaint = _docToMap(doc);
        final studentId = _stringValue(complaint['userId']);

        if (studentId.isEmpty) continue;

        complaintCountByStudentId[studentId] =
            (complaintCountByStudentId[studentId] ?? 0) + 1;
      }

      final visitorCountByStudentId = <String, int>{};

      for (final doc in visitorsSnapshot.docs) {
        final visitor = _docToMap(doc);
        final studentId = _stringValue(visitor['studentId']);

        if (studentId.isEmpty) continue;

        visitorCountByStudentId[studentId] =
            (visitorCountByStudentId[studentId] ?? 0) + 1;
      }

      final students = <Map<String, dynamic>>[];

      for (final doc in usersSnapshot.docs) {
        final user = _docToMap(doc);

        if (_roleOf(user) != 'student') continue;

        final studentId = doc.id;
        final student = _safeUser(user);

        final activeCheckin = activeCheckinByStudentId[studentId];
        final roomId = _stringValue(activeCheckin?['roomId']);
        final room = roomId.isEmpty ? null : roomsById[roomId];

        final studentDues = duesByStudentId[studentId] ?? <Map<String, dynamic>>[];

        var totalFeeAmount = 0;
        var totalFeePaid = 0;
        var totalFeeRemaining = 0;
        var hasPending = false;
        var hasOverdue = false;
        var hasPartial = false;

        for (final fee in studentDues) {
          final amount = _intValue(fee['amount']);
          final paid = _intValue(fee['amountPaid']);
          final remaining = fee.containsKey('remainingAmount')
              ? _intValue(fee['remainingAmount'])
              : (amount - paid > 0 ? amount - paid : 0);

          final status = _feeStatus(fee);

          totalFeeAmount += amount;
          totalFeePaid += paid;
          totalFeeRemaining += remaining;

          if (status == 'overdue') hasOverdue = true;
          if (status == 'partial') hasPartial = true;
          if (status == 'pending') hasPending = true;
        }

        String feeStatus;

        if (studentDues.isEmpty) {
          feeStatus = 'no_record';
        } else if (hasOverdue) {
          feeStatus = 'overdue';
        } else if (hasPartial || hasPending || totalFeeRemaining > 0) {
          feeStatus = 'pending';
        } else {
          feeStatus = 'paid';
        }

        student['currentRoom'] = room == null
            ? null
            : <String, dynamic>{
                'id': roomId,
                'roomNo': room['roomNo'],
                'building': room['building'],
                'floor': room['floor'],
                'type': room['type'],
                'capacity': room['capacity'],
                'occupiedCount': room['occupiedCount'],
                'status': room['status'],
              };

        student['currentRoomId'] = roomId;
        student['currentRoomNumber'] =
            room == null ? '' : _stringValue(room['roomNo']);
        student['currentBlock'] =
            room == null ? '' : _stringValue(room['building']);
        student['currentFloor'] = room?['floor'];

        student['checkInStatus'] = activeCheckin == null
            ? 'checked_out'
            : 'checked_in';
        student['activeCheckin'] = activeCheckin;

        student['feeStatus'] = feeStatus;
        student['feeRecordCount'] = studentDues.length;
        student['feeTotalAmount'] = totalFeeAmount;
        student['feePaidAmount'] = totalFeePaid;
        student['feeRemainingAmount'] = totalFeeRemaining;

        student['complaintCount'] = complaintCountByStudentId[studentId] ?? 0;
        student['visitorCount'] = visitorCountByStudentId[studentId] ?? 0;

        students.add(student);
      }

      students.sort((a, b) {
        return _stringValue(a['name'])
            .toLowerCase()
            .compareTo(_stringValue(b['name']).toLowerCase());
      });

      return students;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  static Future<Map<String, dynamic>> adminUpdateUser(
    String id, {
    String? role,
    String? name,
    String? phone,
    String? email,
    String? gender,
    String? age,
    String? address,
    String? parentName,
    String? parentPhone,
    String? parentOccupation,
  }) async {
    await _requireAdmin();

    final normalizedId = id.trim();
    if (normalizedId.isEmpty) throw ApiException('User ID is required');

    final updates = <String, dynamic>{};

    if (role != null) {
      final normalizedRole = role.trim().toLowerCase();
      if (normalizedRole != 'admin' && normalizedRole != 'student') {
        throw ApiException('Invalid user role');
      }
      updates['role'] = normalizedRole;
    }

    if (name != null) {
      if (name.trim().isEmpty) throw ApiException('Name cannot be empty');
      updates['name'] = name.trim();
    }

    if (phone != null) updates['phone'] = phone.trim();
    if (email != null) updates['email'] = _normalizeEmail(email);
    if (gender != null) updates['gender'] = gender.trim();
    if (age != null) updates['age'] = age.trim();
    if (address != null) updates['address'] = address.trim();
    if (parentName != null) updates['parentName'] = parentName.trim();
    if (parentPhone != null) updates['parentPhone'] = parentPhone.trim();
    if (parentOccupation != null) {
      updates['parentOccupation'] = parentOccupation.trim();
    }

    if (updates.isEmpty) throw ApiException('No fields to update');

    try {
      final docRef = _db.collection('users').doc(normalizedId);
      final doc = await docRef.get();

      if (!doc.exists) throw ApiException('User not found');

      final updatedName = updates['name'] ?? doc.data()?['name'] ?? 'Student';
      final activityRef = _db.collection('activityLogs').doc();
      final batch = _db.batch();
      batch.update(docRef, updates);
      batch.set(
        activityRef,
        await _activityData(
          action: 'student.updated',
          entity: 'student',
          entityId: normalizedId,
          description: 'Updated student $updatedName.',
        ),
      );
      await batch.commit();
      return _safeUser(_docToMap(await docRef.get()));
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

    static Future<String> adminCreateStudent({
      required String name,
      required String email,
      required String password,
      required String gender,
      required String age,
      required String phone,
      required String address,
      required String parentName,
      required String parentPhone,
      required String parentOccupation,
    }) async {
      await _requireAdmin();

      final normalizedEmail = _normalizeEmail(email);
      if (name.trim().isEmpty ||
          normalizedEmail.isEmpty ||
          gender.trim().isEmpty ||
          age.trim().isEmpty ||
          phone.trim().isEmpty ||
          address.trim().isEmpty ||
          parentName.trim().isEmpty ||
          parentPhone.trim().isEmpty ||
          parentOccupation.trim().isEmpty) {
        throw ApiException('Complete all student and parent fields');
      }
      if (password.length < 6) {
        throw ApiException('Password must contain at least 6 characters');
      }

      FirebaseApp? accountApp;
      User? createdUser;
      var profileCommitted = false;
      try {
        accountApp = await Firebase.initializeApp(
          name: 'student-admin-${DateTime.now().microsecondsSinceEpoch}',
          options: Firebase.app().options,
        );
        final accountAuth = FirebaseAuth.instanceFor(app: accountApp);
        final credential = await accountAuth.createUserWithEmailAndPassword(
          email: normalizedEmail,
          password: password,
        );
        createdUser = credential.user;
        final uid = createdUser?.uid;
        if (uid == null || uid.isEmpty) {
          throw ApiException('Unable to create student account');
        }

        final now = DateTime.now();
        final student = <String, dynamic>{
          'id': uid,
          'name': name.trim(),
          'email': normalizedEmail,
          'gender': gender.trim(),
          'age': age.trim(),
          'phone': phone.trim(),
          'address': address.trim(),
          'parentName': parentName.trim(),
          'parentPhone': parentPhone.trim(),
          'parentOccupation': parentOccupation.trim(),
          'role': 'student',
          'createdAt': now.toIso8601String(),
        };
        final feeMonth =
            '${now.year}-${now.month.toString().padLeft(2, '0')}';
        final userRef = _db.collection('users').doc(uid);
        final feeRef = _db.collection('dues').doc();
        final activityRef = _db.collection('activityLogs').doc();
        final batch = _db.batch();
        batch.set(userRef, student);
        batch.set(feeRef, {
          'studentId': uid,
          'student': name.trim(),
          'roomId': null,
          'room': '',
          'amount': 5000,
          'amountPaid': 0,
          'remainingAmount': 5000,
          'feeType': 'Hostel Fee',
          'status': 'pending',
          'paid': false,
          'paidAt': null,
          'dueDate': DateTime(now.year, now.month + 1, 10).toIso8601String(),
          'feeMonth': feeMonth,
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
          'createdBy': _requireAuthUid(),
        });
        batch.set(
          activityRef,
          await _activityData(
            action: 'student.created',
            entity: 'student',
            entityId: uid,
            description:
                'Added student ${name.trim()} and assigned the initial ₹5000 hostel fee.',
          ),
        );
        await batch.commit();
        profileCommitted = true;
        return uid;
      } on FirebaseAuthException catch (e) {
        if (createdUser != null && !profileCommitted) {
          await createdUser.delete();
        }
        throw ApiException(_authErrorMessage(e));
      } on ApiException {
        if (createdUser != null && !profileCommitted) {
          await createdUser.delete();
        }
        rethrow;
      } catch (e) {
        if (createdUser != null && !profileCommitted) {
          await createdUser.delete();
        }
        throw ApiException(_firebaseErrorMessage(e));
      } finally {
        if (accountApp != null) {
          try {
            await FirebaseAuth.instanceFor(app: accountApp).signOut();
            await accountApp.delete();
          } catch (e) {
            if (!profileCommitted) rethrow;
            throw ApiException(
              'Student and initial fee were saved, but the temporary auth '
              'session could not be closed: ${_firebaseErrorMessage(e)}',
            );
          }
        }
      }
    }

    static Future<List<Map<String, dynamic>>> adminListActivity() async {
      await _requireAdmin();
      try {
        final snapshot = await _db
            .collection('activityLogs')
            .orderBy('createdAt', descending: true)
            .get();
        return snapshot.docs.map(_docToMap).toList();
      } catch (e) {
        throw ApiException(_firebaseErrorMessage(e));
      }
    }

    static Future<int> adminGenerateMonthlyDues() async {
      await _requireAdmin();
      try {
        final studentsSnapshot = await _db
            .collection('users')
            .where('role', isEqualTo: 'student')
            .get();
        final duesSnapshot = await _db.collection('dues').get();
        final now = DateTime.now();
        final feeMonth =
            '${now.year}-${now.month.toString().padLeft(2, '0')}';
        final existingStudentMonths = <String>{
          for (final doc in duesSnapshot.docs)
            if (_stringValue(doc.data()['feeMonth']) == feeMonth &&
                _stringValue(doc.data()['feeType']).toLowerCase() ==
                    'hostel fee')
              _stringValue(doc.data()['studentId']),
        };
        final pendingStudents = studentsSnapshot.docs
            .where((student) => !existingStudentMonths.contains(student.id))
            .toList();
        final adminId = _requireAuthUid();
        final activity = _db.collection('activityLogs').doc();

        for (var start = 0; start < pendingStudents.length; start += 400) {
          final batch = _db.batch();
          for (final student in pendingStudents.skip(start).take(400)) {
            final feeRef = _db
                .collection('dues')
                .doc('monthly_${student.id}_$feeMonth');
            batch.set(feeRef, {
              'studentId': student.id,
              'student': _stringValue(student.data()['name']),
              'roomId': null,
              'room': '',
              'amount': 5000,
              'amountPaid': 0,
              'remainingAmount': 5000,
              'feeType': 'Hostel Fee',
              'status': 'pending',
              'paid': false,
              'paidAt': null,
              'dueDate':
                  DateTime(now.year, now.month + 1, 10).toIso8601String(),
              'feeMonth': feeMonth,
              'createdAt': now.toIso8601String(),
              'updatedAt': now.toIso8601String(),
              'createdBy': adminId,
            });
          }
          if (start == 0) {
            batch.set(
              activity,
              await _activityData(
                action: 'fees.monthly_generated',
                entity: 'fees',
                entityId: feeMonth,
                description:
                    'Generated ${pendingStudents.length} monthly hostel fee record(s) for $feeMonth.',
              ),
            );
          }
          await batch.commit();
        }
        if (pendingStudents.isEmpty) {
          await _recordAdminActivity(
            action: 'fees.monthly_generated',
            entity: 'fees',
            entityId: feeMonth,
            description: 'No new monthly hostel fee records were needed for $feeMonth.',
          );
        }
        return pendingStudents.length;
      } catch (e) {
        if (e is ApiException) rethrow;
        throw ApiException(_firebaseErrorMessage(e));
      }
    }

  // ---------------------------------------------------------------------------
  // ADMIN ROOMS
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> adminListRooms() async {
    await _requireAdmin();

    try {
      final snapshot = await _db.collection('rooms').get();
      return snapshot.docs.map(_docToMap).toList();
    } catch (e) {
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  static Future<List<Map<String, dynamic>>> availableRooms() async {
    try {
      final snapshot = await _db.collection('rooms').get();
      return snapshot.docs
          .map(_docToMap)
          .where((room) {
            final status = _stringValue(room['status']).toLowerCase();
            final capacity = int.tryParse(_stringValue(room['capacity'])) ?? 0;
            final occupied =
                int.tryParse(_stringValue(room['occupiedCount'])) ?? 0;
            return status != 'maintenance' && capacity > occupied;
          })
          .toList();
    } catch (e) {
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  static Future<String> adminCreateRoom({
    required String building,
    required String roomNo,
    required String type,
    required int capacity,
    int floor = 0,
    String status = 'available',
  }) async {
    await _requireAdmin();

    if (building.trim().isEmpty) throw ApiException('Building is required');
    if (roomNo.trim().isEmpty) throw ApiException('Room number is required');
    if (type.trim().isEmpty) throw ApiException('Room type is required');
    if (capacity <= 0) throw ApiException('Capacity must be greater than 0');

    try {
      final roomRef = _db.collection('rooms').doc();
      final activityRef = _db.collection('activityLogs').doc();
      final batch = _db.batch();
      batch.set(roomRef, {
        'building': building.trim(),
        'floor': floor,
        'roomNo': roomNo.trim(),
        'capacity': capacity,
        'occupiedCount': 0,
        'type': type.trim(),
        'status': status.trim(),
        'roomImages': <String>[],
        'createdAt': _now(),
      });
      batch.set(
        activityRef,
        await _activityData(
          action: 'room.created',
          entity: 'room',
          entityId: roomRef.id,
          description: 'Created room ${roomNo.trim()} in ${building.trim()}.',
        ),
      );
      await batch.commit();
      return roomRef.id;
    } catch (e) {
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  static Future<void> adminUpdateRoom(
    String id, {
    String? building,
    String? roomNo,
    String? type,
    int? capacity,
    int? floor,
    String? status,
    List<String>? roomImages,
  }) async {
    await _requireAdmin();

    final normalizedId = id.trim();
    if (normalizedId.isEmpty) throw ApiException('Room ID is required');

    final updates = <String, dynamic>{};

    if (building != null) {
      if (building.trim().isEmpty) throw ApiException('Building cannot be empty');
      updates['building'] = building.trim();
    }
    if (roomNo != null) {
      if (roomNo.trim().isEmpty) throw ApiException('Room number cannot be empty');
      updates['roomNo'] = roomNo.trim();
    }
    if (type != null) {
      if (type.trim().isEmpty) throw ApiException('Room type cannot be empty');
      updates['type'] = type.trim();
    }
    if (capacity != null) {
      if (capacity <= 0) throw ApiException('Capacity must be greater than 0');
      updates['capacity'] = capacity;
    }
    if (floor != null) updates['floor'] = floor;
    if (status != null) updates['status'] = status.trim();
    if (roomImages != null) updates['roomImages'] = roomImages;

    if (updates.isEmpty) throw ApiException('No fields to update');

    try {
      final docRef = _db.collection('rooms').doc(normalizedId);
      final doc = await docRef.get();
      if (!doc.exists) throw ApiException('Room not found');
      final batch = _db.batch();
      batch.update(docRef, updates);
      final activityRef = _db.collection('activityLogs').doc();
      batch.set(
        activityRef,
        await _activityData(
          action: 'room.updated',
          entity: 'room',
          entityId: normalizedId,
          description:
              'Updated room ${_stringValue(updates['roomNo'] ?? doc.data()?['roomNo'])}.',
        ),
      );
      await batch.commit();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  // ---------------------------------------------------------------------------
  // ADMIN COMPLAINTS
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> adminListComplaints() async {
    await _requireAdmin();

    try {
      final complaintsSnapshot = await _db.collection('complaints').get();
      final usersSnapshot = await _db.collection('users').get();

      final usersById = <String, Map<String, dynamic>>{
        for (final doc in usersSnapshot.docs)
          doc.id: _safeUser(_docToMap(doc)),
      };

      final result = <Map<String, dynamic>>[];

      for (final doc in complaintsSnapshot.docs) {
        final complaint = _docToMap(doc);
        final user = usersById[_stringValue(complaint['userId'])];
        if (user != null) complaint['user'] = user;
        result.add(complaint);
      }

      _sortDescending(result, 'createdAt');
      return result;
    } catch (e) {
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  static Future<void> adminUpdateComplaintStatus(
  String id,
  String status,
) async {
  await _requireAdmin();
final adminUid = _requireAuthUid();

  final normalizedId = id.trim();
  final normalizedStatus = status.trim().toLowerCase();

  if (normalizedId.isEmpty) {
    throw ApiException('Complaint ID is required');
  }

  const allowedStatuses = {
    'open',
    'in_progress',
    'resolved',
    'closed',
  };

  if (!allowedStatuses.contains(normalizedStatus)) {
    throw ApiException('Invalid complaint status');
  }

  try {
    final docRef =
        _db.collection('complaints').doc(normalizedId);

    final doc = await docRef.get();

    if (!doc.exists) {
      throw ApiException('Complaint not found');
    }

    final complaint = _docToMap(doc);

    final previousStatus =
        _stringValue(complaint['status']);

    if (previousStatus == normalizedStatus) {
      return;
    }

    final now = _now();

    final updates = <String, dynamic>{
      'status': normalizedStatus,
      'updatedAt': now,
    };

    if (normalizedStatus == 'resolved' ||
        normalizedStatus == 'closed') {
      updates['resolvedAt'] = now;
    } else {
      updates['resolvedAt'] = null;
    }

    final timelineRef = docRef
        .collection('timeline')
        .doc();
    final activityRef = _db.collection('activityLogs').doc();

    final batch = _db.batch();

    batch.update(
      docRef,
      updates,
    );

    batch.set(
      timelineRef,
      {
        'type': 'status_changed',
        'message':
            'Status changed from $previousStatus to $normalizedStatus',
        'status': normalizedStatus,
        'createdAt': now,
        'createdBy': adminUid,
      },
    );
    batch.set(
      activityRef,
      await _activityData(
        action: 'complaint.status_updated',
        entity: 'complaint',
        entityId: normalizedId,
        description:
            'Changed complaint status from $previousStatus to $normalizedStatus.',
      ),
    );

    await batch.commit();
  } catch (e) {
    if (e is ApiException) rethrow;

    throw ApiException(
      _firebaseErrorMessage(e),
    );
  }
}

static Future<List<Map<String, dynamic>>> adminComplaintTimeline(
  String complaintId,
) async {
  await _requireAdmin();

  final normalizedId = complaintId.trim();

  if (normalizedId.isEmpty) {
    throw ApiException('Complaint ID is required');
  }

  try {
    final complaintRef =
        _db.collection('complaints').doc(normalizedId);

    final complaintDoc = await complaintRef.get();

    if (!complaintDoc.exists) {
      throw ApiException('Complaint not found');
    }

    final snapshot = await complaintRef
        .collection('timeline')
        .orderBy('createdAt', descending: false)
        .get();

    return snapshot.docs.map(_docToMap).toList();
  } catch (e) {
    if (e is ApiException) rethrow;

    throw ApiException(
      _firebaseErrorMessage(e),
    );
  }
}

static Future<void> reopenComplaint(String id) async {
  final uid = _requireAuthUid();

  final normalizedId = id.trim();

  if (normalizedId.isEmpty) {
    throw ApiException('Complaint ID is required');
  }

  try {
    final complaintRef =
        _db.collection('complaints').doc(normalizedId);

    final doc = await complaintRef.get();

    if (!doc.exists) {
      throw ApiException('Complaint not found');
    }

    final complaint = _docToMap(doc);

    if (_stringValue(complaint['userId']) != uid) {
      throw ApiException(
        'You can only reopen your own complaints',
      );
    }

    final currentStatus =
        _stringValue(complaint['status']).toLowerCase();

    if (currentStatus != 'resolved' &&
        currentStatus != 'closed') {
      throw ApiException(
        'Only resolved complaints can be reopened',
      );
    }

    final now = _now();

    final timelineRef = complaintRef
        .collection('timeline')
        .doc();

    final batch = _db.batch();

    batch.update(
      complaintRef,
      {
        'status': 'open',
        'updatedAt': now,
        'resolvedAt': null,
      },
    );

    batch.set(
      timelineRef,
      {
        'type': 'reopened',
        'message': 'Complaint reopened by student',
        'status': 'open',
        'createdAt': now,
        'createdBy': uid,
      },
    );

    await batch.commit();
  } catch (e) {
    if (e is ApiException) rethrow;

    throw ApiException(
      _firebaseErrorMessage(e),
    );
  }
}

static Future<void> rateComplaint(
  String id, {
  required int rating,
  String feedback = '',
}) async {
  final uid = _requireAuthUid();

  final normalizedId = id.trim();

  if (normalizedId.isEmpty) {
    throw ApiException('Complaint ID is required');
  }

  if (rating < 1 || rating > 5) {
    throw ApiException(
      'Rating must be between 1 and 5',
    );
  }

  try {
    final complaintRef =
        _db.collection('complaints').doc(normalizedId);

    final doc = await complaintRef.get();

    if (!doc.exists) {
      throw ApiException('Complaint not found');
    }

    final complaint = _docToMap(doc);

    if (_stringValue(complaint['userId']) != uid) {
      throw ApiException(
        'You can only rate your own complaints',
      );
    }

    final status =
    _stringValue(complaint['status']).toLowerCase();

if (status != 'resolved' && status != 'closed') {
  throw ApiException(
    'You can rate a complaint only after it is resolved',
  );
}

if (complaint['rating'] != null) {
  throw ApiException(
    'This complaint has already been rated',
  );
}

    final now = _now();

    await complaintRef.update({
      'rating': rating,
      'feedback': feedback.trim(),
      'ratedAt': now,
      'updatedAt': now,
    });
  } catch (e) {
    if (e is ApiException) rethrow;

    throw ApiException(
      _firebaseErrorMessage(e),
    );
  }
}

  // ---------------------------------------------------------------------------
  // ADMIN CHECK-INS
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> adminListCheckins() async {
    await _requireAdmin();

    try {
      final checkinsSnapshot = await _db.collection('checkins').get();
      final usersSnapshot = await _db.collection('users').get();
      final roomsSnapshot = await _db.collection('rooms').get();

      final usersById = <String, Map<String, dynamic>>{
        for (final doc in usersSnapshot.docs)
          doc.id: _safeUser(_docToMap(doc)),
      };

      final roomsById = <String, Map<String, dynamic>>{
        for (final doc in roomsSnapshot.docs) doc.id: _docToMap(doc),
      };

      final result = <Map<String, dynamic>>[];

      for (final doc in checkinsSnapshot.docs) {
        final checkin = _docToMap(doc);
        final user = usersById[_stringValue(checkin['userId'])];
        final room = roomsById[_stringValue(checkin['roomId'])];

        if (user != null) checkin['user'] = user;
        if (room != null) checkin['room'] = room;

        result.add(checkin);
      }

      _sortDescending(result, 'checkInAt');
      return result;
    } catch (e) {
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  static Future<void> adminCheckIn({
  required String userId,
  required String roomId,
}) async {
  await _requireAdmin();

  final normalizedUserId = userId.trim();
  final normalizedRoomId = roomId.trim();

  if (normalizedUserId.isEmpty) {
    throw ApiException('User ID is required');
  }

  if (normalizedRoomId.isEmpty) {
    throw ApiException('Room ID is required');
  }

  try {
    final userRef =
        _db.collection('users').doc(normalizedUserId);

    final roomRef =
        _db.collection('rooms').doc(normalizedRoomId);

    final occupantRef = roomRef
        .collection('occupants')
        .doc(normalizedUserId);

    final userDoc = await userRef.get();

    if (!userDoc.exists) {
      throw ApiException('User not found');
    }

    final user = _docToMap(userDoc);

    if (_roleOf(user) != 'student') {
      throw ApiException('Only students can be checked in');
    }

    // ------------------------------------------------------------
    // Check whether student already has an active check-in
    // ------------------------------------------------------------

    final activeCheckins = await _db
        .collection('checkins')
        .where(
          'userId',
          isEqualTo: normalizedUserId,
        )
        .get();

    final alreadyActive = activeCheckins.docs.any(
      (doc) {
        final checkin = _docToMap(doc);

        return _stringValue(
          checkin['checkOutAt'],
        ).isEmpty;
      },
    );

    if (alreadyActive) {
      throw ApiException('User already checked-in');
    }

    // ------------------------------------------------------------
    // Transaction
    // ------------------------------------------------------------

    final checkinRef =
        _db.collection('checkins').doc();
    final activityRef = _db.collection('activityLogs').doc();
    final activity = await _activityData(
      action: 'room.checkin',
      entity: 'student',
      entityId: normalizedUserId,
      description:
          'Checked in ${_stringValue(user['name'], fallback: 'Student')} '
          'to room ${_stringValue((await roomRef.get()).data()?['roomNo'], fallback: normalizedRoomId)}.',
    );

    await _db.runTransaction((transaction) async {
      final roomSnap = await transaction.get(roomRef);

      if (!roomSnap.exists) {
        throw ApiException('Room not found');
      }

      final room = _docToMap(roomSnap);

      final capacity = _intValue(
        room['capacity'],
        fallback: 1,
      );

      final occupied = _intValue(
        room['occupiedCount'],
      );

      if (occupied >= capacity) {
        throw ApiException('Room is full');
      }

      final newOccupied = occupied + 1;

      // ----------------------------------------------------------
      // Create check-in
      // ----------------------------------------------------------

      transaction.set(checkinRef, {
        'userId': normalizedUserId,
        'roomId': normalizedRoomId,
        'checkInAt': _now(),
        'checkOutAt': '',
      });

      // ----------------------------------------------------------
      // Update room
      // ----------------------------------------------------------

      transaction.update(roomRef, {
        'occupiedCount': newOccupied,
        'status': newOccupied >= capacity
            ? 'full'
            : 'available',
      });

      // ----------------------------------------------------------
      // IMPORTANT:
      // Store room assignment on student profile
      // ----------------------------------------------------------

      transaction.update(userRef, {
        'roomId': normalizedRoomId,
      });

      // ----------------------------------------------------------
      // Create room occupant record
      // ----------------------------------------------------------

      transaction.set(
        occupantRef,
        {
          'userId': normalizedUserId,
          'name': _stringValue(user['name']).isEmpty
              ? 'Student'
              : _stringValue(user['name']),
          'status': 'checkedIn',
          'checkInAt': _now(),
        },
      );
      transaction.set(activityRef, activity);
    });
  } catch (e) {
    if (e is ApiException) {
      rethrow;
    }

    throw ApiException(
      _firebaseErrorMessage(e),
    );
  }
}

  static Future<void> adminCheckOut({
  required String checkinId,
}) async {
  await _requireAdmin();

  final normalizedId = checkinId.trim();

  if (normalizedId.isEmpty) {
    throw ApiException('Check-in ID is required');
  }

  try {
    final checkinRef =
        _db.collection('checkins').doc(normalizedId);
    final activityRef = _db.collection('activityLogs').doc();
    final activity = await _activityData(
      action: 'room.checkout',
      entity: 'student',
      entityId: normalizedId,
      description: 'Checked out student from check-in $normalizedId.',
    );

    await _db.runTransaction((transaction) async {
      final checkinSnap =
          await transaction.get(checkinRef);

      if (!checkinSnap.exists) {
        throw ApiException('Check-in not found');
      }

      final checkin =
          _docToMap(checkinSnap);

      if (_stringValue(
        checkin['checkOutAt'],
      ).isNotEmpty) {
        throw ApiException('Already checked-out');
      }

      final userId =
          _stringValue(checkin['userId']);

      final roomId =
          _stringValue(checkin['roomId']);

      if (userId.isEmpty) {
        throw ApiException(
          'Check-in has no student ID',
        );
      }

      if (roomId.isEmpty) {
        throw ApiException(
          'Check-in has no room ID',
        );
      }

      final roomRef =
          _db.collection('rooms').doc(roomId);

      final userRef =
          _db.collection('users').doc(userId);

      final occupantRef = roomRef
          .collection('occupants')
          .doc(userId);

      final roomSnap =
          await transaction.get(roomRef);

      // ----------------------------------------------------------
      // Mark check-in as checked out
      // ----------------------------------------------------------

      transaction.update(checkinRef, {
        'checkOutAt': _now(),
      });

      // ----------------------------------------------------------
      // Remove student's room assignment
      // ----------------------------------------------------------

      transaction.update(userRef, {
        'roomId': '',
      });

      // ----------------------------------------------------------
      // Remove occupant record
      // ----------------------------------------------------------

      transaction.delete(occupantRef);

      // ----------------------------------------------------------
      // Update room occupancy
      // ----------------------------------------------------------

      if (roomSnap.exists) {
        final room =
            _docToMap(roomSnap);

        final occupied =
            _intValue(room['occupiedCount']);

        final newOccupied =
            occupied > 0
                ? occupied - 1
                : 0;

        final capacity =
            _intValue(
          room['capacity'],
          fallback: 1,
        );

        transaction.update(roomRef, {
          'occupiedCount': newOccupied,
          'status': newOccupied >= capacity
              ? 'full'
              : 'available',
        });
      }
      transaction.set(activityRef, activity);
    });
  } catch (e) {
    if (e is ApiException) {
      rethrow;
    }

    throw ApiException(
      _firebaseErrorMessage(e),
    );
  }
}

  static Future<void> adminSwapRooms({
    required String firstCheckinId,
    required String secondCheckinId,
  }) async {
    await _requireAdmin();
    final firstId = firstCheckinId.trim();
    final secondId = secondCheckinId.trim();
    if (firstId.isEmpty || secondId.isEmpty || firstId == secondId) {
      throw ApiException('Select two different checked-in students');
    }

    try {
      final firstCheckinRef = _db.collection('checkins').doc(firstId);
      final secondCheckinRef = _db.collection('checkins').doc(secondId);
      final activityRef = _db.collection('activityLogs').doc();
      final adminId = _requireAuthUid();
      final admin = await _fetchUserProfile(adminId);

      await _db.runTransaction((transaction) async {
        final firstSnapshot = await transaction.get(firstCheckinRef);
        final secondSnapshot = await transaction.get(secondCheckinRef);
        if (!firstSnapshot.exists || !secondSnapshot.exists) {
          throw ApiException('Check-in not found');
        }
        final first = _docToMap(firstSnapshot);
        final second = _docToMap(secondSnapshot);
        if (_stringValue(first['checkOutAt']).isNotEmpty ||
            _stringValue(second['checkOutAt']).isNotEmpty) {
          throw ApiException('Both students must be checked in');
        }
        final firstUserId = _stringValue(first['userId']);
        final secondUserId = _stringValue(second['userId']);
        final firstRoomId = _stringValue(first['roomId']);
        final secondRoomId = _stringValue(second['roomId']);
        if (firstUserId.isEmpty ||
            secondUserId.isEmpty ||
            firstRoomId.isEmpty ||
            secondRoomId.isEmpty ||
            firstRoomId == secondRoomId ||
            firstUserId == secondUserId) {
          throw ApiException('Students must be assigned to different rooms');
        }

        final firstRoomRef = _db.collection('rooms').doc(firstRoomId);
        final secondRoomRef = _db.collection('rooms').doc(secondRoomId);
        final firstUserRef = _db.collection('users').doc(firstUserId);
        final secondUserRef = _db.collection('users').doc(secondUserId);
        final firstRoomSnapshot = await transaction.get(firstRoomRef);
        final secondRoomSnapshot = await transaction.get(secondRoomRef);
        final firstUserSnapshot = await transaction.get(firstUserRef);
        final secondUserSnapshot = await transaction.get(secondUserRef);
        if (!firstRoomSnapshot.exists ||
            !secondRoomSnapshot.exists ||
            !firstUserSnapshot.exists ||
            !secondUserSnapshot.exists) {
          throw ApiException('Room or student record not found');
        }
        final firstRoom = _docToMap(firstRoomSnapshot);
        final secondRoom = _docToMap(secondRoomSnapshot);
        final firstUser = _docToMap(firstUserSnapshot);
        final secondUser = _docToMap(secondUserSnapshot);
        final now = _now();

        transaction.update(firstCheckinRef, {'roomId': secondRoomId});
        transaction.update(secondCheckinRef, {'roomId': firstRoomId});
        transaction.update(firstUserRef, {'roomId': secondRoomId});
        transaction.update(secondUserRef, {'roomId': firstRoomId});
        transaction.delete(
          firstRoomRef.collection('occupants').doc(firstUserId),
        );
        transaction.delete(
          secondRoomRef.collection('occupants').doc(secondUserId),
        );
        transaction.set(
          secondRoomRef.collection('occupants').doc(firstUserId),
          {
            'userId': firstUserId,
            'name': _stringValue(firstUser['name'], fallback: 'Student'),
            'status': 'checkedIn',
            'checkInAt': first['checkInAt'] ?? now,
          },
        );
        transaction.set(
          firstRoomRef.collection('occupants').doc(secondUserId),
          {
            'userId': secondUserId,
            'name': _stringValue(secondUser['name'], fallback: 'Student'),
            'status': 'checkedIn',
            'checkInAt': second['checkInAt'] ?? now,
          },
        );

        transaction.set(activityRef, {
          'actorId': adminId,
          'actorName': _stringValue(admin['name'], fallback: 'Admin'),
          'action': 'room.students_swapped',
          'entity': 'room',
          'entityId': '$firstRoomId:$secondRoomId',
          'description':
              'Swapped ${_stringValue(firstUser['name'])} (room '
              '${_stringValue(firstRoom['roomNo'])}) with '
              '${_stringValue(secondUser['name'])} (room '
              '${_stringValue(secondRoom['roomNo'])}).',
          'createdAt': now,
        });
      });
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  // ---------------------------------------------------------------------------
  // SESSION
  // ---------------------------------------------------------------------------

  static Future<void> restoreSessionIfNeeded() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final profile = await _fetchUserProfile(user.uid);
      final token = await user.getIdToken() ?? '';

      await ApiService.saveSession({
        'message': 'Session restored',
        'token': token,
        'user': _safeUser(profile),
      });
    } catch (_) {
      await SessionService.clear();
    }
  }

  static Future<Map<String, dynamic>> _buildAuthResponse(
    Map<String, dynamic> userData, {
    String message = 'Login successful',
  }) async {
    final token = await _auth.currentUser?.getIdToken() ?? '';

    final authData = <String, dynamic>{
      'message': message,
      'token': token,
      'user': _safeUser(userData),
    };

    await ApiService.saveSession(authData);
    return authData;
  }

  static Future<Map<String, dynamic>> _fetchUserProfile(String uid) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      throw ApiException('User ID is missing');
    }

    final doc = await _db.collection('users').doc(normalizedUid).get();

    if (!doc.exists) {
      throw ApiException(
        'User profile not found. Contact the hostel office.',
      );
    }

    return _docToMap(doc);
  }

  // ---------------------------------------------------------------------------
  // NOTICES
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> listNotices() async {
    try {
      final snapshot = await _db
          .collection('notices')
          .orderBy('createdAt', descending: true)
          .get();

      final notices = snapshot.docs.map((doc) {
        final data = doc.data();

        return <String, dynamic>{
          'id': doc.id,
          'title': _stringValue(data['title']),
          'description': _stringValue(data['description']),
          'category': _stringValue(data['category'], fallback: 'General'),
          'priority': _stringValue(data['priority'], fallback: 'Normal'),
          'isPinned': data['isPinned'] == true,
          'createdAt': _stringValue(data['createdAt']),
          'expiresAt': _stringValue(data['expiresAt']),
          'authorId': _stringValue(data['authorId']),
        };
      }).toList();

      _sortPinnedThenDate(notices);
      return notices;
    } catch (e) {
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  static Future<void> publishNotice({
    required String title,
    required String description,
    String category = 'General',
    String priority = 'Normal',
    bool isPinned = false,
    String expiresAt = '',
  }) async {
    await _requireAdmin();

    final uid = _requireAuthUid();

    if (title.trim().isEmpty) throw ApiException('Notice title is required');
    if (description.trim().isEmpty) {
      throw ApiException('Notice description is required');
    }

    try {
      final noticeRef = _db.collection('notices').doc();
      final activityRef = _db.collection('activityLogs').doc();
      final batch = _db.batch();
      batch.set(noticeRef, {
        'title': title.trim(),
        'description': description.trim(),
        'category': category.trim(),
        'priority': priority.trim(),
        'isPinned': isPinned,
        'expiresAt': expiresAt.trim(),
        'authorId': uid,
        'createdAt': _now(),
      });
      batch.set(
        activityRef,
        await _activityData(
          action: 'notice.created',
          entity: 'notice',
          entityId: noticeRef.id,
          description: 'Published notice "${title.trim()}".',
        ),
      );
      await batch.commit();
    } catch (e) {
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  static Future<void> updateNotice({
    required String id,
    required String title,
    required String description,
    String category = 'General',
    String priority = 'Normal',
    bool isPinned = false,
    String expiresAt = '',
  }) async {
    await _requireAdmin();

    final normalizedId = id.trim();
    if (normalizedId.isEmpty) throw ApiException('Notice ID is missing');
    if (title.trim().isEmpty) throw ApiException('Notice title is required');
    if (description.trim().isEmpty) {
      throw ApiException('Notice description is required');
    }

    try {
      final noticeRef = _db.collection('notices').doc(normalizedId);
      final activityRef = _db.collection('activityLogs').doc();
      final batch = _db.batch();
      batch.update(noticeRef, {
        'title': title.trim(),
        'description': description.trim(),
        'category': category.trim(),
        'priority': priority.trim(),
        'isPinned': isPinned,
        'expiresAt': expiresAt.trim(),
        'updatedAt': _now(),
      });
      batch.set(
        activityRef,
        await _activityData(
          action: 'notice.updated',
          entity: 'notice',
          entityId: normalizedId,
          description: 'Updated notice "${title.trim()}".',
        ),
      );
      await batch.commit();
    } catch (e) {
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  static Future<void> deleteNotice(String id) async {
    await _requireAdmin();

    final normalizedId = id.trim();
    if (normalizedId.isEmpty) throw ApiException('Notice ID is missing');

    try {
      final batch = _db.batch();
      batch.delete(_db.collection('notices').doc(normalizedId));
      final activityRef = _db.collection('activityLogs').doc();
      batch.set(
        activityRef,
        await _activityData(
          action: 'notice.deleted',
          entity: 'notice',
          entityId: normalizedId,
          description: 'Deleted notice $normalizedId.',
        ),
      );
      await batch.commit();
    } catch (e) {
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  static Future<void> markNoticeAsRead(String noticeId) async {
    final uid = _requireAuthUid();
    final normalizedId = noticeId.trim();

    if (normalizedId.isEmpty) throw ApiException('Notice ID is missing');

    try {
      await _db
          .collection('notices')
          .doc(normalizedId)
          .collection('readBy')
          .doc(uid)
          .set({
        'userId': uid,
        'readAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  static Future<bool> hasReadNotice(String noticeId) async {
    final uid = _auth.currentUser?.uid;
    final normalizedId = noticeId.trim();

    if (uid == null || uid.isEmpty || normalizedId.isEmpty) return false;

    try {
      final doc = await _db
          .collection('notices')
          .doc(normalizedId)
          .collection('readBy')
          .doc(uid)
          .get();

      return doc.exists;
    } catch (e) {
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  static Future<int> getNoticeReadCount(String noticeId) async {
    final normalizedId = noticeId.trim();
    if (normalizedId.isEmpty) return 0;

    try {
      final snapshot = await _db
          .collection('notices')
          .doc(normalizedId)
          .collection('readBy')
          .get();

      return snapshot.size;
    } catch (e) {
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  // ---------------------------------------------------------------------------
  // VISITORS
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> listStudentsForVisitors() async {
    await _requireAdmin();

    try {
      final usersSnapshot = await _db.collection('users').get();
      final checkinsSnapshot = await _db.collection('checkins').get();
      final roomsSnapshot = await _db.collection('rooms').get();

      final activeCheckinByUserId = <String, Map<String, dynamic>>{};

      for (final doc in checkinsSnapshot.docs) {
        final checkin = _docToMap(doc);
        final userId = _stringValue(checkin['userId']);

        if (userId.isEmpty) continue;
        if (_stringValue(checkin['checkOutAt']).isEmpty) {
          activeCheckinByUserId[userId] = checkin;
        }
      }

      final roomsById = <String, Map<String, dynamic>>{
        for (final doc in roomsSnapshot.docs) doc.id: _docToMap(doc),
      };

      final students = <Map<String, dynamic>>[];

      for (final doc in usersSnapshot.docs) {
        final user = _docToMap(doc);
        if (_roleOf(user) != 'student') continue;

        final checkin = activeCheckinByUserId[doc.id];
        if (checkin == null) continue;

        final roomId = _stringValue(checkin['roomId']);
        final room = roomsById[roomId];
        if (room == null) continue;

        final student = _safeUser(user);
        student['roomId'] = roomId;
        student['roomNumber'] = _stringValue(room['roomNo']);
        student['block'] = _stringValue(room['building']);
        student['floor'] = room['floor'];

        students.add(student);
      }

      students.sort((a, b) {
        return _stringValue(a['name'])
            .toLowerCase()
            .compareTo(_stringValue(b['name']).toLowerCase());
      });

      return students;
    } catch (e) {
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  static Future<List<Map<String, dynamic>>> listVisitors() async {
    await _requireAdmin();

    try {
      final snapshot = await _db
          .collection('visitors')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map(_docToMap).toList();
    } catch (e) {
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  /// The caller should create this stream once in initState and reuse it.
  /// Do not call visitorsStream() directly from build() when a search field
  /// is also rebuilding the page.
  static Stream<List<Map<String, dynamic>>> visitorsStream() {
    return _db
        .collection('visitors')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_docToMap).toList());
  }

  static Future<void> registerVisitor({
    required String visitorName,
    required String visitorPhone,
    required String purpose,
    required String studentId,
    required String visitDate,
    required String expectedCheckout,
  }) async {
    await _requireAdmin();

    final normalizedVisitorName = visitorName.trim();
    final normalizedVisitorPhone = visitorPhone.trim();
    final normalizedPurpose = purpose.trim();
    final normalizedStudentId = studentId.trim();
    final normalizedVisitDate = visitDate.trim();
    final normalizedExpectedCheckout = expectedCheckout.trim();

    if (normalizedVisitorName.isEmpty) {
      throw ApiException('Visitor name is required');
    }
    if (normalizedPurpose.isEmpty) {
      throw ApiException('Purpose of visit is required');
    }
    if (normalizedStudentId.isEmpty) {
      throw ApiException('Please select a student');
    }
    if (normalizedVisitDate.isEmpty) {
      throw ApiException('Visit date is required');
    }

    try {
      final studentDoc = await _db.collection('users').doc(normalizedStudentId).get();
      if (!studentDoc.exists) throw ApiException('Student not found');

      final student = _docToMap(studentDoc);
      if (_roleOf(student) != 'student') {
        throw ApiException('Selected user is not a student');
      }

      final checkinsSnapshot = await _db
          .collection('checkins')
          .where('userId', isEqualTo: normalizedStudentId)
          .get();

      Map<String, dynamic>? activeCheckin;

      for (final doc in checkinsSnapshot.docs) {
        final checkin = _docToMap(doc);
        if (_stringValue(checkin['checkOutAt']).isEmpty) {
          activeCheckin = checkin;
          break;
        }
      }

      if (activeCheckin == null) {
        throw ApiException(
          'Selected student does not have an active room.',
        );
      }

      final roomId = _stringValue(activeCheckin['roomId']);
      if (roomId.isEmpty) {
        throw ApiException('Student room information is missing.');
      }

      final roomDoc = await _db.collection('rooms').doc(roomId).get();
      if (!roomDoc.exists) throw ApiException('Student room not found.');

      final room = _docToMap(roomDoc);
      final now = _now();

      final visitorRef = _db.collection('visitors').doc();
      final activityRef = _db.collection('activityLogs').doc();
      final batch = _db.batch();
      batch.set(visitorRef, {
        'visitorName': normalizedVisitorName,
        'visitorPhone': normalizedVisitorPhone,
        'purpose': normalizedPurpose,
        'studentId': normalizedStudentId,
        'studentName': _stringValue(student['name']),
        'roomId': roomId,
        'roomNumber': _stringValue(room['roomNo']),
        'block': _stringValue(room['building']),
        'floor': room['floor'],
        'visitDate': normalizedVisitDate,
        'expectedCheckout': normalizedExpectedCheckout,
        'status': 'checked_in',
        'checkInAt': now,
        'checkOutAt': '',
        'createdAt': now,
        'updatedAt': now,
      });
      batch.set(
        activityRef,
        await _activityData(
          action: 'visitor.created',
          entity: 'visitor',
          entityId: visitorRef.id,
          description:
              'Registered visitor $normalizedVisitorName for ${_stringValue(student['name'])}.',
        ),
      );
      await batch.commit();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  static Future<void> updateVisitor(
    String id, {
    required String visitorName,
    required String visitorPhone,
    required String purpose,
    required String visitDate,
    required String expectedCheckout,
  }) async {
    await _requireAdmin();

    final visitorId = id.trim();
    if (visitorId.isEmpty) throw ApiException('Visitor record ID is missing');

    final normalizedVisitorName = visitorName.trim();
    final normalizedPurpose = purpose.trim();
    final normalizedVisitDate = visitDate.trim();

    if (normalizedVisitorName.isEmpty) {
      throw ApiException('Visitor name is required');
    }
    if (normalizedPurpose.isEmpty) {
      throw ApiException('Purpose of visit is required');
    }
    if (normalizedVisitDate.isEmpty) {
      throw ApiException('Visit date is required');
    }

    try {
      final docRef = _db.collection('visitors').doc(visitorId);
      final doc = await docRef.get();

      if (!doc.exists) throw ApiException('Visitor record not found');

      final batch = _db.batch();
      batch.update(docRef, {
        'visitorName': normalizedVisitorName,
        'visitorPhone': visitorPhone.trim(),
        'purpose': normalizedPurpose,
        'visitDate': normalizedVisitDate,
        'expectedCheckout': expectedCheckout.trim(),
        'updatedAt': _now(),
      });
      final activityRef = _db.collection('activityLogs').doc();
      batch.set(
        activityRef,
        await _activityData(
          action: 'visitor.updated',
          entity: 'visitor',
          entityId: visitorId,
          description: 'Updated visitor ${normalizedVisitorName}.',
        ),
      );
      await batch.commit();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  static Future<void> checkoutVisitor(String id) async {
    await _requireAdmin();

    final visitorId = id.trim();
    if (visitorId.isEmpty) throw ApiException('Visitor record ID is missing');

    try {
      final docRef = _db.collection('visitors').doc(visitorId);
      final doc = await docRef.get();

      if (!doc.exists) throw ApiException('Visitor record not found');

      final visitor = _docToMap(doc);
      if (_stringValue(visitor['status']).toLowerCase() == 'checked_out') {
        throw ApiException('Visitor is already checked out');
      }

      final batch = _db.batch();
      batch.update(docRef, {
        'status': 'checked_out',
        'checkOutAt': _now(),
        'updatedAt': _now(),
      });
      final activityRef = _db.collection('activityLogs').doc();
      batch.set(
        activityRef,
        await _activityData(
          action: 'visitor.checked_out',
          entity: 'visitor',
          entityId: visitorId,
          description:
              'Checked out visitor ${_stringValue(visitor['visitorName'])}.',
        ),
      );
      await batch.commit();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  static Future<void> checkinVisitor(String id) async {
    await _requireAdmin();

    final visitorId = id.trim();
    if (visitorId.isEmpty) throw ApiException('Visitor record ID is missing');

    try {
      final docRef = _db.collection('visitors').doc(visitorId);
      final doc = await docRef.get();

      if (!doc.exists) throw ApiException('Visitor record not found');

      final visitor = _docToMap(doc);
      if (_stringValue(visitor['status']).toLowerCase() == 'checked_in') {
        throw ApiException('Visitor is already checked in');
      }

      final now = _now();

      final batch = _db.batch();
      batch.update(docRef, {
        'status': 'checked_in',
        'checkInAt': now,
        'checkOutAt': '',
        'updatedAt': now,
      });
      final activityRef = _db.collection('activityLogs').doc();
      batch.set(
        activityRef,
        await _activityData(
          action: 'visitor.checked_in',
          entity: 'visitor',
          entityId: visitorId,
          description:
              'Checked in visitor ${_stringValue(visitor['visitorName'])}.',
        ),
      );
      await batch.commit();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  static Future<void> removeVisitor(String id) async {
    await _requireAdmin();

    final visitorId = id.trim();
    if (visitorId.isEmpty) throw ApiException('Visitor record ID is missing');

    try {
      final docRef = _db.collection('visitors').doc(visitorId);
      final doc = await docRef.get();

      if (!doc.exists) throw ApiException('Visitor record not found');

      final batch = _db.batch();
      batch.delete(docRef);
      final activityRef = _db.collection('activityLogs').doc();
      batch.set(
        activityRef,
        await _activityData(
          action: 'visitor.deleted',
          entity: 'visitor',
          entityId: visitorId,
          description: 'Deleted visitor record $visitorId.',
        ),
      );
      await batch.commit();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  // ---------------------------------------------------------------------------
  // FEES / DUES
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> listDues() async {
    await _requireAdmin();

    try {
      final snapshot = await _db.collection('dues').get();
      final dues = snapshot.docs.map(_docToMap).toList();
      _sortDescending(dues, 'createdAt');
      return _includeParentContacts(dues);
    } catch (e) {
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  static Future<List<Map<String, dynamic>>> myDues() async {
    final uid = _requireAuthUid();

    try {
      final snapshot = await _db
          .collection('dues')
          .where('studentId', isEqualTo: uid)
          .get();

      final dues = snapshot.docs.map(_docToMap).toList();
      _sortDescending(dues, 'createdAt');
      return dues;
    } catch (e) {
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  static Future<Map<String, dynamic>> getFeeDetails(String feeId) async {
    final uid = _requireAuthUid();
    final id = feeId.trim();

    if (id.isEmpty) throw ApiException('Fee ID is required');

    try {
      final doc = await _db.collection('dues').doc(id).get();
      if (!doc.exists) throw ApiException('Fee record not found');

      final fee = _docToMap(doc);
      final profile = await _fetchUserProfile(uid);
      final role = _roleOf(profile);

      if (role != 'admin' && _stringValue(fee['studentId']) != uid) {
        throw ApiException('You cannot access this fee');
      }

      return fee;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  /// Keep this stream stable in the consuming State:
  ///
  /// late final Stream<List<Map<String, dynamic>>> _duesStream;
  /// _duesStream = FirebaseService.duesStream();
  ///
  /// Do not recreate it inside build() when the page has text/search inputs.
  static Stream<List<Map<String, dynamic>>> duesStream() {
    return _db.collection('dues').snapshots().asyncMap((snapshot) async {
      await _requireAdmin();
      final dues = snapshot.docs.map(_docToMap).toList();
      _sortDescending(dues, 'createdAt');
      return _includeParentContacts(dues);
    });
  }

  static Future<List<Map<String, dynamic>>> _includeParentContacts(
    List<Map<String, dynamic>> dues,
  ) async {
    final users = await _db.collection('users').get();
    final usersById = <String, Map<String, dynamic>>{
      for (final doc in users.docs) doc.id: _docToMap(doc),
    };
    return dues.map((due) {
      final student = usersById[_stringValue(due['studentId'])];
      return {
        ...due,
        'parentName': student?['parentName'],
        'parentPhone': student?['parentPhone'],
        'parentOccupation': student?['parentOccupation'],
      };
    }).toList();
  }

  static Future<void> adminRecordFeeReminder(String dueId) async {
    await _requireAdmin();
    final id = dueId.trim();
    if (id.isEmpty) throw ApiException('Fee record ID is required');
    try {
      final dueRef = _db.collection('dues').doc(id);
      final dueSnapshot = await dueRef.get();
      if (!dueSnapshot.exists) throw ApiException('Fee record not found');
      final due = _docToMap(dueSnapshot);
      final studentId = _stringValue(due['studentId']);
      if (studentId.isEmpty) {
        throw ApiException('Fee record has no linked student');
      }
      final studentSnapshot =
          await _db.collection('users').doc(studentId).get();
      if (!studentSnapshot.exists ||
          _stringValue(studentSnapshot.data()?['parentPhone']).isEmpty) {
        throw ApiException('No parent phone is saved for this student');
      }
      final now = _now();
      final activityRef = _db.collection('activityLogs').doc();
      final activity = await _activityData(
        action: 'fees.parent_reminder',
        entity: 'fee',
        entityId: id,
        description:
            'Opened a fee reminder for ${_stringValue(due['student'])} and their parent.',
      );
      final batch = _db.batch();
      batch.update(dueRef, {'lastReminderAt': now, 'updatedAt': now});
      batch.set(activityRef, activity);
      await batch.commit();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  static Future<String> addDue({
    String? studentId,
    required String student,
    required String room,
    required int amount,
    required String feeType,
    String? dueDate,
    String? academicYear,
    String? feeMonth,
    String? notes,
  }) async {
    await _requireAdmin();

    if (student.trim().isEmpty) throw ApiException('Student name is required');
    if (room.trim().isEmpty) throw ApiException('Room number is required');
    if (feeType.trim().isEmpty) throw ApiException('Fee type is required');
    if (amount <= 0) throw ApiException('Amount must be greater than ₹0');

    try {
      final now = _now();

      final data = <String, dynamic>{
        'studentId': _nullableString(studentId),
        'student': student.trim(),
        'room': room.trim(),
        'amount': amount,
        'amountPaid': 0,
        'remainingAmount': amount,
        'feeType': feeType.trim(),
        'status': 'pending',
        'paid': false,
        'paidAt': null,
        'paymentMethod': null,
        'paymentReference': null,
        'dueDate': _nullableString(dueDate),
        'academicYear': _nullableString(academicYear),
        'feeMonth': _nullableString(feeMonth),
        'notes': _nullableString(notes),
        'createdAt': now,
        'updatedAt': now,
        'createdBy': _requireAuthUid(),
      };

      final docRef = _db.collection('dues').doc();
      final activityRef = _db.collection('activityLogs').doc();
      final batch = _db.batch();
      batch.set(docRef, data);
      batch.set(
        activityRef,
        await _activityData(
          action: 'fees.created',
          entity: 'fee',
          entityId: docRef.id,
          description: 'Created a $feeType fee of ₹$amount for $student.',
        ),
      );
      await batch.commit();
      return docRef.id;
    } catch (e) {
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  static Future<String> addDueForStudent({
    required String studentId,
    required int amount,
    required String feeType,
    String? dueDate,
    String? academicYear,
    String? feeMonth,
    String? notes,
  }) async {
    await _requireAdmin();

    final normalizedStudentId = studentId.trim();
    if (normalizedStudentId.isEmpty) throw ApiException('Student ID is required');
    if (feeType.trim().isEmpty) throw ApiException('Fee type is required');
    if (amount <= 0) throw ApiException('Amount must be greater than ₹0');

    try {
      final studentDoc =
          await _db.collection('users').doc(normalizedStudentId).get();

      if (!studentDoc.exists) {
        throw ApiException('Selected student does not exist');
      }

      final student = _docToMap(studentDoc);

      if (_roleOf(student) != 'student') {
        throw ApiException('Selected user is not a student');
      }

      Map<String, dynamic>? activeCheckin;
      final checkinsSnapshot = await _db
          .collection('checkins')
          .where('userId', isEqualTo: normalizedStudentId)
          .get();

      for (final doc in checkinsSnapshot.docs) {
        final checkin = _docToMap(doc);
        if (_stringValue(checkin['checkOutAt']).isEmpty) {
          activeCheckin = checkin;
          break;
        }
      }

      String? roomId;
      String? roomNumber;
      String? block;
      dynamic floor;

      if (activeCheckin != null) {
        roomId = _nullableString(activeCheckin['roomId']);

        if (roomId != null) {
          final roomDoc = await _db.collection('rooms').doc(roomId).get();

          if (roomDoc.exists) {
            final room = _docToMap(roomDoc);
            roomNumber = _nullableString(room['roomNo']);
            block = _nullableString(room['building']);
            floor = room['floor'];
          }
        }
      }

      if (feeType.trim().toLowerCase() == 'hostel fee' &&
          (roomId == null || roomId.isEmpty)) {
        throw ApiException(
          'This student does not currently have an active room.',
        );
      }

      final now = _now();

      final data = <String, dynamic>{
        'studentId': normalizedStudentId,
        'student': _stringValue(student['name']),
        'roomId': roomId,
        'room': roomNumber,
        'block': block,
        'floor': floor,
        'amount': amount,
        'amountPaid': 0,
        'remainingAmount': amount,
        'feeType': feeType.trim(),
        'status': 'pending',
        'paid': false,
        'paidAt': null,
        'paymentMethod': null,
        'paymentReference': null,
        'dueDate': _nullableString(dueDate),
        'academicYear': _nullableString(academicYear),
        'feeMonth': _nullableString(feeMonth),
        'notes': _nullableString(notes),
        'createdAt': now,
        'updatedAt': now,
        'createdBy': _requireAuthUid(),
      };

      final docRef = _db.collection('dues').doc();
      final activityRef = _db.collection('activityLogs').doc();
      final batch = _db.batch();
      batch.set(docRef, data);
      batch.set(
        activityRef,
        await _activityData(
          action: 'fees.created',
          entity: 'fee',
          entityId: docRef.id,
          description:
              'Created a $feeType fee of ₹$amount for ${_stringValue(student['name'])}.',
        ),
      );
      await batch.commit();
      return docRef.id;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  static Future<void> updateDue(
    String id, {
    String? studentId,
    String? student,
    String? room,
    int? amount,
    String? feeType,
    String? dueDate,
    String? academicYear,
    String? feeMonth,
    String? notes,
  }) async {
    await _requireAdmin();

    final normalizedId = id.trim();
    if (normalizedId.isEmpty) throw ApiException('Fee record ID is missing');

    try {
      final docRef = _db.collection('dues').doc(normalizedId);
      final doc = await docRef.get();

      if (!doc.exists) throw ApiException('Fee record not found');

      final existing = _docToMap(doc);
      final updates = <String, dynamic>{};

      if (studentId != null) updates['studentId'] = _nullableString(studentId);

      if (student != null) {
        if (student.trim().isEmpty) {
          throw ApiException('Student name cannot be empty');
        }
        updates['student'] = student.trim();
      }

      if (room != null) {
        if (room.trim().isEmpty) {
          throw ApiException('Room number cannot be empty');
        }
        updates['room'] = room.trim();
      }

      if (amount != null) {
        if (amount <= 0) throw ApiException('Amount must be greater than ₹0');

        final paid = _intValue(existing['amountPaid']);
        final remaining = amount - paid;

        updates['amount'] = amount;
        updates['remainingAmount'] = remaining > 0 ? remaining : 0;
        updates['status'] = paid >= amount
            ? 'paid'
            : paid > 0
                ? 'partial'
                : 'pending';
        updates['paid'] = paid >= amount;
        if (paid >= amount) updates['paidAt'] ??= _stringValue(existing['paidAt']);
      }

      if (feeType != null) {
        if (feeType.trim().isEmpty) throw ApiException('Fee type cannot be empty');
        updates['feeType'] = feeType.trim();
      }

      if (dueDate != null) updates['dueDate'] = _nullableString(dueDate);
      if (academicYear != null) {
        updates['academicYear'] = _nullableString(academicYear);
      }
      if (feeMonth != null) updates['feeMonth'] = _nullableString(feeMonth);
      if (notes != null) updates['notes'] = _nullableString(notes);

      if (updates.isEmpty) throw ApiException('No fields to update');

      updates['updatedAt'] = _now();
      final batch = _db.batch();
      batch.update(docRef, updates);
      final activityRef = _db.collection('activityLogs').doc();
      batch.set(
        activityRef,
        await _activityData(
          action: 'fees.updated',
          entity: 'fee',
          entityId: normalizedId,
          description: 'Updated fee record for ${_stringValue(existing['student'])}.',
        ),
      );
      await batch.commit();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  // ---------------------------------------------------------------------------
  // PAYMENT HISTORY
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getPaymentHistory(
    String feeId,
  ) async {
    final fee = await getFeeDetails(feeId);
    final uid = _requireAuthUid();
    final studentId = _stringValue(fee['studentId']);

    if (studentId != uid) await _requireAdmin();

    try {
      final snapshot = await _db
          .collection('dues')
          .doc(feeId.trim())
          .collection('payments')
          .get();

      final payments = snapshot.docs.map(_docToMap).toList();
      _sortDescending(payments, 'paidAt');
      return payments;
    } catch (e) {
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  static Stream<List<Map<String, dynamic>>> paymentHistoryStream(
    String feeId,
  ) {
    final normalizedId = feeId.trim();

    return _db
        .collection('dues')
        .doc(normalizedId)
        .collection('payments')
        .snapshots()
        .map((snapshot) {
      final payments = snapshot.docs.map(_docToMap).toList();
      _sortDescending(payments, 'paidAt');
      return payments;
    });
  }

  static Future<String> recordFeePayment(
    String id, {
    required int paymentAmount,
    String? paymentMethod,
    String? paymentReference,
    String? notes,
  }) async {
    await _requireAdmin();

    final normalizedId = id.trim();
    if (normalizedId.isEmpty) throw ApiException('Fee record ID is missing');
    if (paymentAmount <= 0) {
      throw ApiException('Payment amount must be greater than ₹0');
    }

    try {
      final feeRef = _db.collection('dues').doc(normalizedId);
      final paymentRef = feeRef.collection('payments').doc();
      final receiptNumber = _receiptNumber();
      final now = _now();
      final activityRef = _db.collection('activityLogs').doc();
      final activity = await _activityData(
        action: 'fees.payment_recorded',
        entity: 'fee',
        entityId: normalizedId,
        description: 'Recorded a ₹$paymentAmount payment for fee $normalizedId.',
      );

      await _db.runTransaction((transaction) async {
        final feeSnap = await transaction.get(feeRef);

        if (!feeSnap.exists) throw ApiException('Fee record not found');

        final fee = Map<String, dynamic>.from(feeSnap.data() ?? {});
        final totalAmount = _intValue(fee['amount']);
        final alreadyPaid = _intValue(fee['amountPaid']);
        final remaining = totalAmount - alreadyPaid;

        if (remaining <= 0) {
          throw ApiException('This fee has already been fully paid');
        }

        if (paymentAmount > remaining) {
          throw ApiException(
            'Payment cannot exceed remaining amount of ₹$remaining',
          );
        }

        final newPaid = alreadyPaid + paymentAmount;
        final newRemaining = totalAmount - newPaid;
        final fullyPaid = newRemaining <= 0;

        transaction.update(feeRef, {
          'amountPaid': newPaid,
          'remainingAmount': newRemaining > 0 ? newRemaining : 0,
          'paid': fullyPaid,
          'status': fullyPaid ? 'paid' : 'partial',
          'paidAt': fullyPaid ? now : null,
          'paymentMethod': _nullableString(paymentMethod),
          'paymentReference': _nullableString(paymentReference),
          'lastPaymentAmount': paymentAmount,
          'lastPaymentAt': now,
          'updatedAt': now,
        });

        transaction.set(paymentRef, {
          'receiptNumber': receiptNumber,
          'feeId': normalizedId,
          'studentId': fee['studentId'],
          'student': fee['student'],
          'room': fee['room'],
          'feeType': fee['feeType'],
          'amount': paymentAmount,
          'paymentMethod': _nullableString(paymentMethod),
          'paymentReference': _nullableString(paymentReference),
          'notes': _nullableString(notes),
          'paidAt': now,
          'recordedBy': _requireAuthUid(),
          'remainingAfterPayment': newRemaining > 0 ? newRemaining : 0,
          'createdAt': now,
        });
        transaction.set(activityRef, activity);
      });

      return receiptNumber;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  static Future<Map<String, dynamic>> getPaymentReceipt(
    String feeId,
    String paymentId,
  ) async {
    final fee = await getFeeDetails(feeId);
    final normalizedFeeId = feeId.trim();
    final normalizedPaymentId = paymentId.trim();

    if (normalizedPaymentId.isEmpty) {
      throw ApiException('Payment ID is required');
    }

    try {
      final paymentDoc = await _db
          .collection('dues')
          .doc(normalizedFeeId)
          .collection('payments')
          .doc(normalizedPaymentId)
          .get();

      if (!paymentDoc.exists) {
        throw ApiException('Payment receipt not found');
      }

      final payment = _docToMap(paymentDoc);

      return {
        'receiptNumber': payment['receiptNumber'],
        'paymentId': normalizedPaymentId,
        'feeId': normalizedFeeId,
        'studentId': fee['studentId'],
        'student': fee['student'],
        'room': fee['room'],
        'block': fee['block'],
        'feeType': fee['feeType'],
        'totalAmount': _intValue(fee['amount']),
        'amountPaid': _intValue(payment['amount']),
        'totalPaid': _intValue(fee['amountPaid']),
        'remainingAmount': _intValue(fee['remainingAmount']),
        'paymentMethod': payment['paymentMethod'],
        'paymentReference': payment['paymentReference'],
        'paidAt': payment['paidAt'],
        'notes': payment['notes'],
        'recordedBy': payment['recordedBy'],
      };
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  static Future<List<Map<String, dynamic>>> myPaymentHistory() async {
    final uid = _requireAuthUid();
    final fees = await myDues();
    final result = <Map<String, dynamic>>[];

    try {
      for (final fee in fees) {
        final feeId = _stringValue(fee['id']);
        if (feeId.isEmpty) continue;

        final payments = await _db
            .collection('dues')
            .doc(feeId)
            .collection('payments')
            .get();

        for (final paymentDoc in payments.docs) {
          final payment = _docToMap(paymentDoc);
          payment['feeId'] = feeId;
          payment['student'] = fee['student'];
          payment['room'] = fee['room'];
          payment['feeType'] = fee['feeType'];
          payment['studentId'] = uid;
          result.add(payment);
        }
      }

      _sortDescending(result, 'paidAt');
      return result;
    } catch (e) {
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  // ---------------------------------------------------------------------------
  // SET FEE PAID / UNPAID
  // ---------------------------------------------------------------------------

  static Future<void> setDuePaid(
    String id,
    bool paid,
  ) async {
    await _requireAdmin();

    final normalizedId = id.trim();
    if (normalizedId.isEmpty) throw ApiException('Fee record ID is missing');

    try {
      final docRef = _db.collection('dues').doc(normalizedId);
      final doc = await docRef.get();

      if (!doc.exists) throw ApiException('Fee record not found');

      final fee = _docToMap(doc);
      final totalAmount = _intValue(fee['amount']);

      if (totalAmount <= 0) {
        throw ApiException('Fee amount must be greater than ₹0');
      }

      if (!paid) {
        final batch = _db.batch();
        batch.update(docRef, {
          'amountPaid': 0,
          'remainingAmount': totalAmount,
          'paid': false,
          'status': 'pending',
          'paidAt': null,
          'paymentMethod': null,
          'paymentReference': null,
          'updatedAt': _now(),
        });
        final activityRef = _db.collection('activityLogs').doc();
        batch.set(
          activityRef,
          await _activityData(
            action: 'fees.payment_reversed',
            entity: 'fee',
            entityId: normalizedId,
            description: 'Reversed payment status for ${_stringValue(fee['student'])}.',
          ),
        );
        await batch.commit();
        return;
      }

      final currentPaid = _intValue(fee['amountPaid']);

      // Avoid creating duplicate payment history when the fee is already
      // fully paid.
      if (currentPaid >= totalAmount &&
          (_stringValue(fee['status']).toLowerCase() == 'paid' ||
              fee['paid'] == true)) {
        return;
      }

      final paymentRef = docRef.collection('payments').doc();
      final receiptNumber = _receiptNumber();
      final now = _now();
      final activityRef = _db.collection('activityLogs').doc();
      final activity = await _activityData(
        action: 'fees.payment_recorded',
        entity: 'fee',
        entityId: normalizedId,
        description: 'Marked fee for ${_stringValue(fee['student'])} as paid.',
      );

      await _db.runTransaction((transaction) async {
        final freshSnap = await transaction.get(docRef);
        if (!freshSnap.exists) throw ApiException('Fee record not found');

        final freshFee = Map<String, dynamic>.from(freshSnap.data() ?? {});
        final freshTotal = _intValue(freshFee['amount']);

        transaction.update(docRef, {
          'amountPaid': freshTotal,
          'remainingAmount': 0,
          'paid': true,
          'status': 'paid',
          'paidAt': now,
          'paymentMethod': 'Manual',
          'paymentReference': null,
          'lastPaymentAmount': freshTotal - _intValue(freshFee['amountPaid']),
          'lastPaymentAt': now,
          'updatedAt': now,
        });

        transaction.set(paymentRef, {
          'receiptNumber': receiptNumber,
          'feeId': normalizedId,
          'studentId': freshFee['studentId'],
          'student': freshFee['student'],
          'room': freshFee['room'],
          'feeType': freshFee['feeType'],
          'amount': freshTotal - _intValue(freshFee['amountPaid']),
          'paymentMethod': 'Manual',
          'paymentReference': null,
          'notes': 'Marked as fully paid',
          'paidAt': now,
          'recordedBy': _requireAuthUid(),
          'remainingAfterPayment': 0,
          'createdAt': now,
        });
        transaction.set(activityRef, activity);
      });
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  static Future<void> removeDue(String id) async {
    await _requireAdmin();

    final normalizedId = id.trim();
    if (normalizedId.isEmpty) throw ApiException('Fee record ID is missing');

    try {
      final docRef = _db.collection('dues').doc(normalizedId);
      final doc = await docRef.get();

      if (!doc.exists) throw ApiException('Fee record not found');

      final activityRef = _db.collection('activityLogs').doc();
      final batch = _db.batch();
      batch.delete(docRef);
      batch.set(
        activityRef,
        await _activityData(
          action: 'fees.removed',
          entity: 'fee',
          entityId: normalizedId,
          description:
              'Removed fee record for ${_stringValue(doc.data()?['student'])}.',
        ),
      );
      await batch.commit();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  // ---------------------------------------------------------------------------
  // FEE STATISTICS / REPORTING
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> adminFeeStatistics() async {
    await _requireAdmin();

    try {
      final snapshot = await _db.collection('dues').get();

      var totalAmount = 0;
      var totalPaid = 0;
      var totalPending = 0;

      var paidRecords = 0;
      var pendingRecords = 0;
      var partialRecords = 0;
      var overdueRecords = 0;

      for (final doc in snapshot.docs) {
        final fee = _docToMap(doc);
        final amount = _intValue(fee['amount']);
        final amountPaid = _intValue(fee['amountPaid']);
        final remaining = fee.containsKey('remainingAmount')
            ? _intValue(fee['remainingAmount'])
            : amount - amountPaid;

        final status = _feeStatus(fee);

        totalAmount += amount;
        totalPaid += amountPaid;
        if (remaining > 0) totalPending += remaining;

        switch (status) {
          case 'paid':
            paidRecords++;
            break;
          case 'partial':
            partialRecords++;
            break;
          case 'overdue':
            overdueRecords++;
            break;
          default:
            pendingRecords++;
        }
      }

      return {
        'totalRecords': snapshot.docs.length,
        'totalAmount': totalAmount,
        'totalPaid': totalPaid,
        'totalPending': totalPending,
        'paidRecords': paidRecords,
        'pendingRecords': pendingRecords,
        'partialRecords': partialRecords,
        'overdueRecords': overdueRecords,
      };
    } catch (e) {
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  static Future<List<Map<String, dynamic>>> adminStudentDues(
    String studentId,
  ) async {
    await _requireAdmin();

    final normalizedId = studentId.trim();
    if (normalizedId.isEmpty) throw ApiException('Student ID is required');

    try {
      final snapshot = await _db.collection('dues').get();

      final dues = snapshot.docs
          .map(_docToMap)
          .where((fee) => _stringValue(fee['studentId']) == normalizedId)
          .toList();

      _sortDescending(dues, 'createdAt');
      return dues;
    } catch (e) {
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  static Future<List<Map<String, dynamic>>> adminPendingDues() async {
    await _requireAdmin();

    try {
      final snapshot = await _db.collection('dues').get();

      final dues = snapshot.docs
          .map(_docToMap)
          .where((fee) => _feeStatus(fee) != 'paid')
          .toList();

      dues.sort((a, b) {
        return _dateValue(a['dueDate']).compareTo(_dateValue(b['dueDate']));
      });

      return dues;
    } catch (e) {
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  static Future<int> updateOverdueFees() async {
    await _requireAdmin();

    try {
      final snapshot = await _db.collection('dues').get();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      var updatedCount = 0;
      final batch = _db.batch();

      for (final doc in snapshot.docs) {
        final fee = _docToMap(doc);

        if (_feeStatus(fee) == 'paid') continue;

        final dueDate = _parseDate(fee['dueDate']);
        if (dueDate == null) continue;

        final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
        final remaining = fee.containsKey('remainingAmount')
            ? _intValue(fee['remainingAmount'])
            : _intValue(fee['amount']) - _intValue(fee['amountPaid']);

        if (due.isBefore(today) && remaining > 0) {
          batch.update(doc.reference, {
            'status': 'overdue',
            'updatedAt': _now(),
          });
          updatedCount++;
        }
      }

      if (updatedCount > 0) {
        await batch.commit();
      }

      return updatedCount;
    } catch (e) {
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  // ---------------------------------------------------------------------------
  // ADMIN SETTINGS
  // ---------------------------------------------------------------------------

  static User? get currentUser => _auth.currentUser;

  static DocumentReference<Map<String, dynamic>> get _appSettingsRef =>
      _db.collection('settings').doc('app');

  static DocumentReference<Map<String, dynamic>> _getAdminPreferencesRef(
    String uid,
  ) =>
      _db.collection('users').doc(uid).collection('settings').doc('preferences');

  static Future<Map<String, dynamic>> loadAppSettings() async {
    try {
      final snapshot = await _appSettingsRef.get();

      if (!snapshot.exists) {
        return Map<String, dynamic>.from(_defaultAppSettings);
      }

      return {
        ..._defaultAppSettings,
        ...(snapshot.data() ?? const <String, dynamic>{}),
      };
    } catch (e) {
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  static Future<void> saveAppSettings(
    Map<String, dynamic> settings,
  ) async {
    await _requireAdmin();

    try {
      await _appSettingsRef.set({
        ...settings,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _requireAuthUid(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  static Future<Map<String, dynamic>> loadAdminPreferences() async {
    final user = currentUser;

    if (user == null) {
      return Map<String, dynamic>.from(_defaultAdminPreferences);
    }

    try {
      final snapshot = await _getAdminPreferencesRef(user.uid).get();

      if (!snapshot.exists) {
        return Map<String, dynamic>.from(_defaultAdminPreferences);
      }

      return {
        ..._defaultAdminPreferences,
        ...(snapshot.data() ?? const <String, dynamic>{}),
      };
    } catch (e) {
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  static Future<void> saveAdminPreferences(
    Map<String, dynamic> preferences,
  ) async {
    await _requireAdmin();

    try {
      await _getAdminPreferencesRef(_requireAuthUid()).set({
        ...preferences,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  static Future<void> saveAllAdminSettings({
    required Map<String, dynamic> appSettings,
    required Map<String, dynamic> adminPreferences,
  }) async {
    await _requireAdmin();

    try {
      final uid = _requireAuthUid();
      final batch = _db.batch();

      batch.set(
        _appSettingsRef,
        {
          ...appSettings,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': uid,
        },
        SetOptions(merge: true),
      );

      batch.set(
        _getAdminPreferencesRef(uid),
        {
          ...adminPreferences,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();
    } catch (e) {
      throw ApiException(_firebaseErrorMessage(e));
    }
  }

  static Future<void> changeAdminPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _requireAdmin();

    final user = currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'not-authenticated',
        message: 'Administrator is not logged in.',
      );
    }

    final email = user.email;

    if (email == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-email',
        message: 'The administrator account has no email address.',
      );
    }

    if (newPassword.length < 6) {
      throw FirebaseAuthException(
        code: 'weak-password',
        message: 'Password must contain at least 6 characters.',
      );
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw ApiException(_authErrorMessage(e));
    }
  }

  static Future<void> logoutAdmin() async {
    try {
      await _auth.signOut();
    } finally {
      await SessionService.clear();
    }
  }

  // ---------------------------------------------------------------------------
  // FEE HELPERS
  // ---------------------------------------------------------------------------

  static int _intValue(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString().trim() ?? '') ?? fallback;
  }

  static DateTime _dateValue(dynamic value) {
    return _parseDate(value) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    final string = value.toString().trim();
    if (string.isEmpty) return null;

    return DateTime.tryParse(string);
  }

  static String _feeStatus(Map<String, dynamic> fee) {
    final storedStatus =
        _stringValue(fee['status']).trim().toLowerCase();

    final amount = _intValue(fee['amount']);
    final amountPaid = _intValue(fee['amountPaid']);

    final remaining = fee.containsKey('remainingAmount')
        ? _intValue(fee['remainingAmount'])
        : amount - amountPaid;

    if (fee['paid'] == true ||
        storedStatus == 'paid' ||
        (amount > 0 && amountPaid >= amount) ||
        (amount > 0 && remaining <= 0)) {
      return 'paid';
    }

    final dueDate = _parseDate(fee['dueDate']);

    if (dueDate != null && remaining > 0) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final due = DateTime(dueDate.year, dueDate.month, dueDate.day);

      if (due.isBefore(today)) return 'overdue';
    }

    if (amountPaid > 0 || storedStatus == 'partial') {
      return 'partial';
    }

    return 'pending';
  }

  // ---------------------------------------------------------------------------
  // AUTH / FIRESTORE HELPERS
  // ---------------------------------------------------------------------------

  static String _requireAuthUid() {
    final uid = _auth.currentUser?.uid;

    if (uid == null || uid.isEmpty) {
      throw ApiException('Please sign in again');
    }

    return uid;
  }

  static Future<void> _requireAdmin() async {
    final uid = _requireAuthUid();
    final profile = await _fetchUserProfile(uid);

    if (_roleOf(profile) != 'admin') {
      throw ApiException('Admin access required');
    }
  }

  static Future<Map<String, dynamic>> _activityData({
    required String action,
    required String entity,
    required String entityId,
    required String description,
  }) async {
    final admin = await _fetchUserProfile(_requireAuthUid());
    return {
      'actorId': _requireAuthUid(),
      'actorName': _stringValue(admin['name'], fallback: 'Admin'),
      'action': action,
      'entity': entity,
      'entityId': entityId,
      'description': description,
      'createdAt': _now(),
    };
  }

  static Future<void> _recordAdminActivity({
    required String action,
    required String entity,
    required String entityId,
    required String description,
  }) async {
    await _db.collection('activityLogs').add(
          await _activityData(
            action: action,
            entity: entity,
            entityId: entityId,
            description: description,
          ),
        );
  }

  static String _roleOf(Map<String, dynamic> user) {
    return _stringValue(
      user['role'],
      fallback: 'student',
    ).trim().toLowerCase();
  }

  static Map<String, dynamic> _docToMap(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = Map<String, dynamic>.from(
      doc.data() ?? const <String, dynamic>{},
    );

    data['id'] = doc.id;
    return data;
  }

  static Map<String, dynamic> _safeUser(
    Map<String, dynamic> user,
  ) {
    return {
      'id': user['id'],
      'name': user['name'],
      'email': user['email'],
      'gender': user['gender'],
      'age': user['age'],
      'phone': user['phone'],
      'address': user['address'],
      'parentName': user['parentName'],
      'parentPhone': user['parentPhone'],
      'parentOccupation': user['parentOccupation'],
      'role': _stringValue(user['role'], fallback: 'student'),
    };
  }

  static String _stringValue(
    dynamic value, {
    String fallback = '',
  }) {
    if (value == null) return fallback;
    return value.toString();
  }

  static String? _nullableString(dynamic value) {
    final string = value?.toString().trim() ?? '';
    return string.isEmpty ? null : string;
  }

  static String _normalizeEmail(String email) {
    return email.trim().toLowerCase();
  }

  static String _now() => DateTime.now().toIso8601String();

  static String _receiptNumber() {
    return 'RCP-${DateTime.now().millisecondsSinceEpoch}';
  }

  static void _sortDescending(
    List<Map<String, dynamic>> items,
    String field,
  ) {
    items.sort((a, b) {
      return _dateValue(b[field]).compareTo(_dateValue(a[field]));
    });
  }

  static void _sortPinnedThenDate(
    List<Map<String, dynamic>> items,
  ) {
    items.sort((a, b) {
      final pinnedA = a['isPinned'] == true;
      final pinnedB = b['isPinned'] == true;

      if (pinnedA != pinnedB) {
        return pinnedB ? 1 : -1;
      }

      return _dateValue(b['createdAt'])
          .compareTo(_dateValue(a['createdAt']));
    });
  }

  // ---------------------------------------------------------------------------
  // ERROR HANDLING
  // ---------------------------------------------------------------------------

  static String _firebaseErrorMessage(Object error) {
    if (error is ApiException) return error.toString();

    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Permission denied. Check your Firebase/Firestore rules.';
        case 'unauthenticated':
          return 'Please sign in again.';
        case 'not-found':
          return 'Requested record was not found.';
        case 'already-exists':
          return 'This record already exists.';
        case 'network-request-failed':
          return 'Network error. Check your internet connection.';
        case 'unavailable':
          return 'Firebase is temporarily unavailable. Try again.';
        case 'failed-precondition':
          return error.message ??
              'The Firebase operation could not be completed.';
        default:
          return error.message ?? 'Firebase operation failed.';
      }
    }

    return error.toString();
  }

  static String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'User already exists with this email';
      case 'invalid-email':
        return 'Enter a valid email';
      case 'weak-password':
        return 'Password is too weak (use at least 6 characters)';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Invalid email or password';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      case 'requires-recent-login':
        return 'Please sign in again before changing your password.';
      case 'credential-already-in-use':
        return 'This credential is already in use.';
      default:
        return e.message ?? 'Authentication failed';
    }
  }
}
