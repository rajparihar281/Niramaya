import numpy as np

def is_peak_hour(hour: int) -> int:
    return 1 if (9 <= hour <= 11) or (17 <= hour <= 19) else 0

def calculate_priority(
    symptoms: list = None,
    pain_level: int = 0,
    age: int = 30,
    temperature: float = 98.6,
    heart_rate: int = 75,
    systolic_bp: int = 120,
    is_emergency: bool = False,
    waiting_since_minutes: int = 0,
    current_queue_length: int = 0,
) -> dict:
    starvation_escalated = False
    override_to_front = False

    if is_emergency:
        score = 10.0
        override_to_front = True
    else:
        score = 0.0
        symptoms = symptoms or []

        score += min(pain_level, 10) * 0.3

        if age < 5 or age > 70:
            score += 1.5
        elif age < 12 or age > 60:
            score += 0.8

        if temperature > 103: score += 2.0
        elif temperature > 101: score += 1.0

        if heart_rate > 120 or heart_rate < 50: score += 1.5
        elif heart_rate > 100 or heart_rate < 60: score += 0.7

        if systolic_bp > 180: score += 1.5
        elif systolic_bp > 160: score += 1.0

        critical_symptoms = {"chest pain", "breathing difficulty", "severe bleeding", "stroke symptoms", "seizure"}
        urgent_symptoms = {"high fever", "persistent vomiting", "severe headache", "abdominal pain", "fracture", "burn"}
        instant_critical_keywords = ["bleeding", "trauma", "unconscious", "stroke", "poisoning", "infarct", "arrest", "gunshot"]

        for s in symptoms:
            s_lower = s.lower()
            if any(keyword in s_lower for keyword in instant_critical_keywords):
                score += 5.0
            elif s_lower in critical_symptoms:
                score += 2.0
            elif s_lower in urgent_symptoms:
                score += 1.0

        score = round(min(score, 10.0), 1)

        if waiting_since_minutes >= 180:
            if score < 5.0:
                score = 5.0
                starvation_escalated = True
        elif waiting_since_minutes >= 90:
            score = round(min(score + 1.5, 10.0), 1)
            starvation_escalated = True

    if score >= 8.0 and current_queue_length >= 10:
        override_to_front = True

    return {
        "score": round(min(score, 10.0), 1),
        "starvation_escalated": starvation_escalated,
        "override_to_front": override_to_front,
    }

def build_macro_features(
    hour_of_day: int,
    day_of_week: int,
    department_queue_length: int = 0,
    patients_ahead_in_department: int = 0,
    avg_wait_last_hour: float = 15.0,
    department_bed_utilization: float = 0.5,
) -> dict:
    return {
        "hour_of_day": hour_of_day % 24,
        "day_of_week": day_of_week % 7,
        "is_peak_hour": is_peak_hour(hour_of_day),
        "department_queue_length": max(department_queue_length, 0),
        "patients_ahead_in_department": max(patients_ahead_in_department, 0),
        "avg_wait_last_hour": round(max(avg_wait_last_hour, 0), 1),
        "department_bed_utilization": round(min(max(department_bed_utilization, 0), 1), 2),
    }

FEATURE_NAMES = [
    "hour_of_day",
    "day_of_week",
    "is_peak_hour",
    "department_queue_length",
    "patients_ahead_in_department",
    "avg_wait_last_hour",
    "department_bed_utilization",
]

def features_to_array(features: dict) -> np.ndarray:
    return np.array([[features[name] for name in FEATURE_NAMES]])
