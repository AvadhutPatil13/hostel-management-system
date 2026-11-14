import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/backend_config.dart';
import '../../services/api_service.dart';
import '../../services/firebase_service.dart';

class AdminFeesPage extends StatefulWidget {
  const AdminFeesPage({super.key});

  @override
  State<AdminFeesPage> createState() => _AdminFeesPageState();
}

class _AdminFeesPageState extends State<AdminFeesPage> {
  static const String _prefsKey = 'hostel_fees_v3';

  final TextEditingController _searchController =
      TextEditingController();

  List<Map<String, dynamic>> _dues = <Map<String, dynamic>>[];

  String _searchQuery = '';
  String _filter = 'All';
  String _feeTypeFilter = 'All';

  bool _isAdding = false;
  bool _isGeneratingMonthly = false;
  String? _processingDueId;

  Stream<List<Map<String, dynamic>>>? _duesStream;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_onSearchChanged);

    if (BackendConfig.useFirebase) {
      _duesStream = FirebaseService.duesStream();
    }
    _generateMonthlyDues(showResult: false);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // SEARCH
  // ============================================================

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();

    if (query == _searchQuery) {
      return;
    }

    setState(() {
      _searchQuery = query;
    });
  }

  // ============================================================
  // FILTERING
  // ============================================================

  List<Map<String, dynamic>> _filterDues(
    List<Map<String, dynamic>> dues,
  ) {
    final query = _searchQuery.trim().toLowerCase();

    return dues.where((due) {
      final student = _normalize(due['student']);
      final room = _normalize(due['room']);
      final feeType = _normalize(due['feeType']);
      final amount = _normalize(due['amount']);

      final matchesSearch =
          query.isEmpty ||
          student.contains(query) ||
          room.contains(query) ||
          feeType.contains(query) ||
          amount.contains(query);

      final paid = due['paid'] == true;
      final overdue = _isOverdue(due);

      bool matchesStatus;

      switch (_filter) {
        case 'Paid':
          matchesStatus = paid;
          break;

        case 'Pending':
          matchesStatus = !paid && !overdue;
          break;

        case 'Overdue':
          matchesStatus = overdue;
          break;

        default:
          matchesStatus = true;
      }

      final type = due['feeType']?.toString() ?? 'Hostel Fee';

      final matchesType =
          _feeTypeFilter == 'All' || type == _feeTypeFilter;

      return matchesSearch && matchesStatus && matchesType;
    }).toList();
  }

  String _normalize(dynamic value) {
    return value?.toString().trim().toLowerCase() ?? '';
  }

  // ============================================================
  // LOCAL STORAGE
  // ============================================================

  Future<void> _loadDues() async {
    try {
      final serverDues = await ApiService.adminListDues();
      final prefs = await SharedPreferences.getInstance();

      final raw = prefs.getString(_prefsKey);
      final localDues = <Map<String, dynamic>>[];

      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);

          if (decoded is List) {
            localDues.addAll(decoded
                .whereType<Map>()
                .map(
                  (item) => Map<String, dynamic>.from(item),
                )
                .toList());
          }
        } catch (_) {}
      }

      if (!mounted) return;

      final serverIds = serverDues
          .map((due) => due['id']?.toString())
          .whereType<String>()
          .toSet();
      setState(() {
        _dues = [
          ...serverDues,
          ...localDues.where(
            (due) => !serverIds.contains(due['id']?.toString()),
          ),
        ];
      });
    } catch (e) {
      if (!mounted) return;

      _showError('Unable to load fees: $e');
    }
  }

  Future<void> _generateMonthlyDues({bool showResult = true}) async {
    if (_isGeneratingMonthly) return;
    setState(() => _isGeneratingMonthly = true);
    try {
      final createdCount = await ApiService.adminGenerateMonthlyDues();
      await _loadDues();
      if (!mounted) return;
      if (showResult) {
        _showSuccess(
          createdCount == 0
              ? 'Monthly fees are already assigned for every student.'
              : 'Created $createdCount monthly fee record(s) at ₹5000 each.',
        );
      }
    } catch (e) {
      if (mounted) _showError('Unable to generate monthly fees: $e');
    } finally {
      if (mounted) setState(() => _isGeneratingMonthly = false);
    }
  }

  Future<void> _sendParentReminder(
    Map<String, dynamic> due,
  ) async {
    final dueId = due['id']?.toString() ?? '';
    final phone = due['parentPhone']?.toString().trim() ?? '';
    if (dueId.isEmpty || phone.isEmpty) {
      _showError('This student does not have a parent phone number saved.');
      return;
    }
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final internationalPhone =
        digits.length == 10 ? '91$digits' : digits;
    final student = due['student']?.toString() ?? 'Student';
    final parentName = due['parentName']?.toString().trim();
    final amount =
        _formatAmount(due['remainingAmount'] ?? due['amount']);
    final feeMonth = due['feeMonth']?.toString().trim() ?? '';
    final message = 'Dear ${parentName?.isNotEmpty == true ? parentName : 'Parent'}, '
        'a hostel fee of ₹$amount is due for $student'
        '${feeMonth.isEmpty ? '' : ' for $feeMonth'}. '
        'Please contact the hostel office to complete payment.';

    try {
      final whatsappUri = Uri.https(
        'wa.me',
        '/$internationalPhone',
        {'text': message},
      );
      var opened = await launchUrl(
        whatsappUri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        opened = await launchUrl(
          Uri(
            scheme: 'sms',
            path: phone,
            queryParameters: {'body': message},
          ),
          mode: LaunchMode.externalApplication,
        );
      }
      if (!opened) {
        throw ApiException('No WhatsApp or SMS app is available to send this reminder.');
      }
      await ApiService.adminRecordFeeReminder(dueId);
      if (mounted) _showSuccess('Parent reminder opened and recorded.');
    } catch (e) {
      if (mounted) _showError('Unable to open or record reminder: $e');
    }
  }

  Future<void> _saveDues() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(
        _prefsKey,
        jsonEncode(
          _dues
              .where(
                (due) => due['id']?.toString().startsWith('local_') == true,
              )
              .toList(),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      _showError('Unable to save fees: $e');
    }
  }

  // ============================================================
  // ADD FEE
  // ============================================================

  Future<void> _addDue() async {
    if (_isAdding) return;

    final result =
        await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _AddFeeDialog(),
    );

    if (result == null || !mounted) {
      return;
    }

    final student = result['student'] as String;
    final room = result['room'] as String;
    final amount = result['amount'] as int;
    final feeType = result['feeType'] as String;
    final dueDate = result['dueDate'] as String?;

    setState(() {
      _isAdding = true;
    });

    try {
      await ApiService.adminAddDue(
        studentId: result['studentId'] as String?,
        student: student,
        room: room,
        amount: amount,
        feeType: feeType,
        dueDate: dueDate,
      );
      await _loadDues();
      if (mounted) _showSuccess('Fee added successfully');
    } catch (e) {
      if (!mounted) return;

      _showError('Failed to add fee: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isAdding = false;
        });
      }
    }
  }

  // ============================================================
  // PAID / UNPAID
  // ============================================================

  Future<void> _togglePaid(
    Map<String, dynamic> due,
  ) async {
    final currentPaid = due['paid'] == true;

    final dueId = due['id']?.toString() ?? '';

    if (currentPaid) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.undo_rounded),
                SizedBox(width: 10),
                Text('Reverse Payment?'),
              ],
            ),
            content: Text(
              '${due['student'] ?? 'Student'} has paid '
              '₹${_formatAmount(due['amount'])}.\n\n'
              'Are you sure you want to mark this fee as unpaid?',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Mark Unpaid'),
              ),
            ],
          );
        },
      );

      if (confirmed != true) {
        return;
      }
    }

    setState(() {
      _processingDueId =
          dueId.isEmpty ? '__local__' : dueId;
    });

    try {
      final newPaidStatus = !currentPaid;

      if (dueId.isNotEmpty && !dueId.startsWith('local_')) {
        await ApiService.adminSetDuePaid(dueId, newPaidStatus);

        if (!mounted) return;
        await _loadDues();
        if (!mounted) return;

        _showSuccess(
          newPaidStatus
              ? 'Payment marked as paid'
              : 'Payment marked as unpaid',
        );
      } else {
        final index = _dues.indexOf(due);

        if (index == -1) {
          return;
        }

        setState(() {
          _dues[index]['paid'] = newPaidStatus;

          _dues[index]['paidAt'] =
              newPaidStatus
                  ? DateTime.now().toIso8601String()
                  : null;

          _dues[index]['updatedAt'] =
              DateTime.now().toIso8601String();
        });

        await _saveDues();

        if (!mounted) return;

        _showSuccess(
          newPaidStatus
              ? 'Payment marked as paid'
              : 'Payment marked as unpaid',
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showError(
        'Failed to update payment: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingDueId = null;
        });
      }
    }
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<void> _removeDue(
    Map<String, dynamic> due,
  ) async {
    final student =
        due['student']?.toString() ?? 'Student';

    final amount =
        _formatAmount(due['amount']);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
              ),
              SizedBox(width: 10),
              Text('Remove Fee?'),
            ],
          ),
          content: Text(
            'Remove ₹$amount fee due for $student?\n\n'
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final dueId = due['id']?.toString() ?? '';

    setState(() {
      _processingDueId =
          dueId.isEmpty ? '__local__' : dueId;
    });

    try {
      if (dueId.isNotEmpty && !dueId.startsWith('local_')) {
        await ApiService.adminRemoveDue(dueId);

        if (!mounted) return;
        await _loadDues();
        if (!mounted) return;

        _showSuccess('Fee removed successfully');
      } else {
        setState(() {
          _dues.remove(due);
        });

        await _saveDues();

        if (!mounted) return;

        _showSuccess('Fee removed successfully');
      }
    } catch (e) {
      if (!mounted) return;

      _showError('Failed to remove fee: $e');
    } finally {
      if (mounted) {
        setState(() {
          _processingDueId = null;
        });
      }
    }
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  int _getAmount(dynamic value) {
    if (value is int) return value;

    if (value is double) {
      return value.toInt();
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  int _totalAmount(
    List<Map<String, dynamic>> dues,
  ) {
    return dues.fold<int>(
      0,
      (sum, due) =>
          sum + _getAmount(due['amount']),
    );
  }

  int _paidAmount(
    List<Map<String, dynamic>> dues,
  ) {
    return dues
        .where((due) => due['paid'] == true)
        .fold<int>(
          0,
          (sum, due) =>
              sum + _getAmount(due['amount']),
        );
  }

  int _pendingAmount(
    List<Map<String, dynamic>> dues,
  ) {
    return dues
        .where((due) => due['paid'] != true)
        .fold<int>(
          0,
          (sum, due) =>
              sum + _getAmount(due['amount']),
        );
  }

  int _paidCount(
    List<Map<String, dynamic>> dues,
  ) {
    return dues
        .where((due) => due['paid'] == true)
        .length;
  }

  int _pendingCount(
    List<Map<String, dynamic>> dues,
  ) {
    return dues
        .where((due) => due['paid'] != true)
        .length;
  }

  int _overdueCount(
    List<Map<String, dynamic>> dues,
  ) {
    return dues.where(_isOverdue).length;
  }

  // ============================================================
  // DATE
  // ============================================================

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    try {
      if (value.runtimeType.toString().contains('Timestamp')) {
        return value.toDate();
      }
    } catch (_) {}

    return null;
  }

  bool _isOverdue(
    Map<String, dynamic> due,
  ) {
    if (due['paid'] == true) {
      return false;
    }

    final dueDate = _parseDate(due['dueDate']);

    if (dueDate == null) {
      return false;
    }

    final today = DateTime.now();

    final todayOnly = DateTime(
      today.year,
      today.month,
      today.day,
    );

    final dueOnly = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day,
    );

    return dueOnly.isBefore(todayOnly);
  }

  String _formatDate(dynamic value) {
    final date = _parseDate(value);

    if (date == null) {
      return 'Not specified';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  // ============================================================
  // MAIN LIST
  // ============================================================

  Widget _buildDuesList(
    List<Map<String, dynamic>> dues,
  ) {
    final filteredDues = _filterDues(dues);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop =
            constraints.maxWidth >= 1000;

        return CustomScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 32 : 16,
                24,
                isDesktop ? 32 : 16,
                20,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    _buildHeader(dues.length),
                    const SizedBox(height: 24),
                    _buildSummaryCards(
                      dues,
                      isDesktop,
                    ),
                    const SizedBox(height: 24),
                    _buildSearchAndFilter(),
                    const SizedBox(height: 24),
                    _buildSectionHeader(
                      filteredDues.length,
                    ),
                  ],
                ),
              ),
            ),
            if (filteredDues.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  isDesktop ? 32 : 16,
                  0,
                  isDesktop ? 32 : 16,
                  120,
                ),
                sliver: SliverList(
                  delegate:
                      SliverChildBuilderDelegate(
                    (context, index) {
                      return _buildDueCard(
                        filteredDues[index],
                      );
                    },
                    childCount:
                        filteredDues.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(int totalRecords) {
    final width =
        MediaQuery.sizeOf(context).width;

    final canShowButton = width >= 600;

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 30,
                    color:
                        Theme.of(context)
                            .colorScheme
                            .primary,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Fee Management',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '$totalRecords fee record'
                '${totalRecords == 1 ? '' : 's'}',
                style: TextStyle(
                  color:
                      Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Generate this month’s ₹5000 hostel fees',
          onPressed: _isGeneratingMonthly ? null : _generateMonthlyDues,
          icon: _isGeneratingMonthly
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.calendar_month_outlined),
        ),
        if (canShowButton)
          FilledButton.icon(
            onPressed:
                _isAdding ? null : _addDue,
            icon: const Icon(Icons.add),
            label: const Text('Add Fee'),
          ),
      ],
    );
  }

  Widget _buildSectionHeader(int count) {
    return Row(
      children: [
        const Text(
          'Fee Records',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color:
                Theme.of(context)
                    .colorScheme
                    .primaryContainer,
            borderRadius:
                BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color:
                  Theme.of(context)
                      .colorScheme
                      .onPrimaryContainer,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Widget _buildSummaryCards(
    List<Map<String, dynamic>> dues,
    bool isDesktop,
  ) {
    final total = _totalAmount(dues);
    final paid = _paidAmount(dues);
    final pending = _pendingAmount(dues);
    final paidCount = _paidCount(dues);
    final overdueCount = _overdueCount(dues);

    final collectionRate =
        total == 0
            ? 0
            : ((paid / total) * 100).round();

    final cards = [
      _SummaryData(
        title: 'Total Fees',
        value: '₹${_formatAmount(total)}',
        subtitle: '${dues.length} records',
        icon:
            Icons.account_balance_wallet_outlined,
      ),
      _SummaryData(
        title: 'Collected',
        value: '₹${_formatAmount(paid)}',
        subtitle:
            '$paidCount paid • $collectionRate%',
        icon: Icons.check_circle_outline,
      ),
      _SummaryData(
        title: 'Pending',
        value: '₹${_formatAmount(pending)}',
        subtitle:
            '${_pendingCount(dues)} pending',
        icon:
            Icons.pending_actions_outlined,
      ),
      _SummaryData(
        title: 'Overdue',
        value: '$overdueCount',
        subtitle: 'Requires attention',
        icon:
            Icons.warning_amber_rounded,
      ),
    ];

    if (isDesktop) {
      return Row(
        children: List.generate(
          cards.length,
          (index) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right:
                      index == cards.length - 1
                          ? 0
                          : 12,
                ),
                child: _buildSummaryCard(
                  cards[index],
                ),
              ),
            );
          },
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns =
            constraints.maxWidth >= 600;

        if (!twoColumns) {
          return Column(
            children:
                cards.map((card) {
              return Padding(
                padding:
                    const EdgeInsets.only(
                  bottom: 10,
                ),
                child:
                    _buildSummaryCard(card),
              );
            }).toList(),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics:
              const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.4,
          ),
          itemBuilder:
              (context, index) {
            return _buildSummaryCard(
              cards[index],
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryCard(
    _SummaryData data,
  ) {
    final scheme =
        Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding:
            const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color:
                    scheme.primaryContainer,
                borderRadius:
                    BorderRadius.circular(14),
              ),
              child: Icon(
                data.icon,
                color:
                    scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Text(
                    data.title,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    data.value,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.subtitle,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          Colors.grey.shade600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SEARCH / FILTER
  // ============================================================

  Widget _buildSearchAndFilter() {
    return Card(
      elevation: 0,
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            TextField(
              controller:
                  _searchController,
              textInputAction:
                  TextInputAction.search,
              decoration:
                  InputDecoration(
                hintText:
                    'Search student, room, fee type or amount...',
                prefixIcon:
                    const Icon(
                  Icons.search,
                ),
                suffixIcon:
                    _searchController
                            .text
                            .isNotEmpty
                        ? IconButton(
                            tooltip:
                                'Clear search',
                            onPressed: () {
                              _searchController
                                  .clear();
                            },
                            icon:
                                const Icon(
                              Icons.clear,
                            ),
                          )
                        : null,
                filled: true,
                fillColor:
                    Theme.of(context)
                        .colorScheme
                        .surface,
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterChip('All'),
                _buildFilterChip('Paid'),
                _buildFilterChip('Pending'),
                _buildFilterChip('Overdue'),
              ],
            ),
            const SizedBox(height: 14),
            _buildFeeTypeSelector(),
            if (_searchQuery.isNotEmpty ||
                _filter != 'All' ||
                _feeTypeFilter != 'All')
              Padding(
                padding:
                    const EdgeInsets.only(
                  top: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _buildFilterDescription(),
                        style: TextStyle(
                          color:
                              Colors.grey.shade600,
                          fontSize: 13,
                        ),
                        overflow:
                            TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed:
                          _clearFilters,
                      child:
                          const Text('Clear'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeTypeSelector() {
    const types = [
      'All',
      'Hostel Fee',
      'Mess Fee',
      'Electricity',
      'Maintenance',
      'Fine',
      'Other',
    ];

    return DropdownButtonFormField<String>(
      initialValue: _feeTypeFilter,
      decoration:
          const InputDecoration(
        labelText: 'Fee Type',
        prefixIcon:
            Icon(Icons.category_outlined),
        border: OutlineInputBorder(),
      ),
      items: types.map((type) {
        return DropdownMenuItem(
          value: type,
          child: Text(type),
        );
      }).toList(),
      onChanged: (value) {
        if (value == null) return;

        setState(() {
          _feeTypeFilter = value;
        });
      },
    );
  }

  Widget _buildFilterChip(String value) {
    return FilterChip(
      label: Text(value),
      selected: _filter == value,
      onSelected: (_) {
        setState(() {
          _filter = value;
        });
      },
    );
  }

  String _buildFilterDescription() {
    final parts = <String>[];

    if (_searchQuery.isNotEmpty) {
      parts.add('Search: "$_searchQuery"');
    }

    if (_filter != 'All') {
      parts.add('Status: $_filter');
    }

    if (_feeTypeFilter != 'All') {
      parts.add('Type: $_feeTypeFilter');
    }

    return parts.join(' • ');
  }

  void _clearFilters() {
    _searchController.clear();

    setState(() {
      _filter = 'All';
      _feeTypeFilter = 'All';
    });
  }

  // ============================================================
  // FEE CARD
  // ============================================================

  Widget _buildDueCard(
    Map<String, dynamic> due,
  ) {
    final paid = due['paid'] == true;
    final overdue = _isOverdue(due);

    final id = due['id']?.toString() ?? '';

    final processing =
        _processingDueId == id;

    final student =
        due['student']?.toString() ??
            'Unknown Student';

    final room =
        due['room']?.toString() ?? '-';

    final feeType =
        due['feeType']?.toString() ??
            'Hostel Fee';

    final amount =
        _formatAmount(due['amount']);

    return Card(
      margin:
          const EdgeInsets.only(bottom: 12),
      elevation: 0,
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder:
              (context, constraints) {
            final compact =
                constraints.maxWidth < 650;

            final information = Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                _buildFeeIcon(
                  paid,
                  overdue,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              student,
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                              style:
                                  const TextStyle(
                                fontSize: 17,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ),
                          if (!compact)
                            _buildStatusBadge(
                              paid,
                              overdue,
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Room $room • $feeType',
                        maxLines: 2,
                        overflow:
                            TextOverflow.ellipsis,
                        style: TextStyle(
                          color:
                              Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '₹$amount',
                            style:
                                const TextStyle(
                              fontSize: 19,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (due['dueDate'] != null)
                            _buildDateLabel(
                              due['dueDate'],
                              overdue,
                            ),
                        ],
                      ),
                      if (compact) ...[
                        const SizedBox(height: 8),
                        _buildStatusBadge(
                          paid,
                          overdue,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );

            final actions = Row(
              mainAxisAlignment:
                  MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'View details',
                  onPressed:
                      () => _showFeeDetails(due),
                  icon: const Icon(
                    Icons.visibility_outlined,
                  ),
                ),
                if (!paid)
                  IconButton(
                    tooltip: due['parentPhone']?.toString().trim().isNotEmpty ==
                            true
                        ? 'Send WhatsApp/SMS reminder to parent'
                        : 'Add a parent phone number to send a reminder',
                    onPressed:
                        due['parentPhone']?.toString().trim().isNotEmpty ==
                                true
                            ? () => _sendParentReminder(due)
                            : null,
                    icon: const Icon(Icons.message_outlined),
                  ),
                IconButton(
                  tooltip: 'Remove fee',
                  onPressed:
                      processing
                          ? null
                          : () => _removeDue(due),
                  icon: const Icon(
                    Icons.delete_outline,
                  ),
                ),
                const SizedBox(width: 4),
                if (processing)
                  const SizedBox(
                    width: 46,
                    height: 42,
                    child: Padding(
                      padding:
                          EdgeInsets.all(10),
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                  )
                else if (!paid)
                  FilledButton.icon(
                    onPressed:
                        () => _togglePaid(due),
                    icon: const Icon(
                      Icons.check,
                      size: 18,
                    ),
                    label:
                        const Text('Mark Paid'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed:
                        () => _togglePaid(due),
                    icon: const Icon(
                      Icons.undo,
                      size: 18,
                    ),
                    label:
                        const Text('Unpaid'),
                  ),
              ],
            );

            return Column(
              children: [
                information,
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 4),
                if (compact)
                  Align(
                    alignment:
                        Alignment.centerRight,
                    child: actions,
                  )
                else
                  actions,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFeeIcon(
    bool paid,
    bool overdue,
  ) {
    final Color iconColor;
    final Color background;

    if (paid) {
      iconColor = Colors.green;
      background =
          Colors.green.withValues(alpha: 0.12);
    } else if (overdue) {
      iconColor = Colors.red;
      background =
          Colors.red.withValues(alpha: 0.12);
    } else {
      iconColor = Colors.orange;
      background =
          Colors.orange.withValues(alpha: 0.12);
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: background,
        borderRadius:
            BorderRadius.circular(12),
      ),
      child: Icon(
        paid
            ? Icons.check_circle_outline
            : overdue
                ? Icons.warning_amber_rounded
                : Icons.receipt_long_outlined,
        color: iconColor,
      ),
    );
  }

  Widget _buildStatusBadge(
    bool paid,
    bool overdue,
  ) {
    final String text;
    final Color color;

    if (paid) {
      text = 'PAID';
      color = Colors.green;
    } else if (overdue) {
      text = 'OVERDUE';
      color = Colors.red;
    } else {
      text = 'PENDING';
      color = Colors.orange;
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color:
            color.withValues(alpha: 0.12),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color:
              color.shadeIfMaterial(),
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildDateLabel(
    dynamic date,
    bool overdue,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          overdue
              ? Icons.warning_amber_rounded
              : Icons.event_outlined,
          size: 15,
          color:
              overdue
                  ? Colors.red
                  : Colors.grey.shade600,
        ),
        const SizedBox(width: 4),
        Text(
          _formatDate(date),
          style: TextStyle(
            fontSize: 12,
            fontWeight:
                overdue
                    ? FontWeight.bold
                    : FontWeight.normal,
            color:
                overdue
                    ? Colors.red
                    : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // DETAILS
  // ============================================================

  void _showFeeDetails(
    Map<String, dynamic> due,
  ) {
    final paid = due['paid'] == true;
    final overdue = _isOverdue(due);

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.receipt_long_outlined),
              SizedBox(width: 10),
              Text('Fee Details'),
            ],
          ),
          content: SizedBox(
            width: 430,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow(
                  'Student',
                  due['student']?.toString() ??
                      '-',
                ),
                _detailRow(
                  'Room',
                  due['room']?.toString() ??
                      '-',
                ),
                _detailRow(
                  'Fee Type',
                  due['feeType']?.toString() ??
                      '-',
                ),
                _detailRow(
                  'Amount',
                  '₹${_formatAmount(due['amount'])}',
                ),
                _detailRow(
                  'Status',
                  paid
                      ? 'Paid'
                      : overdue
                          ? 'Overdue'
                          : 'Pending',
                ),
                _detailRow(
                  'Due Date',
                  _formatDate(due['dueDate']),
                ),
                _detailRow(
                  'Paid Date',
                  _formatDate(due['paidAt']),
                ),
                _detailRow(
                  'Created',
                  _formatDate(due['createdAt']),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(
    String label,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color:
                    Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmptyState() {
    final hasFilter =
        _searchQuery.isNotEmpty ||
        _filter != 'All' ||
        _feeTypeFilter != 'All';

    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color:
                    Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasFilter
                    ? Icons.search_off
                    : Icons.receipt_long_outlined,
                size: 48,
                color:
                    Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasFilter
                  ? 'No matching fees'
                  : 'No fees recorded',
              style:
                  const TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilter
                  ? 'Try changing your search or filters.'
                  : 'Add a fee record to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color:
                    Colors.grey.shade600,
              ),
            ),
            if (hasFilter) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed:
                    _clearFilters,
                icon:
                    const Icon(Icons.clear_all),
                label:
                    const Text('Clear Filters'),
              ),
            ] else ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed:
                    _isAdding
                        ? null
                        : _addDue,
                icon:
                    const Icon(Icons.add),
                label:
                    const Text('Add First Fee'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FORMATTING
  // ============================================================

  String _formatAmount(dynamic value) {
    final amount = _getAmount(value);

    final text = amount.toString();
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      final position = text.length - i;

      buffer.write(text[i]);

      if (position > 1 &&
          position % 3 == 1) {
        buffer.write(',');
      }
    }

    return buffer.toString();
  }

  // ============================================================
  // SNACKBARS
  // ============================================================

  void _showSuccess(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior:
              SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final isMobile =
        MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fees'),
        actions: [
          if (!isMobile)
            IconButton(
              tooltip: 'Refresh',
              onPressed: () async {
                try {
                  await FirebaseService.listDues();

                  if (!mounted) return;

                  _showSuccess(
                    'Fees refreshed',
                  );
                } catch (e) {
                  if (!mounted) return;

                  _showError(
                    'Refresh failed: $e',
                  );
                }
              },
              icon:
                  const Icon(Icons.refresh),
            ),
        ],
      ),
      floatingActionButton:
          isMobile
              ? FloatingActionButton.extended(
                  onPressed:
                      _isAdding
                          ? null
                          : _addDue,
                  icon:
                      const Icon(Icons.add),
                  label:
                      const Text('Add Fee'),
                )
              : null,
      body:
          BackendConfig.useFirebase
              ? StreamBuilder<
                  List<Map<String, dynamic>>>(
                  stream: _duesStream,
                  builder:
                      (context, snapshot) {
                    if (snapshot.hasError) {
                      return _buildFirebaseError(
                        snapshot.error,
                      );
                    }

                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child:
                            CircularProgressIndicator(),
                      );
                    }

                    final dues =
                        snapshot.data ??
                            <Map<String, dynamic>>[];

                    return RefreshIndicator(
                      onRefresh: () async {
                        try {
                          await FirebaseService
                              .listDues();

                          if (!mounted) return;

                          _showSuccess(
                            'Fees refreshed successfully',
                          );
                        } catch (e) {
                          if (!mounted) return;

                          _showError(
                            'Refresh failed: $e',
                          );
                        }
                      },
                      child:
                          _buildDuesList(dues),
                    );
                  },
                )
              : RefreshIndicator(
                  onRefresh: _loadDues,
                  child:
                      _buildDuesList(_dues),
                ),
    );
  }

  // ============================================================
  // FIREBASE ERROR
  // ============================================================

  Widget _buildFirebaseError(
    Object? error,
  ) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(
            maxWidth: 500,
          ),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off,
                size: 70,
                color:
                    Colors.grey.shade400,
              ),
              const SizedBox(height: 18),
              const Text(
                'Unable to load fees',
                style:
                    TextStyle(
                  fontSize: 21,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error?.toString() ??
                    'Unknown Firebase error',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  color:
                      Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _duesStream =
                        FirebaseService
                            .duesStream();
                  });
                },
                icon:
                    const Icon(Icons.refresh),
                label:
                    const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// ADD FEE DIALOG
// ================================================================

class _AddFeeDialog extends StatefulWidget {
  const _AddFeeDialog();

  @override
  State<_AddFeeDialog> createState() =>
      _AddFeeDialogState();
}

class _AddFeeDialogState
    extends State<_AddFeeDialog> {
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  late final TextEditingController _nameController;

  late final TextEditingController _roomController;

  late final TextEditingController _amountController;

  String _feeType = 'Hostel Fee';

  DateTime? _dueDate;

  // Students list for selector (reused from Visitors)
  List<Map<String, dynamic>> _students = [];
  String? _selectedStudentId;
  bool _loadingStudents = false;

  String? _selectedRoomId;
  String? _selectedBlock;
  dynamic _selectedFloor;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController();

    _roomController = TextEditingController();

    _amountController = TextEditingController();

    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _loadingStudents = true;
    });

    try {
      final list = await FirebaseService.listStudentsForVisitors();
      if (!mounted) return;
      setState(() {
        _students = list;
      });
    } catch (e) {
      // ignore - leave students empty
    } finally {
      if (mounted) {
        setState(() {
          _loadingStudents = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roomController.dispose();
    _amountController.dispose();

    super.dispose();
  }

  Future<void> _selectDueDate() async {
    final now = DateTime.now();

    final selected =
        await showDatePicker(
      context: context,
      initialDate:
          _dueDate ?? now,
      firstDate:
          DateTime(now.year - 1),
      lastDate:
          DateTime(now.year + 5),
    );

    if (selected == null) return;

    setState(() {
      _dueDate = selected;
    });
  }

  void _submit() {
    final valid =
        _formKey.currentState
                ?.validate() ??
            false;

    if (!valid) return;

    final amount = int.tryParse(
      _amountController.text.trim(),
    );

    if (amount == null || amount <= 0) {
      return;
    }

    Navigator.of(context).pop(
      <String, dynamic>{
        'studentId': _selectedStudentId,
        'student': _nameController.text.trim(),
        'roomId': _selectedRoomId,
        'room': _roomController.text.trim(),
        'block': _selectedBlock,
        'floor': _selectedFloor,
        'amount': amount,
        'feeType': _feeType,
        'dueDate': _dueDate?.toIso8601String(),
      },
    );
  }

  String _formatSelectedDate() {
    if (_dueDate == null) {
      return 'No due date selected';
    }

    return '${_dueDate!.day.toString().padLeft(2, '0')}/'
        '${_dueDate!.month.toString().padLeft(2, '0')}/'
        '${_dueDate!.year}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.add_card),
          SizedBox(width: 10),
          Text('Add Fee Due'),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                // Student selector (reuses Visitor student list)
                _loadingStudents
                    ? const SizedBox(
                        width: double.infinity,
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      )
                    : DropdownButtonFormField<String>(
                        value: _selectedStudentId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Select Registered Student',
                          prefixIcon: const Icon(Icons.school_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: _students.map((student) {
                          final id = student['id']?.toString() ?? '';
                          final name = student['name']?.toString() ?? 'Unknown Student';
                          final room = student['roomNumber']?.toString() ?? '';
                          final block = student['block']?.toString() ?? '';
                          final roomText = room.isEmpty
                              ? ''
                              : block.isEmpty
                                  ? ' • Room $room'
                                  : ' • $block / Room $room';

                          return DropdownMenuItem<String>(
                            value: id,
                            child: Text(
                              '$name$roomText',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedStudentId = value;

                            // populate read-only fields
                            if (_selectedStudentId != null) {
                              final sel = _students.firstWhere(
                                  (s) => s['id']?.toString() == _selectedStudentId,
                                  orElse: () => {});

                              _nameController.text = sel['name']?.toString() ?? '';
                              _roomController.text = sel['roomNumber']?.toString() ?? '';
                              _selectedRoomId = sel['roomId']?.toString() ?? '';
                              _selectedBlock = sel['block']?.toString() ?? '';
                              _selectedFloor = sel['floor'];
                            } else {
                              _nameController.text = '';
                              _roomController.text = '';
                              _selectedRoomId = null;
                              _selectedBlock = null;
                              _selectedFloor = null;
                            }
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a student';
                          }

                          return null;
                        },
                      ),
                const SizedBox(height: 14),
                // Read-only preview of selected student (populated via selector)
                TextFormField(
                  controller: _nameController,
                  readOnly: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Student name',
                    prefixIcon: Icon(
                      Icons.person_outline,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Student name is required';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 14),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _roomController,
                  readOnly: true,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Room number',
                    prefixIcon: Icon(
                      Icons.meeting_room_outlined,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    // Require room only for Hostel Fee
                    if (_feeType == 'Hostel Fee') {
                      if (value == null || value.trim().isEmpty) {
                        return 'Room number is required for Hostel Fee';
                      }
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _feeType,
                  decoration:
                      const InputDecoration(
                    labelText: 'Fee type',
                    prefixIcon:
                        Icon(
                      Icons.category_outlined,
                    ),
                    border:
                        OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Hostel Fee',
                      child:
                          Text('Hostel Fee'),
                    ),
                    DropdownMenuItem(
                      value: 'Mess Fee',
                      child:
                          Text('Mess Fee'),
                    ),
                    DropdownMenuItem(
                      value: 'Electricity',
                      child:
                          Text('Electricity'),
                    ),
                    DropdownMenuItem(
                      value: 'Maintenance',
                      child:
                          Text('Maintenance'),
                    ),
                    DropdownMenuItem(
                      value: 'Fine',
                      child: Text('Fine'),
                    ),
                    DropdownMenuItem(
                      value: 'Other',
                      child: Text('Other'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      _feeType = value;
                    });
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller:
                      _amountController,
                  keyboardType:
                      const TextInputType
                          .numberWithOptions(
                    decimal: false,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter
                        .digitsOnly,
                  ],
                  decoration:
                      const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₹ ',
                    prefixIcon:
                        Icon(
                      Icons.currency_rupee,
                    ),
                    border:
                        OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final amount =
                        int.tryParse(
                      value?.trim() ?? '',
                    );

                    if (amount == null) {
                      return 'Enter a valid amount';
                    }

                    if (amount <= 0) {
                      return 'Amount must be greater than ₹0';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _selectDueDate,
                  borderRadius:
                      BorderRadius.circular(4),
                  child: InputDecorator(
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Payment due date',
                      prefixIcon:
                          Icon(
                        Icons.event_outlined,
                      ),
                      border:
                          OutlineInputBorder(),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _formatSelectedDate(),
                            style: TextStyle(
                              color:
                                  _dueDate == null
                                      ? Colors
                                          .grey
                                          .shade600
                                      : null,
                            ),
                          ),
                        ),
                        if (_dueDate != null)
                          IconButton(
                            tooltip:
                                'Clear date',
                            onPressed: () {
                              setState(() {
                                _dueDate = null;
                              });
                            },
                            icon:
                                const Icon(
                              Icons.clear,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child:
              const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.add),
          label:
              const Text('Add Fee'),
        ),
      ],
    );
  }
}

// ================================================================
// SUMMARY MODEL
// ================================================================

class _SummaryData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const _SummaryData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });
}

// ================================================================
// COLOR HELPER
// ================================================================

extension _MaterialColorHelper on Color {
  Color shadeIfMaterial() {
    if (this is MaterialColor) {
      return (this as MaterialColor).shade700;
    }

    return this;
  }
}