import os
import sys
import json
import pickle
from datetime import datetime, timedelta
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import Optional, List

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from features import build_macro_features, features_to_array, FEATURE_NAMES, calculate_priority
from db import get_db_client
from epidemic import detect_outbreaks

app = FastAPI(title="Niramaya-Net ML Service", version="2.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODELS_DIR = os.path.join(BASE_DIR, "models")

model = None
model_metadata = {}

def load_model():
    global model, model_metadata
    path = os.path.join(MODELS_DIR, "model_macro_v1.pkl")
    if os.path.exists(path):
        with open(path, "rb") as f:
            model = pickle.load(f)

    meta_path = os.path.join(MODELS_DIR, "model_metadata.json")
    if os.path.exists(meta_path):
        with open(meta_path) as f:
            model_metadata = json.load(f)

load_model()
supabase = get_db_client()

class PredictRequest(BaseModel):
    hospital_id: str = Field(..., json_schema_extra={"example": "HOSP-001"})
    department_type: str = Field(..., json_schema_extra={"example": "Cardiology"})
    department_queue_length: Optional[int] = Field(None, json_schema_extra={"example": 12})
    patients_ahead_in_department: Optional[int] = Field(None, json_schema_extra={"example": 5})
    avg_wait_last_hour: Optional[float] = Field(None, json_schema_extra={"example": 25.5})
    department_bed_utilization: Optional[float] = Field(None, json_schema_extra={"example": 0.85})

class PriorityRequest(BaseModel):
    symptoms: List[str] = Field(default=[], json_schema_extra={"example": ["Severe Chest Pain", "Shortness of Breath"]})
    pain_level: int = Field(ge=0, le=10, default=0, json_schema_extra={"example": 9})
    age: int = Field(default=30, json_schema_extra={"example": 60})
    temperature: float = Field(default=98.6, json_schema_extra={"example": 99.0})
    heart_rate: int = Field(default=75, json_schema_extra={"example": 110})
    systolic_bp: int = Field(default=120, json_schema_extra={"example": 160})
    is_emergency: bool = Field(default=False, json_schema_extra={"example": True})
    waiting_since_minutes: Optional[int] = Field(default=0, json_schema_extra={"example": 120})
    current_queue_length: Optional[int] = Field(default=0, json_schema_extra={"example": 15})

class PredictResponse(BaseModel):
    hospital_id: str
    department_type: str
    predicted_wait_minutes: float
    model_version: str
    features_used: dict
    onnx_available: bool

class PriorityResponse(BaseModel):
    priority_score: float
    category: str
    starvation_escalated: bool
    override_to_front: bool

class OutbreakItem(BaseModel):
    district: str
    location: dict
    type: str
    indicator: str
    recent_daily_avg: float
    baseline_daily_avg: float
    spike_percentage: float
    ml_confidence: float
    severity: str

class OutbreakResponse(BaseModel):
    status: str
    analyzed_districts: int
    total_anomalies_detected: int
    outbreaks: List[OutbreakItem]

@app.get("/")
def root():
    return {"service": "Niramaya-Net ML", "status": "running"}

@app.post("/predict", response_model=PredictResponse)
def predict(req: PredictRequest):
    if model is None:
        raise HTTPException(503, "Model not loaded. Run ml/train.py first.")

    now = datetime.now()
    hour = now.hour
    day = now.weekday()

    queue_len = req.department_queue_length
    pts_ahead = req.patients_ahead_in_department
    avg_wait = req.avg_wait_last_hour
    bed_util = req.department_bed_utilization

    if queue_len is None or bed_util is None:
        try:
            day_ago = (datetime.now() - timedelta(hours=24)).isoformat()
            res = (
                supabase.table("queue_logs")
                .select("*")
                .eq("hospital_id", req.hospital_id)
                .eq("department_type", req.department_type)
                .is_("consultation_end_time", "null")
                .gte("check_in_time", day_ago)
                .execute()
            )

            queue_len = len(res.data)
            if pts_ahead is None:
                pts_ahead = max(0, queue_len - 1)

            if bed_util is None:
                d_res = supabase.table("departments").select("total_beds, available_beds").eq("hospital_id", req.hospital_id).eq("type", req.department_type).execute()
                if d_res.data:
                    tb = d_res.data[0].get("total_beds", 0)
                    ab = d_res.data[0].get("available_beds", 0)
                    bed_util = (tb - ab) / tb if tb > 0 else 1.0
                else:
                    bed_util = 0.5
        except Exception as e:
            print(f"DB Fetch Error in predict: {e}")
            if queue_len is None: queue_len = 5
            if pts_ahead is None: pts_ahead = 4
            if bed_util is None: bed_util = 0.5

    if avg_wait is None: avg_wait = 15.0

    features = build_macro_features(
        hour_of_day=hour,
        day_of_week=day,
        department_queue_length=queue_len,
        patients_ahead_in_department=pts_ahead,
        avg_wait_last_hour=avg_wait,
        department_bed_utilization=bed_util
    )

    X = features_to_array(features)
    predicted = float(model.predict(X)[0])
    predicted = int(round(max(2.0, min(predicted, 300.0))))

    return {
        "hospital_id": req.hospital_id,
        "department_type": req.department_type,
        "predicted_wait_minutes": predicted,
        "model_version": model_metadata.get("version", "macro_v1"),
        "features_used": features,
        "onnx_available": model_metadata.get("onnx_export") == "success",
    }

@app.post("/calculate-priority", response_model=PriorityResponse)
def calc_priority(req: PriorityRequest):
    result = calculate_priority(
        symptoms=req.symptoms,
        pain_level=req.pain_level,
        age=req.age,
        temperature=req.temperature,
        heart_rate=req.heart_rate,
        systolic_bp=req.systolic_bp,
        is_emergency=req.is_emergency,
        waiting_since_minutes=req.waiting_since_minutes or 0,
        current_queue_length=req.current_queue_length or 0,
    )

    score = result["score"]
    if score >= 8: category = "CRITICAL"
    elif score >= 5: category = "URGENT"
    elif score >= 3: category = "MODERATE"
    else: category = "LOW"

    return {
        "priority_score": score,
        "category": category,
        "starvation_escalated": result["starvation_escalated"],
        "override_to_front": result["override_to_front"],
    }

@app.get("/predict-outbreak", response_model=OutbreakResponse)
def predict_outbreak():
    result = detect_outbreaks()
    if result.get("status") != "success":
        raise HTTPException(500, f"Outbreak detection failed: {result.get('status')}")

    outbreaks = result.get("outbreaks", [])
    surge_count = 0
    for alert in outbreaks:
        is_surge = alert["severity"] == "CRITICAL" and alert["ml_confidence"] >= 0.8
        alert["surge_alert_triggered"] = is_surge

        if is_surge:
            surge_count += 1
            alert_msg = f"[{datetime.now().strftime('%H:%M:%S')}] SURGE ALERT: CRITICAL {alert['type']} ({alert['indicator']}) detected in {alert['district']}! Confidence: {alert['ml_confidence']}"

            print("\n" + "!" * 80)
            print(f"!!! {alert_msg.upper()} !!!")
            print("!" * 80 + "\n")

            try:
                log_path = os.path.join(BASE_DIR, "surge_alerts.log")
                with open(log_path, "a") as f:
                    f.write(alert_msg + "\n")
            except Exception as e:
                print(f"File Logging Error: {e}")

            try:
                supabase.table("team_logs").insert({
                    "log_type": "SURGE_ALERT",
                    "details": alert_msg,
                    "severity": "CRITICAL"
                }).execute()
            except Exception:
                pass

    result["total_surge_alerts"] = surge_count
    return result

@app.post("/ml/retrain")
def retrain():
    try:
        from train import process_supabase_data, train_and_compare, generate_synthetic_department_data, export_to_onnx

        df = process_supabase_data()
        source = "supabase"
        if df.empty or len(df) < 50:
            df = generate_synthetic_department_data(2000)
            source = "synthetic"

        best_name, best_model, results = train_and_compare(df)

        model_path = os.path.join(MODELS_DIR, "model_macro_v1.pkl")
        with open(model_path, "wb") as f:
            pickle.dump(best_model, f)

        model_path_onnx = os.path.join(MODELS_DIR, "model_macro_v1.onnx")
        onnx_status = export_to_onnx(best_model, best_name, model_path_onnx)

        old_mae = model_metadata.get("metrics", {}).get("mae", 999)

        meta = {
            "version": f"macro_{datetime.now().strftime('%Y%m%d')}",
            "model_type": best_name,
            "trained_at": datetime.now().isoformat(),
            "data_source": source,
            "training_records": len(df),
            "metrics": results[best_name],
            "onnx_export": onnx_status
        }
        with open(os.path.join(MODELS_DIR, "model_metadata.json"), "w") as f:
            json.dump(meta, f, indent=2)

        load_model()
        return {
            "status": "completed",
            "model": best_name,
            "data_source": source,
            "training_records": len(df),
            "new_mae": results[best_name]['mae'],
            "previous_mae": old_mae if old_mae != 999 else None,
        }
    except Exception as e:
        raise HTTPException(500, f"Retrain failed: {str(e)}")

@app.get("/ml/health")
def health():
    return {
        "status": "healthy" if model else "no_model",
        "model_version": model_metadata.get("version", "unknown"),
        "trained_at": model_metadata.get("trained_at", "unknown"),
        "metrics": model_metadata.get("metrics", {}),
        "onnx_available": model_metadata.get("onnx_export") == "success",
    }

if __name__ == "__main__":
    import uvicorn
    print("Starting Niramaya-Net ML Service on http://localhost:8001")
    uvicorn.run(app, host="0.0.0.0", port=8001)
