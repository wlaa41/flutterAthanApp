# Athan & Quran London Pro

A reimagined, modern Islamic Flutter application featuring accurate prayer times with offline astronomical fallback, authentic Athan audio playback, and an interactive Holy Quran reader with Colored Tajweed, clickable verses, and stylus writing & highlighting.

---

## Key Features

### 1. Reimagined Prayer Times & Athan
- **Next Prayer Hero Card**: Live ticking countdown timer (`- HH:MM:SS`), current prayer progress interval bar, Hijri and Gregorian dates.
- **Authentic Athan Audio**:
  - Built-in playback of `asset/smooth.mp3` with instant preview toggle in the hero widget.
  - Per-prayer notification alarms with individual mute/unmute switches.
- **Fail-Safe Offline Fallback Engine**:
  - Completely fixes previous offline crashes and static 2020 fallback dates.
  - Dual-tier strategy: fetches online monthly data from Aladhan API and caches in `SharedPreferences`. If offline or network drops, automatically calculates accurate prayer times using built-in astronomical solar algorithms (Equation of Time, Solar Declination, Solar Noon).
- **Monthly Prayer Schedule**:
  - Interactive bottom sheet displaying full monthly timings with today highlighted.

### 2. Holy Quran with Colored Tajweed & Stylus Canvas
- **Colored Tajweed Engine**:
  - Renders Uthmanic Arabic text with authentic Tajweed color coding:
    - **Qalqalah** (Red)
    - **Ikhfa** (Purple)
    - **Idgham** (Green)
    - **Iqlab** (Cyan)
    - **Madd Rules** (Blue & Indigo shades)
    - **Hamzat Wasl & Silent Letters** (Muted Gray)
  - Includes a built-in **Tajweed Rules Guide** modal explaining each color.
- **Stylus / Pen Writing & Highlighting Canvas**:
  - Floating toolbar to switch effortlessly between **Read Mode** and **Stylus / Annotate Mode**.
  - **Stylus Pen**: Crisp drawing with adjustable stroke width and ink colors (Gold, White, Coral Red, Sky Blue, Emerald Green).
  - **Translucent Highlighter**: Semi-transparent marker (Yellow, Mint Green, Soft Cyan, Rose Pink) designed specifically so Quranic words and Tajweed colors remain clearly visible underneath.
  - **Eraser Tool**: Touch-to-erase and Clear Page actions.
  - **Undo / Redo** history controls.
  - **Auto-Persistence**: Drawings and highlights are saved per Surah and restored on next open.
- **Clickable Quran Verses**:
  - Tap any verse in Read Mode to open the **Verse Action Sheet**:
    - **Play Verse Audio**: Streams Sheikh Mishary Rashid Alafasy's recitation of that exact Ayah.
    - **Translation & Commentary**: View English Saheeh International translation.
    - **Bookmark**: Save Ayah to favorites.
    - **Copy**: Copy Arabic text and English translation to clipboard.
    - **Quick Highlight**: Instant background highlight color picker.
- **114 Surahs Index**:
  - Search by Arabic name, English name, or Surah number.
  - Filter by Meccan and Medinan revelations.

### 3. Qibla Direction & Essential Daily Adhkar
- Visual Qibla compass pointing directly to the Kaaba (`118.98° ESE` from London).
- Authentic daily morning, evening, and post-prayer adhkar with Arabic text, translations, and counter.

---

## Project Structure

```
lib/
├── models/
│   ├── drawing_stroke.dart        # Stylus points, strokes, and JSON serialization
│   ├── prayer_time_model.dart     # Prayer schedule model and formatted strings
│   └── quran_models.dart          # Surah, Ayah, and Tajweed rule definitions
├── screens/
│   ├── athan_screen.dart          # Reimagined prayer countdown and schedule
│   ├── main_navigation_screen.dart# Bottom navigation bar (Prayer, Quran, Qibla, Settings)
│   ├── qibla_screen.dart          # Qibla compass and daily adhkar
│   ├── quran_index_screen.dart    # 114 Surahs browser and search
│   ├── quran_reader_screen.dart   # Interactive Tajweed Quran reader + Stylus Canvas
│   └── settings_screen.dart       # Preferences, calculation method, audio tests
├── services/
│   ├── annotation_storage_service.dart # SharedPreferences drawing persistence
│   ├── astronomical_calculator.dart    # 100% offline solar prayer algorithm
│   ├── audio_service.dart              # Just_audio controller for Athan and Ayahs
│   ├── notification_service.dart       # Local notifications with smooth.mp3
│   ├── prayer_service.dart             # API client + offline fallback manager
│   └── quran_service.dart              # Surah directory, tajweed parser, cache
├── widgets/
│   ├── next_prayer_hero.dart      # Live countdown hero card with Athan preview
│   ├── prayer_row_card.dart       # Prayer row with status badge and alarm toggle
│   ├── stylus_canvas.dart         # CustomPaint overlay for stylus and highlighter
│   ├── tajweed_text.dart          # RichText tajweed parser and Arabic numerals
│   └── verse_action_sheet.dart    # Clickable Ayah modal for audio and translations
└── main.dart                      # App entry point with modern theme
```

---

## Running the App

```bash
# Get dependencies
flutter pub get

# Run unit tests
flutter test

# Launch on connected device / emulator
flutter run
```
