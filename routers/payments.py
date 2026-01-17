from fastapi import APIRouter, HTTPException, Request, Header
import stripe
import os
from supabase import create_client, Client
import json

router = APIRouter()

# Setup Stripe
stripe.api_key = os.environ.get("STRIPE_SECRET_KEY")
stripe_webhook_secret = os.environ.get("STRIPE_WEBHOOK_SECRET")
# For a real app, these should be environment variables mapping Plan Names to Stripe Price IDs
# e.g. "basic": "price_123...", "pro": "price_456..."
# For testing, we'll assume the frontend passes a price_id or we map simple strings.
PRICING_TABLE = {
    "basic": "price_basic_test_id", 
    "pro": "price_pro_test_id" 
}

# Supabase Admin Client (Service Role) required for updating subscription status
url: str = os.environ.get("NEXT_PUBLIC_SUPABASE_URL")
key: str = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")

if not url or not key:
    print("Warning: Supabase Service Role credentials not found. Webhooks might fail to update DB.")

supabase: Client = create_client(url, key) if url and key else None

@router.post("/create-checkout-session")
async def create_checkout_session(request: Request):
    """
    Creates a Stripe Checkout Session for a subscription.
    Expects JSON: { "plan_id": "pro", "school_id": "..." }
    """
    if not stripe.api_key:
        raise HTTPException(status_code=500, detail="Stripe API Key not configured")

    try:
        data = await request.json()
        plan_id = data.get("plan_id")
        school_id = data.get("school_id") # We should strictly get this from auth token if possible, but for simplicity we take it from body if trusted or validated elsewhere.
        
        # Validate logic here...
        price_id = PRICING_TABLE.get(plan_id, plan_id) # Simplify: allow direct price id or mapped
        
        checkout_session = stripe.checkout.Session.create(
            payment_method_types=['card'],
            line_items=[
                {
                    'price': price_id,
                    'quantity': 1,
                },
            ],
            mode='subscription',
            success_url=f'{os.environ.get("NEXT_PUBLIC_APP_URL", "http://localhost:3000")}/dashboard/billing?success=true&session_id={{CHECKOUT_SESSION_ID}}',
            cancel_url=f'{os.environ.get("NEXT_PUBLIC_APP_URL", "http://localhost:3000")}/dashboard/billing?canceled=true',
            metadata={
                "school_id": school_id,
                "plan_id": plan_id
            }
        )
        return {"url": checkout_session.url}
    except Exception as e:
        print(e)
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/webhook")
async def webhook(request: Request, stripe_signature: str = Header(None)):
    if not stripe_webhook_secret:
         raise HTTPException(status_code=500, detail="Stripe Webhook Secret not configured")

    payload = await request.body()

    try:
        event = stripe.Webhook.construct_event(
            payload, stripe_signature, stripe_webhook_secret
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail="Invalid payload")
    except stripe.error.SignatureVerificationError as e:
        raise HTTPException(status_code=400, detail="Invalid signature")

    # Handle the event
    if event['type'] == 'checkout.session.completed':
        session = event['data']['object']
        await handle_checkout_completed(session)
        
    elif event['type'] == 'invoice.payment_succeeded':
        # Extend subscription, etc.
        pass
    
    return {"status": "success"}

async def handle_checkout_completed(session):
    school_id = session.get("metadata", {}).get("school_id")
    plan_id = session.get("metadata", {}).get("plan_id")
    stripe_subscription_id = session.get("subscription")
    stripe_customer_id = session.get("customer")
    
    if school_id and supabase:
        # 1. Update School Status
        try:
             supabase.table("schools").update({"subscription_status": "active"}).eq("id", school_id).execute()
             
             # 2. Add/Update Subscription Record
             # For MVP, just insert. In real app, upsert based on school_id is better.
             supabase.table("subscriptions").insert({
                 "school_id": school_id,
                 "stripe_subscription_id": stripe_subscription_id,
                 "stripe_customer_id": stripe_customer_id,
                 "plan_id": plan_id,
                 "status": "active"
             }).execute()
             
             print(f"Activated subscription for school {school_id}")
        except Exception as e:
            print(f"DB Error: {e}")
