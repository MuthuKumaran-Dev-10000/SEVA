from pydantic import BaseModel, EmailStr
from typing import Optional, List

# Unified Auth Models
class UserCreate(BaseModel):
    email: EmailStr
    password: str
    full_name: str
    mobile: str
    role: str # 'devotee', 'priest', 'temple'
    
    # Optional fields depending on the signup privilege
    dob: Optional[str] = None
    star: Optional[str] = None
    rasi: Optional[str] = None
    gender: Optional[str] = None
    address: Optional[str] = None
    description: Optional[str] = None
    location_link: Optional[str] = None

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class UserResponse(BaseModel):
    id: int
    email: str
    full_name: str
    mobile: str
    role: str
    dob: Optional[str] = None
    star: Optional[str] = None
    rasi: Optional[str] = None
    gender: Optional[str] = None
    address: Optional[str] = None
    description: Optional[str] = None
    location_link: Optional[str] = None
    avatar_url: Optional[str] = None

    class Config:
        from_attributes = True

# Contact details shared when a service booking is accepted
class ContactInfo(BaseModel):
    name: str
    mobile: str
    email: str
    address: Optional[str] = None

# Booking Models
class BookingCreate(BaseModel):
    temple_id: int
    service_id: int
    attendee_name: str
    booking_date: str # YYYY-MM-DD
    slot_time: str    # HH:MM

class BookingResponse(BaseModel):
    id: int
    temple_id: int
    temple_name: str
    service_id: int
    service_name: str
    price: float
    user_id: int
    attendee_name: str
    booking_date: str
    slot_time: str
    payment_status: str
    status: str
    created_at: str
    
    # Conditionally populated only when booking status == 'accepted'
    devotee_contact: Optional[ContactInfo] = None
    priest_contact: Optional[ContactInfo] = None
    temple_contact: Optional[ContactInfo] = None

    class Config:
        from_attributes = True

# Temple & Service Models
class ServiceResponse(BaseModel):
    id: int
    temple_id: int
    name: str
    price: float
    description: str
    duration: str

    class Config:
        from_attributes = True

class TempleResponse(BaseModel):
    id: int
    name: str
    location: str
    image_url: str
    description: str
    location_link: Optional[str] = None

    class Config:
        from_attributes = True

class TempleWithServicesResponse(TempleResponse):
    services: List[ServiceResponse] = []

class ServiceWithTempleResponse(BaseModel):
    id: int
    name: str
    price: float
    description: str
    duration: str
    temple: TempleResponse

class SlotStatus(BaseModel):
    time: str
    status: str # 'available' or 'full'
    booked_count: int

# Priest Search Result
class PriestSearchResponse(BaseModel):
    id: int
    full_name: str
    email: str
    mobile: str
    gender: str
    dob: str
    address: str
    associated_temples: List[str] # List of temple names this priest is already linked to

# Temple Invitation Models
class InviteCreate(BaseModel):
    priest_email: str

class InvitationResponse(BaseModel):
    id: int
    temple_id: int
    temple_name: str
    priest_id: int
    priest_name: str
    status: str
    created_at: str

    class Config:
        from_attributes = True

# Family Member Models
class FamilyMemberCreate(BaseModel):
    name: str
    dob: str
    star: str
    gender: str
    rasi: str
    email: Optional[str] = None
    mobile_no: Optional[str] = None

class FamilyMemberResponse(BaseModel):
    id: int
    user_id: int
    name: str
    dob: str
    star: str
    gender: str
    rasi: str
    email: Optional[str] = None
    mobile_no: Optional[str] = None

    class Config:
        from_attributes = True
