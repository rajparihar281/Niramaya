import os
from dotenv import load_dotenv
from supabase import create_client, Client
import pandas as pd

load_dotenv()

URL = os.environ.get("SUPABASE_URL")
KEY = os.environ.get("SUPABASE_KEY")

supabase: Client = create_client(URL, KEY)

def get_db_client() -> Client:
    return supabase

def fetch_queue_logs(limit: int = 10000) -> pd.DataFrame:
    try:
        response = supabase.table("queue_logs").select("*").not_.is_("consultation_end_time", "null").limit(limit).execute()
        return pd.DataFrame(response.data)
    except Exception as e:
        print(f"Error fetching queue_logs: {e}")
        return pd.DataFrame()

def fetch_departments() -> pd.DataFrame:
    try:
        response = supabase.table("departments").select("*").execute()
        return pd.DataFrame(response.data)
    except Exception as e:
        print(f"Error fetching departments: {e}")
        return pd.DataFrame()

def fetch_symptom_logs(limit: int = 10000) -> pd.DataFrame:
    try:
        response = supabase.table("symptom_logs").select("*").limit(limit).execute()
        return pd.DataFrame(response.data)
    except Exception as e:
        print(f"Error fetching symptom_logs: {e}")
        return pd.DataFrame()

def fetch_pharmacy_sales(limit: int = 10000) -> pd.DataFrame:
    try:
        response = (
            supabase.table("pharmacy_sales")
            .select("medicine_name, created_at, is_verified")
            .eq("is_verified", True)
            .limit(limit)
            .execute()
        )
        return pd.DataFrame(response.data)
    except Exception as e:
        print(f"Error fetching pharmacy_sales: {e}")
        return pd.DataFrame()
