"""
Engine 4: Outbreak Classifier Training Pipeline
Trains an XGBoost model to distinguish between 'Normal Spikes' and 'Critical Epidemics'.
"""

import os
import sys
import pickle
import json
import numpy as np
import pandas as pd
from datetime import datetime
from xgboost import XGBClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, accuracy_score


EPIDEMIC_FEATURE_NAMES = [
    "symptom_spike_velocity",   
    "pharmacy_spike_velocity",  
    "is_cross_correlated",      
    "severity_index",           
    "transmission_potential"    
]

def generate_synthetic_outbreak_data(n_samples: int = 1000):
    """Generate realistic training data for outbreak classification."""
    rng = np.random.RandomState(42)
    records = []
    
    for _ in range(n_samples):
        
        is_epidemic = rng.choice([0, 1], p=[0.8, 0.2])
        
        if is_epidemic:
            sym_vel = rng.uniform(3.0, 10.0) 
            pharm_vel = rng.uniform(2.5, 8.0) 
            correlated = 1
            severity = rng.uniform(6.0, 10.0)
            potential = rng.uniform(0.7, 1.0)
        else:
            sym_vel = rng.uniform(0.5, 2.5) 
            pharm_vel = rng.uniform(0.5, 2.0)
            correlated = rng.choice([0, 1], p=[0.9, 0.1])
            severity = rng.uniform(1.0, 5.0)
            potential = rng.uniform(0.1, 0.6)
            
        records.append({
            "symptom_spike_velocity": sym_vel,
            "pharmacy_spike_velocity": pharm_vel,
            "is_cross_correlated": correlated,
            "severity_index": severity,
            "transmission_potential": potential,
            "label": is_epidemic
        })
        
    return pd.DataFrame(records)

def train_outbreak_model():
    """Train the XGBoost classifier and export to Pickle & ONNX."""
    df = generate_synthetic_outbreak_data(2000)
    X = df[EPIDEMIC_FEATURE_NAMES]
    y = df["label"]
    
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    model = XGBClassifier(
        n_estimators=100,
        max_depth=4,
        learning_rate=0.1,
        use_label_encoder=False,
        eval_metric='l  ogloss'
    )
    
    model.fit(X_train, y_train)
    
    y_pred = model.predict(X_test)
    acc = accuracy_score(y_test, y_pred)
    
    print(f"Epidemic Classifier Training Complete.")
    print(f"Accuracy: {acc:.4f}")
    print(classification_report(y_test, y_pred))
    
    
    base_dir = os.path.dirname(os.path.abspath(__file__))
    models_dir = os.path.join(base_dir, "models")
    os.makedirs(models_dir, exist_ok=True)
    
    model_path = os.path.join(models_dir, "outbreak_classifier_v1.pkl")
    with open(model_path, "wb") as f:
        pickle.dump(model, f)
        
    
    try:
        import onnx
        from onnxmltools.convert import convert_xgboost
        from skl2onnx.common.data_types import FloatTensorType
        
        initial_type = [('float_input', FloatTensorType([None, len(EPIDEMIC_FEATURE_NAMES)]))]
        onnx_model = convert_xgboost(model, initial_types=initial_type, target_opset=12)
        onnx.save(onnx_model, os.path.join(models_dir, "outbreak_classifier_v1.onnx"))
        print("[OK] ONNX Export Success.")
    except Exception as e:
        print(f"[!] ONNX Export Failed: {e}")
        
    
    meta = {
        "version": "outbreak_v1",
        "trained_at": datetime.now().isoformat(),
        "features": EPIDEMIC_FEATURE_NAMES,
        "accuracy": float(acc)
    }
    with open(os.path.join(models_dir, "outbreak_metadata.json"), "w") as f:
        json.dump(meta, f, indent=2)

if __name__ == "__main__":
    train_outbreak_model()
