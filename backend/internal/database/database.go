package database

import (
	"log"
	"strings"

	"mediq-backend/internal/models"
	"mediq-backend/internal/utils"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

var DB *gorm.DB

func InitDB(databaseURL string) *gorm.DB {
	db, err := gorm.Open(postgres.Open(databaseURL), &gorm.Config{})
	if err != nil {
		log.Printf("Warning: Failed to connect to PostgreSQL database: %v", err)
		return nil
	}

	// Pre-migration cleanup: drop stale unique indexes and constraints.
	// In PostgreSQL, GORM's AutoMigrate checks system catalogs and attempts
	// to drop old unique constraints/indexes when a struct tag changes from
	// uniqueIndex to index. Running explicit DROP INDEX / DROP CONSTRAINT WITH
	// IF EXISTS removes them cleanly so GORM doesn't attempt broken SQL.
	staleItems := []struct{ table, name string }{
		{"users", "uni_users_nic"},
		{"users", "uni_users_email"},
		{"users", "uni_users_google_id"},
	}
	for _, item := range staleItems {
		db.Exec(`DROP INDEX IF EXISTS "` + item.name + `" CASCADE`)
		db.Exec(`ALTER TABLE "` + item.table + `" DROP CONSTRAINT IF EXISTS "` + item.name + `" CASCADE`)
	}

	// Ensure opd_appointments table columns have correct string data types in PostgreSQL
	db.Exec(`
		DO $$ 
		BEGIN 
			IF EXISTS (
				SELECT 1 FROM information_schema.columns 
				WHERE table_name = 'opd_appointments' 
				  AND column_name = 'appointment_time' 
				  AND data_type NOT IN ('character varying', 'text')
			) THEN 
				ALTER TABLE opd_appointments ALTER COLUMN appointment_time TYPE varchar(50) USING appointment_time::text;
			END IF;

			IF EXISTS (
				SELECT 1 FROM information_schema.columns 
				WHERE table_name = 'opd_appointments' 
				  AND column_name = 'appointment_date' 
				  AND data_type NOT IN ('character varying', 'text')
			) THEN 
				ALTER TABLE opd_appointments ALTER COLUMN appointment_date TYPE varchar(20) USING appointment_date::text;
			END IF;
		END $$;
	`)

	// Auto-migrate all tables. If migration fails only due to the known stale
	// constraint issue (which we already cleaned up above), log a warning and
	// continue — the server is still functional.
	if err := db.AutoMigrate(
		&models.User{},
		&models.Doctor{},
		&models.AdminStaffAssignment{},
		&models.MedicalRecord{},
		&models.OPDAppointment{},
		&models.QueueSession{},
		&models.ChatMessage{},
		&models.ChatFAQ{},
	); err != nil {
		// Treat missing-constraint errors as non-fatal warnings
		if strings.Contains(err.Error(), "does not exist (SQLSTATE 42704)") {
			log.Printf("Warning: non-fatal migration issue (stale constraint already cleaned): %v", err)
		} else {
			log.Printf("Failed to auto-migrate database schema: %v", err)
		}
	} else {
		log.Println("Database schema auto-migrated successfully (Users, Doctors, StaffAssignments, MedicalRecords, OPDAppointments, QueueSessions, ChatMessages, ChatFAQs)")
	}

	// Ensure ChatFAQ table is always created even if main AutoMigrate had a non-fatal error
	if err := db.AutoMigrate(&models.ChatFAQ{}); err != nil {
		log.Printf("Warning: ChatFAQ migration issue: %v", err)
	}

	log.Println("Database connection established successfully")
	DB = db
	seedDefaultUsers(db)
	seedDefaultChatFAQsOnStartup(db)

	// Fix PostgreSQL sequence desynchronization for primary keys across all tables
	db.Exec(`
		DO $$ 
		DECLARE 
			tbl text;
			seq text;
			max_id bigint;
		BEGIN 
			FOR tbl IN 
				SELECT table_name 
				FROM information_schema.tables 
				WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
			LOOP 
				seq := pg_get_serial_sequence(tbl, 'id');
				IF seq IS NOT NULL THEN 
					EXECUTE format('SELECT COALESCE(MAX(id), 0) FROM %I', tbl) INTO max_id;
					IF max_id > 0 THEN 
						EXECUTE format('SELECT setval(%L, %s)', seq, max_id);
					END IF;
				END IF;
			END LOOP;
		END $$;
	`)

	return db
}

// seedDefaultUsers creates default Doctor, Staff, and Admin accounts if they do not exist
func seedDefaultUsers(db *gorm.DB) {
	type DefaultUser struct {
		Name     string
		NIC      string
		Phone    string
		Password string
		Role     models.UserRole
	}

	defaults := []DefaultUser{
		{Name: "Dr. Suneth Perera", NIC: "198500100200", Phone: "0771112223", Password: "Doctor@123", Role: models.RoleDoctor},
		{Name: "Staff Member (OPD)", NIC: "199000100200", Phone: "0772223334", Password: "Staff@123", Role: models.RoleStaff},
		{Name: "System Admin", NIC: "200305000933", Phone: "0773334445", Password: "Admin@123", Role: models.RoleAdmin},
	}

	for _, d := range defaults {
		var count int64
		db.Model(&models.User{}).Where("nic = ?", d.NIC).Count(&count)
		if count == 0 {
			hashed, err := utils.HashPassword(d.Password)
			if err != nil {
				continue
			}
			user := models.User{
				FullName: strings.TrimSpace(d.Name),
				NIC:      d.NIC,
				Phone:    d.Phone,
				Password: hashed,
				Role:     d.Role,
				Status:   models.StatusActive,
			}
			if err := db.Create(&user).Error; err == nil {
				log.Printf("[Seeder] Created default account: %s (%s) | Role: %s\n", d.Name, d.NIC, d.Role)
			}
		}
	}
}

// seedDefaultChatFAQsOnStartup seeds the built-in FAQ entries the first time the server starts.
// It checks if the chat_faqs table is empty before inserting to avoid duplicates on restart.
func seedDefaultChatFAQsOnStartup(db *gorm.DB) {
	var count int64
	db.Model(&models.ChatFAQ{}).Count(&count)
	if count > 0 {
		return // already seeded
	}

	defaults := []models.ChatFAQ{
		// ── Greetings ──────────────────────────────────────────────────────────────
		{
			Category: "greeting",
			Keywords: "hello,hi,hey,ayubowan,vanakkam,good morning,good afternoon,good evening,ආයුබෝවන්,வணக்கம்",
			AnswerEN: "👋 Hello! I am MediQ AI Assistant. How can I help you today?\n\nYou can ask me about:\n• 📅 Booking appointments\n• 🏥 OPD queue status\n• 🚪 Available rooms & doctors\n• 💊 Medications & prescriptions\n• 📁 Medical records",
			AnswerSI: "👋 ආයුබෝවන්! මම MediQ AI සහකාරයයි. ඔබට කෙසේ උදව් කළ හැකිද?\n\n• 📅 Appointments book කිරීම\n• 🏥 OPD queue status\n• 🚪 Rooms & Doctors\n• 💊 Medicines\n• 📁 Medical Records",
			AnswerTA: "👋 வணக்கம்! நான் MediQ AI உதவியாளர்.\n\n• 📅 சந்திப்பு பதிவு\n• 🏥 OPD வரிசை\n• 🚪 அறைகள் & மருத்துவர்கள்\n• 💊 மருந்துகள்\n• 📁 பதிவுகள்",
			Priority: 10,
			IsActive: true,
		},
		// ── Appointment ────────────────────────────────────────────────────────────
		{
			Category:     "appointment",
			Keywords:     "book,appointment,channel,reserve,schedule,slot,channeling,booking,appointment book,doctor appointment,appointment wl,book appointment,appoint,appointment ekata,appointments,appointment ek,appointment details,book krnna,weiiting,room wlin,room wlin book,rooms wlin krn,rooms wlin krnna,appointment wlin,appointment krna,appointment dina,apointment,appoinment,சந்திப்பு,பதிவு",
			AnswerEN:     "📅 **Booking a Doctor Appointment:**\n\n1. Tap **'Book Appointment'** on the home screen\n2. Select your preferred **OPD Room** & **Doctor**\n3. Pick a **date** and **time slot**\n4. Confirm — you'll get a **QR token** instantly!",
			AnswerSI:     "📅 **Doctor Appointment Book කරන ආකාරය:**\n\n1. Home screen ෙකහි **'Book Appointment'** tap කරන්න\n2. ඔබට අවශ්‍ය **OPD Room** සහ **Doctor** select කරන්න\n3. **Date** සහ **Time slot** select කරන්න\n4. Confirm කරන්න — **QR token** ලැබේ!",
			AnswerTA:     "📅 **மருத்துவர் சந்திப்பு பதிவு:**\n\n1. **'Book Appointment'** தட்டவும்\n2. **OPD அறை** மற்றும் **மருத்துவர்** தேர்வு\n3. **தேதி** மற்றும் **நேரம்** தேர்வு\n4. உறுதிப்படுத்தவும் — **QR token** கிடைக்கும்!",
			IsLiveData:   true,
			LiveDataType: "doctors",
			Priority:     9,
			IsActive:     true,
		},
		// ── OPD Queue ─────────────────────────────────────────────────────────────
		{
			Category:     "queue",
			Keywords:     "queue,ticket,token,waiting,opd,live queue,turn,number,queue status,my turn,when,wait,queue eka,queue number,opd queue,queue ticket,opd ticket,queue ekata,வரிசை,வரிசை நிலை",
			AnswerEN:     "🏥 **OPD Live Queue:**\n\n• Open **'Patient Live Queue'** from the home screen\n• Scan your **QR code** or enter your **token number**\n• Queue updates **in real-time**!",
			AnswerSI:     "🏥 **OPD Live Queue:**\n\n• Home screen ෙකහි **'Patient Live Queue'** open කරන්න\n• **QR code** scan කරන්න හෝ **token number** enter කරන්න\n• Real-time updates!",
			AnswerTA:     "🏥 **OPD நேரடி வரிசை:**\n\n• **'Patient Live Queue'** திறக்கவும்\n• **QR குறியீடு** ஸ்கேன் செய்யவும்\n• நேரடியாக புதுப்பிக்கப்படும்!",
			IsLiveData:   true,
			LiveDataType: "queue",
			Priority:     9,
			IsActive:     true,
		},
		// ── Rooms ─────────────────────────────────────────────────────────────────
		{
			Category:     "rooms",
			Keywords:     "room,rooms,available room,opd room,dressing,injection,bleeding,animal bite,dispensary,clinic,room list,room eka,rooms eka,room wl,rooms wl,room wlin,rooms wlin,room wlin book,room booking,room available,available rooms,room details,அறை,அறைகள்",
			AnswerEN:     "🚪 **OPD Rooms at MediQ:**\n\n• 🩹 Dressing Room\n• 💉 Injection Room\n• 🩸 Bleeding Room\n• 🐾 Animal Bite Room\n• 🏥 OPD Clinic Room\n• 💊 Dispensary Room",
			AnswerSI:     "🚪 **MediQ OPD Rooms:**\n\n• 🩹 Dressing Room\n• 💉 Injection Room\n• 🩸 Bleeding Room\n• 🐾 Animal Bite Room\n• 🏥 OPD Clinic Room\n• 💊 Dispensary Room",
			AnswerTA:     "🚪 **MediQ OPD அறைகள்:**\n\n• 🩹 ஆடை அறை\n• 💉 ஊசி அறை\n• 🩸 இரத்தப்போக்கு அறை\n• 🐾 விலங்கு கடி அறை\n• 🏥 OPD கிளினிக் அறை\n• 💊 மருந்து அறை",
			IsLiveData:   true,
			LiveDataType: "rooms",
			Priority:     8,
			IsActive:     true,
		},
		// ── Doctors ───────────────────────────────────────────────────────────────
		{
			Category:     "doctors",
			Keywords:     "doctor,doctors,available doctor,which doctor,specialist,doctor list,doctor name,doctor info,see doctor,consult,consultation,doctor wl,doctors list,doctor eka,doctor neme,find a doctor,மருத்துவர்,மருத்துவர்கள்",
			AnswerEN:     "👨‍⚕️ **Available Doctors:**\n\nCheck live doctor data below for names, specializations, and rooms.\n\n💡 Book via **'Book Appointment'** on the home screen.",
			AnswerSI:     "👨‍⚕️ **Available Doctors:**\n\nLive doctor data පහතින් බලන්න.\n\n💡 **'Book Appointment'** ෙකන් book කරන්න.",
			AnswerTA:     "👨‍⚕️ **கிடைக்கக்கூடிய மருத்துவர்கள்:**\n\nகீழே நேரடி தரவு காண்க.\n\n💡 **'Book Appointment'** மூலம் பதிவு செய்யலாம்.",
			IsLiveData:   true,
			LiveDataType: "doctors",
			Priority:     8,
			IsActive:     true,
		},
		// ── My Appointments ───────────────────────────────────────────────────────
		{
			Category: "my_appointments",
			Keywords: "my appointment,my booking,cancel appointment,upcoming appointment,my ticket,my token,cancel,cancel my appointment,appointment cancel,cancel booking,ennda appointment,mata appointment,my appt,my appointment eka,எனது சந்திப்பு",
			AnswerEN: "📋 **Your Appointments:**\n\n• Tap **'My Appointments'** to view all bookings\n• **Cancel** upcoming appointments if needed\n• Use your **QR code** for check-in\n\n⚠️ Cancel at least 1 hour before your slot.",
			AnswerSI: "📋 **ඔබේ Appointments:**\n\n• **'My Appointments'** open කරන්න\n• Upcoming appointments cancel කළ හැකිය\n• **QR code** check-in සඳහා use කරන්න\n\n⚠️ 1 ෙගාඩකට කලින් cancel කරන්න.",
			AnswerTA: "📋 **உங்கள் சந்திப்புகள்:**\n\n• **'My Appointments'** திறக்கவும்\n• சந்திப்புகளை **ரத்து** செய்யலாம்\n• **QR குறியீடு** உள்நுழைவிற்கு\n\n⚠️ 1 மணி நேரத்திற்கு முன்னர் ரத்து செய்யுங்கள்.",
			Priority: 7,
			IsActive: true,
		},
		// ── Medications ───────────────────────────────────────────────────────────
		{
			Category: "medications",
			Keywords: "pill,medicine,prescription,remind,medication,dosage,drug,tablet,capsule,pill tracker,medicines,pill reminder,dose,pill ek,medicine ek,prescription eka,மருந்து,மாத்திரை",
			AnswerEN: "💊 **Medications & Pill Tracker:**\n\n• Access **'Pill Tracker'** from home\n• Add medications with dosage & schedule\n• Enable **push notifications** for reminders\n• View prescriptions in **'Medical Records'**",
			AnswerSI: "💊 **Medications & Pill Tracker:**\n\n• Home screen ෙකහි **'Pill Tracker'** open කරන්න\n• Dosage සහ schedule සමඟ add කරන්න\n• **Push notifications** enable කරන්න",
			AnswerTA: "💊 **மருந்துகள் & மாத்திரை ட்ராக்கர்:**\n\n• **'Pill Tracker'** திறக்கவும்\n• அளவு மற்றும் அட்டவணை சேர்க்கவும்\n• **அறிவிப்புகளை** இயக்கவும்",
			Priority: 7,
			IsActive: true,
		},
		// ── Medical Records ───────────────────────────────────────────────────────
		{
			Category: "records",
			Keywords: "record,lab,report,history,medical record,lab report,test result,medical history,health record,upload report,digital record,records,lab results,health reports,record eka,records eka,lab eka,lab report eka,மருத்துவ பதிவுகள்,ஆய்வக அறிக்கை",
			AnswerEN: "📁 **Medical Records:**\n\n• Go to **'Medical Records'** from home\n• View digital prescriptions & lab reports\n• **Upload** doctor notes or PDF reports\n• All records are **encrypted** and private",
			AnswerSI: "📁 **Medical Records:**\n\n• Home screen ෙකහි **'Medical Records'** open කරන්න\n• Prescriptions සහ lab reports බලන්න\n• PDF reports **upload** කරන්න",
			AnswerTA: "📁 **மருத்துவ பதிவுகள்:**\n\n• **'Medical Records'** திறக்கவும்\n• மருந்துச் சீட்டுகள் & ஆய்வக அறிக்கைகள் காண்க\n• PDF **பதிவேற்றவும்**",
			Priority: 6,
			IsActive: true,
		},
		// ── Symptoms ──────────────────────────────────────────────────────────────
		{
			Category: "symptoms",
			Keywords: "fever,headache,cold,cough,symptom,pain,sick,illness,vomit,nausea,dizzy,rash,allergy,stomach,chest pain,breathing,sore throat,body pain,back pain,what to do,symptom checker,நோய் அறிகுறிகள்",
			AnswerEN: "🌡️ **Symptom Guidance:**\n\n• Use **'Symptom Checker'** on the home screen\n• Mild symptoms: stay hydrated and rest\n• Moderate symptoms: book an OPD appointment\n\n⚠️ Emergency if: fever >102°F, chest pain, breathing difficulty, unconsciousness",
			AnswerSI: "🌡️ **Symptom Guidance:**\n\n• **'Symptom Checker'** use කරන්න\n• Mild: hydration, rest\n• Moderate: OPD appointment book කරන්න\n\n⚠️ Emergency: fever >102°F, chest pain",
			AnswerTA: "🌡️ **நோய் அறிகுறி வழிகாட்டல்:**\n\n• **'Symptom Checker'** பயன்படுத்தவும்\n• லேசான: நீர்ப்பசை, ஓய்வு\n• மிதமான: OPD சந்திப்பு\n\n⚠️ அவசரம்: காய்ச்சல் >102°F, மார்பு வலி",
			Priority: 6,
			IsActive: true,
		},
		// ── Emergency ─────────────────────────────────────────────────────────────
		{
			Category: "emergency",
			Keywords: "emergency,urgent,help,ambulance,911,1990,accident,critical,life threatening,emergency line,call ambulance,suwa seriya,please help,danger,அவசரநிலை,அவசர",
			AnswerEN: "🚨 **Emergency Contacts:**\n\n• 🚑 Suwa Seriya: **1990** (24/7 Free)\n• 🏥 MediQ Emergency: **011-234-5678**\n• 🚒 Police: **119**\n• 🔥 Fire & Rescue: **110**",
			AnswerSI: "🚨 **Emergency Contacts:**\n\n• 🚑 Suwa Seriya: **1990** (24/7)\n• 🏥 MediQ: **011-234-5678**\n• 🚒 Police: **119**\n• 🔥 Fire: **110**",
			AnswerTA: "🚨 **அவசர தொடர்புகள்:**\n\n• 🚑 Suwa Seriya: **1990** (24/7)\n• 🏥 MediQ: **011-234-5678**\n• 🚒 காவல்: **119**\n• 🔥 தீயணைப்பு: **110**",
			Priority: 10,
			IsActive: true,
		},
		// ── Profile ───────────────────────────────────────────────────────────────
		{
			Category: "profile",
			Keywords: "profile,nic,account,personal details,update profile,change password,edit profile,user profile,account settings,my profile,my account,profile eka,profile update,என் சுயவிவரம்",
			AnswerEN: "👤 **User Profile:**\n\n• Tap **'Profile'** from the home screen\n• Update: Name, NIC, Phone, Address, Emergency contact\n• Change your **password** securely",
			AnswerSI: "👤 **User Profile:**\n\n• **'Profile'** tap කරන්න\n• Name, NIC, Phone update කරන්න\n• **Password** change කරන්න",
			AnswerTA: "👤 **பயனர் சுயவிவரம்:**\n\n• **'Profile'** தட்டவும்\n• பெயர், NIC, தொலைபேசி புதுப்பிக்கவும்\n• **கடவுச்சொல்** மாற்றலாம்",
			Priority: 5,
			IsActive: true,
		},
		// ── Working Hours ─────────────────────────────────────────────────────────
		{
			Category: "hours",
			Keywords: "hour,open,time,working hours,location,address,when open,opd hours,clinic hours,hospital hours,hours,open hours,hospital time,hospital location,மருத்துவமனை நேரம்",
			AnswerEN: "🕒 **MediQ Working Hours:**\n\n• 🏥 OPD: Mon-Sun 7:00 AM – 9:00 PM\n• 🚨 Emergency: 24/7\n• 💊 Pharmacy & Lab: 24/7\n• 🩺 Specialist Clinics: By appointment",
			AnswerSI: "🕒 **MediQ Working Hours:**\n\n• 🏥 OPD: Mon-Sun 7:00 AM – 9:00 PM\n• 🚨 Emergency: 24/7\n• 💊 Pharmacy & Lab: 24/7",
			AnswerTA: "🕒 **MediQ இயக்க நேரம்:**\n\n• 🏥 OPD: திங்கள்-ஞாயிறு 7:00 AM – 9:00 PM\n• 🚨 அவசர: 24/7\n• 💊 மருந்தகம்: 24/7",
			Priority: 5,
			IsActive: true,
		},
		// ── Health Vitals ──────────────────────────────────────────────────────────
		{
			Category: "vitals",
			Keywords: "vital,blood pressure,bp,heart rate,weight,bmi,health check,vitals,health vitals,blood sugar,oxygen,spo2,temperature,pulse,vitals eka,vitals data,ஆரோக்கிய அறிகுறிகள்,இரத்த அழுத்தம்",
			AnswerEN: "❤️ **Health Vitals Tracking:**\n\n• Access **'Health Vitals'** from home\n• Track: Blood Pressure, Heart Rate, Weight/BMI, Blood Sugar, SpO2, Temperature\n• View **history graphs** over time",
			AnswerSI: "❤️ **Health Vitals Tracking:**\n\n• **'Health Vitals'** open කරන්න\n• BP, Heart Rate, Weight, Sugar, SpO2 track කරන්න",
			AnswerTA: "❤️ **ஆரோக்கிய அறிகுறி கண்காணிப்பு:**\n\n• **'Health Vitals'** திறக்கவும்\n• இரத்த அழுத்தம், இதயத் துடிப்பு, எடை கண்காணிக்கவும்",
			Priority: 5,
			IsActive: true,
		},
	}

	seeded := 0
	for i := range defaults {
		if err := db.Create(&defaults[i]).Error; err == nil {
			seeded++
		}
	}
	if seeded > 0 {
		log.Printf("[Seeder] Seeded %d default ChatFAQs\n", seeded)
	}
}
