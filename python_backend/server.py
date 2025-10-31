from flask import Flask, request, jsonify
from flask_cors import CORS
import tensorflow as tf
import numpy as np
from PIL import Image
import io
import base64
import os
from datetime import datetime
import requests
import json

app = Flask(__name__)
CORS(app)

OPENAI_API_KEY = os.environ.get('OPENAI_API_KEY', '')
MODEL_PATH = 'models/food101_model.keras'
FOOD_CLASSES_PATH = 'models/food101_classes.txt'

model = None
food_classes = []

def load_model():
    global model, food_classes

    try:
        if os.path.exists(MODEL_PATH):
            print(f"Loading model from {MODEL_PATH}...")
            print(f"TensorFlow version: {tf.__version__}")
            print(f"Keras version: {tf.keras.__version__}")
            model = tf.keras.models.load_model(MODEL_PATH)
            print("Model loaded successfully!")
            print(f"Model input shape: {model.input_shape}")
            print(f"Model output shape: {model.output_shape}")
        else:
            print(f"Warning: Model not found at {MODEL_PATH}")
            print("Server will run in fallback mode")
    except Exception as e:
        print(f"Error loading model: {e}")
        import traceback
        traceback.print_exc()
        print("Server will run in fallback mode")

    try:
        if os.path.exists(FOOD_CLASSES_PATH):
            with open(FOOD_CLASSES_PATH, 'r') as f:
                food_classes = [line.strip() for line in f.readlines()]
            print(f"Loaded {len(food_classes)} food classes")
        else:
            print(f"Warning: Food classes not found at {FOOD_CLASSES_PATH}")
            food_classes = ['apple_pie', 'pizza', 'hamburger', 'ice_cream', 'salad']
    except Exception as e:
        print(f"Error loading food classes: {e}")
        food_classes = ['unknown']

load_model()

@app.route('/', methods=['GET'])
def root():
    return jsonify({
        'name': 'BrightBite API',
        'version': '1.0.0',
        'description': 'Food analysis API for BrightBite iOS app',
        'endpoints': {
            'health': '/api/health',
            'analyze': '/api/analyze-food'
        },
        'website': 'https://brightbite.tuandnguyen.dev',
        'documentation': 'https://brightbite.tuandnguyen.dev/docs'
    })

@app.route('/api', methods=['GET'])
def api_root():
    return jsonify({
        'status': 'ok',
        'endpoints': {
            'health': '/api/health',
            'analyze': '/api/analyze-food'
        }
    })

@app.route('/api/health', methods=['GET'])
def health_check():
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'model_loaded': model is not None,
        'openai_configured': bool(OPENAI_API_KEY)
    })

@app.route('/api/analyze-food', methods=['POST'])
def analyze_food():
    try:
        data = request.get_json()

        if not data or 'imageBase64' not in data:
            return jsonify({'error': 'Missing image data'}), 400

        image_base64 = data['imageBase64']
        image_data = base64.b64decode(image_base64)
        image = Image.open(io.BytesIO(image_data))

        user_context = data.get('userContext', {})
        has_braces = user_context.get('hasBraces', False)
        diet_restrictions = user_context.get('dietRestrictions', [])
        recent_procedures = user_context.get('recentProcedures', [])

        food_name, confidence, source = analyze_with_tensorflow(image)

        if confidence < 0.7 and OPENAI_API_KEY:
            print(f"Low confidence ({confidence:.2f}), trying ChatGPT Vision...")
            try:
                chatgpt_result = analyze_with_chatgpt(image_base64, user_context)
                if chatgpt_result:
                    food_name = chatgpt_result['foodName']
                    confidence = chatgpt_result['confidence']
                    source = 'chatgpt'
            except Exception as e:
                print(f"ChatGPT fallback failed: {e}")

        verdict, tags, reasons, alternatives = determine_verdict(
            food_name,
            has_braces=has_braces,
            restrictions=diet_restrictions,
            procedures=recent_procedures
        )

        response = {
            'foodName': food_name,
            'confidence': confidence,
            'verdict': verdict,
            'tags': tags,
            'reasons': reasons,
            'alternatives': alternatives,
            'source': source
        }

        print(f"Analysis complete: {food_name} ({confidence:.2f}) -> {verdict}")
        return jsonify(response)

    except Exception as e:
        print(f"Error analyzing food: {e}")
        return jsonify({'error': str(e)}), 500

def analyze_with_tensorflow(image):
    if model is None:
        print("Model not loaded, using mock data")
        return "Unknown Food", 0.5, "mock"

    try:
        img = image.convert('RGB')
        img = img.resize((224, 224))
        img_array = np.array(img) / 255.0
        img_array = np.expand_dims(img_array, axis=0)

        predictions = model.predict(img_array, verbose=0)
        top_index = np.argmax(predictions[0])
        confidence = float(predictions[0][top_index])

        if top_index < len(food_classes):
            food_name = food_classes[top_index].replace('_', ' ').title()
        else:
            food_name = "Unknown Food"

        return food_name, confidence, "tensorflow"

    except Exception as e:
        print(f"TensorFlow analysis error: {e}")
        return "Unknown Food", 0.5, "mock"

def analyze_with_chatgpt(image_base64, user_context):
    if not OPENAI_API_KEY:
        return None

    try:
        prompt = "Identify this food item. Respond with just the food name."

        if user_context.get('hasBraces'):
            prompt += " Note: This is for someone with braces."

        url = "https://api.openai.com/v1/chat/completions"
        headers = {
            "Authorization": f"Bearer {OPENAI_API_KEY}",
            "Content-Type": "application/json"
        }

        payload = {
            "model": "gpt-4o",
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": prompt},
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:image/jpeg;base64,{image_base64}"
                            }
                        }
                    ]
                }
            ],
            "max_tokens": 50
        }

        response = requests.post(url, headers=headers, json=payload, timeout=15)

        if response.status_code == 200:
            result = response.json()
            food_name = result['choices'][0]['message']['content'].strip()
            return {
                'foodName': food_name,
                'confidence': 0.85
            }
        else:
            print(f"ChatGPT API error: {response.status_code}")
            return None

    except Exception as e:
        print(f"ChatGPT Vision error: {e}")
        return None

def determine_verdict(food_name, has_braces=False, restrictions=[], procedures=[]):
    food_lower = food_name.lower()
    tags = []
    reasons = []
    alternatives = []

    is_hard = any(word in food_lower for word in ['nuts', 'candy', 'popcorn', 'chips', 'cracker', 'carrot', 'apple'])
    is_sticky = any(word in food_lower for word in ['caramel', 'taffy', 'gum', 'gummy', 'toffee'])
    is_chewy = any(word in food_lower for word in ['bagel', 'jerky', 'steak', 'tough'])
    is_hot = any(word in food_lower for word in ['soup', 'coffee', 'tea'])
    is_cold = any(word in food_lower for word in ['ice cream', 'popsicle', 'frozen'])
    is_sugary = any(word in food_lower for word in ['candy', 'cake', 'cookie', 'soda', 'chocolate'])
    is_acidic = any(word in food_lower for word in ['orange', 'lemon', 'lime', 'tomato', 'soda'])
    is_soft = any(word in food_lower for word in ['banana', 'yogurt', 'oatmeal', 'smoothie', 'mashed'])

    if is_hard: tags.append('hard')
    if is_sticky: tags.append('sticky')
    if is_chewy: tags.append('chewy')
    if is_hot: tags.append('hot')
    if is_cold: tags.append('cold')
    if is_sugary: tags.append('sugary')
    if is_acidic: tags.append('acidic')
    if is_soft: tags.append('soft')

    verdict = 'safe'

    if has_braces:
        if is_hard:
            verdict = 'avoid'
            reasons.append('Too hard for braces - may damage brackets')
            alternatives.append('Try softer alternatives like cooked vegetables')
        elif is_sticky:
            verdict = 'avoid'
            reasons.append('Sticky foods can damage braces')
            alternatives.append('Choose non-sticky options')

    if 'softOnly' in restrictions:
        if not is_soft and (is_hard or is_chewy):
            verdict = 'avoid'
            reasons.append('Not soft enough for current diet restrictions')
            alternatives.append('Stick to soft foods like yogurt, smoothies, or mashed foods')

    if 'noSticky' in restrictions and is_sticky:
        verdict = 'caution' if verdict == 'safe' else verdict
        reasons.append('Sticky foods should be avoided')

    if 'noHot' in restrictions and is_hot:
        verdict = 'later'
        reasons.append('Wait for food to cool down')

    if 'noCold' in restrictions and is_cold:
        verdict = 'later'
        reasons.append('Avoid cold foods for now due to sensitivity')

    if 'extraction' in procedures:
        if is_hot or is_hard or is_chewy:
            verdict = 'avoid'
            reasons.append('Not recommended after tooth extraction')
            alternatives.append('Stick to cool, soft foods')

    if verdict == 'safe' and not reasons:
        if is_soft:
            reasons.append('This is a great choice! Soft and safe.')
        else:
            reasons.append('This food looks safe for you to eat.')

    if not alternatives and verdict != 'safe':
        alternatives = ['Yogurt', 'Smoothie', 'Mashed potatoes', 'Scrambled eggs']

    return verdict, tags, reasons, alternatives

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    print(f"Starting BrightBite API server on port {port}...")
    print(f"Model loaded: {model is not None}")
    print(f"OpenAI configured: {bool(OPENAI_API_KEY)}")
    app.run(host='0.0.0.0', port=port, debug=True)
