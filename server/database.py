import json
import os
import requests
import time
import hashlib

# 1. Parse Database URL from google-services.json
json_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "android", "app", "google-services.json"))
try:
    with open(json_path, "r") as f:
        config = json.load(f)
    FIREBASE_URL = config["project_info"]["firebase_url"]
except Exception as e:
    # fallback default project url
    FIREBASE_URL = "https://lubrication-indicator-default-rtdb.firebaseio.com"

ROOT_NODE = "Seva-v1"

def get_hash(pw):
    return hashlib.sha256(pw.encode()).hexdigest()

def _get_url(path):
    return f"{FIREBASE_URL}/{ROOT_NODE}/{path}.json"

# ----------------- DB INITIALIZATION & SEEDING -----------------

def init_db():
    print(f"Initializing Firebase RTDB under node '{ROOT_NODE}' at {FIREBASE_URL}...")
    
    # Reset/Clear current database namespace
    requests.delete(f"{FIREBASE_URL}/{ROOT_NODE}.json")
    
    # 1. Seed Temple Admin Users & Temple Entries
    # PillayarPatti, Meenakshi amman temple, Bridesshwarar temple, devakottai temple
    temple_data = [
        {
            "email": "pillayarpatti_admin@gmail.com",
            "full_name": "PillayarPatti Temple Admin",
            "mobile": "9876543201",
            "role": "temple",
            "address": "Pillayarpatti, Tamil Nadu",
            "description": "Ancient rock-cut cave temple dedicated to Karpaga Vinayagar (Lord Ganesha).",
            "location_link": "https://maps.app.goo.gl/pillayarpatti",
            "image_url": "https://images.unsplash.com/photo-1561361513-2d000a50f0db?w=500",
            "temple_name": "PillayarPatti"
        },
        {
            "email": "meenakshi_admin@gmail.com",
            "full_name": "Meenakshi Amman Temple Admin",
            "mobile": "9876543202",
            "role": "temple",
            "address": "Madurai, Tamil Nadu",
            "description": "Historic Hindu temple located on the southern bank of the Vaigai River, dedicated to Meenakshi and Sundareswarar.",
            "location_link": "https://maps.app.goo.gl/meenakshi",
            "image_url": "https://images.unsplash.com/photo-1582510003544-4d00b7f74220?w=500",
            "temple_name": "Meenakshi amman temple"
        },
        {
            "email": "brihad_admin@gmail.com",
            "full_name": "Brihad Admin",
            "mobile": "9876543203",
            "role": "temple",
            "address": "Thanjavur, Tamil Nadu",
            "description": "A magnificent 1000-year-old Shiva temple built by Raja Raja Chola I. A UNESCO World Heritage Site.",
            "location_link": "https://maps.app.goo.gl/brihadeeswarar",
            "image_url": "https://images.unsplash.com/photo-1600100397608-f010e42ec9a4?w=500",
            "temple_name": "Bridesshwarar temple"
        },
        {
            "email": "devakottai_admin@gmail.com",
            "full_name": "Devakottai Temple Admin",
            "mobile": "9876543204",
            "role": "temple",
            "address": "Devakottai, Tamil Nadu",
            "description": "Famous temple dedicated to Kottai Bhairavar, known for its powerful spiritual presence and heritage.",
            "location_link": "https://maps.app.goo.gl/kottaibhairavar",
            "image_url": "https://images.unsplash.com/photo-1627894483216-2138af692e32?w=500",
            "temple_name": "devakottai temple"
        }
    ]
    
    temple_id_map = {}
    user_id_counter = 100
    temple_id_counter = 200
    service_id_counter = 300
    
    # Store temple admins & temples
    for idx, t in enumerate(temple_data):
        u_id = user_id_counter + idx
        t_id = temple_id_counter + idx
        
        # User Admin Account
        user_node = {
            "id": u_id,
            "email": t["email"],
            "password_hash": get_hash("password"),
            "full_name": t["full_name"],
            "mobile": t["mobile"],
            "role": "temple",
            "address": t["address"],
            "description": t["description"],
            "location_link": t["location_link"],
            "avatar_url": ""
        }
        requests.put(_get_url(f"users/{u_id}"), json=user_node)
        
        # Temple Entry
        temple_node = {
            "id": t_id,
            "user_id": u_id,
            "name": t["temple_name"],
            "location": t["address"],
            "image_url": t["image_url"],
            "description": t["description"],
            "location_link": t["location_link"]
        }
        requests.put(_get_url(f"temples/{t_id}"), json=temple_node)
        temple_id_map[t["temple_name"]] = t_id
        
        # 2. Seed Services for EACH temple
        services = [
            {"name": "Instant seva", "price": 150.0, "desc": "Quick remote puja performed instantly with digital prasad distribution.", "duration": "15 Mins"},
            {"name": "Birthday seva", "price": 250.0, "desc": "Special archana and chants performed on the devotee's birthday for wellness.", "duration": "30 Mins"},
            {"name": "anniversay", "price": 350.0, "desc": "Special anniversary blessings and prayers for long life and happiness.", "duration": "30 Mins"},
            {"name": "Thithi", "price": 450.0, "desc": "Ancestral prayer ritual performed on the thithi day in a traditional manner.", "duration": "45 Mins"}
        ]
        
        for s_idx, s in enumerate(services):
            s_id = service_id_counter + (idx * 10) + s_idx
            service_node = {
                "id": s_id,
                "temple_id": t_id,
                "name": s["name"],
                "price": s["price"],
                "description": s["desc"],
                "duration": s["duration"]
            }
            requests.put(_get_url(f"services/{s_id}"), json=service_node)

    # 3. Seed Priests
    priests_data = [
        {"email": "priest1@gmail.com", "name": "Ramanadha Iyer", "mobile": "9123456781", "address": "Mylapore, Chennai"},
        {"email": "priest2@gmail.com", "name": "Sundaresa Sastrigal", "mobile": "9123456782", "address": "Thillai Nagar, Trichy"},
        {"email": "priest3@gmail.com", "name": "Venkatadri Bhattar", "mobile": "9123456783", "address": "Tirumala Hills, Tirupati"}
    ]
    
    priest_id_map = {}
    for idx, p in enumerate(priests_data):
        p_id = 400 + idx
        priest_node = {
            "id": p_id,
            "email": p["email"],
            "password_hash": get_hash("password"),
            "full_name": p["name"],
            "mobile": p["mobile"],
            "role": "priest",
            "dob": "1980-01-01",
            "gender": "Male",
            "address": p["address"],
            "star": "Anusham",
            "rasi": "Rishabam",
            "avatar_url": ""
        }
        requests.put(_get_url(f"users/{p_id}"), json=priest_node)
        priest_id_map[p["name"]] = p_id

    # 4. Seed Devotee
    dev_id = 500
    devotee_node = {
        "id": dev_id,
        "email": "devotee@gmail.com",
        "password_hash": get_hash("password"),
        "full_name": "Muthukumaran S",
        "mobile": "9566332211",
        "role": "devotee",
        "dob": "1995-10-10",
        "gender": "Male",
        "address": "Adyar, Chennai",
        "star": "Swati",
        "rasi": "Thulam",
        "avatar_url": ""
    }
    requests.put(_get_url(f"users/{dev_id}"), json=devotee_node)
    
    # Primary family member node for devotee
    fam_id = 600
    fam_node = {
        "id": fam_id,
        "user_id": dev_id,
        "name": "Muthukumaran S",
        "dob": "1995-10-10",
        "star": "Swati",
        "gender": "Male",
        "rasi": "Thulam",
        "email": "devotee@gmail.com",
        "mobile_no": "9566332211"
    }
    requests.put(_get_url(f"family_members/{fam_id}"), json=fam_node)

    # 5. Seed Accepted Priest Associations (via Invitations)
    # Ramanadha Iyer (400) -> PillayarPatti & Meenakshi amman temple
    # Sundaresa Sastrigal (401) -> Bridesshwarar temple
    # Venkatadri Bhattar (402) -> devakottai temple
    invitations = [
        {"id": 701, "temple_id": temple_id_map["PillayarPatti"], "temple_name": "PillayarPatti", "priest_id": 400, "priest_name": "Ramanadha Iyer", "status": "accepted"},
        {"id": 702, "temple_id": temple_id_map["Meenakshi amman temple"], "temple_name": "Meenakshi amman temple", "priest_id": 400, "priest_name": "Ramanadha Iyer", "status": "accepted"},
        {"id": 703, "temple_id": temple_id_map["Bridesshwarar temple"], "temple_name": "Bridesshwarar temple", "priest_id": 401, "priest_name": "Sundaresa Sastrigal", "status": "accepted"},
        {"id": 704, "temple_id": temple_id_map["devakottai temple"], "temple_name": "devakottai temple", "priest_id": 402, "priest_name": "Venkatadri Bhattar", "status": "accepted"}
    ]
    for invite in invitations:
        invite["created_at"] = "2026-07-07T00:00:00"
        requests.put(_get_url(f"invitations/{invite['id']}"), json=invite)

    print("Firebase Realtime Database successfully seeded under Seva-v1.")

# ----------------- DB READ/WRITE UTILITIES -----------------

def get_users():
    res = requests.get(_get_url("users"))
    data = res.json()
    if not data:
        return []
    return list(data.values())

def get_user_by_email(email):
    users = get_users()
    for u in users:
        if u and u.get("email") == email:
            return u
    return None

def get_user_by_id(user_id):
    res = requests.get(_get_url(f"users/{user_id}"))
    return res.json()

def create_user(user_data):
    # Generates custom unique ID
    u_id = int(time.time() * 1000)
    user_data["id"] = u_id
    requests.put(_get_url(f"users/{u_id}"), json=user_data)
    return user_data

def update_user(user_id, update_data):
    requests.patch(_get_url(f"users/{user_id}"), json=update_data)
    return get_user_by_id(user_id)

def get_temples():
    res = requests.get(_get_url("temples"))
    data = res.json()
    if not data:
        return []
    # Realtime Database returns dicts, sort by ID to match PillayarPatti, Meenakshi, Bridesshwarar, devakottai order
    temples_list = [t for t in data.values() if t]
    temples_list.sort(key=lambda x: x["id"])
    return temples_list

def get_temple_by_id(temple_id):
    res = requests.get(_get_url(f"temples/{temple_id}"))
    return res.json()

def get_temple_by_user_id(user_id):
    temples = get_temples()
    for t in temples:
        if t and t.get("user_id") == user_id:
            return t
    return None

def update_temple(temple_id, update_data):
    requests.patch(_get_url(f"temples/{temple_id}"), json=update_data)
    return get_temple_by_id(temple_id)

def get_services():
    res = requests.get(_get_url("services"))
    data = res.json()
    if not data:
        return []
    return [s for s in data.values() if s]

def get_services_by_temple(temple_id):
    services = get_services()
    return [s for s in services if s.get("temple_id") == temple_id]

def get_bookings():
    res = requests.get(_get_url("bookings"))
    data = res.json()
    if not data:
        return []
    return [b for b in data.values() if b]

def get_booking_by_id(booking_id):
    res = requests.get(_get_url(f"bookings/{booking_id}"))
    return res.json()

def create_booking(booking_data):
    b_id = int(time.time() * 1000)
    booking_data["id"] = b_id
    requests.put(_get_url(f"bookings/{b_id}"), json=booking_data)
    return booking_data

def update_booking(booking_id, update_data):
    requests.patch(_get_url(f"bookings/{booking_id}"), json=update_data)
    return get_booking_by_id(booking_id)

def get_invitations():
    res = requests.get(_get_url("invitations"))
    data = res.json()
    if not data:
        return []
    return [i for i in data.values() if i]

def get_invitation_by_id(invite_id):
    res = requests.get(_get_url(f"invitations/{invite_id}"))
    return res.json()

def create_invitation(invite_data):
    i_id = int(time.time() * 1000)
    invite_data["id"] = i_id
    requests.put(_get_url(f"invitations/{i_id}"), json=invite_data)
    return invite_data

def update_invitation(invite_id, update_data):
    requests.patch(_get_url(f"invitations/{invite_id}"), json=update_data)
    return get_invitation_by_id(invite_id)

def get_family_members(user_id):
    res = requests.get(_get_url("family_members"))
    data = res.json()
    if not data:
        return []
    return [m for m in data.values() if m and m.get("user_id") == user_id]

def create_family_member(member_data):
    m_id = int(time.time() * 1000)
    member_data["id"] = m_id
    requests.put(_get_url(f"family_members/{m_id}"), json=member_data)
    return member_data

def update_family_member_details(user_id, name, update_data):
    res = requests.get(_get_url("family_members"))
    data = res.json()
    if not data:
        return
    for member_id, member in data.items():
        if member and member.get("user_id") == user_id and member.get("name") == name:
            requests.patch(_get_url(f"family_members/{member_id}"), json=update_data)
            break

def create_temple(temple_data):
    t_id = int(time.time() * 1000)
    temple_data["id"] = t_id
    requests.put(_get_url(f"temples/{t_id}"), json=temple_data)
    return temple_data

if __name__ == "__main__":
    init_db()
