import pandas as pd
import numpy as np
import os
import pickle
from db import fetch_symptom_logs, fetch_pharmacy_sales
from datetime import datetime, timedelta, timezone

OUTBREAK_MODEL = None
MODELS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "models")

def load_outbreak_model():
    global OUTBREAK_MODEL
    path = os.path.join(MODELS_DIR, "outbreak_classifier_v1.pkl")
    if os.path.exists(path):
        with open(path, "rb") as f:
            OUTBREAK_MODEL = pickle.load(f)

DISTRICT_COORDS = {
    "Sector 1": {"lat": 28.6139, "lng": 77.2090},
    "Sector 2": {"lat": 28.6200, "lng": 77.2200},
    "Sector 3": {"lat": 28.6300, "lng": 77.2300},
    "Sector 4": {"lat": 28.6400, "lng": 77.2400},
    "Global":   {"lat": 28.6139, "lng": 77.2090}
}

def generate_synthetic_pharmacy_sales(symptom_df: pd.DataFrame) -> pd.DataFrame:
    if symptom_df.empty:
        return pd.DataFrame()

    records = []
    med_map = {
        'Fever': 'Paracetamol',
        'Cough': 'Cough Syrup',
        'Body Ache': 'Ibuprofen',
        'Infection': 'Amoxicillin'
    }

    for _, row in symptom_df.iterrows():
        symp = row['symptom_type']
        count = row.get('occurrence_count', 1)
        med = med_map.get(symp, 'General Antibiotic')
        sales_count = max(1, int(count * np.random.uniform(0.5, 1.2)))
        records.append({
            'district': row.get('district', 'Unknown'),
            'medicine_name': med,
            'occurrence_count': sales_count,
            'created_at': row['created_at']
        })

    df = pd.DataFrame(records)
    if not df.empty:
        df['is_synthetic'] = True
    return df

def detect_outbreaks(days_baseline: int = 14) -> dict:
    load_outbreak_model()

    sym_df = fetch_symptom_logs(50000)
    if sym_df.empty:
        return {"status": "insufficient_data"}

    sym_df['created_at'] = pd.to_datetime(sym_df['created_at'])
    if sym_df['created_at'].dt.tz is None:
        sym_df['created_at'] = sym_df['created_at'].dt.tz_localize('UTC')
    else:
        sym_df['created_at'] = sym_df['created_at'].dt.tz_convert('UTC')

    pharm_df = fetch_pharmacy_sales(50000)
    if pharm_df.empty:
        pharm_df = generate_synthetic_pharmacy_sales(sym_df)
    else:
        pharm_df['created_at'] = pd.to_datetime(pharm_df['created_at'])
        if pharm_df['created_at'].dt.tz is None:
            pharm_df['created_at'] = pharm_df['created_at'].dt.tz_localize('UTC')
        else:
            pharm_df['created_at'] = pharm_df['created_at'].dt.tz_convert('UTC')
        pharm_df['occurrence_count'] = 1
        pharm_df['district'] = 'Global'
        pharm_df['is_synthetic'] = False

    if not sym_df.empty:
        latest_date = sym_df['created_at'].max()
        # Use the latest date in the db, or current time if the db has future dates
        now = latest_date
    else:
        now = datetime.now(timezone.utc)
        
    recent_cutoff = now - timedelta(days=3)
    baseline_cutoff = recent_cutoff - timedelta(days=days_baseline)
    long_baseline_cutoff = recent_cutoff - timedelta(days=7)

    def calculate_anomalies(df, group_col):
        if df.empty: return pd.DataFrame()

        recent_df = df[df['created_at'] >= recent_cutoff]
        baseline_df = df[(df['created_at'] >= baseline_cutoff) & (df['created_at'] < recent_cutoff)]
        long_baseline_df = df[(df['created_at'] >= long_baseline_cutoff) & (df['created_at'] < recent_cutoff)]

        if recent_df.empty: return pd.DataFrame()

        agg_dict = {'occurrence_count': 'sum'}
        if 'latitude' in recent_df.columns and 'longitude' in recent_df.columns:
            agg_dict['latitude'] = 'mean'
            agg_dict['longitude'] = 'mean'
            
        recent_agg = recent_df.groupby(['district', group_col]).agg(agg_dict).reset_index()
        recent_agg['recent_daily_avg'] = recent_agg['occurrence_count'] / 3.0

        if not baseline_df.empty:
            base_agg = baseline_df.groupby(['district', group_col])['occurrence_count'].sum().reset_index()
            base_agg['baseline_daily_avg'] = base_agg['occurrence_count'] / days_baseline
            merged = pd.merge(recent_agg, base_agg[['district', group_col, 'baseline_daily_avg']], on=['district', group_col], how='left')
        else:
            merged = recent_agg
            merged['baseline_daily_avg'] = 0.1

        merged['baseline_daily_avg'] = merged['baseline_daily_avg'].fillna(0.1)

        if not long_baseline_df.empty:
            long_base_agg = long_baseline_df.groupby(['district', group_col])['occurrence_count'].sum().reset_index()
            long_base_agg['long_baseline_avg'] = long_base_agg['occurrence_count'] / 7.0
            merged = pd.merge(merged, long_base_agg[['district', group_col, 'long_baseline_avg']], on=['district', group_col], how='left')
        else:
            merged['long_baseline_avg'] = 0.1

        merged['long_baseline_avg'] = merged['long_baseline_avg'].fillna(0.1)
        merged['spike_velocity'] = (merged['recent_daily_avg'] + 0.1) / (merged['long_baseline_avg'] + 0.1)

        return merged

    sym_anomalies = calculate_anomalies(sym_df, 'symptom_type')
    pharm_anomalies = calculate_anomalies(pharm_df, 'medicine_name')

    outbreaks = []

    if not sym_anomalies.empty:
        for _, row in sym_anomalies.iterrows():
            recent_avg = row['recent_daily_avg']
            base_avg = row['baseline_daily_avg']

            if recent_avg >= 2.0:
                spike_percentage = ((recent_avg - base_avg) / base_avg) * 100

                is_cross = 0
                pharm_spike_vel = 1.0
                if not pharm_anomalies.empty:
                    match = pharm_anomalies[pharm_anomalies['district'] == row['district']]
                    if not match.empty:
                        is_cross = 1
                        pharm_spike_vel = match['spike_velocity'].max()

                confidence = 0.0
                if OUTBREAK_MODEL:
                    X = np.array([[
                        row['spike_velocity'],
                        pharm_spike_vel,
                        is_cross,
                        5.0,
                        0.8
                    ]])
                    confidence = float(OUTBREAK_MODEL.predict_proba(X)[0][1])
                    is_ml_epidemic = confidence > 0.5
                else:
                    is_ml_epidemic = spike_percentage > 500

                if 'latitude' in row and 'longitude' in row and pd.notna(row['latitude']) and pd.notna(row['longitude']):
                    coords = {"lat": float(row['latitude']), "lng": float(row['longitude'])}
                else:
                    coords = DISTRICT_COORDS.get(row['district'], {"lat": 28.5, "lng": 77.0})

                if spike_percentage > 200:
                    outbreaks.append({
                        "district": row['district'],
                        "location": coords,
                        "type": "Symptom Outbreak" if is_ml_epidemic else "High Symptom Alert",
                        "indicator": row['symptom_type'],
                        "recent_daily_avg": round(recent_avg, 1),
                        "baseline_daily_avg": round(base_avg, 1),
                        "spike_percentage": round(spike_percentage, 1),
                        "ml_confidence": round(confidence, 2),
                        "severity": "CRITICAL" if is_ml_epidemic or spike_percentage > 500 else "WARNING"
                    })

    outbreaks.sort(key=lambda x: x["spike_percentage"], reverse=True)

    return {
        "status": "success",
        "analyzed_districts": int(sym_df['district'].nunique()) if not sym_df.empty else 0,
        "total_anomalies_detected": len(outbreaks),
        "outbreaks": outbreaks
    }
