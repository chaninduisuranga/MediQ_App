import 'package:flutter/material.dart';
import '../core/services/staff_allocation_service.dart';
import '../core/theme/theme.dart';
import '../routes/routes.dart';
import '../widgets/staff_bottom_nav_bar.dart';
import '../widgets/staff_drawer.dart';

class DoctorAllocationScreen extends StatefulWidget {
  const DoctorAllocationScreen({super.key});

  @override
  State<DoctorAllocationScreen> createState() => _DoctorAllocationScreenState();
}

class _DoctorAllocationScreenState extends State<DoctorAllocationScreen> {
  bool _isLoading = false;
  int _unallocatedWaitingCount = 0;
  int _totalWaitingCount = 0;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    try {
      await StaffAllocationService.refreshData();
      if (!mounted) return;
      setState(() {
        _unallocatedWaitingCount =
            StaffAllocationService.unallocatedWaitingCount;
        _totalWaitingCount = StaffAllocationService.waitingCount;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load doctor allocation data: $error'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  Future<void> _handleAllocateNextBatch() async {
    final availableDocs =
        StaffAllocationService.doctors.where((d) => d.isAvailable).toList();

    if (availableDocs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'No doctors are currently available/on-duty for allocation.'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    if (_unallocatedWaitingCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'No unallocated waiting patients found in General OPD queue.'),
          backgroundColor: AppTheme.mutedText,
        ),
      );
      return;
    }

    final maxBatch = availableDocs.length * 5;
    final toAllocate = _unallocatedWaitingCount < maxBatch
        ? _unallocatedWaitingCount
        : maxBatch;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.auto_mode_rounded,
                color: AppTheme.primarySkyBlue, size: 26),
            SizedBox(width: 10),
            Text('Confirm Batch Allocation',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Allocate up to 5 patients per available doctor:',
              style: const TextStyle(fontSize: 14, color: AppTheme.darkText),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.lightBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.primarySkyBlue.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  _buildSummaryRow(
                      'Available Doctors:',
                      '${availableDocs.length} / ${StaffAllocationService.doctors.length}'),
                  _buildSummaryRow(
                      'Waiting Patients:', '$_unallocatedWaitingCount'),
                  _buildSummaryRow('Patients in this Batch:', '$toAllocate'),
                  const Divider(height: 16),
                  ...availableDocs.map((doc) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(doc.name,
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600)),
                            const Text('&le; 5 patients',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.primarySkyBlue,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.mutedText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primarySkyBlue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ALLOCATE NOW',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    final res = await StaffAllocationService.allocateNextBatch();
    await _refreshData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Batch allocation complete!'),
          backgroundColor: res['success'] == true
              ? const Color(0xFF10B981)
              : AppTheme.errorRed,
        ),
      );
    }
  }

  void _showDoctorQueueSheet(GeneralOpdDoctor doctor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${doctor.code} Queue',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkText),
                        ),
                        Text(
                          '${doctor.name} • ${doctor.room}',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.mutedText),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: doctor.isAvailable
                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        doctor.isAvailable ? 'AVAILABLE' : 'OFF DUTY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: doctor.isAvailable
                              ? const Color(0xFF059669)
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.lightBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.primarySkyBlue.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMiniStat(
                          'Allocated Patients', '${doctor.allocatedCount}'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Allocated Patient Tokens:',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkText),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: doctor.allocatedPatients.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.assignment_outlined,
                                  size: 48, color: Colors.grey.shade300),
                              const SizedBox(height: 10),
                              const Text(
                                'No patients currently allocated to this doctor.',
                                style: TextStyle(
                                    color: AppTheme.mutedText, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: doctor.allocatedPatients.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final patient = doctor.allocatedPatients[index];
                            final token = patient['queue_number'] ?? 'G-000';
                            final name = patient['patient_name'] ?? 'Patient';
                            final nic = patient['patient_nic'] ?? '';
                            final isPriority = patient['priority'] == true;

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isPriority
                                      ? AppTheme.errorRed.withValues(alpha: 0.4)
                                      : Colors.grey.shade200,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isPriority
                                          ? AppTheme.errorRed
                                          : AppTheme.primarySkyBlue,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      token,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.darkText,
                                          ),
                                        ),
                                        if (nic.isNotEmpty)
                                          Text(
                                            'NIC: $nic',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.mutedText,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (isPriority)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.errorRed
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'PRIORITY',
                                        style: TextStyle(
                                          color: AppTheme.errorRed,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.primarySkyBlue)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppTheme.mutedText)),
      ],
    );
  }

  static Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: AppTheme.mutedText)),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkText)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doctors = StaffAllocationService.doctors;
    final availableCount = StaffAllocationService.availableDoctorsCount;
    final totalAllocated = StaffAllocationService.totalAllocatedCount;

    return Scaffold(
      drawer: const StaffDrawer(currentRoute: AppRoutes.doctorAllocation),
      appBar: AppBar(
        title: const Text(
          'Doctor Allocation',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Queue',
            onPressed: _refreshData,
          ),
        ],
      ),
      bottomNavigationBar: const StaffBottomNavBar(currentIndex: 1),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Overview Summary Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primarySkyBlue.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.medical_information_rounded,
                            color: Colors.white, size: 24),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'General OPD',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildOverviewCard(
                          'Waiting in Queue',
                          '$_totalWaitingCount',
                          Icons.hourglass_top_rounded,
                        ),
                        _buildOverviewCard(
                          'Available Doctors',
                          '$availableCount / ${doctors.length}',
                          Icons.check_circle_outline_rounded,
                        ),
                        _buildOverviewCard(
                          'Allocated Patients',
                          '$totalAllocated',
                          Icons.people_alt_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 2. Allocate Next Batch Action Button
              Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primarySkyBlue.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primarySkyBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isLoading ? null : _handleAllocateNextBatch,
                  icon: const Icon(Icons.auto_mode_rounded, size: 22),
                  label: const Text(
                    'ALLOCATE NEXT BATCH (UP TO 20)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 3. Four Doctor Cards Header
              const Text(
                'Doctor Queues & Availability',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkText,
                ),
              ),
              const SizedBox(height: 12),

              // 4. Four Doctor Cards List
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: doctors.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final doctor = doctors[index];
                  return _buildDoctorCard(doctor);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCard(String label, String value, IconData icon) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorCard(GeneralOpdDoctor doctor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: doctor.isAvailable
              ? AppTheme.primarySkyBlue.withValues(alpha: 0.25)
              : Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primarySkyBlue.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Doctor Info & Availability Switch Row
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: doctor.isAvailable
                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                    : Colors.grey.shade200,
                child: Icon(
                  Icons.person_rounded,
                  color: doctor.isAvailable
                      ? const Color(0xFF059669)
                      : Colors.grey.shade500,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          doctor.code,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primarySkyBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      doctor.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkText,
                      ),
                    ),
                  ],
                ),
              ),
              // Availability Switch
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    doctor.isAvailable ? 'AVAILABLE' : 'OFF DUTY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: doctor.isAvailable
                          ? const Color(0xFF059669)
                          : Colors.grey.shade600,
                    ),
                  ),
                  SizedBox(
                    height: 30,
                    child: Switch(
                      value: doctor.isAvailable,
                      activeThumbColor: const Color(0xFF10B981),
                      onChanged: null,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const Divider(height: 20),

          // Allocated Count & Token Range
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.people_alt_outlined,
                          size: 14, color: AppTheme.mutedText),
                      const SizedBox(width: 4),
                      Text(
                        '${doctor.allocatedCount} Patients Allocated',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tokens: ${doctor.assignedTokensText}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.primarySkyBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primarySkyBlue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _showDoctorQueueSheet(doctor),
                icon: const Icon(Icons.remove_red_eye_rounded, size: 16),
                label: const Text(
                  'View Queue',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
