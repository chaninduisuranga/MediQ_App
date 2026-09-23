import 'dart:async';

import 'package:flutter/material.dart';

import '../core/models/admin_user_model.dart';
import '../core/services/admin_service.dart';
import '../core/theme/theme.dart';
import '../widgets/admin_bottom_nav_bar.dart';

class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<AdminUser> _users = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _total = 0;
  String? _selectedRole;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = await AdminService.getUsers(
      search: _searchController.text,
      role: _selectedRole ?? '',
    );
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result['success'] == true) {
        _users = result['users'] as List<AdminUser>;
        _total = (result['total'] as num?)?.toInt() ?? _users.length;
      } else {
        _errorMessage = result['message'] as String?;
      }
    });
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _loadUsers);
  }

  Future<void> _updateUser(AdminUser user,
      {String? role, String? status}) async {
    final result =
        await AdminService.updateUser(user.id, role: role, status: status);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message'] as String? ?? 'User updated')),
    );
    if (result['success'] == true) await _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.manage_accounts_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('User Management'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadUsers,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh users',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUsers,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildIntroBanner(),
            const SizedBox(height: 18),
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                labelText: 'Search users',
                hintText: 'Name, NIC, phone, or user ID',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 12),
            _buildRoleFilters(),
            const SizedBox(height: 16),
            Text('$_total users',
                style: const TextStyle(color: AppTheme.mutedText)),
            const SizedBox(height: 10),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              _buildMessage(_errorMessage!, Icons.error_outline_rounded)
            else if (_users.isEmpty)
              _buildMessage('No users found', Icons.people_outline_rounded)
            else
              ..._users.map(_buildUserCard),
          ],
        ),
      ),
      bottomNavigationBar: const AdminBottomNavBar(currentIndex: 0),
    );
  }

  Widget _buildIntroBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF0284C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: const Icon(Icons.people_alt_rounded,
                color: Colors.white, size: 25),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Manage system access',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Text('Doctors, staff, and administrator accounts',
                    style: TextStyle(color: Color(0xFFBAE6FD), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleFilters() {
    const roles = [
      ('DOCTOR', 'Doctor'),
      ('STAFF', 'Staff'),
      ('ADMIN', 'Admin'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: roles.map((role) {
        final isSelected = _selectedRole == role.$1;
        return FilterChip(
          label: Text(role.$2),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              _selectedRole = selected ? role.$1 : null;
            });
            _loadUsers();
          },
          selectedColor: AppTheme.primaryBlue,
          backgroundColor: Colors.white,
          side: BorderSide(
            color: isSelected ? AppTheme.primaryBlue : const Color(0xFFBAE6FD),
          ),
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : AppTheme.primaryBlue,
            fontWeight: FontWeight.w700,
          ),
          checkmarkColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildUserCard(AdminUser user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: const Color(0xFFBAE6FD).withValues(alpha: 0.8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFE0F2FE),
                  child: Text('${user.id}',
                      style: const TextStyle(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(user.fullName,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkText)),
                ),
                _buildStatusBadge(user.status),
              ],
            ),
            const SizedBox(height: 12),
            _buildDetail('NIC', user.nic),
            _buildDetail('Phone', user.phone),
            _buildDetail('Created', _formatDate(user.createdAt)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: user.role,
                    decoration: const InputDecoration(
                        labelText: 'Role',
                        isDense: true,
                        prefixIcon: Icon(Icons.badge_outlined, size: 18)),
                    items: const ['DOCTOR', 'STAFF', 'ADMIN']
                        .map((role) =>
                            DropdownMenuItem(value: role, child: Text(role)))
                        .toList(),
                    onChanged: (role) {
                      if (role != null && role != user.role) {
                        _updateUser(user, role: role);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: user.status,
                    decoration: const InputDecoration(
                        labelText: 'Status',
                        isDense: true,
                        prefixIcon: Icon(Icons.toggle_on_outlined, size: 18)),
                    items: const ['ACTIVE', 'INACTIVE', 'SUSPENDED']
                        .map((status) => DropdownMenuItem(
                            value: status, child: Text(status)))
                        .toList(),
                    onChanged: (status) {
                      if (status != null && status != user.status) {
                        _updateUser(user, status: status);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text('$label: $value',
          style: const TextStyle(color: AppTheme.mutedText)),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = status == 'ACTIVE'
        ? Colors.green
        : status == 'SUSPENDED'
            ? Colors.red
            : Colors.orange;
    return Chip(
      label: Text(status,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildMessage(String message, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppTheme.mutedText),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
