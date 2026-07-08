import 'package:intl/intl.dart';

class AuspiciousService {
  Future<List<Map<String, dynamic>>> getAuspiciousDays() async {
    final today = DateTime.now();
    // Use midnight of today for comparison
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    final List<Map<String, dynamic>> auspicious = [];

    final List<Map<String, String>> events = [
      {
        "name": "Sankashti Chaturthi",
        "desc": "Auspicious day dedicated to Lord Ganesha, ideal for overcoming obstacles."
      },
      {
        "name": "Ekadashi Vrat",
        "desc": "Sacred fasting day dedicated to Lord Vishnu for cleansing sins."
      },
      {
        "name": "Pradosham Seva",
        "desc": "Highly auspicious evening ritual dedicated to Lord Shiva for blessing and health."
      },
      {
        "name": "Pournami (Full Moon) Puja",
        "desc": "Satyanarayana Puja and special offerings for wealth and peace."
      },
      {
        "name": "Amavasya Pitru Puja",
        "desc": "Ancestral offerings and prayers for family blessings."
      },
      {
        "name": "Karthigai Deepam",
        "desc": "Festival of lights dedicated to Murugan/Shiva."
      },
      {
        "name": "Shravan Somvar Puja",
        "desc": "Special Monday puja for Lord Shiva."
      },
      {
        "name": "Ganesha Chaturthi Special",
        "desc": "Special celebrations for the birth of Ganesha."
      }
    ];

    final currentYear = today.year;
    final currentMonth = today.month;

    for (final monthOffset in [0, 1]) {
      var m = currentMonth + monthOffset;
      var y = currentYear;
      if (m > 12) {
        m -= 12;
        y += 1;
      }

      final dayIndices = [5, 11, 15, 23, 27];
      for (final day in dayIndices) {
        try {
          // Verify if it is a valid date (e.g. February might not have 30 days, but dayIndices are 5-27 so they are always valid)
          final dateVal = DateTime(y, m, day);
          if (dateVal.isAtSameMomentAs(todayDateOnly) || dateVal.isAfter(todayDateOnly)) {
            final event = events[(day + m) % events.length];
            final dateStr = DateFormat('yyyy-MM-dd').format(dateVal);
            auspicious.add({
              "date": dateStr,
              "title": event["name"],
              "description": event["desc"],
              "auspicious_time": day % 2 == 0 ? "09:15 AM - 10:45 AM" : "04:30 PM - 06:00 PM"
            });
          }
        } catch (_) {
          // ignore invalid dates
        }
      }
    }

    auspicious.sort((a, b) => a["date"].compareTo(b["date"]));
    return auspicious;
  }
}
