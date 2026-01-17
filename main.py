from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
try:
    from routers import payments_razorpay, media
except ImportError:
    from backend.routers import payments_razorpay, media
import os

app = FastAPI()

# CORS
origins = [
    "http://localhost:3000",
    "http://127.0.0.1:3000",
    os.environ.get("FRONTEND_URL", "http://localhost:3000"),
    "https://*.vercel.app" # Allow Vercel Deployments
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/api/v1") # Root of API
def read_root():
    return {"message": "School App Backend is running on Vercel"}

# Include Routers
app.include_router(media.router, prefix="/api/v1", tags=["media"])
app.include_router(payments_razorpay.router, prefix="/api/v1/payments", tags=["payments"])
