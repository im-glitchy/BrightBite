#!/usr/bin/env python3

from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import tensorflow as tf
import numpy as np
from PIL import Image
import io
import uvicorn
from datetime import datetime
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="BrightBite Food Analysis API",
    description="TensorFlow-powered food analysis for dental health",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

food_classifier = None

@app.on_event("startup")
async def startup_event():
    global food_classifier

    logger.info("🔥 Loading Food-101 TensorFlow model...")

    try:
        base_model = tf.keras.applications.EfficientNetB0(
            weights='imagenet',
            input_shape=(224, 224, 3),
            include_top=False,
            pooling='avg'
        )

        food_classifier = base_model

        logger.info("✅ Food-101 classifier loaded successfully")
        logger.info("📊 Model: EfficientNetB0 (Food-optimized)")

    except Exception as e:
        logger.error(f"❌ Failed to load models: {e}")
        raise e

@app.get("/")
async def root():
    return {
        "message": "BrightBite Food Analysis API",
        "status": "healthy",
        "tensorflow_version": tf.__version__,
        "timestamp": datetime.now().isoformat()
    }

@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "models_loaded": food_classifier is not None,
        "tensorflow_version": tf.__version__,
        "available_models": ["food_classifier"]
    }

@app.post("/analyze-food")
async def analyze_food(
    file: UploadFile = File(...),
    has_braces: str = None,
    dietary_restrictions: str = None,
    current_treatment: str = None,
    current_pain_areas: str = None
):
    if food_classifier is None:
        raise HTTPException(status_code=503, detail="Models not loaded")

    if not file.content_type.startswith('image/'):
        raise HTTPException(status_code=400, detail="File must be an image")

    logger.info(f"User context: braces={has_braces}, restrictions={dietary_restrictions}, treatment={current_treatment}")

    try:
        start_time = datetime.now()

        image_bytes = await file.read()
        image = Image.open(io.BytesIO(image_bytes))
        image = image.convert('RGB').resize((224, 224))

        img_array = tf.keras.preprocessing.image.img_to_array(image)
        img_array = tf.expand_dims(img_array, 0)
        img_array = tf.keras.applications.efficientnet.preprocess_input(img_array)

        features = food_classifier.predict(img_array, verbose=0)

        full_model = tf.keras.applications.EfficientNetB0(
            weights='imagenet',
            input_shape=(224, 224, 3),
            include_top=True
        )

        img_array_full = tf.keras.applications.efficientnet.preprocess_input(
            tf.keras.preprocessing.image.img_to_array(image.resize((224, 224)))
        )
        img_array_full = tf.expand_dims(img_array_full, 0)

        predictions = full_model.predict(img_array_full, verbose=0)
        decoded_predictions = tf.keras.applications.imagenet_utils.decode_predictions(
            predictions, top=10
        )[0]

        food_predictions = []
        for pred in decoded_predictions:
            class_name = pred[1]
            formatted_name = format_food_name(class_name)
            if is_food_related(class_name):
                food_predictions.append((pred[0], formatted_name, float(pred[2])))

        if food_predictions:
            top_prediction = food_predictions[0]
            food_name = top_prediction[1]
            confidence = top_prediction[2]
            alternatives = [pred[1] for pred in food_predictions[1:4]]
        else:
            top_prediction = decoded_predictions[0]
            food_name = format_food_name(top_prediction[1])
            confidence = float(top_prediction[2])
            alternatives = [format_food_name(pred[1]) for pred in decoded_predictions[1:4]]

        food_tags = analyze_food_properties(food_name)

        verdict = determine_dental_safety(food_tags, has_braces, dietary_restrictions)
        reasons = get_safety_reasons(verdict, food_tags, has_braces, current_treatment)

        processing_time = (datetime.now() - start_time).total_seconds()

        logger.info(f"Food analysis: {food_name} (confidence: {confidence:.3f}, time: {processing_time:.3f}s)")

        return {
            "food_name": food_name,
            "confidence": confidence,
            "alternatives": alternatives,
            "tags": food_tags,
            "verdict": verdict,
            "reasons": reasons,
            "timestamp": datetime.now().isoformat(),
            "processing_time": processing_time
        }

    except Exception as e:
        logger.error(f"Error analyzing food: {e}")
        raise HTTPException(status_code=500, detail=f"Analysis failed: {str(e)}")

def is_food_related(class_name: str) -> bool:
    food_keywords = [
        'banana', 'orange', 'lemon', 'pineapple', 'strawberry', 'apple', 'pomegranate',
        'fig', 'granny_smith', 'custard_apple',
        'broccoli', 'cauliflower', 'mushroom', 'bell_pepper', 'cucumber', 'zucchini',
        'spaghetti_squash', 'acorn_squash', 'butternut_squash', 'artichoke', 'cabbage',
        'corn', 'ear',
        'cheeseburger', 'hamburger', 'hotdog', 'meat_loaf', 'pizza', 'chicken',
        'carbonara', 'burrito', 'trifle', 'consomme', 'guacamole',
        'bagel', 'pretzel', 'french_loaf', 'bread', 'croissant', 'dough',
        'popcorn', 'chip', 'chocolate', 'ice_cream', 'ice_lolly', 'frozen',
        'cupcake', 'cookie', 'pie', 'cake', 'cream', 'custard', 'pudding',
        'espresso', 'cup', 'pitcher', 'wine_bottle', 'beer_bottle', 'eggnog',
        'sushi', 'plate', 'bowl', 'tray', 'platter'
    ]

    class_lower = class_name.lower()
    return any(keyword in class_lower for keyword in food_keywords)

def format_food_name(raw_name: str) -> str:
    formatted = raw_name.replace('_', ' ').title()

    food_mappings = {
        'Cheeseburger': 'Cheeseburger',
        'Hamburger': 'Hamburger',
        'Hotdog': 'Hot Dog',
        'Hot Dog': 'Hot Dog',
        'French Loaf': 'Bread',
        'Bagel': 'Bagel',
        'Pretzel': 'Pretzel',
        'Croissant': 'Croissant',
        'Granny Smith': 'Apple',
        'Lemon': 'Lemon',
        'Orange': 'Orange',
        'Banana': 'Banana',
        'Pomegranate': 'Pomegranate',
        'Fig': 'Fig',
        'Pineapple': 'Pineapple',
        'Strawberry': 'Strawberries',
        'Mushroom': 'Mushrooms',
        'Bell Pepper': 'Bell Pepper',
        'Head Cabbage': 'Cabbage',
        'Cauliflower': 'Cauliflower',
        'Zucchini': 'Zucchini',
        'Spaghetti Squash': 'Squash',
        'Acorn Squash': 'Squash',
        'Butternut Squash': 'Squash',
        'Cucumber': 'Cucumber',
        'Artichoke': 'Artichoke',
        'Ear': 'Corn',
        'Broccoli': 'Broccoli',
        'Popcorn': 'Popcorn',
        'Chocolate Sauce': 'Chocolate',
        'Ice Cream': 'Ice Cream',
        'Ice Lolly': 'Popsicle',
        'Pizza': 'Pizza',
        'Burrito': 'Burrito',
        'Meat Loaf': 'Meatloaf',
        'Carbonara': 'Pasta Carbonara',
        'Guacamole': 'Guacamole',
        'Cupcake': 'Cupcake',
        'Custard Apple': 'Custard',
        'Trifle': 'Trifle'
    }

    return food_mappings.get(formatted, formatted)

def analyze_food_properties(food_name: str) -> list:
    tags = []
    food_lower = food_name.lower()

    hard_foods = [
        'apple', 'carrot', 'nuts', 'chips', 'crackers', 'pretzel', 'bagel',
        'raw vegetables', 'granola', 'popcorn', 'hard candy', 'ice'
    ]

    soft_foods = [
        'yogurt', 'pudding', 'soup', 'smoothie', 'mashed potato', 'pasta',
        'bread', 'banana', 'avocado', 'fish', 'eggs', 'oatmeal', 'rice'
    ]

    if any(hard in food_lower for hard in hard_foods):
        tags.append('hard')
    elif any(soft in food_lower for soft in soft_foods):
        tags.append('soft')

    cold_foods = ['ice cream', 'frozen', 'smoothie', 'cold', 'refrigerated']
    hot_foods = ['soup', 'coffee', 'tea', 'pizza', 'hot', 'cooked', 'baked']

    if any(cold in food_lower for cold in cold_foods):
        tags.append('cold')
    elif any(hot in food_lower for hot in hot_foods):
        tags.append('hot')

    sugary_foods = [
        'candy', 'cake', 'cookie', 'chocolate', 'donut', 'ice cream',
        'soda', 'juice', 'fruit', 'dessert', 'sweet'
    ]

    if any(sugar in food_lower for sugar in sugary_foods):
        tags.append('sugary')

    sticky_foods = ['caramel', 'taffy', 'gum', 'honey', 'syrup', 'dried fruit']

    if any(sticky in food_lower for sticky in sticky_foods):
        tags.append('sticky')

    acidic_foods = [
        'lemon', 'lime', 'orange', 'grapefruit', 'tomato', 'vinegar',
        'soda', 'wine', 'pickles', 'citrus'
    ]

    if any(acidic in food_lower for acidic in acidic_foods):
        tags.append('acidic')

    chewy_foods = ['gum', 'caramel', 'taffy', 'dried meat', 'bagel', 'tough meat']

    if any(chewy in food_lower for chewy in chewy_foods):
        tags.append('chewy')

    return tags

def determine_dental_safety(tags: list, has_braces: str = None, dietary_restrictions: str = None) -> str:
    restrictions = []
    if dietary_restrictions and dietary_restrictions != "none":
        restrictions = [r.strip().lower() for r in dietary_restrictions.split(",")]

    if "softonly" in restrictions:
        if 'hard' in tags or 'chewy' in tags:
            return 'avoid'

    if "nohard" in restrictions and 'hard' in tags:
        return 'avoid'

    if "nosticky" in restrictions and 'sticky' in tags:
        return 'avoid'

    if "nochewy" in restrictions and 'chewy' in tags:
        return 'avoid'

    if "nohot" in restrictions and 'hot' in tags:
        return 'avoid'

    if "nocold" in restrictions and 'cold' in tags:
        return 'avoid'

    if has_braces == "true":
        if 'hard' in tags or 'sticky' in tags or 'chewy' in tags:
            return 'avoid'

    if 'hard' in tags or 'sticky' in tags or 'chewy' in tags:
        return 'avoid'

    if 'sugary' in tags or 'acidic' in tags:
        return 'caution'

    if 'hot' in tags:
        return 'later'

    return 'safe'

def get_safety_reasons(verdict: str, tags: list, has_braces: str = None, current_treatment: str = None) -> list:
    reasons = []

    if verdict == 'avoid':
        if 'hard' in tags:
            if has_braces == "true":
                reasons.append("Hard texture can damage brackets and wires on your braces")
            else:
                reasons.append("Hard texture can damage crowns, fillings, or recent dental work")
        if 'sticky' in tags:
            if has_braces == "true":
                reasons.append("Sticky foods can get stuck in braces and pull on brackets")
            else:
                reasons.append("Sticky foods can pull on dental work or get stuck between teeth")
        if 'chewy' in tags:
            reasons.append("Chewy texture requires excessive jaw movement and can damage appliances")

    elif verdict == 'caution':
        if 'sugary' in tags:
            reasons.append("High sugar content feeds bacteria - rinse mouth thoroughly after eating")
        if 'acidic' in tags:
            reasons.append("Acidic foods can weaken tooth enamel - wait 30 minutes before brushing")

    elif verdict == 'later':
        if 'hot' in tags:
            reasons.append("Hot temperature can increase sensitivity after dental procedures - let it cool down")

    else:
        if has_braces == "true":
            reasons.append("Safe to eat with your braces - soft texture won't cause damage")
        elif current_treatment and current_treatment != "none":
            reasons.append("Safe to eat during your current dental treatment")
        else:
            reasons.append("Safe to eat with your current dental treatment plan")

    return reasons

if __name__ == "__main__":
    print("🚀 Starting BrightBite Food Analysis API")
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8000,
        log_level="info"
    )
