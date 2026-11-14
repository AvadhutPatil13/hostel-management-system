import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';

const _jwtSecret = 'rit-hostel-demo-secret';

final _dbFile = _resolveDbFile();

File _resolveDbFile() {
  // The backend is often started from the repo root (`dart run backend/bin/server.dart`)
  // or from inside `backend/`. The DB path must be stable in both cases.
  final candidates = <String>[
    'backend/data/db.json',
    'data/db.json',
  ];

  for (final path in candidates) {
    final file = File(path);
    if (file.existsSync()) return file;
  }

  // Default to the first (preferred) location even if it doesn't exist yet.
  return File(candidates.first);
}

const _defaultAdminEmail = 'admin@rit-hostel.local';
const _defaultAdminPassword = 'admin1234';

Future<void> main() async {
  await _ensureDatabase();

  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8081;
  final hostEnv = Platform.environment['HOST']?.trim();
  final host = hostEnv != null && hostEnv.isNotEmpty
      ? InternetAddress(hostEnv)
      : InternetAddress.loopbackIPv4;

  final app = Router()
    ..get('/api/health', _healthHandler)
    ..get('/api/hostels', _hostelsHandler)
    ..post('/api/auth/register', _registerHandler)
    ..post('/api/auth/login', _loginHandler)
    ..post('/api/auth/forgot-password', _forgotPasswordHandler)
    ..post('/api/contact', _contactHandler)
    ..post('/api/admissions', _admissionHandler)
    ..get('/api/me', _meHandler)
    ..get('/api/my/complaints', _myComplaintsHandler)
    ..get('/api/my/checkins', _myCheckinsHandler)
    ..get('/api/my/room', _myRoomHandler)
    ..get('/api/rooms/available', _availableRoomsHandler)
    ..get('/api/admin/users', _adminUsersHandler)
    ..post('/api/admin/users', _adminCreateStudentHandler)
    ..patch('/api/admin/users/<id>', _adminUpdateUserHandler)
    ..get('/api/admin/activity', _adminActivityHandler)
    ..get('/api/admin/dues', _adminDuesHandler)
    ..post('/api/admin/dues', _adminCreateDueHandler)
    ..patch('/api/admin/dues/<id>', _adminUpdateDueHandler)
    ..delete('/api/admin/dues/<id>', _adminRemoveDueHandler)
    ..post('/api/admin/dues/monthly', _adminGenerateMonthlyDuesHandler)
    ..post('/api/admin/dues/<id>/reminder', _adminRecordFeeReminderHandler)
    ..get('/api/admin/dashboard', _adminDashboardHandler)
    ..get('/api/admin/rooms', _adminRoomsListHandler)
    ..post('/api/admin/rooms', _adminRoomsCreateHandler)
    ..patch('/api/admin/rooms/<id>', _adminRoomsUpdateHandler)
    ..post('/api/complaints', _complaintCreateHandler)
    ..get('/api/admin/complaints', _adminComplaintsListHandler)
    ..patch('/api/admin/complaints/<id>', _adminComplaintsUpdateHandler)
    ..get('/api/admin/checkins', _adminCheckinsListHandler)
    ..post('/api/admin/checkin', _adminCheckInHandler)
    ..post('/api/admin/checkout', _adminCheckOutHandler)
    ..post('/api/admin/swap-rooms', _adminSwapRoomsHandler);

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders())
      .addMiddleware(_errorMiddleware())
      .addHandler(app.call);

  final server = await io.serve(handler, host, port);
  stdout.writeln(
    'Hostel backend running on http://${server.address.address}:${server.port}',
  );
}

Future<Response> _healthHandler(Request request) async {
  return _json({
    'ok': true,
    'service': 'hostel_app_backend',
    'time': DateTime.now().toIso8601String(),
  });
}

Future<Response> _hostelsHandler(Request request) async {
  final db = await _readDb();
  return _json({'hostels': db['hostels']});
}

Future<Response> _registerHandler(Request request) async {
  final body = await _readJson(request);
  final name = _requiredString(body, 'name');
  final email = _requiredString(body, 'email').toLowerCase();
  final password = _requiredString(body, 'password');
  final gender = _requiredString(body, 'gender');
  final age = _requiredString(body, 'age');
  final phone = _requiredString(body, 'phone');

  final db = await _readDb();
  final users = List<Map<String, dynamic>>.from(db['users'] as List);

  final exists = users.any((u) => (u['email'] as String).toLowerCase() == email);
  if (exists) {
    return _error('User already exists with this email', HttpStatus.conflict);
  }

  final user = {
    'id': _id(),
    'name': name,
    'email': email,
    'passwordHash': _hashPassword(password),
    'gender': gender,
    'age': age,
    'phone': phone,
    'role': 'student',
    'createdAt': DateTime.now().toIso8601String(),
  };

  users.add(user);
  db['users'] = users;
  final now = DateTime.now();
  final feeMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
  final dues = List<Map<String, dynamic>>.from(db['dues'] as List);
  dues.add({
    'id': _id(),
    'studentId': user['id'],
    'student': name,
    'room': '',
    'amount': 5000,
    'amountPaid': 0,
    'remainingAmount': 5000,
    'paid': false,
    'status': 'pending',
    'feeType': 'Hostel Fee',
    'feeMonth': feeMonth,
    'dueDate': DateTime(now.year, now.month + 1, 10).toIso8601String(),
    'createdAt': now.toIso8601String(),
    'updatedAt': now.toIso8601String(),
  });
  db['dues'] = dues;
  await _writeDb(db);

  final token = _tokenForUser(user);
  return _json({
    'message': 'Registration successful',
    'token': token,
    'user': _safeUser(user),
  }, statusCode: HttpStatus.created);
}

Future<Response> _loginHandler(Request request) async {
  final body = await _readJson(request);
  final email = _requiredString(body, 'email').toLowerCase();
  final password = _requiredString(body, 'password');

  final db = await _readDb();
  final users = List<Map<String, dynamic>>.from(db['users'] as List);
  final user = users.cast<Map<String, dynamic>?>().firstWhere(
        (u) => u != null && (u['email'] as String).toLowerCase() == email,
        orElse: () => null,
      );

  if (user == null || user['passwordHash'] != _hashPassword(password)) {
    return _error('Invalid email or password', HttpStatus.unauthorized);
  }

  final token = _tokenForUser(user);
  return _json({
    'message': 'Login successful',
    'token': token,
    'user': _safeUser(user),
  });
}

Future<Response> _forgotPasswordHandler(Request request) async {
  final body = await _readJson(request);
  final email = _requiredString(body, 'email').toLowerCase();

  final db = await _readDb();
  final users = List<Map<String, dynamic>>.from(db['users'] as List);
  final exists = users.any((u) => (u['email'] as String).toLowerCase() == email);

  return _json({
    'message': exists
        ? 'Password reset request recorded. Please contact the hostel office to reset it.'
        : 'No user found with that email.',
    'found': exists,
  });
}

Future<Response> _contactHandler(Request request) async {
  final body = await _readJson(request);
  final name = _requiredString(body, 'name');
  final email = _requiredString(body, 'email');
  final phone = _requiredString(body, 'phone');
  final message = _requiredString(body, 'message');

  final db = await _readDb();
  final contacts = List<Map<String, dynamic>>.from(db['contacts'] as List);
  contacts.add({
    'id': _id(),
    'name': name,
    'email': email,
    'phone': phone,
    'message': message,
    'createdAt': DateTime.now().toIso8601String(),
  });
  db['contacts'] = contacts;
  await _writeDb(db);

  return _json({
    'message': 'Contact form submitted successfully',
  }, statusCode: HttpStatus.created);
}

Future<Response> _admissionHandler(Request request) async {
  final body = await _readJson(request);
  final fullName = _requiredString(body, 'fullName');
  final collegeId = _requiredString(body, 'collegeId');
  final email = _requiredString(body, 'email');
  final phone = _requiredString(body, 'phone');
  final course = _requiredString(body, 'course');
  final yearOfStudy = _requiredString(body, 'yearOfStudy');
  final department = _requiredString(body, 'department');
  final hostelType = _requiredString(body, 'hostelType');
  final roomType = _requiredString(body, 'roomType');

  final db = await _readDb();
  final admissions = List<Map<String, dynamic>>.from(db['admissions'] as List);
  admissions.add({
    'id': _id(),
    'fullName': fullName,
    'collegeId': collegeId,
    'email': email,
    'phone': phone,
    'course': course,
    'yearOfStudy': yearOfStudy,
    'department': department,
    'hostelType': hostelType,
    'roomType': roomType,
    'createdAt': DateTime.now().toIso8601String(),
  });
  db['admissions'] = admissions;
  await _writeDb(db);

  return _json({
    'message': 'Admission form submitted successfully',
  }, statusCode: HttpStatus.created);
}

Future<Response> _meHandler(Request request) async {
  try {
    final userId = _requireAuthUserId(request);

    final db = await _readDb();
    final users = List<Map<String, dynamic>>.from(db['users'] as List);
    final user = users.cast<Map<String, dynamic>?>().firstWhere(
          (u) => u != null && u['id'] == userId,
          orElse: () => null,
        );

    if (user == null) {
      return _error('User not found', HttpStatus.notFound);
    }

    return _json({'user': _safeUser(user)});
  } on JWTException {
    return _error('Invalid token', HttpStatus.unauthorized);
  } on _AuthException catch (e) {
    return _error(e.message, e.statusCode);
  }
}

Future<Response> _adminUsersHandler(Request request) async {
  try {
    await _requireAdmin(request);
    final db = await _readDb();
    final users = List<Map<String, dynamic>>.from(db['users'] as List);
    final safeUsers = users.map(_safeUser).toList();
    return _json({'users': safeUsers});
  } on _AuthException catch (e) {
    return _error(e.message, e.statusCode);
  }
}

Future<Response> _adminCreateStudentHandler(Request request) async {
  try {
    final adminId = await _requireAdmin(request);
    final body = await _readJson(request);
    final name = _requiredString(body, 'name');
    final email = _requiredString(body, 'email').toLowerCase();
    final password = _requiredString(body, 'password');
    final gender = _requiredString(body, 'gender');
    final age = _requiredString(body, 'age');
    final phone = _requiredString(body, 'phone');
    final address = _requiredString(body, 'address');
    final parentName = _requiredString(body, 'parentName');
    final parentPhone = _requiredString(body, 'parentPhone');
    final parentOccupation = _requiredString(body, 'parentOccupation');

    if (password.length < 6) {
      return _error('Password must contain at least 6 characters', HttpStatus.badRequest);
    }

    final db = await _readDb();
    final users = List<Map<String, dynamic>>.from(db['users'] as List);
    if (users.any((user) => user['email']?.toString().toLowerCase() == email)) {
      return _error('User already exists with this email', HttpStatus.conflict);
    }

    final now = DateTime.now();
    final student = <String, dynamic>{
      'id': _id(),
      'name': name,
      'email': email,
      'passwordHash': _hashPassword(password),
      'gender': gender,
      'age': age,
      'phone': phone,
      'address': address,
      'parentName': parentName,
      'parentPhone': parentPhone,
      'parentOccupation': parentOccupation,
      'role': 'student',
      'createdAt': now.toIso8601String(),
    };
    users.add(student);
    db['users'] = users;

    final dues = List<Map<String, dynamic>>.from(db['dues'] as List);
    final feeMonth =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    dues.add({
      'id': _id(),
      'studentId': student['id'],
      'student': name,
      'room': '',
      'amount': 5000,
      'amountPaid': 0,
      'remainingAmount': 5000,
      'paid': false,
      'status': 'pending',
      'feeType': 'Hostel Fee',
      'feeMonth': feeMonth,
      'dueDate': DateTime(now.year, now.month + 1, 10).toIso8601String(),
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    });
    db['dues'] = dues;
    _recordActivity(
      db,
      adminId,
      'student.created',
      'student',
      student['id'].toString(),
      'Added student $name and assigned the initial ₹5000 hostel fee.',
    );
    await _writeDb(db);
    return _json(
      {'user': _safeUser(student)},
      statusCode: HttpStatus.created,
    );
  } on _AuthException catch (e) {
    return _error(e.message, e.statusCode);
  }
}

Future<Response> _adminUpdateUserHandler(Request request, String id) async {
  try {
    final adminId = await _requireAdmin(request);
    final body = await _readJson(request);

    final db = await _readDb();
    final users = List<Map<String, dynamic>>.from(db['users'] as List);
    final index = users.indexWhere((u) => u['id']?.toString() == id);
    if (index < 0) {
      return _error('User not found', HttpStatus.notFound);
    }

    final user = Map<String, dynamic>.from(users[index]);
    if (body.containsKey('role')) {
      final role = body['role']?.toString().trim().toLowerCase();
      if (role != 'student' && role != 'admin') {
        return _error('Invalid role', HttpStatus.badRequest);
      }
      user['role'] = role;
    }
    if (body.containsKey('phone')) {
      user['phone'] = body['phone']?.toString().trim() ?? '';
    }
    if (body.containsKey('name')) {
      final name = body['name']?.toString().trim() ?? '';
      if (name.isEmpty) return _error('Name cannot be empty', HttpStatus.badRequest);
      user['name'] = name;
    }
    for (final field in const [
      'email',
      'gender',
      'age',
      'address',
      'parentName',
      'parentPhone',
      'parentOccupation',
    ]) {
      if (body.containsKey(field)) {
        user[field] = body[field]?.toString().trim() ?? '';
      }
    }
    if (body.containsKey('email')) {
      final email = user['email']?.toString().toLowerCase() ?? '';
      final duplicate = users.any(
        (other) =>
            other['id']?.toString() != id &&
            other['email']?.toString().toLowerCase() == email,
      );
      if (email.isEmpty || duplicate) {
        return _error('Email is empty or already in use', HttpStatus.conflict);
      }
      user['email'] = email;
    }

    users[index] = user;
    db['users'] = users;
    _recordActivity(
      db,
      adminId,
      'student.updated',
      'student',
      id,
      'Updated student ${user['name']}.',
    );
    await _writeDb(db);

    return _json({'user': _safeUser(user)});
  } on _AuthException catch (e) {
    return _error(e.message, e.statusCode);
  }
}

Future<Response> _adminActivityHandler(Request request) async {
  try {
    await _requireAdmin(request);
    final db = await _readDb();
    final logs = List<Map<String, dynamic>>.from(db['activityLogs'] as List);
    logs.sort((a, b) =>
        (b['createdAt']?.toString() ?? '').compareTo(
          a['createdAt']?.toString() ?? '',
        ));
    return _json({'logs': logs});
  } on _AuthException catch (e) {
    return _error(e.message, e.statusCode);
  }
}

Future<Response> _adminDuesHandler(Request request) async {
  try {
    await _requireAdmin(request);
    final db = await _readDb();
    final users = List<Map<String, dynamic>>.from(db['users'] as List);
    final usersById = {
      for (final user in users) user['id']?.toString() ?? '': user,
    };
    final dues = List<Map<String, dynamic>>.from(db['dues'] as List)
      ..sort((a, b) => (b['createdAt']?.toString() ?? '').compareTo(
        a['createdAt']?.toString() ?? '',
      ));
    final enriched = dues.map((due) {
      final student = usersById[due['studentId']?.toString() ?? ''];
      return {
        ...due,
        'parentName': student?['parentName'],
        'parentPhone': student?['parentPhone'],
        'parentOccupation': student?['parentOccupation'],
      };
    }).toList();
    return _json({'dues': enriched});
  } on _AuthException catch (e) {
    return _error(e.message, e.statusCode);
  }
}

Future<Response> _adminCreateDueHandler(Request request) async {
  try {
    final adminId = await _requireAdmin(request);
    final body = await _readJson(request);
    final studentId = body['studentId']?.toString().trim() ?? '';
    final amount = int.tryParse(body['amount']?.toString() ?? '') ?? 0;
    final studentName = body['student']?.toString().trim() ?? '';
    final room = body['room']?.toString().trim() ?? '';
    final feeType = body['feeType']?.toString().trim() ?? '';
    if (amount <= 0 || studentName.isEmpty || feeType.isEmpty) {
      return _error('Student, fee type and a positive amount are required', HttpStatus.badRequest);
    }

    final db = await _readDb();
    final users = List<Map<String, dynamic>>.from(db['users'] as List);
    final student = studentId.isEmpty
        ? null
        : users.cast<Map<String, dynamic>?>().firstWhere(
              (user) =>
                  user != null && user['id']?.toString() == studentId,
              orElse: () => null,
            );
    if (studentId.isNotEmpty &&
        (student == null || student['role']?.toString() != 'student')) {
      return _error('Selected student was not found', HttpStatus.notFound);
    }
    final now = DateTime.now();
    final due = <String, dynamic>{
      'id': _id(),
      'studentId': studentId.isEmpty ? null : studentId,
      'student': student?['name']?.toString() ?? studentName,
      'room': room,
      'amount': amount,
      'amountPaid': 0,
      'remainingAmount': amount,
      'paid': false,
      'status': 'pending',
      'feeType': feeType,
      'dueDate': body['dueDate'],
      'feeMonth': body['feeMonth'],
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
    final dues = List<Map<String, dynamic>>.from(db['dues'] as List)..add(due);
    db['dues'] = dues;
    _recordActivity(
      db,
      adminId,
      'fees.created',
      'fee',
      due['id'].toString(),
      'Created a $feeType fee of ₹$amount for ${due['student']}.',
    );
    await _writeDb(db);
    return _json({'due': due}, statusCode: HttpStatus.created);
  } on _AuthException catch (e) {
    return _error(e.message, e.statusCode);
  }
}

Future<Response> _adminUpdateDueHandler(Request request, String id) async {
  try {
    final adminId = await _requireAdmin(request);
    final body = await _readJson(request);
    if (body['paid'] is! bool) {
      return _error('A valid paid status is required', HttpStatus.badRequest);
    }
    final db = await _readDb();
    final dues = List<Map<String, dynamic>>.from(db['dues'] as List);
    final index = dues.indexWhere((due) => due['id']?.toString() == id);
    if (index < 0) return _error('Fee record not found', HttpStatus.notFound);
    final due = Map<String, dynamic>.from(dues[index]);
    final amount = int.tryParse(due['amount']?.toString() ?? '') ?? 0;
    final paid = body['paid'] as bool;
    due['paid'] = paid;
    due['amountPaid'] = paid ? amount : 0;
    due['remainingAmount'] = paid ? 0 : amount;
    due['status'] = paid ? 'paid' : 'pending';
    due['paidAt'] = paid ? DateTime.now().toIso8601String() : null;
    due['updatedAt'] = DateTime.now().toIso8601String();
    dues[index] = due;
    db['dues'] = dues;
    _recordActivity(
      db,
      adminId,
      paid ? 'fees.payment_recorded' : 'fees.payment_reversed',
      'fee',
      id,
      '${paid ? 'Marked' : 'Reversed'} fee for ${due['student']} '
          '${paid ? 'as paid' : 'as unpaid'}.',
    );
    await _writeDb(db);
    return _json({'due': due});
  } on _AuthException catch (e) {
    return _error(e.message, e.statusCode);
  }
}

Future<Response> _adminRemoveDueHandler(Request request, String id) async {
  try {
    final adminId = await _requireAdmin(request);
    final db = await _readDb();
    final dues = List<Map<String, dynamic>>.from(db['dues'] as List);
    final due = dues.cast<Map<String, dynamic>?>().firstWhere(
          (item) => item != null && item['id']?.toString() == id,
          orElse: () => null,
        );
    if (due == null) return _error('Fee record not found', HttpStatus.notFound);
    dues.removeWhere((item) => item['id']?.toString() == id);
    db['dues'] = dues;
    _recordActivity(
      db,
      adminId,
      'fees.removed',
      'fee',
      id,
      'Removed fee record for ${due['student']}.',
    );
    await _writeDb(db);
    return _json({'removed': true});
  } on _AuthException catch (e) {
    return _error(e.message, e.statusCode);
  }
}

Future<Response> _adminGenerateMonthlyDuesHandler(Request request) async {
  try {
    final adminId = await _requireAdmin(request);
    final db = await _readDb();
    final users = List<Map<String, dynamic>>.from(db['users'] as List);
    final dues = List<Map<String, dynamic>>.from(db['dues'] as List);
    final now = DateTime.now();
    final feeMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    var createdCount = 0;

    for (final student in users.where(
      (user) => (user['role']?.toString() ?? 'student') == 'student',
    )) {
      final studentId = student['id']?.toString() ?? '';
      if (dues.any((due) =>
          due['studentId']?.toString() == studentId &&
          due['feeMonth']?.toString() == feeMonth &&
          due['feeType']?.toString() == 'Hostel Fee')) {
        continue;
      }
      dues.add({
        'id': _id(),
        'studentId': studentId,
        'student': student['name']?.toString() ?? '',
        'room': '',
        'amount': 5000,
        'amountPaid': 0,
        'remainingAmount': 5000,
        'paid': false,
        'status': 'pending',
        'feeType': 'Hostel Fee',
        'feeMonth': feeMonth,
        'dueDate': DateTime(now.year, now.month + 1, 10).toIso8601String(),
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });
      createdCount++;
    }
    db['dues'] = dues;
    _recordActivity(
      db,
      adminId,
      'fees.monthly_generated',
      'fees',
      feeMonth,
      'Generated $createdCount monthly hostel fee record(s) for $feeMonth.',
    );
    await _writeDb(db);
    return _json({'createdCount': createdCount, 'feeMonth': feeMonth});
  } on _AuthException catch (e) {
    return _error(e.message, e.statusCode);
  }
}

Future<Response> _adminRecordFeeReminderHandler(
  Request request,
  String id,
) async {
  try {
    final adminId = await _requireAdmin(request);
    final db = await _readDb();
    final dues = List<Map<String, dynamic>>.from(db['dues'] as List);
    final dueIndex = dues.indexWhere((due) => due['id']?.toString() == id);
    if (dueIndex < 0) {
      return _error('Fee record not found', HttpStatus.notFound);
    }

    final due = Map<String, dynamic>.from(dues[dueIndex]);
    final users = List<Map<String, dynamic>>.from(db['users'] as List);
    final student = users.cast<Map<String, dynamic>?>().firstWhere(
          (user) =>
              user != null &&
              user['id']?.toString() == due['studentId']?.toString(),
          orElse: () => null,
        );
    final parentPhone = student?['parentPhone']?.toString().trim() ?? '';
    if (parentPhone.isEmpty) {
      return _error(
        'No parent phone is saved for this student',
        HttpStatus.conflict,
      );
    }
    due['lastReminderAt'] = DateTime.now().toIso8601String();
    dues[dueIndex] = due;
    db['dues'] = dues;
    _recordActivity(
      db,
      adminId,
      'fees.parent_reminder',
      'fee',
      id,
      'Opened a fee reminder for ${due['student']} and their parent.',
    );
    await _writeDb(db);
    return _json({'due': due, 'parentPhone': parentPhone});
  } on _AuthException catch (e) {
    return _error(e.message, e.statusCode);
  }
}

Future<Response> _adminDashboardHandler(Request request) async {
  try {
    await _requireAdmin(request);
    final db = await _readDb();
    final users = List<Map<String, dynamic>>.from(db['users'] as List);
    final rooms = List<Map<String, dynamic>>.from(db['rooms'] as List);
    final complaints = List<Map<String, dynamic>>.from(db['complaints'] as List);
    final checkins = List<Map<String, dynamic>>.from(db['checkins'] as List);

    final studentsCount =
        users.where((u) => (u['role']?.toString() ?? 'student') == 'student').length;
    final adminsCount =
        users.where((u) => (u['role']?.toString() ?? 'student') == 'admin').length;
    final roomsCount = rooms.length;
    final activeCheckins =
        checkins.where((c) => (c['checkOutAt']?.toString() ?? '').isEmpty).length;
    final openComplaints = complaints.where((c) {
      final s = (c['status']?.toString() ?? 'open').toLowerCase();
      return s != 'resolved' && s != 'closed';
    }).length;

    return _json({
      'counts': {
        'students': studentsCount,
        'admins': adminsCount,
        'rooms': roomsCount,
        'activeCheckins': activeCheckins,
        'openComplaints': openComplaints,
      },
    });
  } on _AuthException catch (e) {
    return _error(e.message, e.statusCode);
  }
}

Future<Response> _adminRoomsListHandler(Request request) async {
  try {
    await _requireAdmin(request);
    final db = await _readDb();
    final rooms = List<Map<String, dynamic>>.from(db['rooms'] as List);
    return _json({'rooms': rooms});
  } on _AuthException catch (e) {
    return _error(e.message, e.statusCode);
  }
}

Future<Response> _availableRoomsHandler(Request request) async {
  try {
    _requireAuthUserId(request);
    final db = await _readDb();
    final rooms = List<Map<String, dynamic>>.from(db['rooms'] as List)
        .where((room) {
          final status = room['status']?.toString().toLowerCase() ?? '';
          final capacity = int.tryParse(room['capacity']?.toString() ?? '') ?? 0;
          final occupied =
              int.tryParse(room['occupiedCount']?.toString() ?? '') ?? 0;
          return status != 'maintenance' && capacity > occupied;
        })
        .toList();
    return _json({'rooms': rooms});
  } on _AuthException catch (e) {
    return _error(e.message, e.statusCode);
  }
}

Future<Response> _adminRoomsCreateHandler(Request request) async {
  try {
    final adminId = await _requireAdmin(request);
    final body = await _readJson(request);

    final building = _requiredString(body, 'building');
    final roomNo = _requiredString(body, 'roomNo');
    final type = _requiredString(body, 'type');
    final status = (body['status']?.toString().trim().isEmpty ?? true)
        ? 'available'
        : body['status']!.toString().trim();
    final floor = int.tryParse(body['floor']?.toString() ?? '') ?? 0;
    final capacity = int.tryParse(body['capacity']?.toString() ?? '') ?? 1;

    final db = await _readDb();
    final rooms = List<Map<String, dynamic>>.from(db['rooms'] as List);

    final room = {
      'id': _id(),
      'building': building,
      'floor': floor,
      'roomNo': roomNo,
      'capacity': capacity,
      'occupiedCount': 0,
      'type': type,
      'status': status,
      'createdAt': DateTime.now().toIso8601String(),
    };
    rooms.add(room);

    db['rooms'] = rooms;
    _recordActivity(
      db,
      adminId,
      'room.created',
      'room',
      room['id'].toString(),
      'Created room $roomNo in $building.',
    );
    await _writeDb(db);
    return _json({'rooms': rooms}, statusCode: HttpStatus.created);
  } on _AuthException catch (e) {
    return _error(e.message, e.statusCode);
  }
}

Future<Response> _adminRoomsUpdateHandler(Request request, String id) async {
  try {
    final adminId = await _requireAdmin(request);
    final body = await _readJson(request);

    final db = await _readDb();
    final rooms = List<Map<String, dynamic>>.from(db['rooms'] as List);
    final index = rooms.indexWhere((r) => r['id']?.toString() == id);
    if (index < 0) return _error('Room not found', HttpStatus.notFound);

    final room = Map<String, dynamic>.from(rooms[index]);
    if (body.containsKey('building')) room['building'] = body['building']?.toString() ?? '';
    if (body.containsKey('roomNo')) room['roomNo'] = body['roomNo']?.toString() ?? '';
    if (body.containsKey('type')) room['type'] = body['type']?.toString() ?? '';
    if (body.containsKey('status')) room['status'] = body['status']?.toString() ?? '';
    if (body.containsKey('floor')) {
      room['floor'] = int.tryParse(body['floor']?.toString() ?? '') ?? 0;
    }
    if (body.containsKey('capacity')) {
      room['capacity'] = int.tryParse(body['capacity']?.toString() ?? '') ?? 1;
    }

    rooms[index] = room;
    db['rooms'] = rooms;
    _recordActivity(
      db,
      adminId,
      'room.updated',
      'room',
      id,
      'Updated room ${room['roomNo']}.',
    );
    await _writeDb(db);
    return _json({'room': room});
  } on _AuthException catch (e) {
    return _error(e.message, e.statusCode);
  }
}

Future<Response> _complaintCreateHandler(Request request) async {
  try {
    final userId = _requireAuthUserId(request);
    final body = await _readJson(request);
    final title = _requiredString(body, 'title');
    final description = _requiredString(body, 'description');

    final db = await _readDb();
    final complaints = List<Map<String, dynamic>>.from(db['complaints'] as List);
    final complaint = {
      'id': _id(),
      'userId': userId,
      'title': title,
      'description': description,
      'status': 'open',
      'createdAt': DateTime.now().toIso8601String(),
    };
    complaints.add(complaint);
    db['complaints'] = complaints;
    await _writeDb(db);
    return _json({'complaint': complaint}, statusCode: HttpStatus.created);
  } on _AuthException catch (e) {
    return _error(e.message, e.statusCode);
  }
}

Future<Response> _myComplaintsHandler(Request request) async {
  try {
    final userId = _requireAuthUserId(request);
    final db = await _readDb();
    final complaints = List<Map<String, dynamic>>.from(db['complaints'] as List);
    final mine = complaints
        .where((c) => c['userId']?.toString() == userId)
        .map((c) => Map<String, dynamic>.from(c))
        .toList();
    mine.sort((a, b) => (b['createdAt']?.toString() ?? '').compareTo(a['createdAt']?.toString() ?? ''));
    return _json({'complaints': mine});
  } on _AuthException catch (e) {
    return _error(e.message, e.statusCode);
  }
}

Future<Response> _myCheckinsHandler(Request request) async {
  try {
    final userId = _requireAuthUserId(request);
    final db = await _readDb();
    final checkins = List<Map<String, dynamic>>.from(db['checkins'] as List);
    final rooms = List<Map<String, dynamic>>.from(db['rooms'] as List);
    final roomsById = <String, Map<String, dynamic>>{
      for (final r in rooms) r['id']?.toString() ?? '': r,
    };

    final mine = checkins
        .where((c) => c['userId']?.toString() == userId)
        .map((c) {
          final m = Map<String, dynamic>.from(c);
          final room = roomsById[m['roomId']?.toString() ?? ''];
          if (room != null) m['room'] = room;
          return m;
        })
        .toList();
    mine.sort((a, b) => (b['checkInAt']?.toString() ?? '').compareTo(a['checkInAt']?.toString() ?? ''));
    return _json({'checkins': mine});
  } on _AuthException catch (e) {
    return _error(e.message, e.statusCode);
  }
}

Future<Response> _myRoomHandler(Request request) async {
  try {
    final userId = _requireAuthUserId(request);
    final db = await _readDb();
    final checkins = List<Map<String, dynamic>>.from(db['checkins'] as List);
    final rooms = List<Map<String, dynamic>>.from(db['rooms'] as List);
    final roomsById = <String, Map<String, dynamic>>{
      for (final r in rooms) r['id']?.toString() ?? '': r,
    };

    final active = checkins.cast<Map<String, dynamic>?>().firstWhere(
          (c) =>
              c != null &&
              c['userId']?.toString() == userId &&
              (c['checkOutAt']?.toString() ?? '').isEmpty,
          orElse: () => null,
        );

    if (active == null) {
      return _json({'activeCheckin': null, 'room': null});
    }

    final room = roomsById[active['roomId']?.toString() ?? ''];
    return _json({
      'activeCheckin': active,
      'room': room,
    });
  } on _AuthException catch (e) {
    return _error(e.message, e.statusCode);
  }
}

Future<Response> _adminComplaintsListHandler(Request request) async {
  try {
    await _requireAdmin(request);
    final db = await _readDb();
    final complaints = List<Map<String, dynamic>>.from(db['complaints'] as List);
    final users = List<Map<String, dynamic>>.from(db['users'] as List);

    final byId = <String, Map<String, dynamic>>{
      for (final u in users) u['id']?.toString() ?? '': u,
    };

    final enriched = complaints.map((c) {
      final m = Map<String, dynamic>.from(c);
      final user = byId[m['userId']?.toString() ?? ''];
      if (user != null) {
        m['user'] = _safeUser(user);
      }
      return m;
    }).toList();

    return _json({'complaints': enriched});
  } on _AuthException catch (e) {
    return _error(e.message, e.statusCode);
  }
}

Future<Response> _adminComplaintsUpdateHandler(Request request, String id) async {
  try {
    final adminId = await _requireAdmin(request);
    final body = await _readJson(request);
    final status = body['status']?.toString().trim().toLowerCase();
    if (status == null || status.isEmpty) {
      return _error('Missing field: status', HttpStatus.badRequest);
    }

    final db = await _readDb();
    final complaints = List<Map<String, dynamic>>.from(db['complaints'] as List);
    final index = complaints.indexWhere((c) => c['id']?.toString() == id);
    if (index < 0) return _error('Complaint not found', HttpStatus.notFound);

    final complaint = Map<String, dynamic>.from(complaints[index]);
    complaint['status'] = status;
    if (status == 'resolved' || status == 'closed') {
      complaint['resolvedAt'] = DateTime.now().toIso8601String();
    }
    complaints[index] = complaint;
    db['complaints'] = complaints;
    _recordActivity(
      db,
      adminId,
      'complaint.status_updated',
      'complaint',
      id,
      'Changed complaint status to $status.',
    );
    await _writeDb(db);
    return _json({'complaint': complaint});
  } on _AuthException catch (e) {
    return _error(e.message, e.statusCode);
  }
}

Future<Response> _adminCheckinsListHandler(Request request) async {
  try {
    await _requireAdmin(request);
    final db = await _readDb();
    final checkins = List<Map<String, dynamic>>.from(db['checkins'] as List);
    final users = List<Map<String, dynamic>>.from(db['users'] as List);
    final rooms = List<Map<String, dynamic>>.from(db['rooms'] as List);

    final usersById = <String, Map<String, dynamic>>{
      for (final u in users) u['id']?.toString() ?? '': u,
    };
    final roomsById = <String, Map<String, dynamic>>{
      for (final r in rooms) r['id']?.toString() ?? '': r,
    };

    final enriched = checkins.map((c) {
      final m = Map<String, dynamic>.from(c);
      final user = usersById[m['userId']?.toString() ?? ''];
      final room = roomsById[m['roomId']?.toString() ?? ''];
      if (user != null) m['user'] = _safeUser(user);
      if (room != null) m['room'] = room;
      return m;
    }).toList();

    return _json({'checkins': enriched});
  } on _AuthException catch (e) {
    return _error(e.message, e.statusCode);
  }
}

Future<Response> _adminCheckInHandler(Request request) async {
  try {
    final adminId = await _requireAdmin(request);
    final body = await _readJson(request);
    final userId = _requiredString(body, 'userId');
    final roomId = _requiredString(body, 'roomId');

    final db = await _readDb();
    final users = List<Map<String, dynamic>>.from(db['users'] as List);
    final rooms = List<Map<String, dynamic>>.from(db['rooms'] as List);
    final checkins = List<Map<String, dynamic>>.from(db['checkins'] as List);

    final user = users.cast<Map<String, dynamic>?>().firstWhere(
          (u) => u != null && u['id']?.toString() == userId,
          orElse: () => null,
        );
    if (user == null) return _error('User not found', HttpStatus.notFound);

    final roomIndex = rooms.indexWhere((r) => r['id']?.toString() == roomId);
    if (roomIndex < 0) return _error('Room not found', HttpStatus.notFound);

    final room = Map<String, dynamic>.from(rooms[roomIndex]);
    final capacity = int.tryParse(room['capacity']?.toString() ?? '') ?? 1;
    final occupied = int.tryParse(room['occupiedCount']?.toString() ?? '') ?? 0;
    if (occupied >= capacity) {
      return _error('Room is full', HttpStatus.conflict);
    }

    final alreadyActive = checkins.any(
      (c) =>
          c['userId']?.toString() == userId &&
          (c['checkOutAt']?.toString() ?? '').isEmpty,
    );
    if (alreadyActive) {
      return _error('User already checked-in', HttpStatus.conflict);
    }

    final checkin = {
      'id': _id(),
      'userId': userId,
      'roomId': roomId,
      'checkInAt': DateTime.now().toIso8601String(),
      'checkOutAt': '',
    };
    checkins.add(checkin);
    room['occupiedCount'] = occupied + 1;
    rooms[roomIndex] = room;

    db['checkins'] = checkins;
    db['rooms'] = rooms;
    _recordActivity(
      db,
      adminId,
      'room.checkin',
      'student',
      userId,
      'Checked in ${user['name']} to room ${room['roomNo'] ?? roomId}.',
    );
    await _writeDb(db);
    return _json({'checkin': checkin}, statusCode: HttpStatus.created);
  } on _AuthException catch (e) {
    return _error(e.message, e.statusCode);
  }
}

Future<Response> _adminCheckOutHandler(Request request) async {
  try {
    final adminId = await _requireAdmin(request);
    final body = await _readJson(request);
    final checkinId = _requiredString(body, 'checkinId');

    final db = await _readDb();
    final rooms = List<Map<String, dynamic>>.from(db['rooms'] as List);
    final checkins = List<Map<String, dynamic>>.from(db['checkins'] as List);

    final checkinIndex = checkins.indexWhere((c) => c['id']?.toString() == checkinId);
    if (checkinIndex < 0) return _error('Check-in not found', HttpStatus.notFound);

    final checkin = Map<String, dynamic>.from(checkins[checkinIndex]);
    if ((checkin['checkOutAt']?.toString() ?? '').isNotEmpty) {
      return _error('Already checked-out', HttpStatus.conflict);
    }
    checkin['checkOutAt'] = DateTime.now().toIso8601String();
    checkins[checkinIndex] = checkin;

    final roomId = checkin['roomId']?.toString() ?? '';
    final roomIndex = rooms.indexWhere((r) => r['id']?.toString() == roomId);
    if (roomIndex >= 0) {
      final room = Map<String, dynamic>.from(rooms[roomIndex]);
      final occupied = int.tryParse(room['occupiedCount']?.toString() ?? '') ?? 0;
      room['occupiedCount'] = occupied > 0 ? occupied - 1 : 0;
      rooms[roomIndex] = room;
    }

    db['checkins'] = checkins;
    db['rooms'] = rooms;
    _recordActivity(
      db,
      adminId,
      'room.checkout',
      'student',
      checkin['userId']?.toString() ?? '',
      'Checked out student ${checkin['userId']}.',
    );
    await _writeDb(db);
    return _json({'checkin': checkin});
  } on _AuthException catch (e) {
    return _error(e.message, e.statusCode);
  }
}

Future<Response> _adminSwapRoomsHandler(Request request) async {
  try {
    final adminId = await _requireAdmin(request);
    final body = await _readJson(request);
    final firstId = _requiredString(body, 'firstCheckinId');
    final secondId = _requiredString(body, 'secondCheckinId');
    if (firstId == secondId) {
      return _error('Select two different students', HttpStatus.badRequest);
    }

    final db = await _readDb();
    final users = List<Map<String, dynamic>>.from(db['users'] as List);
    final rooms = List<Map<String, dynamic>>.from(db['rooms'] as List);
    final checkins = List<Map<String, dynamic>>.from(db['checkins'] as List);
    final firstIndex = checkins.indexWhere((item) => item['id']?.toString() == firstId);
    final secondIndex = checkins.indexWhere((item) => item['id']?.toString() == secondId);
    if (firstIndex < 0 || secondIndex < 0) {
      return _error('Check-in not found', HttpStatus.notFound);
    }

    final first = Map<String, dynamic>.from(checkins[firstIndex]);
    final second = Map<String, dynamic>.from(checkins[secondIndex]);
    if ((first['checkOutAt']?.toString() ?? '').isNotEmpty ||
        (second['checkOutAt']?.toString() ?? '').isNotEmpty) {
      return _error('Both students must be checked in', HttpStatus.conflict);
    }
    final firstRoomId = first['roomId']?.toString() ?? '';
    final secondRoomId = second['roomId']?.toString() ?? '';
    if (firstRoomId.isEmpty || secondRoomId.isEmpty || firstRoomId == secondRoomId) {
      return _error('Students must be in different rooms', HttpStatus.conflict);
    }

    final firstRoom = rooms.firstWhere((room) => room['id']?.toString() == firstRoomId);
    final secondRoom = rooms.firstWhere((room) => room['id']?.toString() == secondRoomId);
    final firstStudent = users.firstWhere(
      (user) => user['id']?.toString() == first['userId']?.toString(),
    );
    final secondStudent = users.firstWhere(
      (user) => user['id']?.toString() == second['userId']?.toString(),
    );

    first['roomId'] = secondRoomId;
    second['roomId'] = firstRoomId;
    checkins[firstIndex] = first;
    checkins[secondIndex] = second;
    for (final student in users) {
      if (student['id']?.toString() == first['userId']?.toString()) {
        student['roomId'] = secondRoomId;
      } else if (student['id']?.toString() == second['userId']?.toString()) {
        student['roomId'] = firstRoomId;
      }
    }
    db['checkins'] = checkins;
    db['users'] = users;
    _recordActivity(
      db,
      adminId,
      'room.students_swapped',
      'room',
      '$firstRoomId:$secondRoomId',
      'Swapped ${firstStudent['name']} (room ${firstRoom['roomNo']}) with '
          '${secondStudent['name']} (room ${secondRoom['roomNo']}).',
    );
    await _writeDb(db);
    return _json({'checkins': [first, second]});
  } on _AuthException catch (e) {
    return _error(e.message, e.statusCode);
  } on StateError {
    return _error('Room or student record not found', HttpStatus.notFound);
  }
}

Future<void> _ensureDatabase() async {
  if (!_dbFile.parent.existsSync()) {
    _dbFile.parent.createSync(recursive: true);
  }
  if (!_dbFile.existsSync()) {
    final seed = {
      'users': <Map<String, dynamic>>[],
      'contacts': <Map<String, dynamic>>[],
      'admissions': <Map<String, dynamic>>[],
      'complaints': <Map<String, dynamic>>[],
      'rooms': <Map<String, dynamic>>[],
      'checkins': <Map<String, dynamic>>[],
      'hostels': [
        {
          'id': 'indra',
          'name': 'Indra (New Boys Hostel)',
          'type': 'Boys',
          'roomType': 'Double Occupancy',
          'summary': 'Modern mess, WiFi, laundry, and study room',
        },
        {
          'id': 'boys-abcd',
          'name': 'Boys Hostel (A, B, C, D)',
          'type': 'Boys',
          'roomType': 'Single / Double Occupancy',
          'summary': 'Security, attached bathroom, wardrobe, and campus video',
        },
        {
          'id': 'girls-fairy',
          'name': 'Girls Hostel (Fairy)',
          'type': 'Girls',
          'roomType': 'Triple Occupancy',
          'summary': 'Common study room, WiFi, and reading lamp',
        },
        {
          'id': 'girls-haripriya',
          'name': 'Girls Hostel (Haripriya)',
          'type': 'Girls',
          'roomType': 'Double Occupancy',
          'summary': 'Recreation room, WiFi, and reading lamp',
        },
      ],
    };
    await _writeDb(seed);
  }

  await _migrateDb();
}

Future<Map<String, dynamic>> _readDb() async {
  final raw = await _dbFile.readAsString();
  return Map<String, dynamic>.from(jsonDecode(raw) as Map);
}

Future<void> _writeDb(Map<String, dynamic> db) async {
  await _dbFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(db),
  );
}

Future<Map<String, dynamic>> _readJson(Request request) async {
  try {
    final raw = await request.readAsString();
    if (raw.trim().isEmpty) {
      return <String, dynamic>{};
    }
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  } catch (_) {
    throw const FormatException('Invalid JSON body');
  }
}

Response _json(Map<String, dynamic> body, {int statusCode = HttpStatus.ok}) {
  return Response(
    statusCode,
    body: jsonEncode(body),
    headers: {HttpHeaders.contentTypeHeader: ContentType.json.mimeType},
  );
}

Response _error(String message, int statusCode) {
  return _json({'message': message}, statusCode: statusCode);
}

String _requiredString(Map<String, dynamic> body, String key) {
  final value = body[key];
  if (value == null || value.toString().trim().isEmpty) {
    throw FormatException('Missing field: $key');
  }
  return value.toString().trim();
}

String _hashPassword(String value) {
  return sha256.convert(utf8.encode(value)).toString();
}

String _tokenForUser(Map<String, dynamic> user) {
  final jwt = JWT({
    'sub': user['id'],
    'email': user['email'],
    'name': user['name'],
    'role': user['role']?.toString() ?? 'student',
  });
  return jwt.sign(SecretKey(_jwtSecret), expiresIn: const Duration(days: 7));
}

Map<String, dynamic> _safeUser(Map<String, dynamic> user) {
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
    'role': user['role']?.toString() ?? 'student',
  };
}

void _recordActivity(
  Map<String, dynamic> db,
  String adminId,
  String action,
  String entity,
  String entityId,
  String description,
) {
  final users = List<Map<String, dynamic>>.from(db['users'] as List);
  final admin = users.cast<Map<String, dynamic>?>().firstWhere(
        (user) => user != null && user['id']?.toString() == adminId,
        orElse: () => null,
      );
  final logs = List<Map<String, dynamic>>.from(db['activityLogs'] as List);
  logs.add({
    'id': _id(),
    'actorId': adminId,
    'actorName': admin?['name']?.toString() ?? 'Admin',
    'action': action,
    'entity': entity,
    'entityId': entityId,
    'description': description,
    'createdAt': DateTime.now().toIso8601String(),
  });
  db['activityLogs'] = logs;
}

String _id() => DateTime.now().microsecondsSinceEpoch.toString();

Future<void> _migrateDb() async {
  final db = await _readDb();
  var changed = false;

  void ensureList(String key) {
    if (db[key] is! List) {
      db[key] = <Map<String, dynamic>>[];
      changed = true;
    }
  }

  ensureList('users');
  ensureList('contacts');
  ensureList('admissions');
  ensureList('hostels');
  ensureList('rooms');
  ensureList('complaints');
  ensureList('checkins');
  ensureList('dues');
  ensureList('activityLogs');

  final users = List<Map<String, dynamic>>.from(db['users'] as List);
  for (var i = 0; i < users.length; i++) {
    final u = Map<String, dynamic>.from(users[i]);
    if (u['role'] == null || u['role'].toString().trim().isEmpty) {
      u['role'] = 'student';
      users[i] = u;
      changed = true;
    }
  }

  final hasAdmin = users.any((u) => (u['role']?.toString() ?? '') == 'admin');
  if (!hasAdmin) {
    final adminEmail = (Platform.environment['ADMIN_EMAIL'] ?? _defaultAdminEmail)
        .trim()
        .toLowerCase();
    final adminPassword = Platform.environment['ADMIN_PASSWORD'] ?? _defaultAdminPassword;

    final existsEmail = users.any(
      (u) => (u['email']?.toString().toLowerCase() ?? '') == adminEmail,
    );
    if (!existsEmail) {
      users.add({
        'id': _id(),
        'name': 'Admin',
        'email': adminEmail,
        'passwordHash': _hashPassword(adminPassword),
        'gender': 'N/A',
        'age': 'N/A',
        'phone': 'N/A',
        'role': 'admin',
        'createdAt': DateTime.now().toIso8601String(),
      });
      changed = true;
    }
  }

  db['users'] = users;

  if (changed) {
    await _writeDb(db);
  }
}

class _AuthException implements Exception {
  _AuthException(this.message, this.statusCode);
  final String message;
  final int statusCode;
}

String _requireAuthUserId(Request request) {
  final auth = request.headers[HttpHeaders.authorizationHeader];
  if (auth == null || !auth.startsWith('Bearer ')) {
    throw _AuthException('Missing bearer token', HttpStatus.unauthorized);
  }
  final token = auth.substring('Bearer '.length);
  final jwt = JWT.verify(token, SecretKey(_jwtSecret));
  final payload = jwt.payload as Map<String, dynamic>;
  final sub = payload['sub']?.toString();
  if (sub == null || sub.isEmpty) {
    throw _AuthException('Invalid token', HttpStatus.unauthorized);
  }
  return sub;
}

Future<String> _requireAdmin(Request request) async {
  final userId = _requireAuthUserId(request);
  final db = await _readDb();
  final users = List<Map<String, dynamic>>.from(db['users'] as List);
  final user = users.cast<Map<String, dynamic>?>().firstWhere(
        (u) => u != null && u['id'] == userId,
        orElse: () => null,
      );
  if (user == null) {
    throw _AuthException('User not found', HttpStatus.unauthorized);
  }
  if ((user['role']?.toString() ?? 'student') != 'admin') {
    throw _AuthException('Admin access required', HttpStatus.forbidden);
  }
  return userId;
}

Middleware _errorMiddleware() {
  return (innerHandler) {
    return (request) async {
      try {
        return await innerHandler(request);
      } on FormatException catch (e) {
        return _error(e.message, HttpStatus.badRequest);
      } catch (_) {
        return _error('Internal server error', HttpStatus.internalServerError);
      }
    };
  };
}
