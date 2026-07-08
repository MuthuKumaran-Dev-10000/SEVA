import os
import hashlib
import uuid
import datetime
import threading
from fastapi import FastAPI, HTTPException, UploadFile, File, Form, Query, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from typing import List, Optional
from dotenv import load_dotenv

import cloudinary
import cloudinary.uploader

import database
import models

# Load environment configurations
load_dotenv(dotenv_path=os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".env")))

# Configure Cloudinary SDK
cloudinary.config(
    cloud_name=os.getenv("CLOUDINARY_CLOUD_NAME"),
    api_key=os.getenv("CLOUDINARY_API_KEY"),
    api_secret=os.getenv("CLOUDINARY_API_SECRET"),
    secure=True
)

app = FastAPI(title="Seva Divine API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Static directory fallback for local uploads (if needed)
UPLOAD_DIR = os.path.join(os.path.dirname(__file__), "static", "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)
app.mount("/static", StaticFiles(directory=os.path.join(os.path.dirname(__file__), "static")), name="static")

# Concurrency thread-lock for slot double booking prevention
booking_lock = threading.Lock()

@app.on_event("startup")
def startup_event():
    # If the database is empty under Seva-v1, seed it.
    # We can also check if we want to run seeding explicitly.
    users = database.get_users()
    if not users:
        database.init_db()

# Password helper
def hash_password(password: str) -> str:
    return hashlib.sha256(password.encode()).hexdigest()

# Helper to fetch shared contact information
def fetch_contact_info(entity_id: int, entity_type: str) -> Optional[models.ContactInfo]:
    if entity_type == 'devotee' or entity_type == 'priest':
        user = database.get_user_by_id(entity_id)
        if user:
            return models.ContactInfo(
                name=user.get("full_name", ""),
                mobile=user.get("mobile", ""),
                email=user.get("email", ""),
                address=user.get("address", "")
            )
    elif entity_type == 'temple':
        temple = database.get_temple_by_id(entity_id)
        if temple:
            admin_user = database.get_user_by_id(temple.get("user_id", 0))
            return models.ContactInfo(
                name=temple.get("name", ""),
                mobile=admin_user.get("mobile", "") if admin_user else "",
                email=admin_user.get("email", "") if admin_user else "",
                address=temple.get("location", "")
            )
    return None

# ----------------- AUTH ENDPOINTS -----------------

@app.post("/auth/signup", response_model=models.UserResponse)
def signup(user: models.UserCreate):
    existing = database.get_user_by_email(user.email)
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")
        
    pw_hash = hash_password(user.password)
    user_node = {
        "email": user.email,
        "password_hash": pw_hash,
        "full_name": user.full_name,
        "mobile": user.mobile,
        "role": user.role,
        "dob": user.dob or "",
        "star": user.star or "",
        "rasi": user.rasi or "",
        "gender": user.gender or "",
        "address": user.address or "",
        "description": user.description or "",
        "location_link": user.location_link or "",
        "avatar_url": ""
    }
    
    created_user = database.create_user(user_node)
    user_id = created_user["id"]
    
    # If Devotee, insert as first primary family member defaultly
    if user.role == 'devotee':
        database.create_family_member({
            "user_id": user_id,
            "name": user.full_name,
            "dob": user.dob or "1990-01-01",
            "star": user.star or "",
            "gender": user.gender or "Male",
            "rasi": user.rasi or "",
            "email": user.email,
            "mobile_no": user.mobile
        })
    
    # If Temple, create temple entry linked to user_id
    elif user.role == 'temple':
        img_url = "https://images.unsplash.com/photo-1548013146-72479768bada?w=500" # fallback
        database.create_temple({
            "user_id": user_id,
            "name": user.full_name,
            "location": user.address or "Address",
            "image_url": img_url,
            "description": user.description or "Temple description",
            "location_link": user.location_link or ""
        })
        
    return created_user

@app.post("/auth/login", response_model=models.UserResponse)
def login(credentials: models.UserLogin):
    user = database.get_user_by_email(credentials.email)
    if not user:
        raise HTTPException(status_code=401, detail="Invalid email or password")
        
    pw_hash = hash_password(credentials.password)
    if user.get("password_hash") != pw_hash:
        raise HTTPException(status_code=401, detail="Invalid email or password")
        
    return user

@app.put("/auth/profile", response_model=models.UserResponse)
def update_profile(
    user_id: int = Form(...),
    full_name: str = Form(...),
    mobile: str = Form(...),
    address: Optional[str] = Form(None),
    dob: Optional[str] = Form(None),
    star: Optional[str] = Form(None),
    rasi: Optional[str] = Form(None),
    gender: Optional[str] = Form(None),
    description: Optional[str] = Form(None),
    location_link: Optional[str] = Form(None)
):
    user = database.get_user_by_id(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
        
    role = user.get("role")
    
    update_node = {
        "full_name": full_name,
        "mobile": mobile,
        "address": address or "",
        "dob": dob or "",
        "star": star or "",
        "rasi": rasi or "",
        "gender": gender or "",
        "description": description or "",
        "location_link": location_link or ""
    }
    
    updated = database.update_user(user_id, update_node)
    
    # Also update the primary family member details if Devotee
    if role == 'devotee':
        database.update_family_member_details(user_id, user.get("full_name"), {
            "name": full_name,
            "mobile_no": mobile,
            "dob": dob or "1990-01-01",
            "star": star or "",
            "rasi": rasi or "",
            "gender": gender or "Male"
        })
    elif role == 'temple':
        temple = database.get_temple_by_user_id(user_id)
        if temple:
            database.update_temple(temple["id"], {
                "name": full_name,
                "location": address or "Address",
                "description": description or "Description",
                "location_link": location_link or ""
            })

    return updated

@app.post("/auth/profile/avatar")
async def upload_avatar(user_id: int = Form(...), file: UploadFile = File(...)):
    ext = os.path.splitext(file.filename)[1].lower()
    if ext not in [".jpg", ".jpeg", ".png", ".webp"]:
        raise HTTPException(status_code=400, detail="Invalid file type. Only JPG, PNG, WEBP allowed.")
        
    # Upload directly to Cloudinary
    try:
        upload_result = cloudinary.uploader.upload(
            file.file, 
            upload_preset=os.getenv("CLOUDINARY_UPLOAD_PRESET", "seva")
        )
        avatar_url = upload_result.get("secure_url")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Cloudinary upload failed: {str(e)}")
    
    database.update_user(user_id, {"avatar_url": avatar_url})
    return {"avatar_url": avatar_url}

# ----------------- FAMILY ENDPOINTS -----------------

@app.get("/family", response_model=List[models.FamilyMemberResponse])
def get_family(user_id: int):
    return database.get_family_members(user_id)

@app.post("/family/add", response_model=models.FamilyMemberResponse)
def add_family_member(user_id: int, member: models.FamilyMemberCreate):
    created = database.create_family_member({
        "user_id": user_id,
        "name": member.name,
        "dob": member.dob,
        "star": member.star,
        "gender": member.gender,
        "rasi": member.rasi,
        "email": member.email or "",
        "mobile_no": member.mobile_no or ""
    })
    return created

# ----------------- TEMPLES & SERVICES ENDPOINTS -----------------

@app.get("/temples", response_model=List[models.TempleResponse])
def get_temples():
    return database.get_temples()

@app.get("/temples/{temple_id}", response_model=models.TempleWithServicesResponse)
def get_temple_details(temple_id: int):
    temple = database.get_temple_by_id(temple_id)
    if not temple:
        raise HTTPException(status_code=404, detail="Temple not found")
        
    services = database.get_services_by_temple(temple_id)
    temple["services"] = services
    return temple

@app.get("/services", response_model=List[models.ServiceWithTempleResponse])
def get_all_services(query: Optional[str] = Query(None)):
    services = database.get_services()
    results = []
    
    for s in services:
        t = database.get_temple_by_id(s.get("temple_id", 0))
        if not t:
            continue
            
        # Match query if present
        if query:
            q = query.lower()
            s_name = s.get("name", "").lower()
            s_desc = s.get("description", "").lower()
            t_name = t.get("name", "").lower()
            if q not in s_name and q not in s_desc and q not in t_name:
                continue
                
        results.append({
            "id": s["id"],
            "name": s["name"],
            "price": s["price"],
            "description": s["description"],
            "duration": s["duration"],
            "temple": t
        })
        
    return results

# ----------------- AUSPICIOUS DAYS -----------------

@app.get("/auspicious-days")
def get_auspicious_days():
    today = datetime.date.today()
    auspicious = []
    
    events = [
        {"name": "Sankashti Chaturthi", "desc": "Auspicious day dedicated to Lord Ganesha, ideal for overcoming obstacles."},
        {"name": "Ekadashi Vrat", "desc": "Sacred fasting day dedicated to Lord Vishnu for cleansing sins."},
        {"name": "Pradosham Seva", "desc": "Highly auspicious evening ritual dedicated to Lord Shiva for blessing and health."},
        {"name": "Pournami (Full Moon) Puja", "desc": "Satyanarayana Puja and special offerings for wealth and peace."},
        {"name": "Amavasya Pitru Puja", "desc": "Ancestral offerings and prayers for family blessings."},
        {"name": "Karthigai Deepam", "desc": "Festival of lights dedicated to Murugan/Shiva."},
        {"name": "Shravan Somvar Puja", "desc": "Special Monday puja for Lord Shiva."},
        {"name": "Ganesha Chaturthi Special", "desc": "Special celebrations for the birth of Ganesha."}
    ]
    
    current_year = today.year
    current_month = today.month
    
    for month_offset in [0, 1]:
        m = current_month + month_offset
        y = current_year
        if m > 12:
            m -= 12
            y += 1
            
        day_indices = [5, 11, 15, 23, 27]
        for idx, day in enumerate(day_indices):
            try:
                date_val = datetime.date(y, m, day)
                if date_val >= today:
                    event = events[(day + m) % len(events)]
                    auspicious.append({
                        "date": date_val.strftime("%Y-%m-%d"),
                        "title": event["name"],
                        "description": event["desc"],
                        "auspicious_time": "09:15 AM - 10:45 AM" if day % 2 == 0 else "04:30 PM - 06:00 PM"
                    })
            except ValueError:
                pass
                
    return sorted(auspicious, key=lambda x: x["date"])

# ----------------- TIMINGS / DOUBLE BOOKING -----------------

SLOTS = ["06:00", "07:30", "09:00", "10:30", "12:00", "16:00", "17:30", "19:00"]

@app.get("/timings/slots", response_model=List[models.SlotStatus])
def get_slots_status(service_id: int, date: str):
    try:
        datetime.datetime.strptime(date, "%Y-%m-%d")
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid date format. Use YYYY-MM-DD")
        
    bookings = database.get_bookings()
    booked_counts = {}
    
    for b in bookings:
        if b.get("service_id") == service_id and b.get("booking_date") == date and b.get("status") != "declined":
            slot = b.get("slot_time")
            booked_counts[slot] = booked_counts.get(slot, 0) + 1
            
    response = []
    for slot in SLOTS:
        booked = booked_counts.get(slot, 0)
        # Strict capacity limit = 1
        status_color = "full" if booked >= 1 else "available"
        response.append({
            "time": slot,
            "status": status_color,
            "booked_count": booked
        })
        
    return response

@app.post("/bookings/book")
def book_seva(booking: models.BookingCreate, user_id: int):
    # Acquire thread lock to make check-and-insert atomic
    with booking_lock:
        bookings = database.get_bookings()
        already_booked = 0
        for b in bookings:
            if b.get("service_id") == booking.service_id and \
               b.get("booking_date") == booking.booking_date and \
               b.get("slot_time") == booking.slot_time and \
               b.get("status") != "declined":
                already_booked += 1
                
        if already_booked >= 1:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="This timing slot has already been booked. Please select another timing."
            )
            
        booking_node = {
            "temple_id": booking.temple_id,
            "service_id": booking.service_id,
            "user_id": user_id,
            "priest_id": "",
            "attendee_name": booking.attendee_name,
            "booking_date": booking.booking_date,
            "slot_time": booking.slot_time,
            "payment_status": "pending",
            "status": "pending",
            "created_at": datetime.datetime.utcnow().isoformat()
        }
        created = database.create_booking(booking_node)
        return {"booking_id": created["id"], "status": "pending", "message": "Slot locked."}

# ----------------- PAYMENT ENDPOINTS -----------------

@app.post("/payments/checkout")
def checkout_and_pay(booking_id: int):
    booking = database.get_booking_by_id(booking_id)
    if not booking:
        raise HTTPException(status_code=404, detail="Booking not found")
        
    database.update_booking(booking_id, {"payment_status": "paid"})
    return {"status": "success", "message": "Seva booked successfully!"}

# ----------------- ROLE-SPECIFIC BOOKING HISTORY ENDPOINTS -----------------

@app.get("/bookings/history", response_model=List[models.BookingResponse])
def get_booking_history(user_id: int):
    user = database.get_user_by_id(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
        
    role = user.get("role")
    bookings = database.get_bookings()
    filtered = []
    
    if role == 'devotee':
        # Devotee sees their own bookings
        filtered = [b for b in bookings if b.get("user_id") == user_id]
    elif role == 'priest':
        # Priest sees bookings assigned to them OR unassigned bookings in temples they are associated with
        invites = database.get_invitations()
        associated_temple_ids = [i.get("temple_id") for i in invites if i.get("priest_id") == user_id and i.get("status") == "accepted"]
        filtered = [b for b in bookings if b.get("priest_id") == user_id or (not b.get("priest_id") and b.get("temple_id") in associated_temple_ids)]
    elif role == 'temple':
        # Temple Admin sees bookings for their temple
        temple = database.get_temple_by_user_id(user_id)
        if temple:
            filtered = [b for b in bookings if b.get("temple_id") == temple["id"]]
            
    # Format and attach names & contact details
    results = []
    for b in filtered:
        temple = database.get_temple_by_id(b.get("temple_id", 0))
        service = next((s for s in database.get_services() if s["id"] == b.get("service_id")), None)
        
        b_dict = {
            "id": b["id"],
            "temple_id": b["temple_id"],
            "temple_name": temple.get("name", "Temple") if temple else "Temple",
            "service_id": b["service_id"],
            "service_name": service.get("name", "Service") if service else "Service",
            "price": service.get("price", 0.0) if service else 0.0,
            "user_id": b["user_id"],
            "attendee_name": b["attendee_name"],
            "booking_date": b["booking_date"],
            "slot_time": b["slot_time"],
            "payment_status": b["payment_status"],
            "status": b["status"],
            "created_at": b.get("created_at", ""),
            "priest_id": b.get("priest_id") or 0
        }
        
        # Attach shared contacts if accepted
        if b["status"] == 'accepted':
            b_dict["devotee_contact"] = fetch_contact_info(b["user_id"], 'devotee')
            b_dict["temple_contact"] = fetch_contact_info(b["temple_id"], 'temple')
            if b.get("priest_id"):
                b_dict["priest_contact"] = fetch_contact_info(b["priest_id"], 'priest')
            else:
                b_dict["priest_contact"] = None
        else:
            b_dict["devotee_contact"] = None
            b_dict["priest_contact"] = None
            b_dict["temple_contact"] = None
            
        results.append(b_dict)
        
    results.sort(key=lambda x: (x["booking_date"], x["slot_time"]), reverse=True)
    return results

@app.post("/bookings/respond")
def respond_to_booking(booking_id: int, priest_id: int, status: str):
    if status not in ['accepted', 'declined']:
        raise HTTPException(status_code=400, detail="Invalid status. Must be accepted or declined.")
        
    booking = database.get_booking_by_id(booking_id)
    if not booking:
        raise HTTPException(status_code=404, detail="Booking request not found")
        
    # Check if priest is associated with this temple
    invites = database.get_invitations()
    is_linked = any(
        i.get("temple_id") == booking.get("temple_id") and \
        i.get("priest_id") == priest_id and \
        i.get("status") == "accepted"
        for i in invites
    )
    if not is_linked:
        raise HTTPException(status_code=403, detail="Priest is not associated with this temple.")
        
    if status == 'accepted':
        database.update_booking(booking_id, {"status": "accepted", "priest_id": priest_id})
    else:
        database.update_booking(booking_id, {"status": "declined", "priest_id": ""})
        
    return {"status": "success", "message": f"Service booking {status}."}

# ----------------- REVENUE STATS (FOR TEMPLE ADMIN) -----------------

@app.get("/temples/stats")
def get_temple_stats(user_id: int):
    temple = database.get_temple_by_user_id(user_id)
    if not temple:
        raise HTTPException(status_code=404, detail="Temple not found for this user admin account.")
        
    t_id = temple["id"]
    bookings = database.get_bookings()
    services = database.get_services()
    
    temple_bookings = [b for b in bookings if b.get("temple_id") == t_id]
    total_bookings = len(temple_bookings)
    
    total_revenue = 0.0
    breakdown_map = {}
    
    for b in temple_bookings:
        if b.get("payment_status") == "paid":
            service = next((s for s in services if s["id"] == b.get("service_id")), None)
            if service:
                price = service.get("price", 0.0)
                total_revenue += price
                
                s_name = service.get("name", "")
                if s_name not in breakdown_map:
                    breakdown_map[s_name] = {"service_name": s_name, "count": 0, "revenue": 0.0}
                breakdown_map[s_name]["count"] += 1
                breakdown_map[s_name]["revenue"] += price
                
    return {
        "temple_id": t_id,
        "total_bookings": total_bookings,
        "total_revenue": total_revenue,
        "breakdown": list(breakdown_map.values())
    }

# ----------------- PRIEST RECRUITMENT / SEARCH ENDPOINTS -----------------

@app.get("/priests/search", response_model=models.PriestSearchResponse)
def search_priest(email: str):
    user = database.get_user_by_email(email.strip())
    if not user or user.get("role") != "priest":
        raise HTTPException(status_code=404, detail="Priest not found with this email.")
        
    # Get associated temple names
    invites = database.get_invitations()
    associated_names = []
    for i in invites:
        if i.get("priest_id") == user["id"] and i.get("status") == "accepted":
            t = database.get_temple_by_id(i.get("temple_id"))
            if t:
                associated_names.append(t.get("name"))
                
    return {
        "id": user["id"],
        "full_name": user["full_name"],
        "email": user["email"],
        "mobile": user["mobile"],
        "gender": user.get("gender", ""),
        "dob": user.get("dob", ""),
        "address": user.get("address", ""),
        "associated_temples": associated_names
    }

@app.post("/temples/invite")
def send_priest_invitation(user_id: int, invite: models.InviteCreate):
    temple = database.get_temple_by_user_id(user_id)
    if not temple:
        raise HTTPException(status_code=404, detail="Temple admin profile not found.")
        
    t_id = temple["id"]
    
    priest = database.get_user_by_email(invite.priest_email.strip())
    if not priest or priest.get("role") != "priest":
        raise HTTPException(status_code=404, detail="Priest not found with this email.")
        
    priest_id = priest["id"]
    
    # Check if invitation already exists
    invites = database.get_invitations()
    existing_invite = next((i for i in invites if i.get("temple_id") == t_id and i.get("priest_id") == priest_id), None)
    
    if existing_invite:
        inv_status = existing_invite.get("status")
        if inv_status == 'accepted':
            raise HTTPException(status_code=400, detail="Priest is already working for your temple!")
        database.update_invitation(existing_invite["id"], {"status": "pending"})
        return {"status": "success", "message": "Priest invitation resent successfully."}
        
    database.create_invitation({
        "temple_id": t_id,
        "temple_name": temple["name"],
        "priest_id": priest_id,
        "priest_name": priest["full_name"],
        "status": "pending",
        "created_at": datetime.datetime.utcnow().isoformat()
    })
    return {"status": "success", "message": "Recruitment invitation sent to priest!"}

@app.get("/temples/invites", response_model=List[models.InvitationResponse])
def get_temple_sent_invites(user_id: int):
    temple = database.get_temple_by_user_id(user_id)
    if not temple:
        return []
    invites = database.get_invitations()
    return [i for i in invites if i.get("temple_id") == temple["id"]]

@app.get("/priests/invitations", response_model=List[models.InvitationResponse])
def get_priest_received_invites(priest_id: int):
    invites = database.get_invitations()
    return [i for i in invites if i.get("priest_id") == priest_id]

@app.post("/priests/invitations/respond")
def respond_to_invitation(invite_id: int, status: str):
    if status not in ['accepted', 'declined']:
        raise HTTPException(status_code=400, detail="Invalid status response.")
    database.update_invitation(invite_id, {"status": status})
    return {"status": "success", "message": f"Invitation {status}."}

@app.get("/temples/priests")
def get_temple_associated_priests(user_id: int):
    temple = database.get_temple_by_user_id(user_id)
    if not temple:
        return []
        
    invites = database.get_invitations()
    priest_ids = [i.get("priest_id") for i in invites if i.get("temple_id") == temple["id"] and i.get("status") == "accepted"]
    
    priests = []
    for p_id in priest_ids:
        p = database.get_user_by_id(p_id)
        if p:
            priests.append({
                "id": p["id"],
                "full_name": p["full_name"],
                "email": p["email"],
                "mobile": p["mobile"],
                "gender": p.get("gender", ""),
                "dob": p.get("dob", ""),
                "address": p.get("address", "")
            })
    return priests

if __name__ == "__main__":
    import uvicorn
    # Clear the database and re-seed with clean gmail.com addresses on restart
    database.init_db()
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
