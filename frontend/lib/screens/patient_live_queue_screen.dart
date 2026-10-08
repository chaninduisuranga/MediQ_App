import 'dart:async';
import 'package:flutter/material.dart';
import '../core/services/appointment_service.dart';
import '../core/services/auth_service.dart';
import '../core/theme/theme.dart';
import '../widgets/app_bottom_nav_bar.dart';

class PatientLiveQueueScreen extends StatefulWidget {
  final String? initialRoomKey;
  final String? initialDate;

  const PatientLiveQueueScreen({
    super.key,
    this.initialRoomKey,
    this.initialDate,
  });

  @override
  State<PatientLiveQueueScreen> createState() => _PatientLiveQueueScreenState();
}

class _PatientLiveQueueScreenState extends State<PatientLiveQueueScreen> {
  Timer? _timer;
  bool _isLoading = true;
  String? _errorMessage;

  String _selectedRoomKey = 'BLEEDING_ROOM';
  DateTime _selectedDate = DateTime.now();

  Map<String, dynamic>? _queueData;
  List<dynamic> _myAppointments = [];
  Map<String, dynamic>? _myCurrentAppt;

  final List<Map<String, String>> _rooms = [
    {'key': 'DRESSING_ROOM', 'name': 'Dressing Room', 'icon': 'assets/images/opd_room_dressing.png'},
    {'key': 'INJECTION_ROOM', 'name': 'Injection Room', 'icon': 'assets/images/opd_room_injection.png'},
    {'key': 'BLEEDING_ROOM', 'name': 'Bleeding Room', 'icon': 'assets/images/opd_room_bleeding.png'},
    {'key': 'ANIMAL_BITE_ROOM', 'name': 'Animal Bite Room', 'icon': 'assets/images/opd_room_bite.png'},
    {'key': 'OPD_CLINIC_ROOM', 'name': 'OPD Clinic Room', 'icon': 'assets/images/opd_room_clinic.png'},
    {'key': 'DISPENSARY_ROOM', 'name': 'Dispensary', 'icon': 'assets/images/opd_room_dispensary.png'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialRoomKey != null && widget.initialRoomKey!.isNotEmpty) {
      _selectedRoomKey = widget.initialRoomKey!;
    }
    if (widget.initialDate != null && widget.initialDate!.isNotEmpty) {
      try {
        _selectedDate = DateTime.parse(widget.initialDate!);
      } catch (_) {}
    }
    _initializeData();
    _startLiveSyncTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startLiveSyncTimer() {
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        _fetchLiveQueue(showLoading: false);
      }
    });
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await _loadMyAppointments();

    // Auto-select room & date based on patient's active appointment if initial params were not explicitly supplied
    if (widget.initialRoomKey == null && _myAppointments.isNotEmpty) {
      final active = _findActivePatientAppt();
      if (active != null) {
        _selectedRoomKey = active['room'] ?? _selectedRoomKey;
        if (active['appointment_date'] != null) {
          try {
            _selectedDate = DateTime.parse(active['appointment_date']);
          } catch (_) {}
        }
      }
    }

    await _fetchLiveQueue(showLoading: false);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic>? _findActivePatientAppt() {
    final todayStr = _formatDate(DateTime.now());
    for (final appt in _myAppointments) {
      final date = appt['appointment_date'] as String? ?? '';
      final status = appt['status'] as String? ?? '';
      if (status != 'CANCELLED' && date.compareTo(todayStr) >= 0) {
        return appt as Map<String, dynamic>;
      }
    }
    return _myAppointments.isNotEmpty ? _myAppointments.first as Map<String, dynamic> : null;
  }

  Future<void> _loadMyAppointments() async {
    final res = await AppointmentService.getMyAppointments();
    if (res['success'] == true) {
      _myAppointments = res['data'] ?? [];
    }
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _fetchLiveQueue({bool showLoading = false}) async {
    if (showLoading && mounted) {
      setState(() => _isLoading = true);
    }

    final dateStr = _formatDate(_selectedDate);
    final res = await AppointmentService.getQueueStatus(_selectedRoomKey, date: dateStr);

    if (!mounted) return;

    if (res['success'] == true) {
      final data = res['data'] as Map<String, dynamic>?;
      // Match current patient's appointment for this selected room and date
      Map<String, dynamic>? myAppt;
      for (final a in _myAppointments) {
        if (a['room'] == _selectedRoomKey && a['appointment_date'] == dateStr && a['status'] != 'CANCELLED') {
          myAppt = a as Map<String, dynamic>;
          break;
        }
      }

      setState(() {
        _queueData = data;
        _myCurrentAppt = myAppt;
        _errorMessage = null;
        if (showLoading) _isLoading = false;
      });
    } else {
      setState(() {
        if (showLoading) _isLoading = false;
        _errorMessage = res['message'] ?? 'Failed to load live queue';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFF22C55E),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF22C55E),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'OPD Live Queue',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => _fetchLiveQueue(showLoading: true),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)),
            )
          : RefreshIndicator(
              onRefresh: () => _fetchLiveQueue(showLoading: false),
              color: const Color(0xFF2563EB),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ROOM SELECTOR HORIZONTAL SCROLL
                    _buildRoomSelectorTabs(),
                    const SizedBox(height: 16),

                    // DATE SELECTOR CHIPS
                    _buildDateSelectorChips(),
                    const SizedBox(height: 18),

                    // ERROR BANNER IF ANY
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppTheme.errorRed, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: AppTheme.errorRed, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // PATIENT'S BOOKED TICKET CARD (IF ANY)
                    if (_myCurrentAppt != null)
                      _buildPatientTicketHighlightCard()
                    else
                      _buildNoAppointmentNoticeCard(),
                    const SizedBox(height: 18),

                    // NOW SERVING MONITOR CARD
                    _buildNowServingMonitorCard(),
                    const SizedBox(height: 20),

                    // QUEUE BREAKDOWN LIST HEADER
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Live Queue Tokens',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.people_alt_rounded, size: 14, color: Color(0xFF2563EB)),
                              const SizedBox(width: 4),
                              Text(
                                '${_queueData?['total_booked'] ?? 0} Booked',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // QUEUE TOKENS LIST
                    _buildQueueTokensList(),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 0),
    );
  }

  Widget _buildRoomSelectorTabs() {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _rooms.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (ctx, index) {
          final r = _rooms[index];
          final isSelected = r['key'] == _selectedRoomKey;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedRoomKey = r['key']!;
              });
              _fetchLiveQueue(showLoading: true);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF1E40AF) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected ? const Color(0xFF1E40AF).withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      r['icon']!,
                      width: 38,
                      height: 38,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.meeting_room_rounded,
                        color: isSelected ? Colors.white : const Color(0xFF2563EB),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        r['name']!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isSelected ? 'Active Room' : 'Tap to view',
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected ? const Color(0xFF93C5FD) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateSelectorChips() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day1 = today.add(const Duration(days: 1));
    final day2 = today.add(const Duration(days: 2));

    final dates = [
      {'label': 'Today', 'date': today},
      {'label': 'Tomorrow', 'date': day1},
      {'label': 'Day 3', 'date': day2},
    ];

    return Row(
      children: [
        ...dates.map((d) {
          final dt = d['date'] as DateTime;
          final isSelected = _formatDate(dt) == _formatDate(_selectedDate);
          final label = d['label'] as String;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDate = dt;
                });
                _fetchLiveQueue(showLoading: true);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF2563EB) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? const Color(0xFFBFDBFE) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${dt.day} ${_getMonthName(dt.month)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        IconButton(
          icon: const Icon(Icons.calendar_month_rounded, color: Color(0xFF2563EB)),
          onPressed: _pickCustomDate,
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final maxDate = today.add(const Duration(days: 2));

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(today) || _selectedDate.isAfter(maxDate) ? today : _selectedDate,
      firstDate: today,
      lastDate: maxDate,
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _fetchLiveQueue(showLoading: true);
    }
  }

  Widget _buildPatientTicketHighlightCard() {
    final qNum = _myCurrentAppt!['queue_number'] ?? 0;
    final status = _myCurrentAppt!['status'] as String? ?? 'PENDING';

    final nowServing = _queueData?['now_serving'] ?? 0;
    int patientsAhead = 0;
    if (nowServing > 0 && qNum > nowServing) {
      patientsAhead = qNum - nowServing - 1;
    } else if (nowServing == 0 && qNum > 1) {
      patientsAhead = qNum - 1;
    }

    final estWaitMins = (patientsAhead + 1) * 15;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.35),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'YOUR BOOKED TOKEN',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5),
                ),
              ),
              _buildStatusBadge(status),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                '#${qNum.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppointmentService.getRoomDisplayName(_selectedRoomKey),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Date: ${_formatDate(_selectedDate)}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF93C5FD)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatMiniColumn('Patients Ahead', '$patientsAhead Patients', Icons.group_rounded),
                Container(width: 1, height: 28, color: Colors.white24),
                _buildStatMiniColumn('Est. Wait Time', '~$estWaitMins Mins', Icons.timer_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatMiniColumn(String label, String val, IconData icon) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFF60A5FA), size: 14),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFFCBD5E1))),
          ],
        ),
        const SizedBox(height: 3),
        Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }

  Widget _buildNoAppointmentNoticeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No Token Booked for This Room',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 2),
                Text(
                  'You don\'t have an active token for ${AppointmentService.getRoomDisplayName(_selectedRoomKey)} on ${_formatDate(_selectedDate)}.',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              elevation: 0,
            ),
            onPressed: () => Navigator.pushNamed(context, '/book-appointment'),
            child: const Text('Book', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildNowServingMonitorCard() {
    final nowServing = _queueData?['now_serving'] ?? 0;
    final doctorName = _queueData?['serving_doctor_name'] as String? ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: nowServing > 0 ? const Color(0xFF22C55E).withValues(alpha: 0.4) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: nowServing > 0 ? const Color(0xFF22C55E).withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.02),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: nowServing > 0
                    ? [const Color(0xFF16A34A), const Color(0xFF22C55E)]
                    : [const Color(0xFF64748B), const Color(0xFF94A3B8)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: nowServing > 0 ? const Color(0xFF22C55E).withValues(alpha: 0.4) : Colors.black12,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                nowServing > 0 ? '#${nowServing.toString().padLeft(2, '0')}' : '--',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: nowServing > 0 ? const Color(0xFF22C55E) : const Color(0xFF94A3B8),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      nowServing > 0 ? 'NOW SERVING IN ROOM' : 'QUEUE STANDBY',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: nowServing > 0 ? const Color(0xFF15803D) : const Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  nowServing > 0 ? 'Token #${nowServing.toString().padLeft(2, '0')} Called' : 'Waiting for Staff to Call Patient',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                if (doctorName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.medical_information_rounded, size: 14, color: Color(0xFF2563EB)),
                      const SizedBox(width: 4),
                      Text(
                        doctorName,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueTokensList() {
    final tokens = (_queueData?['queue_tokens'] as List<dynamic>?) ?? [];

    if (tokens.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: const [
            Icon(Icons.inbox_rounded, size: 40, color: Color(0xFF94A3B8)),
            SizedBox(height: 10),
            Text(
              'No Tokens Issued Yet',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            SizedBox(height: 4),
            Text(
              'Be the first to book a token for this room!',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    final currentUserId = AuthService.currentUser?['id'];

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tokens.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, index) {
        final token = tokens[index] as Map<String, dynamic>;
        final qNum = token['queue_number'] ?? 0;
        final status = token['status'] as String? ?? 'PENDING';
        final isPriority = token['is_priority'] as bool? ?? false;
        final patientId = token['patient_id'];
        final isMyToken = (currentUserId != null && patientId == currentUserId) ||
            (_myCurrentAppt != null && _myCurrentAppt!['queue_number'] == qNum);

        final isServing = status == 'SERVING';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isMyToken
                ? const Color(0xFFEFF6FF)
                : isServing
                    ? const Color(0xFFF0FDF4)
                    : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isMyToken
                  ? const Color(0xFF3B82F6)
                  : isServing
                      ? const Color(0xFF22C55E)
                      : const Color(0xFFE2E8F0),
              width: isMyToken || isServing ? 1.8 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isServing
                      ? const Color(0xFF22C55E)
                      : isMyToken
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '#${qNum.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isServing || isMyToken ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isMyToken ? 'Your Token' : 'Token #${qNum.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isMyToken ? const Color(0xFF1D4ED8) : const Color(0xFF0F172A),
                          ),
                        ),
                        if (isPriority) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEDD5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'PRIORITY',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFFC2410C)),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isServing
                          ? 'Now in Doctor Consultation Room'
                          : status == 'COMPLETED'
                              ? 'Treatment Completed'
                              : 'Waiting in OPD Queue',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(status),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFFF1F5F9);
    Color fg = const Color(0xFF64748B);
    String label = status;

    switch (status) {
      case 'SERVING':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        label = 'SERVING';
        break;
      case 'CONFIRMED':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
        label = 'CHECKED IN';
        break;
      case 'PENDING':
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        label = 'BOOKED';
        break;
      case 'COMPLETED':
        bg = const Color(0xFFF3E8FF);
        fg = const Color(0xFF7E22CE);
        label = 'DONE';
        break;
      case 'SKIPPED':
      case 'NO_SHOW':
        bg = const Color(0xFFFEF2F2);
        fg = const Color(0xFFB91C1C);
        label = status;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}
