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
  bool isPatient = false; // ✅ define here
  
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
    _checkUserRole().then((_) {
      _loadCaregivers();
      _loadAppointmentsForWeek(DateTime.now());
    });
  }

  Future<void> _checkUserRole() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    final profile = await supabase
        .from('Profile')
        .select('is_patient')
        .eq('user_id', user!.id)
        .single();

    setState(() {
      isPatient = profile['is_patient'];
    });
  }

Color hexToColor(String code) {
  return Color(int.parse(code.substring(1, 7), radix: 16) + 0xFF000000);
}


/* ########################################
 * Load + fetch appointments 
 * ########################################
 */

Future<List<Caregiver>> fetchCaregivers(bool isPatient) async {
  final supabase = Supabase.instance.client;
  final currentUser = supabase.auth.currentUser!;
  
  List<Map<String, dynamic>> response;
  print("isPatient: $isPatient");
  if (isPatient) {
    // If current user is a patient, fetch caregivers linked to them
    response = await supabase
        .from('CareRelation')
        .select('user_id, profile:user_id (name, color)')
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
          .select('user_id, profile:user_id (name, color)')
          .eq('patient_id', patientId);
    }
  }
  print("number of caregivers: ${response.length}");

  final formatted_caregivers = response.map((row) => Caregiver(
    id: row['user_id'],
    name: row['profile']?['name'] ?? '',
    color: hexToColor(row['profile']?['color'] ?? Colors.grey), // ✅ access color from profile table,
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

Future<void> _loadAppointments() async {
  try {
    final fetched = await fetchAppointments(selectedDate);
    setState(() {
      appointments = fetched;
    });
  } catch (e) {
    print('❌ Failed to load appointments: $e');
  }
}

Future<List<CaregiverAppointment>> fetchAppointmentsForWeek(DateTime startOfWeek) async {
  final supabase = Supabase.instance.client;
  final currentUser = supabase.auth.currentUser;
  if (currentUser == null) {
    throw Exception('User not logged in — cannot fetch appointments.');
  }
  final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
  // End of week = 7 days later, also at midnight (exclusive)
  final end = start.add(const Duration(days: 7));

  try {
    final response = await supabase
        .from('Event')
        .select()
        .gte('start_datetime', start.toIso8601String())
        .lt('start_datetime', end.toIso8601String());

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

Future<void> _loadAppointmentsForWeek(DateTime referenceDate) async {
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

bool isMonthView = false;

Future<List<CaregiverAppointment>> fetchAppointmentsForMonth(DateTime referenceDate) async {
  final supabase = Supabase.instance.client;
  final currentUser = supabase.auth.currentUser;
  if (currentUser == null) {
    throw Exception('User not logged in — cannot fetch appointments.');
  }

  // Start and end of month
  final startOfMonth = DateTime(referenceDate.year, referenceDate.month, 1);
  final endOfMonth = DateTime(referenceDate.year, referenceDate.month + 1, 1);

  try {
    final response = await supabase
        .from('Event')
        .select()
        .gte('start_datetime', startOfMonth.toIso8601String())
        .lt('start_datetime', endOfMonth.toIso8601String());

    if (response == null || response.isEmpty) {
      return [];
    }

    return (response as List<dynamic>)
        .map<CaregiverAppointment>((e) => CaregiverAppointment.fromJson(e))
        .toList();
  } catch (e) {
    print('Failed to fetch appointments for month: $e');
    return [];
  }
}

Future<void> _loadAppointmentsForMonth(DateTime referenceDate) async {
  final monthAppointments = await fetchAppointmentsForMonth(referenceDate);

  final Map<DateTime, List<CaregiverAppointment>> grouped = {};
  for (var appt in monthAppointments) {
    final dateKey = DateTime(appt.dateTime.year, appt.dateTime.month, appt.dateTime.day);
    grouped.putIfAbsent(dateKey, () => []).add(appt);
  }

  setState(() {
    groupedAppointments = grouped;
  });
}


/* ######################################
 * Link to backend
 * ######################################
 */
// ---------------- Add Appointment ----------------
Future<void> addAppointmentToBackend(CaregiverAppointment appointment) async {
  final supabase = Supabase.instance.client;
  final currentUser = supabase.auth.currentUser;

  if (currentUser == null) {
    throw Exception('User not logged in — cannot add appointment.');
  }

  try {
    // 1️⃣ Check user role
    final roleRes = await supabase
        .from('Profile')
        .select('is_patient')
        .eq('user_id', currentUser.id)
        .maybeSingle();

    if (roleRes == null) {
      throw Exception('No profile found for current user.');
    }
    if (roleRes['is_patient'] == true)
    {
      throw Exception('Patients cannot create appointments.');
    }

    // 2️⃣ Get the caregiver's assigned patient
    final assignment = await supabase
        .from('CareRelation')
        .select('patient_id')
        .eq('user_id', currentUser.id)
        .maybeSingle();

    if (assignment == null || assignment['patient_id'] == null) {
      throw Exception('No assigned patient found for this caregiver.');
    }

    final patientId = assignment['patient_id'] as String;

    // 3️⃣ Insert appointment
    final response = await supabase
        .from('Event')
        .insert({
          'patient_id': patientId,
          'assigned_user': appointment.caregiverId,
          'name': appointment.title,
          'description': appointment.description,
          'start_datetime': appointment.dateTime.toIso8601String(),
          'end_datetime': appointment.dateTime
              .add(appointment.duration)
              .toIso8601String(),
          'is_completed': appointment.status == 'completed',
        })
        .select()
        .maybeSingle();

    if (response == null) {
      throw Exception('Insert failed — Supabase returned null.');
    }

    print('✅ Appointment created: ${response['event_id']}');
  } catch (error) {
    print('❌ Failed to add appointment: $error');
    rethrow;
  }
}

// ---------------- Update Appointment ----------------
Future<void> updateAppointmentBackend(CaregiverAppointment appointment) async {
  final supabase = Supabase.instance.client;
  final currentUser = supabase.auth.currentUser;

  if (currentUser == null) {
    throw Exception('User not logged in — cannot update appointment.');
  }

  // 1️⃣ Check role
  final roleRes = await supabase
      .from('Profile')
      .select('is_patient')
      .eq('user_id', currentUser.id)
      .maybeSingle();

  if (roleRes == null) {
    throw Exception('No profile found for current user.');
  }
  if (roleRes['is_patient'] == true) {
    throw Exception('Patients cannot update appointments.');
  }

  try {
    final response = await supabase
        .from('Event')
        .update({
          'name': appointment.title,
          'description': appointment.description,
          'start_datetime': appointment.dateTime.toIso8601String(),
          'end_datetime': appointment.dateTime.add(appointment.duration).toIso8601String(),
          'assigned_user': appointment.caregiverId,
          'is_completed': appointment.status == AppointmentStatus.completed,
        })
        .eq('event_id', appointment.id)
        .select()
        .maybeSingle();

    if (response == null) {
      throw Exception('Update failed — Supabase returned null.');
    }

    print('✅ Appointment updated: ${appointment.id}');
  } catch (e) {
    print('❌ Failed to update appointment: $e');
    rethrow;
  }
}

// ---------------- Delete Appointment ----------------
Future<void> deleteAppointmentBackend(String id) async {
  final supabase = Supabase.instance.client;

  try {
    final response = await supabase
        .from('Event')
        .delete()
        .eq('event_id', id)
        .select(); // optional: returns deleted row(s)

    if (response == null) {
      throw Exception('Delete failed — no rows returned.');
    }

    print('✅ Appointment deleted: $id');
  } catch (e) {
    print('❌ Failed to delete appointment: $e');
    rethrow;
  }
}


/* ######################################
 * Widgets
 * ######################################
 */
  @override

@override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // prevents automatic resizing when keyboard appears
      appBar: AppBar(
        title: Text("Care Schedule"),
        centerTitle: true,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- Header with week/month toggle ---
            _buildCalendarHeader(),

            // --- Calendar Grid ---
            if (isMonthView)
              SizedBox(
                height: 450, // fixed height for month grid
                child: _buildMonthlyCalendarGrid(),
              )
            else
              SizedBox(
                height: 110, // fixed height for week grid
                child: _buildWeeklyCalendarGrid(),
              ),

            // --- Caregiver Legend ---
            _buildCaregiverLegend(),

            // --- Appointments list ---
            // Wrap in SizedBox to give it a fixed height so scroll works
            SizedBox(
              height: 400, // adjust this depending on screen
              child: _buildAppointmentsList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAppointmentDialog,
        child: Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

Widget _buildCalendarHeader() {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
    ),
    child: Column(
      children: [
        // First row: arrows + month text
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ⬅️ PREVIOUS
            IconButton(
              onPressed: () {
                setState(() {
                  if (isMonthView) {
                    selectedDate = DateTime(selectedDate.year, selectedDate.month - 1, 1);
                    _loadAppointmentsForMonth(selectedDate);
                  } else {
                    selectedDate = selectedDate.subtract(const Duration(days: 7));
                    _loadAppointmentsForWeek(selectedDate);
                  }
                  _loadAppointments();
                });
              },
              icon: const Icon(Icons.chevron_left),
            ),

            // Month display
            Text(
              _formatMonthYear(selectedDate),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            // ➡️ NEXT
            IconButton(
              onPressed: () {
                setState(() {
                  if (isMonthView) {
                    selectedDate = DateTime(selectedDate.year, selectedDate.month + 1, 1);
                    _loadAppointmentsForMonth(selectedDate);
                  } else {
                    selectedDate = selectedDate.add(const Duration(days: 7));
                    _loadAppointmentsForWeek(selectedDate);
                  }
                  _loadAppointments();
                });
              },
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Toggle chips centered
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ChoiceChip(
              label: const Text('Week'),
              selected: !isMonthView,
              onSelected: (val) {
                setState(() {
                  isMonthView = false;
                  _loadAppointmentsForWeek(selectedDate);
                });
              },
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Month'),
              selected: isMonthView,
              onSelected: (val) {
                setState(() {
                  isMonthView = true;
                  _loadAppointmentsForMonth(selectedDate);
                });
              },
            ),
          ],
        ),

        // Optional: Only show week range in WEEK view
        if (!isMonthView) ...[
          const SizedBox(height: 8),
          Text(
            '${_formatShortDate(selectedDate.subtract(Duration(days: selectedDate.weekday % 7)))}'
            ' - '
            '${_formatShortDate(selectedDate.subtract(Duration(days: selectedDate.weekday % 7)).add(const Duration(days: 6)))}',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
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
                            color: Colors.blue[600],
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
                        _loadAppointmentsForWeek(selectedDate);
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
                                            color: _getCaregiverById(apt.caregiverId)?.color ?? Colors.blue,
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

  Widget _buildMonthlyCalendarGrid() {
    // Get the first day of the current month
    final firstDayOfMonth = DateTime(selectedDate.year, selectedDate.month, 1);
    // Find the start of the first week (Sunday) that includes the first day
    final startOfCalendar = firstDayOfMonth.subtract(Duration(days: firstDayOfMonth.weekday % 7));
    // Calculate total number of days to display (6 weeks = 42 days)
    const totalDays = 42;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                            color: Colors.blue[600],
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          // Month grid (6 weeks, 7 days per week)
          Column(
            children: List.generate(6, (weekIndex) {
              return Row(
                children: List.generate(7, (dayIndex) {
                  final dayOffset = weekIndex * 7 + dayIndex;
                  final currentDate = startOfCalendar.add(Duration(days: dayOffset));
                  final isToday = _isSameDay(currentDate, DateTime.now());
                  final isSelected = _isSameDay(currentDate, selectedDate);
                  final isCurrentMonth = currentDate.month == selectedDate.month;
                  final dayAppointments = _getAppointmentsForDate(currentDate);

                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedDate = currentDate;
                          _loadAppointments();
                          _loadAppointmentsForMonth(selectedDate);
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : isToday
                                  ? Theme.of(context).primaryColor.withOpacity(0.2)
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: isToday && !isSelected
                              ? Border.all(color: Theme.of(context).primaryColor, width: 2)
                              : null,
                        ),
                        height: 60,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              currentDate.day.toString(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.white
                                    : isCurrentMonth
                                        ? Colors.black
                                        : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Appointment indicators
                            if (dayAppointments.isNotEmpty)
                              Container(
                                height: 14,
                                child: Wrap(
                                  spacing: 2,
                                  runSpacing: 2,
                                  alignment: WrapAlignment.center,
                                  children: dayAppointments
                                      .take(3)
                                      .map((apt) => Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: _getCaregiverById(apt.caregiverId)?.color ??
                                                  Colors.blue,
                                              shape: BoxShape.circle,
                                            ),
                                          ))
                                      .toList(),
                                ),
                              )
                            else
                              const SizedBox(height: 14),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              );
            }),
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
                      // final caregiver = _getCaregiverById(appointment.caregiverId);
                      final caregiver = caregivers.firstWhere(
                        (c) => c.id == appointment.caregiverId,
                        orElse: () => Caregiver(
                        id: '',
                        name: 'Unknown',
                        color: Colors.grey,
                      ),
                      );
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
                backgroundColor: caregiver?.color ?? Colors.blue,
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

  Caregiver? _getCaregiverById(String caregiverId) {
  try {
    return caregivers.firstWhere(
      (c) => c.id == caregiverId,
    );
  } catch (e) {
    // No caregiver found with that ID
    return null;
  }
}

  void _toggleCompletion(CaregiverAppointment appointment) async {
  final index = appointments.indexWhere((apt) => apt.id == appointment.id);
  if (index == -1) return;

  final isCompleted = appointment.status == AppointmentStatus.completed;
  final updatedAppointment = appointment.copyWith(
    status: isCompleted ? AppointmentStatus.scheduled : AppointmentStatus.completed,
  );

  // Optimistic update: update local state first
  setState(() {
    appointments[index] = updatedAppointment;
  });

  try {
    // Update backend
    await updateAppointmentBackend(updatedAppointment);
    // Optional: reload weekly appointments to refresh calendar bubbles
    await _loadAppointmentsForWeek(updatedAppointment.dateTime);
  } catch (e) {
    // Roll back if backend update fails
    setState(() {
      appointments[index] = appointment;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to update appointment: $e')),
    );
  }
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
                        await addAppointmentToBackend(newEvent);
                        await _loadAppointmentsForWeek(selectedDate); 
                        await _loadAppointments(); // refresh appointments list or calendar
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

  Caregiver? selectedCaregiver = caregivers.firstWhere(
    (c) => c.id == appointment.caregiverId,
    orElse: () => Caregiver(
      id: '',
      name: 'Unknown',
      color: Colors.grey,
    ),
  );

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
                onPressed: () async {
                  if (_titleController.text.trim().isEmpty) return;

                  final updatedAppointment = appointment.copyWith(
                    title: _titleController.text.trim(),
                    description: _descriptionController.text.trim(),
                    caregiverId: selectedCaregiver!.id,
                    dateTime: selectedDateTime,
                    duration: selectedDuration,
                  );

                  // 1️⃣ Update local state optimistically
                  final index = appointments.indexWhere((a) => a.id == appointment.id);
                  setState(() {
                    appointments[index] = updatedAppointment;
                  });

                  // 2️⃣ Update backend
                  try {
                    await updateAppointmentBackend(updatedAppointment);

                    // 3️⃣ Reload appointments for week to refresh calendar header & grid
                    await _loadAppointmentsForWeek(selectedDateTime);

                    Navigator.of(context).pop(); // close dialog
                  } catch (e) {
                    // Roll back local changes if backend fails
                    setState(() {
                      appointments[index] = appointment;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update appointment: $e')),
                    );
                  }
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

// ---------------- Delete Appointment Dialog ----------------
void _showDeleteAppointmentDialog(CaregiverAppointment appointment) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Delete Appointment'),
        content: const Text('Are you sure you want to delete this appointment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop(); // close dialog first

              try {
                await deleteAppointmentBackend(appointment.id);

                // 1️⃣ Remove from local appointments
                setState(() {
                  appointments.removeWhere((a) => a.id == appointment.id);
                  final dateKey = DateTime(
                    appointment.dateTime.year,
                    appointment.dateTime.month,
                    appointment.dateTime.day,
                  );
                  groupedAppointments[dateKey]?.removeWhere((a) => a.id == appointment.id);
                });

                // 2️⃣ Reload weekly appointments
                await _loadAppointmentsForWeek(selectedDate);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Appointment deleted successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to delete appointment: $e')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );
}
}