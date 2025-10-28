// lib/pages/calendar_page.dart
import 'package:flutter/material.dart';
import '../models/appointment.dart';
import '../models/caregiver.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime selectedDate = DateTime.now();
  
  List<Caregiver> caregivers = [];
  List<CaregiverAppointment> appointments = [];

  void _addEvent(CaregiverAppointment event) {
      setState(() {
        appointments.add(event);
      });
    }
  
  @override
  void initState() {
    super.initState();
    _loadAppointmentsForWeek(DateTime.now());
    _loadCaregivers();
    _loadAppointments(); // Safe to call here because Supabase is already initialized
  }

  
Future<List<Caregiver>> fetchCaregivers(bool isPatient) async {
  final supabase = Supabase.instance.client;
  final currentUser = supabase.auth.currentUser!;
  
  List<Map<String, dynamic>> response;
  print("isPatient: $isPatient");
  if (isPatient) {
    // If current user is a patient, fetch caregivers linked to them
    response = await supabase
        .from('CareRelation')
        .select('user_id')
        .eq('patient_id', currentUser.id);
  } else {
    // If current user is a caregiver, first fetch their patient_id
    final relation = await supabase
        .from('CareRelation')
        .select('patient_id')
        .eq('user_id', currentUser.id)
        .maybeSingle();

    if (relation == null) {
      response = [];
    } else {
      final patientId = relation['patient_id'];
      response = await supabase
          .from('CareRelation')
          .select('user_id, profile:user_id (name)')
          .eq('patient_id', patientId);
    }
  }
  print("number of caregivers: ${response.length}");

  final formatted_caregivers = response.map((row) => Caregiver(
    id: row['user_id'],
    name: row['profile']?['name'] ?? '',
    color: Colors.blue,
  )).toList();
  return formatted_caregivers;
}

Future<void> _loadCaregivers() async {
  final currentUser = Supabase.instance.client.auth.currentUser!;
  final profile = await Supabase.instance.client
      .from('Profile')
      .select('is_patient')
      .eq('user_id', currentUser.id)
      .maybeSingle();

  final isPatient = profile?['is_patient'] ?? false;

  List<Caregiver> fetchedCaregivers = await fetchCaregivers(isPatient);
  final names = caregivers.map((c) => c.name).join(', ');
  print("Caregiver names: $names");

  setState(() {
    caregivers = fetchedCaregivers;
  });
}

Future<List<CaregiverAppointment>> fetchAppointments(DateTime date) async {
  final supabase = Supabase.instance.client;
  final currentUser = supabase.auth.currentUser;
  if (currentUser == null) {
    throw Exception('User not logged in — cannot fetch appointments.');
  }
  final startOfDay = DateTime(date.year, date.month, date.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));

  try {
    final response = await supabase
        .from('Event')
        .select()
        .gte('start_datetime', startOfDay.toIso8601String())
        .lt('start_datetime', endOfDay.toIso8601String());

    if (response == null || response.isEmpty) {
      print('No appointments found for ${date.toIso8601String()}');
      return [];
    }
    print('✅ Fetched ${response.length} appointments');

    return (response as List<dynamic>)
        .map<CaregiverAppointment>((e) => CaregiverAppointment.fromJson(e))
        .toList();
  } catch (error) {
    print('❌ Failed to fetch appointments: $error');
    rethrow;
  }
}

void _loadAppointments() async {
  try {
    final fetched = await fetchAppointments(selectedDate);
    setState(() {
      appointments = fetched;
    });
  } catch (e) {
    print(e);
  }
}

Future<List<CaregiverAppointment>> fetchAppointmentsForWeek(DateTime startOfWeek) async {
  final supabase = Supabase.instance.client;
  final currentUser = supabase.auth.currentUser;
  if (currentUser == null) {
    throw Exception('User not logged in — cannot fetch appointments.');
  }
  final endOfWeek = startOfWeek.add(Duration(days: 7));

  try {
    final response = await supabase
        .from('Event')
        .select()
        .gte('start_datetime', startOfWeek.toIso8601String())
        .lt('start_datetime', endOfWeek.toIso8601String());

    if (response == null || response.isEmpty) {
      return [];
    }

    return (response as List<dynamic>)
        .map<CaregiverAppointment>((e) => CaregiverAppointment.fromJson(e))
        .toList();
  } catch (e) {
    print('Failed to fetch appointments for week: $e');
    return [];
  }
}

Map<DateTime, List<CaregiverAppointment>> groupedAppointments = {};

void _loadAppointmentsForWeek(DateTime referenceDate) async {
  final startOfWeek = referenceDate.subtract(Duration(days: referenceDate.weekday % 7));
  final weekAppointments = await fetchAppointmentsForWeek(startOfWeek);


  final Map<DateTime, List<CaregiverAppointment>> grouped = {};
  for (var appt in weekAppointments) {
    final dateKey = DateTime(appt.dateTime.year, appt.dateTime.month, appt.dateTime.day);
    grouped.putIfAbsent(dateKey, () => []).add(appt);
  }

  setState(() {
    groupedAppointments = grouped;
    selectedDate = referenceDate; // optional, keep currently selected day
  });
}

List<CaregiverAppointment> _getAppointmentsForDate(DateTime date) {
  final dateKey = DateTime(date.year, date.month, date.day);
  return groupedAppointments[dateKey] ?? [];
}



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


      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAppointmentDialog,
        child: Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat, // ⬅ bottom-right


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
                _loadAppointments();
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
                _loadAppointments();
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
                        _loadAppointments();
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
  final bool isCompleted = appointment.status == AppointmentStatus.completed;

  return Card(
    margin: EdgeInsets.only(bottom: 12),
    color: isCompleted ? Colors.grey.shade300 : Colors.white, // ✅ Background change
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
                // child: Text(
                  // caregiver?.avatar ?? '?',
                  // style: TextStyle(
                  //   color: Colors.white,
                  //   fontWeight: FontWeight.bold,
                  // ),
                // ),
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
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        color: isCompleted
                            ? Colors.grey.shade700 // ✅ Dimmed when completed (optional)
                            : Colors.black,
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isCompleted
                          ? Colors.grey.shade700 // ✅ Optional dimming
                          : Colors.black,
                    ),
                  ),
                ],
              ),
              SizedBox(width: 8),
            ],
          ),
          if (appointment.description.isNotEmpty) ...[
            SizedBox(height: 8),
            Text(
              appointment.description,
              style: TextStyle(
                color: isCompleted
                    ? Colors.grey.shade700 // ✅ Optional dimming
                    : Colors.grey[600],
              ),
            ),
          ],
          SizedBox(height: 12),
          Row(
            children: [
              Spacer(),
              Row(
                children: [
                  SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _toggleCompletion(appointment),
                    icon: Icon(
                      isCompleted
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                    ),
                    label: Text(
                      isCompleted ? 'Uncomplete' : 'Complete',
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _showEditAppointmentDialog(appointment),
                    child: Text('Edit'),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _showDeleteAppointmentDialog(appointment),
                    child: Text('Delete'),
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

  // List<CaregiverAppointment> _getAppointmentsForDate(DateTime date) {
  //   return appointments.where((appointment) => _isSameDay(appointment.dateTime, date)).toList();
  // }

  Caregiver? _getCaregiverById(String id) {
    try {
      return caregivers.firstWhere((caregiver) => caregiver.id == id);
    } catch (e) {
      return null;
    }
  }

  void _toggleCompletion(CaregiverAppointment appointment) {
  setState(() {
    final index = appointments.indexWhere((apt) => apt.id == appointment.id);
    if (index != -1) {
      final isCompleted = appointments[index].status == AppointmentStatus.completed;
      appointments[index] = appointment.copyWith(
        status: isCompleted ? AppointmentStatus.scheduled : AppointmentStatus.completed,
      );
    }
    // updateAppointmentBackend(appointments[index]);
  });
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
                  // child: Text(caregiver.avatar, style: TextStyle(color: Colors.white)),
                ),
                title: Text(caregiver.name),
                // subtitle: Text(caregiver.role),
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
      final _titleController = TextEditingController();
      final _descriptionController = TextEditingController();
      // Caregiver? selectedCaregiver = caregivers.first;
      Caregiver? selectedCaregiver = caregivers.isNotEmpty ? caregivers.first : null;
      if (selectedCaregiver == null) 
      {
        print("Error: cannot create new event because this patient has no caregivers.");
        return;
      }
      // DateTime selectedDate = DateTime.now();       // default date
      DateTime selectedDateOnly = selectedDate;
      TimeOfDay? selectedTime;                      // must pick time
      Duration selectedDuration = const Duration(hours: 1);

      showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              return AlertDialog(
                title: const Text('Add Appointment'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(labelText: 'Title'),
                      ),
                      TextField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(labelText: 'Description'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<Caregiver>(
                        value: selectedCaregiver,
                        items: caregivers
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c.name),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setModalState(() {
                            selectedCaregiver = value!;
                          });
                        },
                        decoration: const InputDecoration(labelText: 'Assign to'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (pickedDate != null) {
                            setModalState(() {
                              selectedDate = pickedDate;
                            });
                          }
                        },
                        child: Text(
                          'Pick Date: ${selectedDate.toLocal().toString().split(' ')[0]}',
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: selectedTime ?? TimeOfDay.now(),
                          );
                          if (pickedTime != null) {
                            setModalState(() {
                              selectedTime = pickedTime;
                            });
                          }
                        },
                        child: Text(
                          selectedTime == null
                              ? 'Pick Time'
                              : 'Time: ${selectedTime!.format(context)}',
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (_titleController.text.trim().isEmpty) return;

                      if (selectedTime == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select a time')),
                        );
                        return;
                      }

                      final finalDateTime = DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        selectedTime!.hour,
                        selectedTime!.minute,
                      );

                      final newEvent = CaregiverAppointment(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        title: _titleController.text.trim(),
                        description: _descriptionController.text.trim(),
                        caregiverId: selectedCaregiver!.id,
                        dateTime: finalDateTime,
                        duration: selectedDuration,
                        status: AppointmentStatus.scheduled,
                      );

                      // 1️⃣ Update local state immediately
                      _addEvent(newEvent);

                      // 2️⃣ Call backend and handle errors
                      try {
                        // await addAppointmentToBackend(newEvent);
                        Navigator.of(context).pop(); // only close if successful
                      } catch (e) {
                        // Roll back local state if needed
                        setState(() {
                          appointments.removeWhere((a) => a.id == newEvent.id);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to add appointment: $e')),
                        );
                      }
                    },
                    child: const Text('Add'),
                  ),
                ],
              );
            },
          );
        },
      );
    }

  void _showEditAppointmentDialog(CaregiverAppointment appointment) {
    final _titleController = TextEditingController(text: appointment.title);
    final _descriptionController = TextEditingController(text: appointment.description);
    Caregiver? selectedCaregiver = _getCaregiverById(appointment.caregiverId);
    DateTime selectedDateTime = appointment.dateTime;
    Duration selectedDuration = appointment.duration;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Edit Appointment'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    TextField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Description'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Caregiver>(
                      value: selectedCaregiver,
                      items: caregivers
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c.name),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setModalState(() {
                          selectedCaregiver = value!;
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Assign to'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDateTime,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (pickedDate != null) {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                          );
                          if (pickedTime != null) {
                            setModalState(() {
                              selectedDateTime = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                pickedTime.hour,
                                pickedTime.minute,
                              );
                            });
                          }
                        }
                      },
                      child: Text(
                        'Pick Date & Time: ${selectedDateTime.toString().substring(0, 16)}',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_titleController.text.trim().isEmpty) return;

                    // Update the appointment
                    setState(() {
                      final index = appointments.indexWhere((a) => a.id == appointment.id);
                      appointments[index] = appointment.copyWith(
                        title: _titleController.text.trim(),
                        description: _descriptionController.text.trim(),
                        caregiverId: selectedCaregiver!.id,
                        dateTime: selectedDateTime,
                        duration: selectedDuration,
                      );
                    });

                    Navigator.of(context).pop();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteAppointment(CaregiverAppointment appointment, BuildContext dialogContext) async {
      try {
        // await deleteAppointmentBackend(appointment.id); // backend call
        setState(() {
          appointments.removeWhere((a) => a.id == appointment.id);
        });
        Navigator.of(dialogContext).pop(); // pop dialog
      } catch (e) {
        // handle error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete appointment: $e')),
        );
      }
    }

  void _showDeleteAppointmentDialog(CaregiverAppointment appointment) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Delete Appointment'),
            content: Text(
              'Are you sure you want to delete "${appointment.title}" from the schedule?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),

              ElevatedButton(
              onPressed: () => _deleteAppointment(appointment, context),
              child: Text('Delete'),
            ),
            ],
          );
        },
      );
    }
}