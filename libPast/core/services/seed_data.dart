import 'package:firebase_database/firebase_database.dart';
import 'package:bcrypt/bcrypt.dart';
import 'firebase_service.dart';

Future<void> runDatabaseSeeding() async {
  final service = FirebaseService();
  
  if (!service.isFirebaseAvailable) {
    print("Firebase not configured. Skipping live seeding.");
    return;
  }

  if (await service.isDatabaseSeeded()) {
    // Force re-seeding if database contains old email for Karpaka Vinayagar temple
    final check = await FirebaseDatabase.instance.ref('seva/users/admin_pillayar/email').get();
    if (check.exists && check.value == 'pillayar_admin@gmail.com') {
      print("Found old email 'pillayar_admin@gmail.com' in database. Re-running seeding to update...");
    } else {
      print("SevaSetu live database already seeded. Skipping seeding.");
      return;
    }
  }

  print("Starting SevaSetu Live Database Seeding...");

  // Generate generic encrypted password for all mock user logins: "123456"
  final salt = BCrypt.gensalt();
  final hash = BCrypt.hashpw("123456", salt);

  final db = FirebaseDatabase.instance;

  // Clear database first to avoid mixed versions of seed data
  print("Clearing old live data under 'seva' root...");
  await db.ref('seva').remove();

  // --- 1. SEED USERS & TEMPLE ADMINS ---
  final users = {
    // Devotee Users
    "usr_muthu": {
      "name": "Muthu Kumaran",
      "email": "muthu@gmail.com",
      "phone": "9876543210",
      "passwordHash": hash,
      "securityQuestion": "What is your birth city?",
      "securityAnswer": "Madurai",
      "profilePic": "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=150",
      "bio": "Spiritual devotee and app tester.",
      "role": "user"
    },
    "usr_ganesan": {
      "name": "Ganesan",
      "email": "ganesan@gmail.com",
      "phone": "9876543211",
      "passwordHash": hash,
      "securityQuestion": "What is your birth city?",
      "securityAnswer": "Madurai",
      "profilePic": "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=150",
      "bio": "Devotee visiting temples regularly.",
      "role": "user"
    },
    "usr_kumaran": {
      "name": "Kumaran",
      "email": "kumaran@gmail.com",
      "phone": "9876543212",
      "passwordHash": hash,
      "securityQuestion": "What is your birth city?",
      "securityAnswer": "Madurai",
      "profilePic": "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=150",
      "bio": "Spiritual seeker.",
      "role": "user"
    },
    "usr_gokul": {
      "name": "Gokul",
      "email": "gokul@gmail.com",
      "phone": "9876543213",
      "passwordHash": hash,
      "securityQuestion": "What is your birth city?",
      "securityAnswer": "Madurai",
      "profilePic": "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=150",
      "role": "user"
    },
    // Temple Admins
    "admin_meenakshi": {
      "name": "Meenakshi Amman Admin",
      "email": "meenakshi_admin@gmail.com",
      "phone": "9876543201",
      "passwordHash": hash,
      "securityQuestion": "What is your pet name?",
      "securityAnswer": "Meena",
      "profilePic": "https://images.unsplash.com/photo-1608958415712-42171457497d?q=80&w=150",
      "bio": "Admin at Madurai Meenakshi Temple.",
      "role": "temple"
    },
    "admin_pillayar": {
      "name": "Pillayar Patti Admin",
      "email": "pillayarpatti_admin@gmail.com",
      "phone": "9876543202",
      "passwordHash": hash,
      "securityQuestion": "What is your pet name?",
      "securityAnswer": "Karpaka",
      "profilePic": "https://images.unsplash.com/photo-1542856391-010fb87dcfed?q=80&w=150",
      "bio": "Admin at Pillayar Patti Cave Temple.",
      "role": "temple"
    },
    "admin_thiruparam": {
      "name": "Thiruparamkundram Admin",
      "email": "thiruparam_admin@gmail.com",
      "phone": "9876543203",
      "passwordHash": hash,
      "securityQuestion": "What is your pet name?",
      "securityAnswer": "Muruga",
      "profilePic": "https://images.unsplash.com/photo-1600100397608-f010e423b971?q=80&w=150",
      "bio": "Admin at Thiruparamkundram Temple.",
      "role": "temple"
    }
  };

  for (var entry in users.entries) {
    await db.ref('seva/users/${entry.key}').set(entry.value);
  }

  // --- 2. SEED TEMPLES ---
  final temples = {
    "admin_meenakshi": {
      "name": "Meenakshi Amman Temple",
      "description": "Historic Hindu temple located on the southern bank of the Vaigai River in Madurai, Tamil Nadu.",
      "address": "Madurai, Tamil Nadu 625001",
      "contact": "9876543201",
      "profileImage": "https://images.unsplash.com/photo-1608958415712-42171457497d?q=80&w=200",
      "coverImage": "https://images.unsplash.com/photo-1608958415712-42171457497d?q=80&w=800",
      "galleryImages": [
        "https://images.unsplash.com/photo-1608958415712-42171457497d?q=80&w=200"
      ],
      "ownerUid": "admin_meenakshi",
      "activePriests": {
        "priest_prassana": "accepted",
        "priest_mukuntha": "accepted"
      }
    },
    "admin_pillayar": {
      "name": "Pillayar Patti Temple",
      "description": "Ancient rock-cut cave temple dedicated to Karpaka Vinayagar in Tiruppathur, Tamil Nadu.",
      "address": "Pillayarpatti, Tamil Nadu 630207",
      "contact": "9876543202",
      "profileImage": "https://images.unsplash.com/photo-1542856391-010fb87dcfed?q=80&w=200",
      "coverImage": "https://images.unsplash.com/photo-1542856391-010fb87dcfed?q=80&w=800",
      "galleryImages": [
        "https://images.unsplash.com/photo-1542856391-010fb87dcfed?q=80&w=200"
      ],
      "ownerUid": "admin_pillayar",
      "activePriests": {
        "priest_vengadesh": "accepted",
        "priest_madesh": "accepted"
      }
    },
    "admin_thiruparam": {
      "name": "Thiruparamkundram Murugan Temple",
      "description": "One of the Six Abodes of Lord Murugan, carved in rock, situated at Thirupparankundram, Madurai.",
      "address": "Thirupparankundram, Madurai, Tamil Nadu 625005",
      "contact": "9876543203",
      "profileImage": "https://images.unsplash.com/photo-1600100397608-f010e423b971?q=80&w=200",
      "coverImage": "https://images.unsplash.com/photo-1600100397608-f010e423b971?q=80&w=800",
      "galleryImages": [
        "https://images.unsplash.com/photo-1600100397608-f010e423b971?q=80&w=200"
      ],
      "ownerUid": "admin_thiruparam",
      "activePriests": {
        "priest_gokul": "accepted",
        "priest_arun": "accepted"
      }
    }
  };

  for (var entry in temples.entries) {
    await db.ref('seva/temples/${entry.key}').set(entry.value);
  }

  // --- 3. SEED PRIESTS ---
  final priests = {
    "priest_prassana": {
      "name": "Prassana Gurukkal",
      "dob": "1984-05-10",
      "age": 42,
      "gender": "Male",
      "mobile": "9876543001",
      "email": "prassana@gmail.com",
      "address": "Sannadhi St, Madurai",
      "experience": "12 Years",
      "rasi": "Mesha",
      "nakshatra": "Aswini",
      "lagnam": "Mesha",
      "bio": "Specialist in Meenakshi Amman pujas and sacred wedding rituals.",
      "photo": "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=150"
    },
    "priest_mukuntha": {
      "name": "Mukuntha Gurukkal",
      "dob": "1981-02-12",
      "age": 45,
      "gender": "Male",
      "mobile": "9876543002",
      "email": "mukuntha@gmail.com",
      "address": "East Chithirai St, Madurai",
      "experience": "15 Years",
      "rasi": "Rishaba",
      "nakshatra": "Rohini",
      "lagnam": "Rishaba",
      "bio": "Senior Vedic scholar performing Lakshmi Homam and Abhishekam.",
      "photo": "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?q=80&w=150"
    },
    "priest_vengadesh": {
      "name": "Vengadesh Bhattar",
      "dob": "1986-09-18",
      "age": 39,
      "gender": "Male",
      "mobile": "9876543003",
      "email": "vengadesh@gmail.com",
      "address": "Pillayarpatti, Temple Rd",
      "experience": "10 Years",
      "rasi": "Mithuna",
      "nakshatra": "Arudra",
      "lagnam": "Mithuna",
      "bio": "Specialist in Karpaka Vinayagar Abhishekam and Vinayagar Chaturthi special homams.",
      "photo": "https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?q=80&w=150"
    },
    "priest_madesh": {
      "name": "Madesh Bhattar",
      "dob": "1988-11-20",
      "age": 37,
      "gender": "Male",
      "mobile": "9876543004",
      "email": "madesh@gmail.com",
      "address": "Tiruppathur Temple View St",
      "experience": "8 Years",
      "rasi": "Karka",
      "nakshatra": "Punarvasu",
      "lagnam": "Karka",
      "bio": "Vedic rituals coordinator and home puja practitioner.",
      "photo": "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?q=80&w=150"
    },
    "priest_gokul": {
      "name": "Gokul Gurukkal",
      "dob": "1982-03-15",
      "age": 44,
      "gender": "Male",
      "mobile": "9876543005",
      "email": "gokul@gmail.com",
      "address": "Thirupparankundram Temple St",
      "experience": "14 Years",
      "rasi": "Simha",
      "nakshatra": "Magha",
      "lagnam": "Simha",
      "bio": "Specialist in Shanmuga Archana and Murugan Abhishekam.",
      "photo": "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=150"
    },
    "priest_arun": {
      "name": "Arun Gurukkal",
      "dob": "1990-07-22",
      "age": 35,
      "gender": "Male",
      "mobile": "9876543006",
      "email": "arun@gmail.com",
      "address": "Thirupparankundram Giri Rd",
      "experience": "6 Years",
      "rasi": "Kanya",
      "nakshatra": "Uttara",
      "lagnam": "Kanya",
      "bio": "Assists in all Murugan temple services and special festival events.",
      "photo": "https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?q=80&w=150"
    }
  };

  for (var entry in priests.entries) {
    await db.ref('seva/priests/${entry.key}').set(entry.value);
    
    // Auto insert login mapping under users node
    await db.ref('seva/users/${entry.key}').set({
      "name": entry.value["name"],
      "email": entry.value["email"],
      "phone": entry.value["mobile"],
      "passwordHash": hash,
      "securityQuestion": "What is your birth city?",
      "securityAnswer": "Madurai",
      "profilePic": entry.value["photo"],
      "bio": entry.value["bio"],
      "role": "priest"
    });
  }

  // --- 4. SEED SERVICES ---
  final services = {
    "srv_meenakshi_1": {
      "templeId": "admin_meenakshi",
      "priestId": "",
      "name": "Meenakshi Amman Maha Archana",
      "description": "Comprehensive offering with flower petals and coconuts.",
      "amount": 100.0,
      "maxParticipants": 20,
      "duration": "20 Mins",
      "image": "https://images.unsplash.com/photo-1608958415712-42171457497d?q=80&w=200"
    },
    "srv_meenakshi_2": {
      "templeId": "admin_meenakshi",
      "priestId": "",
      "name": "Special Abhishekam",
      "description": "Bathing of deities with milk, honey, turmeric, and sandalwood.",
      "amount": 1500.0,
      "maxParticipants": 5,
      "duration": "1 Hour",
      "image": "https://images.unsplash.com/photo-1542856391-010fb87dcfed?q=80&w=200"
    },
    "srv_pillayar_1": {
      "templeId": "admin_pillayar",
      "priestId": "",
      "name": "Ganapathy Homam",
      "description": "Auspicious fire ritual seeking Karpaka Vinayagar blessings.",
      "amount": 2500.0,
      "maxParticipants": 10,
      "duration": "2 Hours",
      "image": "https://images.unsplash.com/photo-1590050752117-238cb0fb12b1?q=80&w=200"
    },
    "srv_pillayar_2": {
      "templeId": "admin_pillayar",
      "priestId": "",
      "name": "Karpaka Vinayagar Archana",
      "description": "Simple archana offering for removing life's hurdles.",
      "amount": 50.0,
      "maxParticipants": 50,
      "duration": "10 Mins",
      "image": "https://images.unsplash.com/photo-1542856391-010fb87dcfed?q=80&w=200"
    },
    "srv_thiruparam_1": {
      "templeId": "admin_thiruparam",
      "priestId": "",
      "name": "Subramanya Sahasranama Archana",
      "description": "Chanting of 1000 holy names of Lord Murugan.",
      "amount": 200.0,
      "maxParticipants": 15,
      "duration": "30 Mins",
      "image": "https://images.unsplash.com/photo-1600100397608-f010e423b971?q=80&w=200"
    },
    "srv_thiruparam_2": {
      "templeId": "admin_thiruparam",
      "priestId": "",
      "name": "Special Kavadi Puja",
      "description": "Special puja for devotees offering kavadi to Lord Murugan.",
      "amount": 1000.0,
      "maxParticipants": 5,
      "duration": "1.5 Hours",
      "image": "https://images.unsplash.com/photo-1600100397608-f010e423b971?q=80&w=200"
    }
  };

  for (var entry in services.entries) {
    await db.ref('seva/services/${entry.key}').set(entry.value);
  }

  // --- 5. SEED SOCIAL POSTS ---
  final posts = {
    "post_meenakshi": {
      "authorId": "admin_meenakshi",
      "authorName": "Meenakshi Amman Temple",
      "authorImage": "https://images.unsplash.com/photo-1608958415712-42171457497d?q=80&w=150",
      "imageUrl": "https://images.unsplash.com/photo-1608958415712-42171457497d?q=80&w=600",
      "videoUrl": "",
      "caption": "Devotees attending morning pujas and seeking blessings. May the Divine Mother shower grace on all.",
      "timestamp": DateTime.now().subtract(const Duration(hours: 3)).millisecondsSinceEpoch,
    },
    "post_pillayar": {
      "authorId": "admin_pillayar",
      "authorName": "Pillayar Patti Temple",
      "authorImage": "https://images.unsplash.com/photo-1542856391-010fb87dcfed?q=80&w=150",
      "imageUrl": "https://images.unsplash.com/photo-1542856391-010fb87dcfed?q=80&w=600",
      "videoUrl": "",
      "caption": "Blessings of Karpaka Vinayagar. Chants from morning Ganapathy Homam.",
      "timestamp": DateTime.now().subtract(const Duration(hours: 8)).millisecondsSinceEpoch,
    }
  };

  for (var entry in posts.entries) {
    await db.ref('seva/posts/${entry.key}').set(entry.value);
  }

  // --- 6. SEED BOOKINGS ---
  final bookings = {
    "ord_seeded_1": {
      "userId": "usr_muthu",
      "userName": "Muthu Kumaran",
      "templeId": "admin_meenakshi",
      "templeName": "Meenakshi Amman Temple",
      "priestId": "priest_prassana",
      "serviceId": "srv_meenakshi_1",
      "serviceName": "Meenakshi Amman Maha Archana",
      "assignedPriest": "priest_prassana",
      "assignedPriestName": "Prassana Gurukkal",
      "bookingDate": DateTime.now().add(const Duration(days: 1)).toString().split(' ')[0],
      "bookingTime": "10:30 AM",
      "amount": 100.0,
      "status": "accepted",
      "paymentStatus": "success",
      "paymentReference": "pay_test_seeded1",
      "jitsiLink": "https://meet.jit.si/sevasetu_room_seeded1",
      "createdAt": DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch
    },
    "ord_seeded_2": {
      "userId": "usr_ganesan",
      "userName": "Ganesan",
      "templeId": "admin_pillayar",
      "templeName": "Pillayar Patti Temple",
      "priestId": "priest_vengadesh",
      "serviceId": "srv_pillayar_1",
      "serviceName": "Ganapathy Homam",
      "assignedPriest": "priest_vengadesh",
      "assignedPriestName": "Vengadesh Bhattar",
      "bookingDate": DateTime.now().add(const Duration(days: 2)).toString().split(' ')[0],
      "bookingTime": "08:00 AM",
      "amount": 2500.0,
      "status": "assigned",
      "paymentStatus": "success",
      "paymentReference": "pay_test_seeded2",
      "jitsiLink": "https://meet.jit.si/sevasetu_room_seeded2",
      "createdAt": DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch
    }
  };

  for (var entry in bookings.entries) {
    await db.ref('seva/orders/${entry.key}').set(entry.value);
  }

  // Set the system seeded flag to true
  await service.setDatabaseSeeded();
  print("SevaSetu live database seeded successfully!");
}
