import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService {
  static const String keySelectedLanguage = 'selected_language';

  // Supported languages: 'en' (English), 'si' (Sinhala), 'ta' (Tamil)
  static final ValueNotifier<String> currentLanguageNotifier = ValueNotifier<String>('en');

  static String get currentLanguage => currentLanguageNotifier.value;

  static Future<void> initLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLang = prefs.getString(keySelectedLanguage) ?? 'en';
    currentLanguageNotifier.value = savedLang;
  }

  static Future<void> setLanguage(String langCode) async {
    if (['en', 'si', 'ta'].contains(langCode)) {
      currentLanguageNotifier.value = langCode;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keySelectedLanguage, langCode);
    }
  }

  static String tr(String key) {
    final lang = currentLanguageNotifier.value;
    if (_translations.containsKey(lang) && _translations[lang]!.containsKey(key)) {
      return _translations[lang]![key]!;
    }
    // Fallback to English
    if (_translations['en']!.containsKey(key)) {
      return _translations['en']![key]!;
    }
    return key;
  }

  static final Map<String, Map<String, String>> _translations = {
    'en': {
      // App Header & Drawer
      'app_title': 'MediQ OPD Portal',
      'menu_my_profile': 'My Profile',
      'menu_notifications': 'Notifications & Alerts',
      'menu_family_cards': 'Family OPD Cards',
      'menu_opd_assistance': 'OPD ASSISTANCE',
      'menu_emergency': 'Emergency Helpline (1990)',
      'menu_counter_guide': 'Hospital Counter Guide',
      'menu_help_faq': 'Help & OPD FAQ',
      'menu_preferences': 'PREFERENCES',
      'menu_settings': 'App Settings',
      'menu_app_info': 'App Information',
      'menu_logout': 'Logout Account',
      'menu_language': 'Language / භාෂාව / மொழி',
      'select_language': 'Select Language',

      // Home Screen
      'smart_opd_guide': 'Smart OPD Guide',
      'smart_opd_subtitle': 'Select your symptom to find your hospital room & queue instructions.',
      'opd_services': 'OPD Services',
      'opd_live_queue': 'OPD Live Queue',
      'opd_live_queue_sub': 'Check live token status',
      'book_appointment': 'Book Appointment',
      'book_appointment_sub': 'Schedule OPD Visit',
      'medical_records': 'Medical Records',
      'medical_records_sub': 'Prescriptions & History',
      'pill_tracker': 'Pill & Dose Tracker',
      'pill_tracker_sub': 'Daily Prescriptions',
      'symptom_checker': 'Symptom Checker',
      'symptom_checker_sub': 'Find OPD Clinic Room',
      'health_vitals': 'Health Vitals & BMI',
      'health_vitals_sub': 'Track Weight & Sugar',
      'slot_active_today': 'SLOT ACTIVE TODAY',
      'countdown': 'COUNTDOWN',
      'token': 'TOKEN',
      'present_qr': 'Present QR at counter',
      'role_patient': 'PATIENT',
      'nic': 'NIC',
      'phone': 'Phone',

      // Symptom Checker
      'select_symptom_title': '1. Select Primary Symptom / Queue',
      'symptom_intensity': '2. Symptom Intensity Level',
      'mild': 'Mild',
      'moderate': 'Moderate',
      'severe': 'Severe',
      'recommended_clinic': 'RECOMMENDED CLINIC',
      'high_priority': 'High Priority',
      'guidance': 'Guidance',
      'pre_visit_checklist': '📋 OPD Pre-Visit Checklist:',
      'book_opd_now': 'Book OPD Appointment Now',

      // Symptoms Items
      'symptom_fever_title': 'Fever, Cough & Body Pain',
      'symptom_fever_desc': 'General OPD consultation room with 4 doctors attending to patients for fever, cold & aches.',
      'symptom_wounds_title': 'Wounds, Cuts & Boils',
      'symptom_wounds_desc': 'Wound cleaning, dressing, and bandage re-application room.',
      'symptom_injection_title': 'Prescribed Injections',
      'symptom_injection_desc': 'Queue for patients prescribed IM/IV injection shots by doctors.',
      'symptom_animal_title': 'Animal Bite Treatment',
      'symptom_animal_desc': 'Dedicated queue & doctor for dog/cat/animal bites and Anti-Rabies vaccination.',
      'symptom_blood_title': 'Blood Sample Draw',
      'symptom_blood_desc': 'Combined queue for registered OPD patients and external clinic referral chits for blood draws.',

      // Book Appointment
      'select_clinic_room': 'Select OPD Clinic / Room',
      'select_date': 'Select Visit Date',
      'live_queue_status': 'Live Queue Status',
      'patients_waiting': 'patients waiting in queue today',
      'book_token_now': 'Book OPD Token & Appointment',
      'my_appointments': 'My OPD Appointments',
      'active_token': 'Active Token',
      'queue_position': 'Queue Position',
      'cancel_appointment': 'Cancel Appointment',
      'scan_qr_at_counter': 'Scan QR Code at Hospital Counter',

      // Profile Screen
      'patient_profile': 'Patient Profile',
      'personal_info': 'Personal Information',
      'contact_location': 'Contact & Location',
      'emergency_contact': 'Emergency Contact',
      'medical_background': 'Medical Background',
      'full_name': 'Full Name',
      'dob': 'Date of Birth',
      'gender': 'Gender',
      'civil_status': 'Civil Status',
      'address': 'Address',
      'district': 'District',
      'blood_group': 'Blood Group',
      'allergies': 'Allergies',
      'medical_conditions': 'Medical Conditions',
      'edit_profile': 'Edit Profile',
      'save_changes': 'Save Changes',
      'delete_profile': 'Delete Profile',
      'change_photo': 'Change Photo',

      // Helplines & Guides
      'emergency_helplines': 'OPD Emergency & Helplines',
      'suwa_seriya': '1990 Suwa Seriya Ambulance',
      'suwa_seriya_sub': 'Free 24/7 National Emergency Hotline',
      'hospital_triage': 'National Hospital OPD Triage',
      'triage_sub': 'OPD Reception & Emergency Gate',
      'pharmacy_desk': 'OPD Pharmacy Desk',
      'pharmacy_sub': 'Prescription & Drug Inquiries',
      'counter_guide_title': 'OPD Hospital Counter Guide',
      'counter_guide_sub': 'Floor plan and key counter locations for OPD visitors',
      'family_cards_title': 'Family OPD Cards',
      'family_cards_sub': 'Manage OPD tokens for your family members from a single account.',
      'add_family_member': 'Add Family Member',
      'app_settings': 'App Settings',
      'help_faq': 'OPD Help & FAQ',
      'close': 'Close',
    },
    'si': {
      // App Header & Drawer
      'app_title': 'MediQ OPD ද්වාරය',
      'menu_my_profile': 'මගේ ගිණුම (Profile)',
      'menu_notifications': 'දැනුම්දීම් & ඇලර්ට් (Notifications)',
      'menu_family_cards': 'පවුලේ OPD කාඩ්පත්',
      'menu_opd_assistance': 'OPD සහාය (ASSISTANCE)',
      'menu_emergency': 'හදිසි ඇමතුම් සේවාව (1990)',
      'menu_counter_guide': 'රෝහල් කවුන්ටර මඟ පෙන්වීම',
      'menu_help_faq': 'උදව් & නිතර අසන පැණ (FAQ)',
      'menu_preferences': 'සැකසුම් (PREFERENCES)',
      'menu_settings': 'ඇප් සැකසුම් (App Settings)',
      'menu_app_info': 'ඇප් එක පිළිබඳ තොරතුරු',
      'menu_logout': 'ගිණුමෙන් ඉවත් වන්න (Logout)',
      'menu_language': 'භාෂාව / Language / மொழி',
      'select_language': 'භාෂාව තෝරන්න (Select Language)',

      // Home Screen
      'smart_opd_guide': 'ස්මාර්ට් OPD මඟපෙන්වන්නා',
      'smart_opd_subtitle': 'ඔබේ රෝග ලක්ෂණය තෝරා අදාළ රෝහල් කාමරය සහ උපදෙස් ලබා ගන්න.',
      'opd_services': 'OPD සේවාවන්',
      'opd_live_queue': 'OPD සජීවී පෝලිම',
      'opd_live_queue_sub': 'සජීවී ටෝකන් තත්ත්වය',
      'book_appointment': 'වෙලාවක් වෙන් කරගන්න',
      'book_appointment_sub': 'OPD පැමිණීම',
      'medical_records': 'වෛද්‍ය වාර්තා',
      'medical_records_sub': 'බෙහෙත් වට්ටෝරු & ඉතිහාසය',
      'pill_tracker': 'බෙහෙත් මතක් කැඳවුම',
      'pill_tracker_sub': 'දෛනික බෙහෙත් වට්ටෝරු',
      'symptom_checker': 'රෝග ලක්ෂණ පරීක්ෂාව',
      'symptom_checker_sub': 'OPD සායන කාමරය',
      'health_vitals': 'සෞඛ්‍ය දත්ත & BMI',
      'health_vitals_sub': 'බර සහ සීනි මට්ටම',
      'slot_active_today': 'අද දින සක්‍රීය ටෝකනය',
      'countdown': 'ඉතිරි කාලය',
      'token': 'ටෝකනය',
      'present_qr': 'කවුන්ටරයට QR කේතය පෙන්වන්න',
      'role_patient': 'රෝගියා (PATIENT)',
      'nic': 'හැඳුනුම්පත',
      'phone': 'දුරකථනය',

      // Symptom Checker
      'select_symptom_title': '1. ප්‍රධාන රෝග ලක්ෂණය / පෝලිම තෝරන්න',
      'symptom_intensity': '2. රෝග ලක්ෂණයේ తీవ్రතාවය',
      'mild': 'සුළු (Mild)',
      'moderate': 'මධ්‍යස්ථ (Moderate)',
      'severe': 'දරුණු (Severe)',
      'recommended_clinic': 'නිර්දේශිත සායන කාමරය',
      'high_priority': 'ඉහළ ප්‍රමුඛතාවය',
      'guidance': 'උපදෙස්',
      'pre_visit_checklist': '📋 OPD පැමිණීමට පෙර පරීක්ෂා ලැයිස්තුව:',
      'book_opd_now': 'දැන්ම OPD ටෝකනයක් වෙන් කරගන්න',

      // Symptoms Items
      'symptom_fever_title': 'උණ, කැස්ස & ඇඟපත වේදනාව',
      'symptom_fever_desc': 'උණ, හෙම්බිරිස්සාව සහ වේදනාවන් සඳහා වෛද්‍යවරුන් 4 දෙනෙකු සිටින සාමාන්‍ය OPD සායන කාමරය.',
      'symptom_wounds_title': 'තුවාල, ගෙඩි & බෙහෙත් දැමීම',
      'symptom_wounds_desc': 'තුවාල පිරිසිදු කිරීම, බෙහෙත් දැමීම සහ වෙළුම් පටි යෙදීමේ කාමරය.',
      'symptom_injection_title': 'ඉන්ජෙක්ෂන් (විදීම්) ලබාගැනීම',
      'symptom_injection_desc': 'වෛද්‍යවරුන් විසින් නිර්දේශිත එන්නත් ලබාගැනීමේ පෝලිම.',
      'symptom_animal_title': 'සතුන් හපාකෑම & රේබීස් එන්නත',
      'symptom_animal_desc': 'බල්ලන්/පූසන් හපාකෑම් සහ රේබීස් එන්නත් ලබාගැනීම සඳහා විශේෂිත සායනය.',
      'symptom_blood_title': 'ලේ ලබාදීම (Bleeding Room)',
      'symptom_blood_desc': 'රක්ත පරීක්ෂණ සහ ලේ සාම්පල ලබාගැනීමේ එක්සත් පෝලිම.',

      // Book Appointment
      'select_clinic_room': 'OPD සායනය / කාමරය තෝරන්න',
      'select_date': 'පැමිණෙන දිනය තෝරන්න',
      'live_queue_status': 'සජීවී පෝලිම් තත්ත්වය',
      'patients_waiting': 'අද පෝලිමේ සිටින රෝගීන් ගණන',
      'book_token_now': 'OPD ටෝකනය වෙන් කරගන්න',
      'my_appointments': 'මගේ OPD වෙන්කිරීම්',
      'active_token': 'සක්‍රීය ටෝකනය',
      'queue_position': 'පෝලිමේ ස්ථානය',
      'cancel_appointment': 'වෙන්කිරීම අවලංගු කරන්න',
      'scan_qr_at_counter': 'රෝහල් කවුන්ටරයේදී QR කේතය පෙන්වන්න',

      // Profile Screen
      'patient_profile': 'රෝගියාගේ විස්තර',
      'personal_info': 'පෞද්ගලික තොරතුරු',
      'contact_location': 'සම්බන්ධතා & ලිපිනය',
      'emergency_contact': 'හදිසි සම්බන්ධතාවය',
      'medical_background': 'වෛද්‍ය පසුබිම',
      'full_name': 'සම්පූර්ණ නම',
      'dob': 'උපන් දිනය',
      'gender': 'ස්ත්‍රී / පුරුෂ භාවය',
      'civil_status': 'විවාහක / අවිවාහක බව',
      'address': 'ලිපිනය',
      'district': 'දිස්ත්‍රික්කය',
      'blood_group': 'ලේ වර්ගය',
      'allergies': 'ආසාත්මිකතා (Allergies)',
      'medical_conditions': 'කල්පවතින රෝග තත්ත්වයන්',
      'edit_profile': 'විස්තර වෙනස් කරන්න',
      'save_changes': 'වෙනස්කම් සුරකින්න',
      'delete_profile': 'ගිණුම ඉවත් කරන්න',
      'change_photo': 'ඡායාරූපය වෙනස් කරන්න',

      // Helplines & Guides
      'emergency_helplines': 'OPD හදිසි ඇමතුම් & උපකාරක අංක',
      'suwa_seriya': '1990 සුව සැරිය ගිලන්රථ සේවාව',
      'suwa_seriya_sub': 'නොමිලේ 24/7 ජාතික හදිසි ඇමතුම් අංකය',
      'hospital_triage': 'ජාතික රෝහල් OPD පිළිගැනීමේ Desk',
      'triage_sub': 'OPD පිළිගැනීමේ & හදිසි ප්‍රතිකාර දොරටුව',
      'pharmacy_desk': 'OPD ඖෂධසැල (Pharmacy)',
      'pharmacy_sub': 'බෙහෙත් වට්ටෝරු සහ ඖෂධ විමසීම්',
      'counter_guide_title': 'OPD රෝහල් කවුන්ටර මඟ පෙන්වීම',
      'counter_guide_sub': 'OPD පැමිණෙන්නන් සඳහා කවුන්ටර පිහිටීම සහ විස්තර',
      'family_cards_title': 'පවුලේ OPD කාඩ්පත්',
      'family_cards_sub': 'එක් ගිණුමකින් ඔබේ පවුලේ සාමාජිකයින්ගේ OPD ටෝකන් පාලනය කරන්න.',
      'add_family_member': 'සාමාජිකයෙකු එකතු කරන්න',
      'app_settings': 'ඇප් සැකසුම් (Settings)',
      'help_faq': 'OPD උදව් & නිතර අසන පැණ',
      'close': 'වහන්න',
    },
    'ta': {
      // App Header & Drawer
      'app_title': 'MediQ OPD போர்டல்',
      'menu_my_profile': 'என் சுயவிவரம் (Profile)',
      'menu_notifications': 'அறிவிப்புகள் (Notifications)',
      'menu_family_cards': 'குடும்ப OPD கார்டுகள்',
      'menu_opd_assistance': 'OPD உதவி (ASSISTANCE)',
      'menu_emergency': 'அவசர உதவி எண் (1990)',
      'menu_counter_guide': 'மருத்துவமனை கவுண்டர் வழிகாட்டி',
      'menu_help_faq': 'உதவி & கேள்விகள் (FAQ)',
      'menu_preferences': 'முன்னுரிமைகள் (PREFERENCES)',
      'menu_settings': 'செயலி அமைப்புகள் (Settings)',
      'menu_app_info': 'செயலி விவரங்கள் (App Info)',
      'menu_logout': 'வெளியேறு (Logout)',
      'menu_language': 'மொழி / Language / භාෂාව',
      'select_language': 'மொழியைத் தேர்ந்தெடுக்கவும்',

      // Home Screen
      'smart_opd_guide': 'ஸ்மார்ட் OPD வழிகாட்டி',
      'smart_opd_subtitle': 'உங்கள் அறையையும் வரிசை அறிவுறுத்தல்களையும் கண்டறிய உங்கள் அறிகுறிகளைத் தேர்ந்தெடுக்கவும்.',
      'opd_services': 'OPD சேவைகள்',
      'opd_live_queue': 'நேரலை வரிசை',
      'opd_live_queue_sub': 'நேரலை நிலை',
      'book_appointment': 'முன்பதிவு செய்ய',
      'book_appointment_sub': 'OPD வருகை',
      'medical_records': 'மருத்துவப் பதிவுகள்',
      'medical_records_sub': 'மருந்துச் சீட்டுகள் & வரலாறு',
      'pill_tracker': 'மாத்திரை நினைவூட்டல்',
      'pill_tracker_sub': 'தினசரி மருந்துகள்',
      'symptom_checker': 'அறிகுறி சரிபார்ப்பு',
      'symptom_checker_sub': 'OPD அறை கண்டறிய',
      'health_vitals': 'சுகாதாரத் தரவு & BMI',
      'health_vitals_sub': 'எடை & சர்க்கரை நிலை',
      'slot_active_today': 'இன்று செயலில் உள்ள டோக்கன்',
      'countdown': 'மீதமுள்ள நேரம்',
      'token': 'டோக்கன்',
      'present_qr': 'கவுண்டரில் QR குறியீட்டைக் காண்பி',
      'role_patient': 'நோயாளி (PATIENT)',
      'nic': 'அடையாள அட்டை',
      'phone': 'தொலைபேசி',

      // Symptom Checker
      'select_symptom_title': '1. முதன்மை அறிகுறி / வரிசையைத் தேர்ந்தெடுக்கவும்',
      'symptom_intensity': '2. அறிகுறி தீவிர நிலை',
      'mild': 'லேசான (Mild)',
      'moderate': 'மிதமான (Moderate)',
      'severe': 'கடுமையான (Severe)',
      'recommended_clinic': 'பரிந்துரைக்கப்பட்ட மருத்துவறை',
      'high_priority': 'அதி முக்கியத்துவம்',
      'guidance': 'வழிகாட்டுதல்',
      'pre_visit_checklist': '📋 OPD வருகைக்கு முந்தைய சரிபார்ப்புப் பட்டியல்:',
      'book_opd_now': 'இப்போதே OPD டோக்கன் பெறவும்',

      // Symptoms Items
      'symptom_fever_title': 'காய்ச்சல், இருமல் & உடல் வலி',
      'symptom_fever_desc': 'காய்ச்சல், சளி மற்றும் வலிகளுக்காக 4 மருத்துவர்கள் உள்ள பொது OPD அறை.',
      'symptom_wounds_title': 'காயங்கள், வெட்டுகள் & கொப்புளங்கள்',
      'symptom_wounds_desc': 'காயங்களை சுத்தம் செய்தல் மற்றும் கட்டு போடும் அறை.',
      'symptom_injection_title': 'ஊசி செலுத்துதல்',
      'symptom_injection_desc': 'மருத்துவரால் பரிந்துரைக்கப்பட்ட ஊசிகளைப் பெறுவதற்கான வரிசை.',
      'symptom_animal_title': 'விலங்கு கடி சிகிச்சை',
      'symptom_animal_desc': 'நாய்/பூனை கடி மற்றும் வெறிநாய் தடுப்பூசிக்கான சிறப்பு மருத்துவறை.',
      'symptom_blood_title': 'இரத்த மாதிரி சேகரிப்பு',
      'symptom_blood_desc': 'இரத்தப் பரிசோதனைக்கான மாதிரி சேகரிக்கும் அறை.',

      // Book Appointment
      'select_clinic_room': 'OPD அறையைத் தேர்ந்தெடுக்கவும்',
      'select_date': 'வருகை தேதியைத் தேர்ந்தெடுக்கவும்',
      'live_queue_status': 'நேரலை வரிசை நிலை',
      'patients_waiting': 'இன்று வரிசையில் காத்திருக்கும் நோயாளிகள்',
      'book_token_now': 'OPD டோக்கன் பெறவும்',
      'my_appointments': 'என் OPD பதிவுகள்',
      'active_token': 'செயலில் உள்ள டோக்கன்',
      'queue_position': 'வரிசை நிலை',
      'cancel_appointment': 'முன்பதிவை ரத்து செய்',
      'scan_qr_at_counter': 'கவுண்டரில் QR குறியீட்டை ஸ்கேன் செய்யவும்',

      // Profile Screen
      'patient_profile': 'நோயாளி சுயவிவரம்',
      'personal_info': 'சுய விவரங்கள்',
      'contact_location': 'தொடர்பு & முகவரி',
      'emergency_contact': 'அவசர தொடர்பு',
      'medical_background': 'மருத்துவ பின்னணி',
      'full_name': 'முழு பெயர்',
      'dob': 'பிறந்த தேதி',
      'gender': 'பாலினம்',
      'civil_status': 'திருமண நிலை',
      'address': 'முகவரி',
      'district': 'மாவட்டம்',
      'blood_group': 'இரத்த வகை',
      'allergies': 'ஒவ்வாமைகள் (Allergies)',
      'medical_conditions': 'மருத்துவ நிலைமைகள்',
      'edit_profile': 'சுயவிவரத்தைத் திருத்து',
      'save_changes': 'மாற்றங்களைச் சேமி',
      'delete_profile': 'கணக்கை நீக்கு',
      'change_photo': 'படத்தை மாற்று',

      // Helplines & Guides
      'emergency_helplines': 'OPD அவசர உதவி எண்கள்',
      'suwa_seriya': '1990 சுவ செரிய ஆம்புலன்ஸ்',
      'suwa_seriya_sub': 'இலவச 24/7 தேசிய அவசர உதவி எண்',
      'hospital_triage': 'தேசிய மருத்துவமனை OPD வரவேற்பு',
      'triage_sub': 'OPD வரவேற்பு & அவசர சிகிச்சை வாயில்',
      'pharmacy_desk': 'OPD மருந்தகம்',
      'pharmacy_sub': 'மருந்துச் சீட்டு விசாரணைகள்',
      'counter_guide_title': 'OPD மருத்துவமனை கவுண்டர் வழிகாட்டி',
      'counter_guide_sub': 'OPD பார்வையாளர்களுக்கான கவுண்டர் இடங்கள்',
      'family_cards_title': 'குடும்ப OPD கார்டுகள்',
      'family_cards_sub': 'ஒரே கணக்கின் மூலம் குடும்ப உறுப்பினர்களின் டோக்கன்களை நிர்வகிக்கவும்.',
      'add_family_member': 'உறுப்பினரைச் சேர்',
      'app_settings': 'செயலி அமைப்புகள்',
      'help_faq': 'OPD உதவி & கேள்விகள்',
      'close': 'மூடு',
    },
  };
}
