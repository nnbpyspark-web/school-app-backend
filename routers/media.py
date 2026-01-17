from fastapi import APIRouter, UploadFile, File, HTTPException, Header
import os
from supabase import create_client, Client
from typing import Optional
import uuid

router = APIRouter()

# Initialize Supabase Client
url: str = os.environ.get("NEXT_PUBLIC_SUPABASE_URL")
key: str = os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or os.environ.get("NEXT_PUBLIC_SUPABASE_ANON_KEY")

if not url or not key:
    print("Warning: Supabase credentials not found in environment variables.")

supabase: Client = create_client(url, key) if url and key else None

@router.post("/upload")
async def upload_file(file: UploadFile = File(...), authorization: Optional[str] = Header(None)):
    if not supabase:
        raise HTTPException(status_code=500, detail="Supabase not configured")
    
    # 1. Validate JWT (Basic check)
    if not authorization:
        raise HTTPException(status_code=401, detail="Missing Authorization Header")
    
    token = authorization.replace("Bearer ", "")
    
    try:
        user_response = supabase.auth.get_user(token)
        user = user_response.user
    except Exception as e:
        print(f"Auth error: {e}")
        # If we are using Service Role Key, we might need to manually verify JWT or just trust if we want (not recommended).
        # Actually getUser with a service role client might behave differently or expect an admin token.
        # But if we use ANON key, it works as expected.
        # If 'key' is Service Role, we can use `supabase.auth.admin` methods or pass the token to storage methods?
        # A simple pattern: Use the token to create a scoped client?
        # For now, let's assume verify works or fail.
        raise HTTPException(status_code=401, detail="Invalid Token")
    
    if not user:
        raise HTTPException(status_code=401, detail="Invalid Token")

    # 2. Upload to Supabase Storage
    bucket_name = "media" 
    
    # Read file content
    file_content = await file.read()
    
    # Generate a unique path: {user_id}/{uuid}_{filename}
    file_extension = file.filename.split(".")[-1] if "." in file.filename else ""
    unique_filename = f"{uuid.uuid4()}.{file_extension}"
    file_path = f"{user.id}/{unique_filename}"
    
    try:
        # Check if bucket exists, create if not?
        # existing_buckets = supabase.storage.list_buckets()
        # bucket_exists = any(b.name == bucket_name for b in existing_buckets)
        # if not bucket_exists:
        #     supabase.storage.create_bucket(bucket_name, options={"public": true})

        # We assume bucket exists for performance, or user must create it.
        
        response = supabase.storage.from_(bucket_name).upload(
            path=file_path,
            file=file_content,
            file_options={"content-type": file.content_type, "upsert": "true"}
        )
        
        # Get Public URL
        public_url = supabase.storage.from_(bucket_name).get_public_url(file_path)
        
        return {"url": public_url}
        
    except Exception as e:
        print(f"Upload error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
