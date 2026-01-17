from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel
import razorpay
import os
from supabase import create_client, Client

router = APIRouter()

# ------------------------------------------------------------------
# 1. Configuration & Dependency Setup
# ------------------------------------------------------------------

# Razorpay Client
KEY_ID = os.environ.get("RAZORPAY_KEY_ID")
KEY_SECRET = os.environ.get("RAZORPAY_KEY_SECRET")

# Supabase Admin Client (Service Role)
SUPABASE_URL = os.environ.get("NEXT_PUBLIC_SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")

# ------------------------------------------------------------------
# 2. Pydantic Models for Validation
# ------------------------------------------------------------------
class OrderRequest(BaseModel):
    amount: int  # in paise (e.g. 50000 = 500 INR)
    currency: str = "INR"
    plan_id: str # 'basic', 'pro'
    school_id: str # Who is buying?

class VerificationRequest(BaseModel):
    razorpay_order_id: str
    razorpay_payment_id: str
    razorpay_signature: str
    school_id: str # To update status
    plan_id: str

# ------------------------------------------------------------------
# 3. Endpoints
# ------------------------------------------------------------------

@router.post("/create-order")
async def create_order(request: OrderRequest):
    """
    Creates a Razorpay Order ID to be sent to frontend.
    """
    if not KEY_ID or not KEY_SECRET:
         raise HTTPException(status_code=500, detail="Razorpay credentials not configured")

    client = razorpay.Client(auth=(KEY_ID, KEY_SECRET))

    data = {
        "amount": request.amount, 
        "currency": request.currency, 
        "payment_capture": 1 # Auto capture
    }
    
    try:
        order = client.order.create(data=data)
        return {
            "order_id": order["id"],
            "currency": order["currency"],
            "amount": order["amount"],
            "key": KEY_ID # Send public key to frontend for convenience
        }
    except Exception as e:
        print(f"Razorpay Error: {str(e)}")
        raise HTTPException(status_code=400, detail="Could not create order")


@router.post("/verify-payment")
async def verify_payment(data: VerificationRequest):
    """
    Verifies the signature returned by Razorpay Checkout.
    If valid, updates the Supabase DB to mark subscription as active.
    """
    if not KEY_ID or not KEY_SECRET:
         raise HTTPException(status_code=500, detail="Razorpay credentials not configured")

    client = razorpay.Client(auth=(KEY_ID, KEY_SECRET))

    # Verify Signature
    try:
        params_dict = {
            'razorpay_order_id': data.razorpay_order_id,
            'razorpay_payment_id': data.razorpay_payment_id,
            'razorpay_signature': data.razorpay_signature
        }
        client.utility.verify_payment_signature(params_dict)
    except razorpay.errors.SignatureVerificationError:
        raise HTTPException(status_code=400, detail="Invalid Payment Signature")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    # Signature is Valid -> Update Database
    if SUPABASE_URL and SUPABASE_KEY:
        try:
            supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
            
            # 1. Update School Status
            supabase.table("schools").update({
                "subscription_status": "active"
            }).eq("id", data.school_id).execute()

            # 2. Log Subscription (Optional but recommended)
            # You might need to check if a record exists first or use upsert
            supabase.table("subscriptions").insert({
                 "school_id": data.school_id,
                 "razorpay_order_id": data.razorpay_order_id,
                 "razorpay_payment_id": data.razorpay_payment_id,
                 "razorpay_signature": data.razorpay_signature,
                 "plan_id": data.plan_id,
                 "status": "active"
             }).execute()
             
            return {"status": "success", "message": "Payment Verified & Subscription Activated"}

        except Exception as e:
            print(f"DB Error: {e}")
            # Payment was successful, but DB update failed. 
            # In production, log this critical error to alert admins.
            raise HTTPException(status_code=500, detail="Payment verified but failed to update subscription.")
    else:
        print("Warning: Supabase credentials missing during verification.")
        return {"status": "success", "message": "Payment Verified (No DB Update)"}
