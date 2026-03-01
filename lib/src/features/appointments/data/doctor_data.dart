class DoctorData {
  static final List<Map<String, dynamic>> doctors = [
    {
      'id': 'd1',
      'name_en': 'Dr. Anika Das',
      'name_ml': 'ഡോ. അനിക ദാസ്',
      'department_en': 'Cardiology',
      'department_ml': 'ഹൃദ്രോഗ വിഭാഗം', // Cardiology in Malayalam
    },
    {
      'id': 'd2',
      'name_en': 'Dr. Nashva P',
      'name_ml': 'ഡോ. നഷ്വ പി',
      'department_en': 'General Medicine',
      'department_ml': 'പൊതുവായ മരുന്ന്', // General Medicine roughly
    },
    {
      'id': 'd3',
      'name_en': 'Dr. Thanveer C N',
      'name_ml': 'ഡോ. തൻവീർ സി എൻ',
      'department_en': 'Orthopedics',
      'department_ml': 'അസ്ഥിരോഗ വിഭാഗം', // Orthopedics
    },
    {
      'id': 'd4',
      'name_en': 'Dr. Nasrin Ibrahim',
      'name_ml': 'ഡോ. നസ്രിൻ ഇബ്രാഹിം',
      'department_en': 'Neurology',
      'department_ml': 'ന്യൂറോളജി', // Neurology
    },
  ];

  static String getDoctorName(String doctorId, String languageCode) {
    final doctor = doctors.firstWhere(
      (d) => d['id'] == doctorId || d['name_en'] == doctorId,
      orElse: () => {},
    );
    if (doctor.isEmpty) return doctorId;

    if (languageCode == 'ml') {
      return doctor['name_ml'] ?? doctor['name_en'];
    }
    return doctor['name_en'];
  }
  
  static String getDoctorDepartment(String englishDepartment, String languageCode) {
    final doctor = doctors.firstWhere(
      (d) => d['department_en'] == englishDepartment,
      orElse: () => {},
    );
    if (doctor.isEmpty) return englishDepartment;

    if (languageCode == 'ml') {
      return doctor['department_ml'] ?? englishDepartment;
    }
    return englishDepartment;
  }
}
