# BrightBite 🦷

A comprehensive iOS dental care app built with SwiftUI, featuring AI-powered food scanning, pain tracking, and treatment plan management.

## Features

### 🔍 ChewCheck - AI Food Scanner
- Scan food with your camera to check if it's safe for your braces
- Powered by TensorFlow Lite (Food-101 model) and OpenAI Vision
- Get instant feedback: Safe, Caution, Avoid, or Wait
- Smart detection for unidentified items

### 🗺️ 3D Pain Map
- Interactive 3D tooth visualization using RealityKit
- Tap individual teeth to log pain levels
- Track pain history over time with timeline slider
- Visual indicators for tooth conditions and procedures

### 📋 Treatment Plan Management
- Track diet restrictions and medications
- Scan dental notes with OCR
- Manage appointments with calendar integration
- Medical history tracking

### 🏠 Dashboard
- Dental summary with real-time stats
- Recent activity feed
- Quick actions for common tasks
- Treatment plan overview

### 💬 DentalBot Assistant
- AI-powered dental care advice
- Context-aware responses based on your treatment plan
- Food verdict explanations

## Tech Stack

- **Frontend**: SwiftUI, RealityKit
- **Backend**: Python (Flask), Firebase
- **AI/ML**:
  - TensorFlow Lite (Food-101)
  - OpenAI GPT-4o Vision
  - Vision Framework (OCR)
- **Database**: Firebase Firestore
- **Storage**: Firebase Storage
- **Authentication**: Firebase Auth

## Prerequisites

- Xcode 15.0+
- iOS 17.0+
- Python 3.9+
- Firebase account
- OpenAI API key

## Setup

### 1. Clone the Repository

```bash
git clone https://github.com/im-glitchy/BrightBite.git
cd BrightBite
```

### 2. Firebase Configuration

1. Create a new Firebase project at [Firebase Console](https://console.firebase.google.com)
2. Download `GoogleService-Info.plist` from Firebase
3. Place it in the `BrightBite/` directory (this file is git-ignored for security)

### 3. Python Backend Setup

```bash
cd python_backend

# Create virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Setup environment variables
cp .env.example .env
# Edit .env and add your OPENAI_API_KEY
```

### 4. Configure OpenAI API Key

**Option 1: Environment Variable (Recommended)**
```bash
export OPENAI_API_KEY="your-api-key-here"
```

**Option 2: Xcode Scheme**
1. Open BrightBite.xcodeproj in Xcode
2. Edit Scheme → Run → Arguments
3. Add Environment Variable: `OPENAI_API_KEY = your-api-key-here`

### 5. Run the Backend Server

```bash
# In python_backend directory
python server.py
```

The server will run on `http://localhost:8000`

### 6. Build and Run

1. Open `BrightBite.xcodeproj` in Xcode
2. Select your target device/simulator
3. Build and run (⌘R)

## Project Structure

```
BrightBite/
├── BrightBite/
│   ├── Models/           # Data models
│   ├── Services/         # Firebase, OpenAI, ML services
│   ├── Views/           # SwiftUI views
│   │   ├── Home/        # Dashboard
│   │   ├── Map/         # 3D Pain Map
│   │   ├── Chat/        # DentalBot
│   │   ├── Plan/        # Treatment Plans
│   │   └── Components/  # Reusable components
│   ├── Extensions/      # Swift extensions
│   └── Teeth/          # 3D tooth models (.usdz)
├── python_backend/      # Flask server
│   ├── server.py       # Main server
│   ├── requirements.txt
│   └── .env.example
└── Descriptions/        # Documentation
```

## Security Notes

⚠️ **NEVER commit sensitive files:**
- `GoogleService-Info.plist` (Firebase config)
- `.env` files (API keys)
- Any files containing API keys or secrets

These are already added to `.gitignore` for your protection.

## Environment Variables

Create a `.env` file in `python_backend/` with:

```env
OPENAI_API_KEY=your_openai_api_key_here
```

## Features in Detail

### ChewCheck Food Scanner
- Real-time camera capture
- TensorFlow Lite inference on-device
- Fallback to OpenAI Vision API
- Context-aware recommendations based on treatment plan

### 3D Pain Map
- 32 individual tooth models
- Interactive rotation and zoom
- Pain level tracking (0-10 scale)
- Historical pain data visualization
- Tooth status management (fillings, crowns, etc.)

### Treatment Plans
- OCR-based dental notes scanning
- AI-powered note parsing
- Automatic medication and restriction extraction
- Calendar integration for appointments

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is private and proprietary.

## Contact

Tuan Nguyen - [@im-glitchy](https://github.com/im-glitchy)

Project Link: [https://github.com/im-glitchy/BrightBite](https://github.com/im-glitchy/BrightBite)

## Acknowledgments

- TensorFlow Lite for on-device ML
- OpenAI for GPT-4o Vision API
- Firebase for backend services
- Apple Vision Framework for OCR
