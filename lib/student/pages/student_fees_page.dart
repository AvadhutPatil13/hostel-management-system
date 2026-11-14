import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../config/backend_config.dart';
import '../../services/firebase_service.dart';

class StudentFeesPage extends StatefulWidget {
  const StudentFeesPage({super.key});

  @override
  State<StudentFeesPage> createState() => _StudentFeesPageState();
}

class _StudentFeesPageState extends State<StudentFeesPage> {
  bool _loading = false;

  List<Map<String, dynamic>> _dues = [];

  String? _error;

  static const String _defaultHostelName =
      'Hostel Management System';

  static const String _defaultReceiptTitle =
      'HOSTEL FEE PAYMENT RECEIPT';

  @override
  void initState() {
    super.initState();
    _loadDues();
  }

  // ============================================================
  // LOAD FEES
  // ============================================================

  Future<void> _loadDues() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    if (BackendConfig.useFirebase) {
      try {
        final list = await FirebaseService.myDues();

        if (!mounted) return;

        setState(() {
          _dues = list;
          _loading = false;
        });
      } catch (e) {
        if (!mounted) return;

        setState(() {
          _dues = [];
          _error = e.toString();
          _loading = false;
        });
      }

      return;
    }

    // ==========================================================
    // DEMO / FALLBACK DATA
    // ==========================================================

    if (!mounted) return;

    setState(() {
      _dues = [
        {
          'id': 'demo-fee-001',
          'hostelName': 'RIT Boys Hostel',
          'student': 'Avadhut Patil',
          'studentId': 'STU001',
          'room': 'A-101',
          'block': 'Block A',
          'amount': 14500,
          'amountPaid': 5000,
          'remainingAmount': 9500,
          'feeType': 'Hostel Fee',
          'dueDate': '31 Aug 2026',
          'academicYear': '2026-27',
          'feeMonth': 'August 2026',
          'status': 'partial',
          'paymentMethod': 'UPI',
          'paymentReference': 'UPI123456789',
          'lastPaymentAmount': 5000,
          'lastPaymentAt': DateTime.now().toIso8601String(),
          'createdAt': DateTime.now().toIso8601String(),
        },
      ];

      _loading = false;
    });
  }

  // ============================================================
  // BASIC HELPERS
  // ============================================================

  int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.round();

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  String _stringValue(
    dynamic value, {
    String fallback = '',
  }) {
    final text = value?.toString().trim() ?? '';

    return text.isEmpty ? fallback : text;
  }

  // ============================================================
  // MONEY
  // ============================================================

  String _money(int amount) {
    return '₹${NumberFormat('#,##0', 'en_IN').format(amount)}';
  }

  // ============================================================
  // REMAINING
  // ============================================================

  int _remainingAmount(
    Map<String, dynamic> due,
  ) {
    if (due.containsKey('remainingAmount')) {
      final remaining = _intValue(
        due['remainingAmount'],
      );

      return remaining > 0 ? remaining : 0;
    }

    final amount = _intValue(
      due['amount'],
    );

    final paid = _intValue(
      due['amountPaid'],
    );

    final remaining = amount - paid;

    return remaining > 0 ? remaining : 0;
  }

  // ============================================================
  // OVERDUE
  // ============================================================

  bool _isOverdue(
    Map<String, dynamic> due,
  ) {
    final remaining = _remainingAmount(due);

    if (remaining <= 0) {
      return false;
    }

    final rawDate = _stringValue(
      due['dueDate'],
    );

    if (rawDate.isEmpty) {
      return false;
    }

    DateTime? dueDate;

    try {
      dueDate = DateTime.tryParse(rawDate);

      if (dueDate == null) {
        try {
          dueDate = DateFormat(
            'dd MMM yyyy',
          ).parseStrict(rawDate);
        } catch (_) {
          return false;
        }
      }
    } catch (_) {
      return false;
    }

    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    final normalizedDueDate = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day,
    );

    return normalizedDueDate.isBefore(today);
  }

  // ============================================================
  // STATUS
  // ============================================================

  String _status(
    Map<String, dynamic> due,
  ) {
    final remaining = _remainingAmount(due);

    if (remaining <= 0) {
      return 'paid';
    }

    if (_isOverdue(due)) {
      return 'overdue';
    }

    final firestoreStatus = _stringValue(
      due['status'],
    ).toLowerCase();

    if (firestoreStatus == 'partial') {
      return 'partial';
    }

    if (firestoreStatus == 'pending') {
      return 'pending';
    }

    final paid = _intValue(
      due['amountPaid'],
    );

    if (paid > 0) {
      return 'partial';
    }

    return 'pending';
  }

  Color _statusColor(
    String status,
  ) {
    switch (status) {
      case 'paid':
        return Colors.green;

      case 'partial':
        return Colors.orange;

      case 'overdue':
        return Colors.red;

      default:
        return Colors.blue;
    }
  }

  IconData _statusIcon(
    String status,
  ) {
    switch (status) {
      case 'paid':
        return Icons.check_circle;

      case 'partial':
        return Icons.timelapse;

      case 'overdue':
        return Icons.warning_rounded;

      default:
        return Icons.pending_actions;
    }
  }

  // ============================================================
  // DATE HELPERS
  // ============================================================

  String _formatDate(
    dynamic value,
  ) {
    if (value == null) return '';

    final text = value.toString().trim();

    if (text.isEmpty) return '';

    try {
      final parsed = DateTime.tryParse(text);

      if (parsed != null) {
        return DateFormat(
          'dd MMM yyyy',
        ).format(parsed);
      }

      try {
        final parsedManual = DateFormat(
          'dd MMM yyyy',
        ).parseStrict(text);

        return DateFormat(
          'dd MMM yyyy',
        ).format(parsedManual);
      } catch (_) {
        return text;
      }
    } catch (_) {
      return text;
    }
  }

  String _formatDateTime(
    dynamic value,
  ) {
    if (value == null) return '';

    final text = value.toString().trim();

    if (text.isEmpty) return '';

    try {
      final parsed = DateTime.tryParse(text);

      if (parsed == null) return text;

      return DateFormat(
        'dd MMM yyyy, hh:mm a',
      ).format(parsed);
    } catch (_) {
      return text;
    }
  }

  // ============================================================
  // RECEIPT NUMBER
  // ============================================================

  String _receiptNumber(
    Map<String, dynamic> payment,
  ) {
    final existing = _stringValue(
      payment['receiptNumber'],
    );

    if (existing.isNotEmpty) {
      return existing;
    }

    final paymentId = _stringValue(
      payment['id'],
      fallback: 'PAYMENT',
    );

    final shortId = paymentId.length > 8
        ? paymentId.substring(0, 8).toUpperCase()
        : paymentId.toUpperCase();

    return 'REC-$shortId';
  }

  // ============================================================
  // HOSTEL NAME
  // ============================================================

  String _hostelName(
    Map<String, dynamic> due,
  ) {
    return _stringValue(
      due['hostelName'],
      fallback: _defaultHostelName,
    );
  }

  // ============================================================
  // PAYMENT HISTORY
  // ============================================================

  Future<void> _showPaymentHistory(
    Map<String, dynamic> due,
  ) async {
    final feeId = _stringValue(
      due['id'],
    );

    if (feeId.isEmpty) {
      _showMessage(
        'Fee record ID is missing.',
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return _PaymentHistoryDialog(
          fee: due,
          feeId: feeId,
          money: _money,
          formatDateTime: _formatDateTime,
          receiptNumber: _receiptNumber,
          onReceipt: (payment) {
            Navigator.pop(dialogContext);

            _printPaymentReceipt(
              due,
              payment,
            );
          },
        );
      },
    );
  }

  // ============================================================
  // PAYMENT RECEIPT
  // ============================================================

  Future<void> _printPaymentReceipt(
    Map<String, dynamic> due,
    Map<String, dynamic> payment,
  ) async {
    try {
      await Printing.layoutPdf(
        name:
            'Fee Receipt ${_receiptNumber(payment)}',
        onLayout: (PdfPageFormat format) {
          return _generatePaymentReceiptPdf(
            format,
            due,
            payment,
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Unable to generate receipt: $e',
      );
    }
  }

  // ============================================================
  // GENERATE PAYMENT PDF
  // ============================================================

  Future<Uint8List> _generatePaymentReceiptPdf(
    PdfPageFormat format,
    Map<String, dynamic> due,
    Map<String, dynamic> payment,
  ) async {
    final pdf = pw.Document();

    final hostelName = _hostelName(due);

    final studentName = _stringValue(
      due['student'],
      fallback: 'Student',
    );

    final studentId = _stringValue(
      due['studentId'],
      fallback: 'N/A',
    );

    final room = _stringValue(
      due['room'],
      fallback: 'N/A',
    );

    final block = _stringValue(
      due['block'],
      fallback: 'N/A',
    );

    final feeType = _stringValue(
      due['feeType'],
      fallback: 'Hostel Fee',
    );

    final academicYear = _stringValue(
      due['academicYear'],
      fallback: 'N/A',
    );

    final feeMonth = _stringValue(
      due['feeMonth'],
      fallback: 'N/A',
    );

    final totalAmount = _intValue(
      due['amount'],
    );

    final paymentAmount = _intValue(
      payment['amount'],
    );

    final totalPaid = _intValue(
      due['amountPaid'],
    );

    final remaining = _intValue(
      payment['remainingAfterPayment'],
    ) > 0
        ? _intValue(
            payment['remainingAfterPayment'],
          )
        : _remainingAmount(due);

    final paymentMethod = _stringValue(
      payment['paymentMethod'],
      fallback: 'N/A',
    );

    final paymentReference = _stringValue(
      payment['paymentReference'],
      fallback: 'N/A',
    );

    final receiptNumber = _receiptNumber(
      payment,
    );

    final paymentDate = _formatDateTime(
      payment['paidAt'],
    );

    final dueDate = _formatDate(
      due['dueDate'],
    );

    final paymentStatus =
        remaining <= 0 ? 'PAID' : 'PARTIAL';

    final notes = _stringValue(
      payment['notes'],
    );

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(36),
        build: (context) {
          return pw.Column(
            crossAxisAlignment:
                pw.CrossAxisAlignment.start,
            children: [
              // ==================================================
              // HEADER
              // ==================================================

              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      hostelName.toUpperCase(),
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 21,
                        fontWeight:
                            pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      _defaultReceiptTitle,
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight:
                            pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 15),

              pw.Divider(),

              pw.SizedBox(height: 12),

              // ==================================================
              // RECEIPT INFO
              // ==================================================

              pw.Row(
                mainAxisAlignment:
                    pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment:
                    pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment:
                        pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Receipt Number',
                        style: pw.TextStyle(
                          fontSize: 9,
                          color:
                              PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        receiptNumber,
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight:
                              pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment:
                        pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Payment Date',
                        style: pw.TextStyle(
                          fontSize: 9,
                          color:
                              PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        paymentDate.isEmpty
                            ? 'N/A'
                            : paymentDate,
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight:
                              pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              // ==================================================
              // STUDENT DETAILS
              // ==================================================

              pw.Text(
                'STUDENT DETAILS',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight:
                      pw.FontWeight.bold,
                ),
              ),

              pw.SizedBox(height: 8),

              pw.Container(
                width: double.infinity,
                padding:
                    const pw.EdgeInsets.all(12),
                decoration:
                    pw.BoxDecoration(
                  border: pw.Border.all(
                    color:
                        PdfColors.grey400,
                  ),
                ),
                child: pw.Column(
                  children: [
                    _pdfInfoRow(
                      'Student Name',
                      studentName,
                    ),
                    _pdfInfoRow(
                      'Student ID',
                      studentId,
                    ),
                    _pdfInfoRow(
                      'Room',
                      room,
                    ),
                    _pdfInfoRow(
                      'Block',
                      block,
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // ==================================================
              // FEE DETAILS
              // ==================================================

              pw.Text(
                'FEE DETAILS',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight:
                      pw.FontWeight.bold,
                ),
              ),

              pw.SizedBox(height: 8),

              pw.Table(
                border:
                    pw.TableBorder.all(
                  color:
                      PdfColors.grey400,
                ),
                columnWidths: {
                  0:
                      const pw.FlexColumnWidth(2),
                  1:
                      const pw.FlexColumnWidth(1.2),
                },
                children: [
                  _pdfTableRow(
                    'Fee Type',
                    feeType,
                  ),
                  _pdfTableRow(
                    'Academic Year',
                    academicYear,
                  ),
                  _pdfTableRow(
                    'Fee Month',
                    feeMonth,
                  ),
                  _pdfTableRow(
                    'Total Fee',
                    _money(totalAmount),
                  ),
                  _pdfTableRow(
                    'Due Date',
                    dueDate.isEmpty
                        ? 'N/A'
                        : dueDate,
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              // ==================================================
              // PAYMENT INFORMATION
              // ==================================================

              pw.Text(
                'PAYMENT INFORMATION',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight:
                      pw.FontWeight.bold,
                ),
              ),

              pw.SizedBox(height: 8),

              pw.Table(
                border:
                    pw.TableBorder.all(
                  color:
                      PdfColors.grey400,
                ),
                columnWidths: {
                  0:
                      const pw.FlexColumnWidth(2),
                  1:
                      const pw.FlexColumnWidth(1.2),
                },
                children: [
                  _pdfTableRow(
                    'Amount Received',
                    _money(paymentAmount),
                  ),
                  _pdfTableRow(
                    'Payment Method',
                    paymentMethod,
                  ),
                  _pdfTableRow(
                    'Reference Number',
                    paymentReference,
                  ),
                  _pdfTableRow(
                    'Payment Date',
                    paymentDate.isEmpty
                        ? 'N/A'
                        : paymentDate,
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              // ==================================================
              // ACCOUNT SUMMARY
              // ==================================================

              pw.Text(
                'ACCOUNT SUMMARY',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight:
                      pw.FontWeight.bold,
                ),
              ),

              pw.SizedBox(height: 8),

              pw.Table(
                border:
                    pw.TableBorder.all(
                  color:
                      PdfColors.grey400,
                ),
                columnWidths: {
                  0:
                      const pw.FlexColumnWidth(2),
                  1:
                      const pw.FlexColumnWidth(1.2),
                },
                children: [
                  _pdfTableRow(
                    'Total Paid',
                    _money(totalPaid),
                  ),
                  _pdfTableRow(
                    'Remaining Balance',
                    _money(remaining),
                  ),
                ],
              ),

              pw.SizedBox(height: 18),

              // ==================================================
              // STATUS
              // ==================================================

              pw.Container(
                width: double.infinity,
                padding:
                    const pw.EdgeInsets.all(12),
                decoration:
                    pw.BoxDecoration(
                  border: pw.Border.all(
                    color:
                        PdfColors.grey400,
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment:
                      pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'PAYMENT STATUS',
                      style: pw.TextStyle(
                        fontWeight:
                            pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      paymentStatus,
                      style: pw.TextStyle(
                        fontWeight:
                            pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              if (notes.isNotEmpty) ...[
                pw.SizedBox(height: 18),
                pw.Text(
                  'Notes',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight:
                        pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  notes,
                  style: pw.TextStyle(
                    fontSize: 9,
                  ),
                ),
              ],

              pw.SizedBox(height: 20),

              pw.Text(
                'This receipt is generated electronically by the Hostel Management System.',
                style: pw.TextStyle(
                  fontSize: 9,
                  color:
                      PdfColors.grey700,
                ),
              ),

              pw.Spacer(),

              pw.Divider(),

              pw.Row(
                mainAxisAlignment:
                    pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Student Copy',
                    style: pw.TextStyle(
                      fontSize: 9,
                    ),
                  ),
                  pw.Text(
                    'Hostel Office',
                    style: pw.TextStyle(
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ============================================================
  // PDF HELPERS
  // ============================================================

  pw.Widget _pdfInfoRow(
    String label,
    String value,
  ) {
    return pw.Padding(
      padding:
          const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 9,
                color:
                    PdfColors.grey700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value.isEmpty ? 'N/A' : value,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight:
                    pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.TableRow _pdfTableRow(
    String label,
    String value,
  ) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding:
              const pw.EdgeInsets.all(8),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 9,
            ),
          ),
        ),
        pw.Padding(
          padding:
              const pw.EdgeInsets.all(8),
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight:
                  pw.FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // FEE DETAILS
  // ============================================================

  void _showFeeDetails(
    Map<String, dynamic> due,
  ) {
    final amount = _intValue(
      due['amount'],
    );

    final paid = _intValue(
      due['amountPaid'],
    );

    final remaining = _remainingAmount(
      due,
    );

    final status = _status(
      due,
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                _statusIcon(status),
                color:
                    _statusColor(status),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _stringValue(
                    due['feeType'],
                    fallback: 'Fee Details',
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _detailRow(
                    'Hostel',
                    _hostelName(due),
                  ),
                  _detailRow(
                    'Student',
                    _stringValue(
                      due['student'],
                      fallback: 'N/A',
                    ),
                  ),
                  _detailRow(
                    'Student ID',
                    _stringValue(
                      due['studentId'],
                      fallback: 'N/A',
                    ),
                  ),
                  _detailRow(
                    'Room',
                    _stringValue(
                      due['room'],
                      fallback: 'N/A',
                    ),
                  ),
                  _detailRow(
                    'Block',
                    _stringValue(
                      due['block'],
                      fallback: 'N/A',
                    ),
                  ),
                  _detailRow(
                    'Academic Year',
                    _stringValue(
                      due['academicYear'],
                      fallback: 'N/A',
                    ),
                  ),
                  _detailRow(
                    'Fee Month',
                    _stringValue(
                      due['feeMonth'],
                      fallback: 'N/A',
                    ),
                  ),
                  _detailRow(
                    'Total Fee',
                    _money(amount),
                  ),
                  _detailRow(
                    'Total Paid',
                    _money(paid),
                    valueColor:
                        Colors.green,
                  ),
                  _detailRow(
                    'Remaining',
                    _money(remaining),
                    valueColor:
                        remaining > 0
                            ? Colors.red
                            : Colors.green,
                  ),
                  _detailRow(
                    'Due Date',
                    _formatDate(
                      due['dueDate'],
                    ),
                  ),
                  _detailRow(
                    'Status',
                    status.toUpperCase(),
                    valueColor:
                        _statusColor(status),
                  ),
                  _detailRow(
                    'Last Payment',
                    _money(
                      _intValue(
                        due['lastPaymentAmount'],
                      ),
                    ),
                  ),
                  _detailRow(
                    'Last Payment Date',
                    _formatDateTime(
                      due['lastPaymentAt'],
                    ),
                  ),
                  _detailRow(
                    'Payment Method',
                    _stringValue(
                      due['paymentMethod'],
                      fallback: 'N/A',
                    ),
                  ),
                  _detailRow(
                    'Payment Reference',
                    _stringValue(
                      due['paymentReference'],
                      fallback: 'N/A',
                    ),
                  ),
                  if (_stringValue(
                    due['notes'],
                  ).isNotEmpty)
                    _detailRow(
                      'Notes',
                      _stringValue(
                        due['notes'],
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Close'),
            ),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showPaymentHistory(due);
              },
              icon: const Icon(
                Icons.history,
              ),
              label: const Text(
                'Payment History',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 6,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 155,
            child: Text(
              label,
              style: TextStyle(
                color:
                    Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty
                  ? 'N/A'
                  : value,
              style: TextStyle(
                fontWeight:
                    FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    int totalFee = 0;
    int totalPaid = 0;
    int totalRemaining = 0;

    int paidFees = 0;
    int partialFees = 0;
    int pendingFees = 0;
    int overdueFees = 0;

    for (final due in _dues) {
      final amount = _intValue(
        due['amount'],
      );

      final paid = _intValue(
        due['amountPaid'],
      );

      final remaining =
          _remainingAmount(due);

      final status = _status(due);

      totalFee += amount;
      totalPaid += paid;
      totalRemaining += remaining;

      switch (status) {
        case 'paid':
          paidFees++;
          break;

        case 'partial':
          partialFees++;
          break;

        case 'overdue':
          overdueFees++;
          break;

        default:
          pendingFees++;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fees'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed:
                _loading
                    ? null
                    : _loadDues,
            icon: const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDues,
        child: _loading
            ? const Center(
                child:
                    CircularProgressIndicator(),
              )
            : ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.all(16),
                children: [
                  // ==================================================
                  // HEADER
                  // ==================================================

                  const Text(
                    'My Fees',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'View your fee details, payments and receipts.',
                    style: TextStyle(
                      color:
                          Colors.grey.shade600,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ==================================================
                  // ERROR
                  // ==================================================

                  if (_error != null)
                    Card(
                      child: Padding(
                        padding:
                            const EdgeInsets.all(
                          16,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                            ),
                            const SizedBox(
                              width: 12,
                            ),
                            Expanded(
                              child: Text(
                                _error!,
                              ),
                            ),
                            IconButton(
                              onPressed:
                                  _loadDues,
                              icon:
                                  const Icon(
                                Icons.refresh,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ==================================================
                  // SUMMARY
                  // ==================================================

                  LayoutBuilder(
                    builder:
                        (
                          context,
                          constraints,
                        ) {
                      final width =
                          constraints.maxWidth;

                      final columns =
                          width >= 1000
                              ? 4
                              : width >= 650
                                  ? 2
                                  : 1;

                      return GridView.count(
                        crossAxisCount:
                            columns,
                        shrinkWrap: true,
                        physics:
                            const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio:
                            width < 650
                                ? 3.2
                                : 1.8,
                        children: [
                          _summaryCard(
                            title: 'Total Fee',
                            value:
                                _money(totalFee),
                            icon:
                                Icons.receipt_long,
                            color:
                                Colors.blue,
                          ),
                          _summaryCard(
                            title: 'Total Paid',
                            value:
                                _money(totalPaid),
                            icon:
                                Icons.payments,
                            color:
                                Colors.green,
                          ),
                          _summaryCard(
                            title:
                                'Total Remaining',
                            value:
                                _money(
                              totalRemaining,
                            ),
                            icon:
                                Icons.account_balance_wallet,
                            color:
                                totalRemaining >
                                        0
                                    ? Colors.red
                                    : Colors.green,
                          ),
                          _summaryCard(
                            title:
                                'Paid / Pending',
                            value:
                                '$paidFees / ${pendingFees + partialFees + overdueFees}',
                            icon:
                                Icons.analytics,
                            color:
                                Colors.orange,
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // ==================================================
                  // STATUS SUMMARY
                  // ==================================================

                  if (_dues.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _statusChip(
                          'Paid',
                          paidFees,
                          Colors.green,
                        ),
                        _statusChip(
                          'Partial',
                          partialFees,
                          Colors.orange,
                        ),
                        _statusChip(
                          'Pending',
                          pendingFees,
                          Colors.blue,
                        ),
                        _statusChip(
                          'Overdue',
                          overdueFees,
                          Colors.red,
                        ),
                      ],
                    ),

                  const SizedBox(height: 24),

                  // ==================================================
                  // FEE RECORDS
                  // ==================================================

                  const Text(
                    'Fee Records',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (_dues.isEmpty &&
                      _error == null)
                    Card(
                      child: Padding(
                        padding:
                            const EdgeInsets.all(
                          28,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 55,
                              color:
                                  Colors.grey.shade500,
                            ),
                            const SizedBox(
                              height: 12,
                            ),
                            const Text(
                              'No fee records found.',
                              style: TextStyle(
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  ..._dues.map(
                    _buildFeeCard,
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  // ==================================================
                  // ONLINE PAYMENT
                  // ==================================================

                  if (totalRemaining > 0)
                    Card(
                      child: Padding(
                        padding:
                            const EdgeInsets.all(
                          16,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.payment,
                            ),
                            const SizedBox(
                              width: 12,
                            ),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Online Payment',
                                    style:
                                        TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(
                                    height: 4,
                                  ),
                                  Text(
                                    'Online payment gateway can be connected here.',
                                  ),
                                ],
                              ),
                            ),
                            FilledButton(
                              onPressed: () {
                                _showMessage(
                                  'Online payment will be available soon.',
                                );
                              },
                              child:
                                  const Text(
                                'Pay Now',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  // ============================================================
  // SUMMARY CARD
  // ============================================================

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.all(10),
              decoration:
                  BoxDecoration(
                color:
                    color.withOpacity(0.12),
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    value,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
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
  // STATUS CHIP
  // ============================================================

  Widget _statusChip(
    String label,
    int count,
    Color color,
  ) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor:
            color.withOpacity(0.15),
        child: Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ),
      label: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight:
              FontWeight.w600,
        ),
      ),
    );
  }

  // ============================================================
  // FEE CARD
  // ============================================================

  Widget _buildFeeCard(
    Map<String, dynamic> due,
  ) {
    final amount =
        _intValue(due['amount']);

    final paid =
        _intValue(due['amountPaid']);

    final remaining =
        _remainingAmount(due);

    final status =
        _status(due);

    final statusColor =
        _statusColor(status);

    final feeType =
        _stringValue(
      due['feeType'],
      fallback: 'Fee',
    );

    final dueDate =
        _formatDate(
      due['dueDate'],
    );

    final room =
        _stringValue(due['room']);

    final block =
        _stringValue(due['block']);

    final month =
        _stringValue(due['feeMonth']);

    final academicYear =
        _stringValue(
      due['academicYear'],
    );

    final paymentProgress =
        amount > 0
            ? (paid / amount)
                .clamp(0.0, 1.0)
            : 0.0;

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 14,
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // ======================================================
            // HEADER
            // ======================================================

            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.all(10),
                  decoration:
                      BoxDecoration(
                    color: statusColor
                        .withOpacity(0.12),
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                  child: Icon(
                    _statusIcon(status),
                    color:
                        statusColor,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        feeType,
                        style:
                            const TextStyle(
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      if (academicYear
                          .isNotEmpty)
                        Text(
                          academicYear,
                          style:
                              TextStyle(
                            color:
                                Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),

                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration:
                      BoxDecoration(
                    color: statusColor
                        .withOpacity(0.12),
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style:
                        TextStyle(
                      color:
                          statusColor,
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ======================================================
            // BASIC DETAILS
            // ======================================================

            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                if (room.isNotEmpty)
                  _smallInfo(
                    Icons.meeting_room,
                    'Room',
                    room,
                  ),
                if (block.isNotEmpty)
                  _smallInfo(
                    Icons.apartment,
                    'Block',
                    block,
                  ),
                if (month.isNotEmpty)
                  _smallInfo(
                    Icons.calendar_month,
                    'Month',
                    month,
                  ),
                if (dueDate.isNotEmpty)
                  _smallInfo(
                    Icons.event,
                    'Due',
                    dueDate,
                  ),
              ],
            ),

            const SizedBox(height: 16),

            const Divider(),

            const SizedBox(height: 10),

            // ======================================================
            // MONEY
            // ======================================================

            LayoutBuilder(
              builder:
                  (
                    context,
                    constraints,
                  ) {
                if (constraints.maxWidth <
                    450) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child:
                                _moneyColumn(
                              'Total',
                              amount,
                            ),
                          ),
                          Expanded(
                            child:
                                _moneyColumn(
                              'Paid',
                              paid,
                              valueColor:
                                  Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      Align(
                        alignment:
                            Alignment.centerLeft,
                        child:
                            _moneyColumn(
                          'Remaining',
                          remaining,
                          valueColor:
                              remaining > 0
                                  ? Colors.red
                                  : Colors.green,
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: _moneyColumn(
                        'Total',
                        amount,
                      ),
                    ),
                    Expanded(
                      child: _moneyColumn(
                        'Paid',
                        paid,
                        valueColor:
                            Colors.green,
                      ),
                    ),
                    Expanded(
                      child: _moneyColumn(
                        'Remaining',
                        remaining,
                        valueColor:
                            remaining > 0
                                ? Colors.red
                                : Colors.green,
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 16),

            // ======================================================
            // PROGRESS
            // ======================================================

            if (amount > 0)
              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Payment progress',
                        style:
                            TextStyle(
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${(paymentProgress * 100).toStringAsFixed(0)}%',
                        style:
                            const TextStyle(
                          fontSize: 12,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                    child:
                        LinearProgressIndicator(
                      value:
                          paymentProgress,
                      minHeight: 8,
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 16),

            // ======================================================
            // LAST PAYMENT
            // ======================================================

            if (paid > 0)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(10),
                decoration:
                    BoxDecoration(
                  color: Colors.green
                      .withOpacity(0.06),
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.payments_outlined,
                      size: 18,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Last payment: ${_money(_intValue(due['lastPaymentAmount']))}'
                        '${_formatDateTime(due['lastPaymentAt']).isNotEmpty ? ' • ${_formatDateTime(due['lastPaymentAt'])}' : ''}',
                        style:
                            const TextStyle(
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // ======================================================
            // ACTIONS
            // ======================================================

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    _showFeeDetails(
                      due,
                    );
                  },
                  icon: const Icon(
                    Icons.visibility,
                  ),
                  label: const Text(
                    'Fee Details',
                  ),
                ),

                OutlinedButton.icon(
                  onPressed: () {
                    _showPaymentHistory(
                      due,
                    );
                  },
                  icon: const Icon(
                    Icons.history,
                  ),
                  label: const Text(
                    'Payment History',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SMALL INFO
  // ============================================================

  Widget _smallInfo(
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color:
              Colors.grey.shade600,
        ),
        const SizedBox(width: 5),
        Text(
          '$label: ',
          style:
              TextStyle(
            color:
                Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // MONEY COLUMN
  // ============================================================

  Widget _moneyColumn(
    String label,
    int amount, {
    Color? valueColor,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style:
              TextStyle(
            color:
                Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _money(amount),
          style:
              TextStyle(
            fontWeight:
                FontWeight.bold,
            fontSize: 17,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// PAYMENT HISTORY DIALOG
// ============================================================================

class _PaymentHistoryDialog extends StatefulWidget {
  final Map<String, dynamic> fee;
  final String feeId;

  final String Function(int amount) money;

  final String Function(dynamic value)
      formatDateTime;

  final String Function(
    Map<String, dynamic> payment,
  ) receiptNumber;

  final void Function(
    Map<String, dynamic> payment,
  ) onReceipt;

  const _PaymentHistoryDialog({
    required this.fee,
    required this.feeId,
    required this.money,
    required this.formatDateTime,
    required this.receiptNumber,
    required this.onReceipt,
  });

  @override
  State<_PaymentHistoryDialog> createState() =>
      _PaymentHistoryDialogState();
}

class _PaymentHistoryDialogState
    extends State<_PaymentHistoryDialog> {
  bool _loading = true;

  String? _error;

  List<Map<String, dynamic>> _payments = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final payments =
          await FirebaseService.getPaymentHistory(
        widget.feeId,
      );

      if (!mounted) return;

      setState(() {
        _payments = payments;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _payments = [];
        _error = e.toString();
        _loading = false;
      });
    }
  }

  int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.round();

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final feeType =
        widget.fee['feeType']
            ?.toString()
            .trim();

    return AlertDialog(
      title: Row(
        children: [
          const Icon(
            Icons.history,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${feeType?.isNotEmpty == true ? feeType : 'Fee'} Payment History',
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 650,
        height: 480,
        child: _buildContent(),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign:
                  TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loadHistory,
              icon: const Icon(
                Icons.refresh,
              ),
              label: const Text(
                'Retry',
              ),
            ),
          ],
        ),
      );
    }

    if (_payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 55,
              color:
                  Colors.grey.shade500,
            ),
            const SizedBox(height: 12),
            const Text(
              'No payment history found.',
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _payments.length,
      separatorBuilder:
          (_, __) => const SizedBox(
        height: 10,
      ),
      itemBuilder: (
        context,
        index,
      ) {
        final payment =
            _payments[index];

        return _paymentTile(
          payment,
        );
      },
    );
  }

  Widget _paymentTile(
    Map<String, dynamic> payment,
  ) {
    final amount =
        _intValue(payment['amount']);

    final remainingAfterPayment =
        _intValue(
      payment['remainingAfterPayment'],
    );

    final method =
        payment['paymentMethod']
                ?.toString()
                .trim()
                .isNotEmpty ==
            true
        ? payment['paymentMethod']
              .toString()
        : 'N/A';

    final reference =
        payment['paymentReference']
                ?.toString()
                .trim()
                .isNotEmpty ==
            true
        ? payment['paymentReference']
              .toString()
        : 'N/A';

    final paidAt =
        widget.formatDateTime(
      payment['paidAt'],
    );

    final receipt =
        widget.receiptNumber(
      payment,
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding:
            const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.all(9),
                  decoration:
                      BoxDecoration(
                    color: Colors.green
                        .withOpacity(0.12),
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.money(
                          amount,
                        ),
                        style:
                            const TextStyle(
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      Text(
                        receipt,
                        style:
                            TextStyle(
                          color:
                              Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip:
                      'Print / Save Receipt',
                  onPressed: () {
                    widget.onReceipt(
                      payment,
                    );
                  },
                  icon: const Icon(
                    Icons.picture_as_pdf,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                _info(
                  Icons.calendar_today,
                  paidAt.isEmpty
                      ? 'N/A'
                      : paidAt,
                ),
                _info(
                  Icons.payment,
                  method,
                ),
                _info(
                  Icons.tag,
                  reference,
                ),
              ],
            ),

            const SizedBox(height: 10),

            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(9),
              decoration:
                  BoxDecoration(
                color: Colors.grey
                    .withOpacity(0.06),
                borderRadius:
                    BorderRadius.circular(
                  8,
                ),
              ),
              child: Text(
                'Remaining after payment: ${widget.money(remainingAfterPayment)}',
                style:
                    const TextStyle(
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),

            finalNotes(payment),
          ],
        ),
      ),
    );
  }

  Widget finalNotes(
    Map<String, dynamic> payment,
  ) {
    final notes =
        payment['notes']
                ?.toString()
                .trim() ??
            '';

    if (notes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding:
          const EdgeInsets.only(top: 8),
      child: Text(
        'Notes: $notes',
        style: TextStyle(
          fontSize: 12,
          color:
              Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _info(
    IconData icon,
    String text,
  ) {
    return Row(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color:
              Colors.grey.shade600,
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style:
              const TextStyle(
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
