import os
import sys
import pickle
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from datetime import datetime
import warnings

from xgboost import XGBRegressor
from sklearn.ensemble import RandomForestRegressor
from sklearn.linear_model import LinearRegression
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_absolute_error, r2_score, root_mean_squared_error

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from features import FEATURE_NAMES
from db import fetch_queue_logs, fetch_departments

def generate_synthetic_department_data(n_records: int = 5000) -> pd.DataFrame:
    rng = np.random.RandomState(42)
    records = []

    for _ in range(n_records):
        hour = rng.choice(range(0, 24))
        day = rng.randint(0, 7)
        peak = 1 if (9 <= hour <= 11) or (17 <= hour <= 19) else 0

        is_sudden_influx = rng.choice([0, 1], p=[0.9, 0.1])
        if is_sudden_influx:
            dept_queue_len = rng.randint(30, 80)
            patients_ahead = rng.randint(20, dept_queue_len + 1)
            avg_wait_last_hr = round(rng.uniform(5, 15), 1)
        else:
            dept_queue_len = rng.randint(0, 50) if peak else rng.randint(0, 20)
            patients_ahead = rng.randint(0, dept_queue_len + 1)
            avg_wait_last_hr = round(rng.uniform(10, 60) if peak else rng.uniform(5, 30), 1)

        bed_util = round(rng.uniform(0.4, 1.0), 2)

        base_dept_speed = 15.0
        actual_wait = (patients_ahead * base_dept_speed) * bed_util
        if peak: actual_wait *= 1.3

        actual_wait += rng.normal(0, 5)
        actual_wait = max(2.0, min(actual_wait, 300.0))

        records.append({
            "hour_of_day": hour,
            "day_of_week": day,
            "is_peak_hour": peak,
            "department_queue_length": dept_queue_len,
            "patients_ahead_in_department": patients_ahead,
            "avg_wait_last_hour": avg_wait_last_hr,
            "department_bed_utilization": bed_util,
            "actual_wait_minutes": round(actual_wait, 1)
        })

    return pd.DataFrame(records)

def process_supabase_data() -> pd.DataFrame:
    logs_df = fetch_queue_logs(10000)
    if logs_df.empty:
        return pd.DataFrame()

    depts_df = fetch_departments()

    if 'check_in_time' not in logs_df.columns or 'consultation_end_time' not in logs_df.columns:
        return pd.DataFrame()

    logs_df['check_in_time'] = pd.to_datetime(logs_df['check_in_time'], format='ISO8601')
    logs_df['consultation_end_time'] = pd.to_datetime(logs_df['consultation_end_time'], format='ISO8601')

    logs_df['actual_wait_minutes'] = (logs_df['consultation_end_time'] - logs_df['check_in_time']).dt.total_seconds() / 60.0

    logs_df = logs_df[logs_df['actual_wait_minutes'] > 0]

    Q1 = logs_df['actual_wait_minutes'].quantile(0.25)
    Q3 = logs_df['actual_wait_minutes'].quantile(0.75)
    IQR = Q3 - Q1
    upper_bound = Q3 + 1.5 * IQR
    max_allowed = min(upper_bound, 1440.0)

    logs_df = logs_df[logs_df['actual_wait_minutes'] <= max_allowed]

    records = []

    for _, row in logs_df.iterrows():
        check_in = row['check_in_time']
        hour = check_in.hour
        day = check_in.weekday()
        peak = 1 if (9 <= hour <= 11) or (17 <= hour <= 19) else 0

        bed_util = 0.5
        if not depts_df.empty and 'hospital_id' in row and 'department_type' in row:
            dept_match = depts_df[(depts_df['hospital_id'] == row['hospital_id']) & (depts_df['type'] == row['department_type'])]
            if not dept_match.empty:
                tb = dept_match.iloc[0].get('total_beds', 0)
                ab = dept_match.iloc[0].get('available_beds', 0)
                if tb > 0:
                    bed_util = (tb - ab) / tb

        active_at_time = logs_df[
            (logs_df['hospital_id'] == row['hospital_id']) &
            (logs_df['department_type'] == row['department_type']) &
            (logs_df['check_in_time'] <= check_in) &
            (logs_df['consultation_end_time'] > check_in)
        ]
        dept_queue_len = len(active_at_time)
        patients_ahead = max(0, dept_queue_len - 1)

        last_hr_logs = logs_df[
            (logs_df['hospital_id'] == row['hospital_id']) &
            (logs_df['department_type'] == row['department_type']) &
            (logs_df['consultation_end_time'] <= check_in) &
            (logs_df['consultation_end_time'] >= check_in - pd.Timedelta(hours=1))
        ]
        avg_wait = last_hr_logs['actual_wait_minutes'].mean() if len(last_hr_logs) > 0 else 15.0

        records.append({
            "hour_of_day": hour,
            "day_of_week": day,
            "is_peak_hour": peak,
            "department_queue_length": dept_queue_len,
            "patients_ahead_in_department": patients_ahead,
            "avg_wait_last_hour": float(avg_wait) if pd.notna(avg_wait) else 15.0,
            "department_bed_utilization": bed_util,
            "actual_wait_minutes": row['actual_wait_minutes']
        })

    return pd.DataFrame(records)

def train_and_compare(df: pd.DataFrame):
    X = df[FEATURE_NAMES]
    y = df["actual_wait_minutes"]

    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

    models = {
        "XGBoost": XGBRegressor(n_estimators=150, learning_rate=0.1, max_depth=5, random_state=42),
        "Random Forest": RandomForestRegressor(n_estimators=100, max_depth=8, random_state=42),
        "Linear Regression": LinearRegression(),
    }

    results = {}
    trained_models = {}

    for name, model in models.items():
        model.fit(X_train.values, y_train.values)
        y_pred = np.clip(model.predict(X_test.values), 0, 300)

        mae = mean_absolute_error(y_test, y_pred)
        r2 = r2_score(y_test, y_pred)
        rmse = root_mean_squared_error(y_test, y_pred)

        errors = np.abs(y_test.values - y_pred)
        results[name] = {
            "mae": round(mae, 2),
            "r2": round(r2, 4),
            "rmse": round(rmse, 2),
            "within_10_min": round((errors <= 10).mean() * 100, 1)
        }
        trained_models[name] = model

    best_name = min(results, key=lambda k: results[k]["mae"])
    return best_name, trained_models[best_name], results

def export_to_onnx(model, model_name, file_path):
    try:
        import onnx
        from skl2onnx.common.data_types import FloatTensorType
        initial_type = [('float_input', FloatTensorType([None, len(FEATURE_NAMES)]))]

        if "XGBoost" in model_name:
            from onnxmltools.convert import convert_xgboost
            onnx_model = convert_xgboost(model, initial_types=initial_type, target_opset=12)
        else:
            from skl2onnx import convert_sklearn
            onnx_model = convert_sklearn(model, initial_types=initial_type, target_opset=12)

        onnx.save(onnx_model, file_path)
        return "success"
    except Exception as e:
        print(f"ONNX Export Failed: {e}")
        return f"failed: {str(e)}"

if __name__ == "__main__":
    base_dir = os.path.dirname(os.path.abspath(__file__))
    models_dir = os.path.join(base_dir, "models")
    os.makedirs(models_dir, exist_ok=True)

    print("Fetching real hospital data from Supabase...")
    df = process_supabase_data()
    source = "supabase"

    if df.empty or len(df) < 200:
        print("Not enough real DB records. Falling back to realistic synthetic data...")
        df = generate_synthetic_department_data(5000)
        source = "synthetic"
    else:
        print(f"Blending {len(df)} real records with synthetic data for stability...")
        synthetic_df = generate_synthetic_department_data(2000)
        df = pd.concat([df, synthetic_df], ignore_index=True)
        source = "blended"

    print(f"Training on {len(df)} records (Source: {source})...")
    best_name, best_model, results = train_and_compare(df)

    model_path_pkl = os.path.join(models_dir, "model_macro_v1.pkl")
    with open(model_path_pkl, "wb") as f:
        pickle.dump(best_model, f)

    model_path_onnx = os.path.join(models_dir, "model_macro_v1.onnx")
    onnx_status = export_to_onnx(best_model, best_name, model_path_onnx)

    metadata = {
        "model_name": best_name,
        "version": "macro_v1",
        "trained_at": datetime.now().isoformat(),
        "data_source": source,
        "training_rows": len(df),
        "features": FEATURE_NAMES,
        "metrics": results[best_name],
        "onnx_export": onnx_status
    }

    import json
    with open(os.path.join(models_dir, "model_metadata.json"), "w") as f:
        json.dump(metadata, f, indent=2)

    print(f"WINNER: {best_name} (MAE = {results[best_name]['mae']} min)")
    print(f"Model saved to models/model_macro_v1.pkl (.onnx: {onnx_status})")
