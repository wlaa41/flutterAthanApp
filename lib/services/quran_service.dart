import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quran_models.dart';

class QuranService {
  static final QuranService instance = QuranService._internal();
  QuranService._internal();

  /// Comprehensive list of all 114 Surahs
  static const List<Surah> surahList = [
    Surah(number: 1, name: "الفاتحة", englishName: "Al-Faatiha", englishNameTranslation: "The Opening", numberOfAyahs: 7, revelationType: "Meccan"),
    Surah(number: 2, name: "البقرة", englishName: "Al-Baqara", englishNameTranslation: "The Cow", numberOfAyahs: 286, revelationType: "Medinan"),
    Surah(number: 3, name: "آل عمران", englishName: "Aal-i-Imraan", englishNameTranslation: "The Family of Imraan", numberOfAyahs: 200, revelationType: "Medinan"),
    Surah(number: 4, name: "النساء", englishName: "An-Nisaa", englishNameTranslation: "The Women", numberOfAyahs: 176, revelationType: "Medinan"),
    Surah(number: 5, name: "المائدة", englishName: "Al-Maaida", englishNameTranslation: "The Table Spread", numberOfAyahs: 120, revelationType: "Medinan"),
    Surah(number: 6, name: "الأنعام", englishName: "Al-An'aam", englishNameTranslation: "The Cattle", numberOfAyahs: 165, revelationType: "Meccan"),
    Surah(number: 7, name: "الأعراف", englishName: "Al-A'raaf", englishNameTranslation: "The Heights", numberOfAyahs: 206, revelationType: "Meccan"),
    Surah(number: 8, name: "الأنفال", englishName: "Al-Anfaal", englishNameTranslation: "The Spoils of War", numberOfAyahs: 75, revelationType: "Medinan"),
    Surah(number: 9, name: "التوبة", englishName: "At-Tawba", englishNameTranslation: "The Repentance", numberOfAyahs: 129, revelationType: "Medinan"),
    Surah(number: 10, name: "يونس", englishName: "Yunus", englishNameTranslation: "Jonas", numberOfAyahs: 109, revelationType: "Meccan"),
    Surah(number: 11, name: "هود", englishName: "Hud", englishNameTranslation: "Hud", numberOfAyahs: 123, revelationType: "Meccan"),
    Surah(number: 12, name: "يوسف", englishName: "Yusuf", englishNameTranslation: "Joseph", numberOfAyahs: 111, revelationType: "Meccan"),
    Surah(number: 13, name: "الرعد", englishName: "Ar-Ra'd", englishNameTranslation: "The Thunder", numberOfAyahs: 43, revelationType: "Medinan"),
    Surah(number: 14, name: "إبراهيم", englishName: "Ibrahim", englishNameTranslation: "Abraham", numberOfAyahs: 52, revelationType: "Meccan"),
    Surah(number: 15, name: "الحجر", englishName: "Al-Hijr", englishNameTranslation: "The Rock", numberOfAyahs: 99, revelationType: "Meccan"),
    Surah(number: 16, name: "النحل", englishName: "An-Nahl", englishNameTranslation: "The Bee", numberOfAyahs: 128, revelationType: "Meccan"),
    Surah(number: 17, name: "الإسراء", englishName: "Al-Israa", englishNameTranslation: "The Night Journey", numberOfAyahs: 111, revelationType: "Meccan"),
    Surah(number: 18, name: "الكهف", englishName: "Al-Kahf", englishNameTranslation: "The Cave", numberOfAyahs: 110, revelationType: "Meccan"),
    Surah(number: 19, name: "مريم", englishName: "Maryam", englishNameTranslation: "Mary", numberOfAyahs: 98, revelationType: "Meccan"),
    Surah(number: 20, name: "طه", englishName: "Taa-Haa", englishNameTranslation: "Taa-Haa", numberOfAyahs: 135, revelationType: "Meccan"),
    Surah(number: 21, name: "الأنبياء", englishName: "Al-Anbiyaa", englishNameTranslation: "The Prophets", numberOfAyahs: 112, revelationType: "Meccan"),
    Surah(number: 22, name: "الحج", englishName: "Al-Hajj", englishNameTranslation: "The Pilgrimage", numberOfAyahs: 78, revelationType: "Medinan"),
    Surah(number: 23, name: "المؤمنون", englishName: "Al-Muminoon", englishNameTranslation: "The Believers", numberOfAyahs: 118, revelationType: "Meccan"),
    Surah(number: 24, name: "النور", englishName: "An-Noor", englishNameTranslation: "The Light", numberOfAyahs: 64, revelationType: "Medinan"),
    Surah(number: 25, name: "الفرقان", englishName: "Al-Furqaan", englishNameTranslation: "The Criterion", numberOfAyahs: 77, revelationType: "Meccan"),
    Surah(number: 26, name: "الشعراء", englishName: "Ash-Shu'araa", englishNameTranslation: "The Poets", numberOfAyahs: 227, revelationType: "Meccan"),
    Surah(number: 27, name: "النمل", englishName: "An-Naml", englishNameTranslation: "The Ant", numberOfAyahs: 93, revelationType: "Meccan"),
    Surah(number: 28, name: "القصص", englishName: "Al-Qasas", englishNameTranslation: "The Stories", numberOfAyahs: 88, revelationType: "Meccan"),
    Surah(number: 29, name: "العنكبوت", englishName: "Al-Ankaboot", englishNameTranslation: "The Spider", numberOfAyahs: 69, revelationType: "Meccan"),
    Surah(number: 30, name: "الروم", englishName: "Ar-Room", englishNameTranslation: "The Romans", numberOfAyahs: 60, revelationType: "Meccan"),
    Surah(number: 31, name: "لقمان", englishName: "Luqman", englishNameTranslation: "Luqman", numberOfAyahs: 34, revelationType: "Meccan"),
    Surah(number: 32, name: "السجدة", englishName: "As-Sajda", englishNameTranslation: "The Prostration", numberOfAyahs: 30, revelationType: "Meccan"),
    Surah(number: 33, name: "الأحزاب", englishName: "Al-Ahzaab", englishNameTranslation: "The Clans", numberOfAyahs: 73, revelationType: "Medinan"),
    Surah(number: 34, name: "سبأ", englishName: "Saba", englishNameTranslation: "Sheba", numberOfAyahs: 54, revelationType: "Meccan"),
    Surah(number: 35, name: "فاطر", englishName: "Faatir", englishNameTranslation: "The Originator", numberOfAyahs: 45, revelationType: "Meccan"),
    Surah(number: 36, name: "يس", englishName: "Yaseen", englishNameTranslation: "Yaseen", numberOfAyahs: 83, revelationType: "Meccan"),
    Surah(number: 37, name: "الصافات", englishName: "As-Saaffaat", englishNameTranslation: "Those drawn up in Ranks", numberOfAyahs: 182, revelationType: "Meccan"),
    Surah(number: 38, name: "ص", englishName: "Saad", englishNameTranslation: "The letter Saad", numberOfAyahs: 88, revelationType: "Meccan"),
    Surah(number: 39, name: "الزمر", englishName: "Az-Zumar", englishNameTranslation: "The Groups", numberOfAyahs: 75, revelationType: "Meccan"),
    Surah(number: 40, name: "غافر", englishName: "Ghafir", englishNameTranslation: "The Forgiver God", numberOfAyahs: 85, revelationType: "Meccan"),
    Surah(number: 41, name: "فصلت", englishName: "Fussilat", englishNameTranslation: "Explained in detail", numberOfAyahs: 54, revelationType: "Meccan"),
    Surah(number: 42, name: "الشورى", englishName: "Ash-Shura", englishNameTranslation: "Consultation", numberOfAyahs: 53, revelationType: "Meccan"),
    Surah(number: 43, name: "الزخرف", englishName: "Az-Zukhruf", englishNameTranslation: "Ornaments of gold", numberOfAyahs: 89, revelationType: "Meccan"),
    Surah(number: 44, name: "الدخان", englishName: "Ad-Dukhaan", englishNameTranslation: "The Smoke", numberOfAyahs: 59, revelationType: "Meccan"),
    Surah(number: 45, name: "الجاثية", englishName: "Al-Jaathiya", englishNameTranslation: "Crouching", numberOfAyahs: 37, revelationType: "Meccan"),
    Surah(number: 46, name: "الأحقاف", englishName: "Al-Ahqaaf", englishNameTranslation: "The Dunes", numberOfAyahs: 35, revelationType: "Meccan"),
    Surah(number: 47, name: "محمد", englishName: "Muhammad", englishNameTranslation: "Muhammad", numberOfAyahs: 38, revelationType: "Medinan"),
    Surah(number: 48, name: "الفتح", englishName: "Al-Fath", englishNameTranslation: "The Victory", numberOfAyahs: 29, revelationType: "Medinan"),
    Surah(number: 49, name: "الحجرات", englishName: "Al-Hujuraat", englishNameTranslation: "The Inner Apartments", numberOfAyahs: 18, revelationType: "Medinan"),
    Surah(number: 50, name: "ق", englishName: "Qaaf", englishNameTranslation: "The letter Qaaf", numberOfAyahs: 45, revelationType: "Meccan"),
    Surah(number: 51, name: "الذاريات", englishName: "Adh-Dhaariyat", englishNameTranslation: "The Winnowing Winds", numberOfAyahs: 60, revelationType: "Meccan"),
    Surah(number: 52, name: "الطور", englishName: "At-Toor", englishNameTranslation: "The Mount", numberOfAyahs: 49, revelationType: "Meccan"),
    Surah(number: 53, name: "النجم", englishName: "An-Najm", englishNameTranslation: "The Star", numberOfAyahs: 62, revelationType: "Meccan"),
    Surah(number: 54, name: "القمر", englishName: "Al-Qamar", englishNameTranslation: "The Moon", numberOfAyahs: 55, revelationType: "Meccan"),
    Surah(number: 55, name: "الرحمن", englishName: "Ar-Rahmaan", englishNameTranslation: "The Beneficent", numberOfAyahs: 78, revelationType: "Medinan"),
    Surah(number: 56, name: "الواقعة", englishName: "Al-Waaqia", englishNameTranslation: "The Inevitable", numberOfAyahs: 96, revelationType: "Meccan"),
    Surah(number: 57, name: "الحديد", englishName: "Al-Hadid", englishNameTranslation: "The Iron", numberOfAyahs: 29, revelationType: "Medinan"),
    Surah(number: 58, name: "المجادلة", englishName: "Al-Mujaadila", englishNameTranslation: "The Pleading Woman", numberOfAyahs: 22, revelationType: "Medinan"),
    Surah(number: 59, name: "الحشر", englishName: "Al-Hashr", englishNameTranslation: "The Exile", numberOfAyahs: 24, revelationType: "Medinan"),
    Surah(number: 60, name: "الممتحنة", englishName: "Al-Mumtahana", englishNameTranslation: "She that is to be examined", numberOfAyahs: 13, revelationType: "Medinan"),
    Surah(number: 61, name: "الصف", englishName: "As-Saff", englishNameTranslation: "The Ranks", numberOfAyahs: 14, revelationType: "Medinan"),
    Surah(number: 62, name: "الجمعة", englishName: "Al-Jumu'a", englishNameTranslation: "Friday", numberOfAyahs: 11, revelationType: "Medinan"),
    Surah(number: 63, name: "المنافقون", englishName: "Al-Munaafiqoon", englishNameTranslation: "The Hypocrites", numberOfAyahs: 11, revelationType: "Medinan"),
    Surah(number: 64, name: "التغابن", englishName: "At-Taghaabun", englishNameTranslation: "Mutual Disillusion", numberOfAyahs: 18, revelationType: "Medinan"),
    Surah(number: 65, name: "الطلاق", englishName: "At-Talaaq", englishNameTranslation: "Divorce", numberOfAyahs: 12, revelationType: "Medinan"),
    Surah(number: 66, name: "التحريم", englishName: "At-Tahrim", englishNameTranslation: "The Prohibition", numberOfAyahs: 12, revelationType: "Medinan"),
    Surah(number: 67, name: "الملك", englishName: "Al-Mulk", englishNameTranslation: "The Sovereignty", numberOfAyahs: 30, revelationType: "Meccan"),
    Surah(number: 68, name: "القلم", englishName: "Al-Qalam", englishNameTranslation: "The Pen", numberOfAyahs: 52, revelationType: "Meccan"),
    Surah(number: 69, name: "الحاقة", englishName: "Al-Haaqqa", englishNameTranslation: "The Reality", numberOfAyahs: 52, revelationType: "Meccan"),
    Surah(number: 70, name: "المعارج", englishName: "Al-Ma'aarij", englishNameTranslation: "The Ascending Stairways", numberOfAyahs: 44, revelationType: "Meccan"),
    Surah(number: 71, name: "نوح", englishName: "Nooh", englishNameTranslation: "Noah", numberOfAyahs: 28, revelationType: "Meccan"),
    Surah(number: 72, name: "الجن", englishName: "Al-Jinn", englishNameTranslation: "The Jinn", numberOfAyahs: 28, revelationType: "Meccan"),
    Surah(number: 73, name: "المزمل", englishName: "Al-Muzzammil", englishNameTranslation: "The Enshrouded One", numberOfAyahs: 20, revelationType: "Meccan"),
    Surah(number: 74, name: "المدثر", englishName: "Al-Muddathir", englishNameTranslation: "The Cloaked One", numberOfAyahs: 56, revelationType: "Meccan"),
    Surah(number: 75, name: "القيامة", englishName: "Al-Qiyaama", englishNameTranslation: "The Resurrection", numberOfAyahs: 40, revelationType: "Meccan"),
    Surah(number: 76, name: "الإنسان", englishName: "Al-Insaan", englishNameTranslation: "Man", numberOfAyahs: 31, revelationType: "Medinan"),
    Surah(number: 77, name: "المرسلات", englishName: "Al-Mursalaat", englishNameTranslation: "The Emissaries", numberOfAyahs: 50, revelationType: "Meccan"),
    Surah(number: 78, name: "النبأ", englishName: "An-Naba", englishNameTranslation: "The Announcement", numberOfAyahs: 40, revelationType: "Meccan"),
    Surah(number: 79, name: "النازعات", englishName: "An-Naazi'aat", englishNameTranslation: "Those who drag forth", numberOfAyahs: 46, revelationType: "Meccan"),
    Surah(number: 80, name: "عبس", englishName: "Abasa", englishNameTranslation: "He frowned", numberOfAyahs: 42, revelationType: "Meccan"),
    Surah(number: 81, name: "التكوير", englishName: "At-Takwir", englishNameTranslation: "The Overthrowing", numberOfAyahs: 29, revelationType: "Meccan"),
    Surah(number: 82, name: "الانفطار", englishName: "Al-Infitaar", englishNameTranslation: "The Cleaving", numberOfAyahs: 19, revelationType: "Meccan"),
    Surah(number: 83, name: "المطففين", englishName: "Al-Mutaffifin", englishNameTranslation: "Defrauding", numberOfAyahs: 36, revelationType: "Meccan"),
    Surah(number: 84, name: "الانشقاق", englishName: "Al-Inshiqaaq", englishNameTranslation: "The Splitting Open", numberOfAyahs: 25, revelationType: "Meccan"),
    Surah(number: 85, name: "البروج", englishName: "Al-Burooj", englishNameTranslation: "The Constellations", numberOfAyahs: 22, revelationType: "Meccan"),
    Surah(number: 86, name: "الطارق", englishName: "At-Taariq", englishNameTranslation: "The Morning Star", numberOfAyahs: 17, revelationType: "Meccan"),
    Surah(number: 87, name: "الأعلى", englishName: "Al-A'laa", englishNameTranslation: "The Most High", numberOfAyahs: 19, revelationType: "Meccan"),
    Surah(number: 88, name: "الغاشية", englishName: "Al-Ghaashiya", englishNameTranslation: "The Overwhelming", numberOfAyahs: 26, revelationType: "Meccan"),
    Surah(number: 89, name: "الفجر", englishName: "Al-Fajr", englishNameTranslation: "The Dawn", numberOfAyahs: 30, revelationType: "Meccan"),
    Surah(number: 90, name: "البلد", englishName: "Al-Balad", englishNameTranslation: "The City", numberOfAyahs: 20, revelationType: "Meccan"),
    Surah(number: 91, name: "الشمس", englishName: "Ash-Shams", englishNameTranslation: "The Sun", numberOfAyahs: 15, revelationType: "Meccan"),
    Surah(number: 92, name: "الليل", englishName: "Al-Layl", englishNameTranslation: "The Night", numberOfAyahs: 21, revelationType: "Meccan"),
    Surah(number: 93, name: "الضحى", englishName: "Ad-Dhuhaa", englishNameTranslation: "The Morning Hours", numberOfAyahs: 11, revelationType: "Meccan"),
    Surah(number: 94, name: "الشرح", englishName: "Ash-Sharh", englishNameTranslation: "The Relief", numberOfAyahs: 8, revelationType: "Meccan"),
    Surah(number: 95, name: "التين", englishName: "At-Tin", englishNameTranslation: "The Fig", numberOfAyahs: 8, revelationType: "Meccan"),
    Surah(number: 96, name: "العلق", englishName: "Al-Alaq", englishNameTranslation: "The Clot", numberOfAyahs: 19, revelationType: "Meccan"),
    Surah(number: 97, name: "القدر", englishName: "Al-Qadr", englishNameTranslation: "The Power", numberOfAyahs: 5, revelationType: "Meccan"),
    Surah(number: 98, name: "البينة", englishName: "Al-Bayyina", englishNameTranslation: "The Clear Proof", numberOfAyahs: 8, revelationType: "Medinan"),
    Surah(number: 99, name: "الزلزلة", englishName: "Az-Zalzala", englishNameTranslation: "The Earthquake", numberOfAyahs: 8, revelationType: "Medinan"),
    Surah(number: 100, name: "العاديات", englishName: "Al-Aadiyaat", englishNameTranslation: "The Courser", numberOfAyahs: 11, revelationType: "Meccan"),
    Surah(number: 101, name: "القارعة", englishName: "Al-Qaari'a", englishNameTranslation: "The Calamity", numberOfAyahs: 11, revelationType: "Meccan"),
    Surah(number: 102, name: "التكاثر", englishName: "At-Takaathur", englishNameTranslation: "The Rivalry in world increase", numberOfAyahs: 8, revelationType: "Meccan"),
    Surah(number: 103, name: "العصر", englishName: "Al-Asr", englishNameTranslation: "The Declining Day", numberOfAyahs: 3, revelationType: "Meccan"),
    Surah(number: 104, name: "الهمزة", englishName: "Al-Humaza", englishNameTranslation: "The Traducer", numberOfAyahs: 9, revelationType: "Meccan"),
    Surah(number: 105, name: "الفيل", englishName: "Al-Feel", englishNameTranslation: "The Elephant", numberOfAyahs: 5, revelationType: "Meccan"),
    Surah(number: 106, name: "قريش", englishName: "Quraish", englishNameTranslation: "Quraysh", numberOfAyahs: 4, revelationType: "Meccan"),
    Surah(number: 107, name: "الماعون", englishName: "Al-Maa'oon", englishNameTranslation: "The Small Kindnesses", numberOfAyahs: 7, revelationType: "Meccan"),
    Surah(number: 108, name: "الكوثر", englishName: "Al-Kawthar", englishNameTranslation: "The Abundance", numberOfAyahs: 3, revelationType: "Meccan"),
    Surah(number: 109, name: "الكافرون", englishName: "Al-Kaafiroon", englishNameTranslation: "The Disbelievers", numberOfAyahs: 6, revelationType: "Meccan"),
    Surah(number: 110, name: "النصر", englishName: "An-Nasr", englishNameTranslation: "The Divine Support", numberOfAyahs: 3, revelationType: "Medinan"),
    Surah(number: 111, name: "المسد", englishName: "Al-Masad", englishNameTranslation: "The Palm Fiber", numberOfAyahs: 5, revelationType: "Meccan"),
    Surah(number: 112, name: "الإخلاص", englishName: "Al-Ikhlaas", englishNameTranslation: "The Sincerity", numberOfAyahs: 4, revelationType: "Meccan"),
    Surah(number: 113, name: "الفلق", englishName: "Al-Falaq", englishNameTranslation: "The Daybreak", numberOfAyahs: 5, revelationType: "Meccan"),
    Surah(number: 114, name: "الناس", englishName: "An-Naas", englishNameTranslation: "Mankind", numberOfAyahs: 6, revelationType: "Meccan"),
  ];

  /// Offline bundled data for Surah Al-Fatiha (The Opening) with Tajweed notation
  static final List<Ayah> offlineFatiha = [
    Ayah(
      number: 1,
      numberInSurah: 1,
      juz: 1,
      page: 1,
      tajweedText: "بِسْمِ [h:1[ٱ]للَّهِ [h:2[ٱ]لرَّحْمَ[n[ـٰ]نِ [h:3[ٱ]لرَّحِ[p[ي]مِ",
      cleanText: "بِسْمِ اللَّهِ الرَّحْمَـٰنِ الرَّحِيمِ",
      translation: "In the name of Allah, the Entirely Merciful, the Especially Merciful.",
      audioUrl: "https://cdn.islamic.network/quran/audio/128/ar.alafasy/1.mp3",
    ),
    Ayah(
      number: 2,
      numberInSurah: 2,
      juz: 1,
      page: 1,
      tajweedText: "[h:4[ٱ]لْحَمْدُ لِلَّهِ رَبِّ [h:5[ٱ]لْعَ[n[ـٰ]لَمِ[p[ي]نَ",
      cleanText: "الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ",
      translation: "[All] praise is [due] to Allah, Lord of the worlds -",
      audioUrl: "https://cdn.islamic.network/quran/audio/128/ar.alafasy/2.mp3",
    ),
    Ayah(
      number: 3,
      numberInSurah: 3,
      juz: 1,
      page: 1,
      tajweedText: "[h:1[ٱ]لرَّحْمَ[n[ـٰ]نِ [h:2[ٱ]لرَّحِ[p[ي]مِ",
      cleanText: "الرَّحْمَـٰنِ الرَّحِيمِ",
      translation: "The Entirely Merciful, the Especially Merciful,",
      audioUrl: "https://cdn.islamic.network/quran/audio/128/ar.alafasy/3.mp3",
    ),
    Ayah(
      number: 4,
      numberInSurah: 4,
      juz: 1,
      page: 1,
      tajweedText: "مَ[n[ـٰ]لِكِ يَوْمِ [h:3[ٱ]لدِّ[p[ي]نِ",
      cleanText: "مَالِكِ يَوْمِ الدِّينِ",
      translation: "Sovereign of the Day of Recompense.",
      audioUrl: "https://cdn.islamic.network/quran/audio/128/ar.alafasy/4.mp3",
    ),
    Ayah(
      number: 5,
      numberInSurah: 5,
      juz: 1,
      page: 1,
      tajweedText: "إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِ[p[ي]نُ",
      cleanText: "إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ",
      translation: "It is You we worship and You we ask for help.",
      audioUrl: "https://cdn.islamic.network/quran/audio/128/ar.alafasy/5.mp3",
    ),
    Ayah(
      number: 6,
      numberInSurah: 6,
      juz: 1,
      page: 1,
      tajweedText: "[h:6[ٱ]هْدِنَا [h:7[ٱ]لصِّرَ[n[ـٰ]طَ [h:8[ٱ]لْمُسْتَقِ[p[ي]مَ",
      cleanText: "اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ",
      translation: "Guide us to the straight path -",
      audioUrl: "https://cdn.islamic.network/quran/audio/128/ar.alafasy/6.mp3",
    ),
    Ayah(
      number: 7,
      numberInSurah: 7,
      juz: 1,
      page: 1,
      tajweedText: "صِرَ[n[ـٰ]طَ [h:9[ٱ]لَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ [h:10[ٱ]لْمَغْضُوبِ عَلَيْهِمْ وَلَا [h:11[ٱ]ل[m[ضَّ]آلِّ[p[ي]نَ",
      cleanText: "صِرَاطَ الَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ الْمَغْضُوبِ عَلَيْهِمْ وَلَا الضَّالِّينَ",
      translation: "The path of those upon whom You have bestowed favor, not of those who have evoked [Your] anger or of those who are astray.",
      audioUrl: "https://cdn.islamic.network/quran/audio/128/ar.alafasy/7.mp3",
    ),
  ];

  /// Offline bundled data for Surah Al-Ikhlas (The Sincerity)
  static final List<Ayah> offlineIkhlas = [
    Ayah(
      number: 6222,
      numberInSurah: 1,
      juz: 30,
      page: 604,
      tajweedText: "قُ[q[لْ] هُوَ [h:1[ٱ]للَّهُ أَحَ[q[دٌ]",
      cleanText: "قُلْ هُوَ اللَّهُ أَحَدٌ",
      translation: "Say, 'He is Allah, [who is] One,",
      audioUrl: "https://cdn.islamic.network/quran/audio/128/ar.alafasy/6222.mp3",
    ),
    Ayah(
      number: 6223,
      numberInSurah: 2,
      juz: 30,
      page: 604,
      tajweedText: "[h:2[ٱ]للَّهُ [h:3[ٱ]ل[m[صَّ]مَ[q[دُ]",
      cleanText: "اللَّهُ الصَّمَدُ",
      translation: "Allah, the Eternal Refuge.",
      audioUrl: "https://cdn.islamic.network/quran/audio/128/ar.alafasy/6223.mp3",
    ),
    Ayah(
      number: 6224,
      numberInSurah: 3,
      juz: 30,
      page: 604,
      tajweedText: "لَمْ يَلِ[q[دْ] وَلَمْ يُولَ[q[دْ]",
      cleanText: "لَمْ يَلِدْ وَلَمْ يُولَدْ",
      translation: "He neither begets nor is born,",
      audioUrl: "https://cdn.islamic.network/quran/audio/128/ar.alafasy/6224.mp3",
    ),
    Ayah(
      number: 6225,
      numberInSurah: 4,
      juz: 30,
      page: 604,
      tajweedText: "وَلَمْ يَكُ[a[ن لَّ]هُۥ كُفُوًا أَحَ[q[دٌ]",
      cleanText: "وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ",
      translation: "Nor is there to Him any equivalent.'",
      audioUrl: "https://cdn.islamic.network/quran/audio/128/ar.alafasy/6225.mp3",
    ),
  ];

  /// Get Ayahs for a Surah with automatic caching and offline fallback
  Future<List<Ayah>> getSurahAyahs(int surahNumber) async {
    final cacheKey = 'surah_detail_$surahNumber';

    // 1. Try reading from SharedPreferences cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(cacheKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(cachedJson);
        final list = decoded
            .map((item) => Ayah.fromJson(item as Map<String, dynamic>))
            .toList();
        if (list.isNotEmpty) {
          return list;
        }
      }
    } catch (e) {
      debugPrint('QuranService: cache read error: $e');
    }

    // 2. Fetch from API
    try {
      final url = Uri.parse(
        'https://api.alquran.cloud/v1/surah/$surahNumber/editions/quran-tajweed,en.sahih',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        final List<dynamic> editions = body['data'] as List<dynamic>;

        final tajweedAyahs = editions[0]['ayahs'] as List<dynamic>;
        final englishAyahs = editions.length > 1
            ? (editions[1]['ayahs'] as List<dynamic>)
            : [];

        final list = <Ayah>[];
        for (int i = 0; i < tajweedAyahs.length; i++) {
          final tAyah = tajweedAyahs[i];
          final rawTajweed = tAyah['text'] as String;
          final clean = stripTajweedTags(rawTajweed);
          final engText = i < englishAyahs.length
              ? (englishAyahs[i]['text'] as String)
              : '';
          final globalNum = tAyah['number'] as int;

          list.add(Ayah(
            number: globalNum,
            numberInSurah: tAyah['numberInSurah'] as int,
            juz: tAyah['juz'] as int? ?? 1,
            page: tAyah['page'] as int? ?? 1,
            tajweedText: rawTajweed,
            cleanText: clean,
            translation: engText,
            audioUrl:
                'https://cdn.islamic.network/quran/audio/128/ar.alafasy/$globalNum.mp3',
          ));
        }

        // Cache to storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          cacheKey,
          jsonEncode(list.map((a) => a.toJson()).toList()),
        );

        return list;
      }
    } catch (e) {
      debugPrint('QuranService: API fetch error for Surah $surahNumber ($e).');
    }

    // 3. Fallback for offline mode
    if (surahNumber == 1) return offlineFatiha;
    if (surahNumber == 112) return offlineIkhlas;

    return offlineFatiha;
  }

  /// Removes bracketed Tajweed markers for clean copy/search
  static String stripTajweedTags(String text) {
    // Replaces patterns like [h:1[ٱ], [q[لْ], etc.
    final regex = RegExp(r'\[[a-z0-9:]*\[([^\]]*)\]');
    var result = text;
    while (regex.hasMatch(result)) {
      result = result.replaceAllMapped(regex, (m) => m.group(1) ?? '');
    }
    // Remove leftover brackets if any
    return result.replaceAll(RegExp(r'\[|\]'), '');
  }

  /// Bookmark storage
  Future<void> toggleBookmark(int ayahGlobalNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = prefs.getStringList('quran_bookmarks') ?? [];
    final numStr = ayahGlobalNumber.toString();
    if (bookmarks.contains(numStr)) {
      bookmarks.remove(numStr);
    } else {
      bookmarks.add(numStr);
    }
    await prefs.setStringList('quran_bookmarks', bookmarks);
  }

  Future<bool> isAyahBookmarked(int ayahGlobalNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = prefs.getStringList('quran_bookmarks') ?? [];
    return bookmarks.contains(ayahGlobalNumber.toString());
  }
}
