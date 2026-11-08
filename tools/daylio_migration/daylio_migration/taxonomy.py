"""Mappings from Daylio's moods and activity tags to DailyRhythm categories.

Daylio mixes food sources, activities and symptoms in one tag list. Each
tag maps to exactly one category and a canonical name; canonical names
match DailyRhythm's existing tags where one exists.
"""

MOODS = {"awful": 1, "bad": 2, "meh": 3, "good": 4, "rad": 5}

FOOD_SOURCE = "food_source"
ACTIVITY = "activity"
SYMPTOM = "symptom"

# daylio tag -> (category, canonical name)
ACTIVITIES: dict[str, tuple[str, str]] = {
    # Where the day's food came from
    "takeout": (FOOD_SOURCE, "Takeout"),
    "fast food": (FOOD_SOURCE, "Fast Food"),
    "homemade": (FOOD_SOURCE, "Homemade"),
    "free food": (FOOD_SOURCE, "Free Food"),
    "restaurant": (FOOD_SOURCE, "Restaurant"),
    "food court": (FOOD_SOURCE, "Food Court"),
    "delivery": (FOOD_SOURCE, "Delivery"),
    # Things done
    "exercise": (ACTIVITY, "Exercise"),
    "intense exercise": (ACTIVITY, "Intense Exercise"),
    "gaming": (ACTIVITY, "Video Games"),
    "watching videos": (ACTIVITY, "Watch Videos"),
    "studying": (ACTIVITY, "Study"),
    "work": (ACTIVITY, "Work"),
    "class": (ACTIVITY, "Class"),
    "test": (ACTIVITY, "Test"),
    "nap": (ACTIVITY, "Nap"),
    "social event": (ACTIVITY, "Social Event"),
    "family": (ACTIVITY, "Family Time"),
    "family issues": (ACTIVITY, "Family Issues"),
    "draw": (ACTIVITY, "Draw"),
    "haircut": (ACTIVITY, "Haircut"),
    "change bedsheet": (ACTIVITY, "Change Bedsheets"),
    "dentist": (ACTIVITY, "Dentist"),
    "cab": (ACTIVITY, "Cab"),
    "woke up early": (ACTIVITY, "Woke Up Early"),
    "sleep early": (ACTIVITY, "Slept Early"),
    # Symptoms
    "anxiety": (SYMPTOM, "Anxiety"),
    "stomachache": (SYMPTOM, "Stomach Ache"),
    "muscle ache": (SYMPTOM, "Muscle Ache"),
    "backpain": (SYMPTOM, "Back Pain"),
    "coughing": (SYMPTOM, "Cough"),
    "headache": (SYMPTOM, "Headache"),
    "migraine": (SYMPTOM, "Migraine"),
    "rashes": (SYMPTOM, "Rash"),
    "fever": (SYMPTOM, "Fever"),
    "runny nose": (SYMPTOM, "Runny Nose"),
    "drowzee": (SYMPTOM, "Drowsiness"),
    "diarrhea": (SYMPTOM, "Diarrhea"),
    "nauseous": (SYMPTOM, "Nausea"),
    "sore throat": (SYMPTOM, "Sore Throat"),
    "congested": (SYMPTOM, "Congestion"),
    "gastric": (SYMPTOM, "Gastric Pain"),
    "toothache": (SYMPTOM, "Toothache"),
    "neck pain": (SYMPTOM, "Neck Pain"),
    "constipated": (SYMPTOM, "Constipation"),
}


def categorize(tag: str) -> tuple[str, str] | None:
    """Returns (category, canonical name), or None for an unknown tag."""
    return ACTIVITIES.get(tag.strip().lower())
