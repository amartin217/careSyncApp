// lib/pages/calendar_page.dart
import 'package:flutter/material.dart';
import '../models/appointment.dart';
import '../models/caregiver.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime selectedDate = DateTime.now();
  
  // Sample caregivers
  List<Caregiver> caregivers = [
    Caregiver(
      id: '1',
      name: 'Sarah Johnson',
      role: 'Primary Nurse',
      phone: '(555) 123-4567',
      email: 'sarah.j@caregiving.com',
      color: Colors.blue,
      avatar: 'SJ',
    ),
    Caregiver(
      id: '2',
      name: 'Mike Rodriguez',
      role: 'Physical Therapist',
      phone: '(555) 234-5678',
      email: 'mike.r@therapy.com',
      color: Colors.green,
      avatar: 'MR',
    ),
    Caregiver(
      id: '3',
      name: 'Emily Chen',
      role: 'Home Health Aide',
      phone: '(555) 345-6789',
      email: 'emily.c@homecare.com',
      color: Colors.purple,
      avatar: 'EC',
    ),
    Caregiver(
      id: '4',
      name: 'Dr. Williams',
      role: 'Primary Physician',
      phone: '(555) 456-7890',
      email: 'dr.williams@clinic.com',
      color: Colors.orange,
      avatar: 'DW',
    ),
  ];

  // Sample appointments assigned to caregivers
  List<CaregiverAppointment> appointments = [
    CaregiverAppointment(
      id: '1',
      title: 'Morning Care Routine',
      description: 'Help with bathing, dressing, and breakfast',
      dateTime: DateTime.now().add(Duration(hours: 1)),
      caregiverId: '3', // Emily Chen
      duration: Duration(hours: 2),
      status: AppointmentStatus.scheduled,
      priority: Priority.high,
    ),
    CaregiverAppointment(
      id: '2',
      title: 'Physical Therapy Session',
      description: 'Leg strengthening exercises and mobility work',
      dateTime: DateTime.now().add(Duration(days: 1, hours: 14)),
      caregiverId: '2', // Mike Rodriguez
      duration: Duration(hours: 1),
      status: AppointmentStatus.scheduled,
      priority: Priority.medium,
    ),
    CaregiverAppointment(
      id: '3',
      title: 'Medical Checkup',
      description: 'Monthly health assessment and medication review',
      dateTime: DateTime.now().add(Duration(days: 2, hours: 10)),
      caregiverId: '4', // Dr. Williams
      duration: Duration(minutes: 45),
      status: AppointmentStatus.scheduled,
      priority: Priority.high,
    ),
    CaregiverAppointment(
      id: '4',
      title: 'Wound Care',
      description: 'Daily wound dressing change and assessment',
      dateTime: DateTime.now().add(Duration(hours: 8)),
      caregiverId: '1', // Sarah Johnson
      duration: Duration(minutes: 30),
      status: AppointmentStatus.scheduled,
      priority: Priority.high,
    ),
    CaregiverAppointment(
      id: '5',
      title: 'Evening Care',
      description: 'Dinner assistance and bedtime routine',
      dateTime: DateTime.now().add(Duration(hours: 12)),
      caregiverId: '3', // Emily Chen
      duration: Duration(hours: 1, minutes: 30),
      status: AppointmentStatus.completed,
      priority: Priority.medium,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Care Schedule"),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.people),
            onPressed: _showCaregiversDialog,
          ),
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _showAddAppointmentDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildWeeklyCalendarHeader(),
          _buildWeeklyCalendarGrid(),
          _buildCaregiverLegend(),
          Expanded(
            child: _buildAppointmentsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyCalendarHeader() {
    // Get the start and end of the current week
    final startOfWeek = selectedDate.subtract(Duration(days: selectedDate.weekday % 7));
    final endOfWeek = startOfWeek.add(Duration(days: 6));
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                selectedDate = selectedDate.subtract(Duration(days: 7)); // Go back one week
              });
            },
            icon: Icon(Icons.chevron_left),
          ),
          Column(
            children: [
              Text(
                _formatMonthYear(selectedDate),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                '${_formatShortDate(startOfWeek)} - ${_formatShortDate(endOfWeek)}',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
          IconButton(
            onPressed: () {
              setState(() {
                selectedDate = selectedDate.add(Duration(days: 7)); // Go forward one week
              });
            },
            icon: Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyCalendarGrid() {
    // Get the start of the week (Sunday) for the selected date
    final startOfWeek = selectedDate.subtract(Duration(days: selectedDate.weekday % 7));
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Weekday headers
          Row(
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map((day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          SizedBox(height: 8),
          // Weekly calendar grid (just one row for the week)
          Container(
            height: 80,
            child: Row(
              children: List.generate(7, (index) {
                final currentDate = startOfWeek.add(Duration(days: index));
                final isToday = _isSameDay(currentDate, DateTime.now());
                final isSelected = _isSameDay(currentDate, selectedDate);
                final dayAppointments = _getAppointmentsForDate(currentDate);
                final isCurrentMonth = currentDate.month == DateTime.now().month;

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedDate = currentDate;
                      });
                    },
                    child: Container(
                      margin: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : isToday
                                ? Theme.of(context).primaryColor.withOpacity(0.3)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isToday && !isSelected
                            ? Border.all(color: Theme.of(context).primaryColor, width: 2)
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            currentDate.day.toString(),
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : isCurrentMonth
                                      ? Colors.black
                                      : Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          SizedBox(height: 4),
                          // Show appointment indicators
                          if (dayAppointments.isNotEmpty)
                            Container(
                              height: 20,
                              child: Wrap(
                                spacing: 2,
                                runSpacing: 2,
                                alignment: WrapAlignment.center,
                                children: dayAppointments
                                    .take(4) // Show up to 4 indicators
                                    .map((apt) => Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: _getCaregiverById(apt.caregiverId)?.color ?? Colors.grey,
                                            shape: BoxShape.circle,
                                          ),
                                        ))
                                    .toList(),
                              ),
                            )
                          else
                            SizedBox(height: 20), // Maintain consistent height
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaregiverLegend() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Care Team",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: caregivers.map((caregiver) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: caregiver.color,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 4),
                Text(
                  caregiver.name.split(' ')[0], // First name only
                  style: TextStyle(fontSize: 12),
                ),
              ],
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsList() {
    final dayAppointments = _getAppointmentsForDate(selectedDate);
    dayAppointments.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Schedule for ${_formatDate(selectedDate)}",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          Expanded(
            child: dayAppointments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today, size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          "No appointments scheduled",
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: dayAppointments.length,
                    itemBuilder: (context, index) {
                      final appointment = dayAppointments[index];
                      final caregiver = _getCaregiverById(appointment.caregiverId);
                      return _buildAppointmentCard(appointment, caregiver);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(CaregiverAppointment appointment, Caregiver? caregiver) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: caregiver?.color ?? Colors.grey,
                  child: Text(
                    caregiver?.avatar ?? '?',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          decoration: appointment.status == AppointmentStatus.completed 
                              ? TextDecoration.lineThrough 
                              : TextDecoration.none,
                        ),
                      ),
                      Text(
                        caregiver?.name ?? 'Unknown Caregiver',
                        style: TextStyle(
                          color: caregiver?.color ?? Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatTime(appointment.dateTime),
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${appointment.duration.inHours}h ${appointment.duration.inMinutes % 60}m',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                SizedBox(width: 8),
                _buildPriorityIndicator(appointment.priority),
              ],
            ),
            if (appointment.description.isNotEmpty) ...[
              SizedBox(height: 8),
              Text(
                appointment.description,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
            SizedBox(height: 12),
            Row(
              children: [
                _buildStatusChip(appointment.status),
                Spacer(),
                if (appointment.status == AppointmentStatus.scheduled)
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => _callCaregiver(caregiver),
                        icon: Icon(Icons.phone, size: 16),
                        label: Text('Call'),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _markAsCompleted(appointment),
                        child: Text('Complete'),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(AppointmentStatus status) {
    Color color;
    String text;
    
    switch (status) {
      case AppointmentStatus.scheduled:
        color = Colors.blue;
        text = 'Scheduled';
        break;
      case AppointmentStatus.inProgress:
        color = Colors.orange;
        text = 'In Progress';
        break;
      case AppointmentStatus.completed:
        color = Colors.green;
        text = 'Completed';
        break;
      case AppointmentStatus.cancelled:
        color = Colors.red;
        text = 'Cancelled';
        break;
    }

    return Chip(
      label: Text(
        text,
        style: TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: color,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildPriorityIndicator(Priority priority) {
    Color color;
    IconData icon;
    
    switch (priority) {
      case Priority.low:
        color = Colors.green;
        icon = Icons.keyboard_arrow_down;
        break;
      case Priority.medium:
        color = Colors.orange;
        icon = Icons.remove;
        break;
      case Priority.high:
        color = Colors.red;
        icon = Icons.keyboard_arrow_up;
        break;
    }

    return Container(
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon, color: color, size: 16),
    );
  }

  // Helper methods
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }

  String _formatMonthYear(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _formatShortDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  String _formatDate(DateTime date) {
    const weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${weekdays[date.weekday % 7]}, ${months[date.month - 1]} ${date.day}';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  List<CaregiverAppointment> _getAppointmentsForDate(DateTime date) {
    return appointments.where((appointment) => _isSameDay(appointment.dateTime, date)).toList();
  }

  Caregiver? _getCaregiverById(String id) {
    try {
      return caregivers.firstWhere((caregiver) => caregiver.id == id);
    } catch (e) {
      return null;
    }
  }

  void _markAsCompleted(CaregiverAppointment appointment) {
    setState(() {
      final index = appointments.indexWhere((apt) => apt.id == appointment.id);
      if (index != -1) {
        appointments[index] = appointment.copyWith(status: AppointmentStatus.completed);
      }
    });
  }

  void _callCaregiver(Caregiver? caregiver) {
    if (caregiver != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Call ${caregiver.name}'),
          content: Text('Would you like to call ${caregiver.phone}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Here you would integrate with phone dialer
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Calling ${caregiver.name}...')),
                );
              },
              child: Text('Call'),
            ),
          ],
        ),
      );
    }
  }

  void _showCaregiversDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Care Team'),
        content: Container(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: caregivers.length,
            itemBuilder: (context, index) {
              final caregiver = caregivers[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: caregiver.color,
                  child: Text(caregiver.avatar, style: TextStyle(color: Colors.white)),
                ),
                title: Text(caregiver.name),
                subtitle: Text(caregiver.role),
                trailing: IconButton(
                  icon: Icon(Icons.phone),
                  onPressed: () => _callCaregiver(caregiver),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAddAppointmentDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Add appointment feature coming soon!')),
    );
  }
}