package handlers

import (
	"net/http"
	"strconv"

	"mediq-backend/internal/database"
	"mediq-backend/internal/models"

	"github.com/gin-gonic/gin"
)

type ChatFAQHandler struct{}

func NewChatFAQHandler() *ChatFAQHandler {
	return &ChatFAQHandler{}
}

// ---- Request structs ----

type CreateFAQRequest struct {
	Category     string `json:"category" binding:"required"`
	Keywords     string `json:"keywords" binding:"required"` // comma-separated
	AnswerEN     string `json:"answer_en" binding:"required"`
	AnswerSI     string `json:"answer_si"`
	AnswerTA     string `json:"answer_ta"`
	IsLiveData   bool   `json:"is_live_data"`
	LiveDataType string `json:"live_data_type"`
	Priority     int    `json:"priority"`
	IsActive     *bool  `json:"is_active"`
}

type UpdateFAQRequest struct {
	Category     *string `json:"category"`
	Keywords     *string `json:"keywords"`
	AnswerEN     *string `json:"answer_en"`
	AnswerSI     *string `json:"answer_si"`
	AnswerTA     *string `json:"answer_ta"`
	IsLiveData   *bool   `json:"is_live_data"`
	LiveDataType *string `json:"live_data_type"`
	Priority     *int    `json:"priority"`
	IsActive     *bool   `json:"is_active"`
}

// ListFAQs - GET /api/v1/admin/chat-faqs
// Returns all FAQs (including inactive) for admin management
func (h *ChatFAQHandler) ListFAQs(c *gin.Context) {
	if database.DB == nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "Database unavailable"})
		return
	}

	var faqs []models.ChatFAQ
	query := database.DB.Order("priority DESC, id ASC")

	// optional filter by category
	if cat := c.Query("category"); cat != "" {
		query = query.Where("category = ?", cat)
	}
	// optional filter by active only
	if c.Query("active") == "true" {
		query = query.Where("is_active = true")
	}

	if err := query.Find(&faqs).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve FAQs"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "success", "data": faqs, "count": len(faqs)})
}

// CreateFAQ - POST /api/v1/admin/chat-faqs
func (h *ChatFAQHandler) CreateFAQ(c *gin.Context) {
	if database.DB == nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "Database unavailable"})
		return
	}

	var req CreateFAQRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	isActive := true
	if req.IsActive != nil {
		isActive = *req.IsActive
	}

	faq := models.ChatFAQ{
		Category:     req.Category,
		Keywords:     req.Keywords,
		AnswerEN:     req.AnswerEN,
		AnswerSI:     req.AnswerSI,
		AnswerTA:     req.AnswerTA,
		IsLiveData:   req.IsLiveData,
		LiveDataType: req.LiveDataType,
		Priority:     req.Priority,
		IsActive:     isActive,
	}

	if err := database.DB.Create(&faq).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create FAQ"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"status": "success", "data": faq})
}

// UpdateFAQ - PATCH /api/v1/admin/chat-faqs/:id
func (h *ChatFAQHandler) UpdateFAQ(c *gin.Context) {
	if database.DB == nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "Database unavailable"})
		return
	}

	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid FAQ ID"})
		return
	}

	var faq models.ChatFAQ
	if err := database.DB.First(&faq, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "FAQ not found"})
		return
	}

	var req UpdateFAQRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	updates := map[string]interface{}{}
	if req.Category != nil {
		updates["category"] = *req.Category
	}
	if req.Keywords != nil {
		updates["keywords"] = *req.Keywords
	}
	if req.AnswerEN != nil {
		updates["answer_en"] = *req.AnswerEN
	}
	if req.AnswerSI != nil {
		updates["answer_si"] = *req.AnswerSI
	}
	if req.AnswerTA != nil {
		updates["answer_ta"] = *req.AnswerTA
	}
	if req.IsLiveData != nil {
		updates["is_live_data"] = *req.IsLiveData
	}
	if req.LiveDataType != nil {
		updates["live_data_type"] = *req.LiveDataType
	}
	if req.Priority != nil {
		updates["priority"] = *req.Priority
	}
	if req.IsActive != nil {
		updates["is_active"] = *req.IsActive
	}

	if err := database.DB.Model(&faq).Updates(updates).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update FAQ"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "success", "data": faq})
}

// DeleteFAQ - DELETE /api/v1/admin/chat-faqs/:id (soft delete)
func (h *ChatFAQHandler) DeleteFAQ(c *gin.Context) {
	if database.DB == nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "Database unavailable"})
		return
	}

	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid FAQ ID"})
		return
	}

	if err := database.DB.Delete(&models.ChatFAQ{}, id).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete FAQ"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "success", "message": "FAQ deleted successfully"})
}

// SeedDefaultFAQs - POST /api/v1/admin/chat-faqs/seed
// Seeds the default FAQ set into the database (skips if already seeded)
func (h *ChatFAQHandler) SeedDefaultFAQs(c *gin.Context) {
	if database.DB == nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "Database unavailable"})
		return
	}

	count, err := seedDefaultChatFAQs()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Seed failed: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status":  "success",
		"message": "Default FAQs seeded",
		"seeded":  count,
	})
}

// seedDefaultChatFAQs inserts the built-in FAQ set if the table is empty.
// Returns the number of rows inserted.
func seedDefaultChatFAQs() (int, error) {
	var existing int64
	database.DB.Model(&models.ChatFAQ{}).Count(&existing)
	if existing > 0 {
		return 0, nil // already seeded
	}

	defaults := []models.ChatFAQ{
		// ── Greetings ──────────────────────────────────────────────────────────────
		{
			Category: "greeting",
			Keywords: "hello,hi,hey,ayubowan,vanakkam,good morning,good afternoon,good evening,ආයුබෝවන්,வணக்கம்",
			AnswerEN: "👋 Hello! I am MediQ AI Assistant. How can I help you today?\n\nYou can ask me about:\n• 📅 Booking appointments\n• 🏥 OPD queue status\n• 🚪 Available rooms & doctors\n• 💊 Medications & prescriptions\n• 📁 Medical records",
			AnswerSI: "👋 ආයුබෝවන්! මම MediQ AI සහකාරයයි. අද ඔබට කෙසේ උදව් කළ හැකිද?\n\nඔබට මෙසේ ඇසිය හැකිය:\n• 📅 Appointments book කිරීම\n• 🏥 OPD queue status\n• 🚪 Rooms & Doctors ලැයිස්තුව\n• 💊 Medicines & Prescriptions\n• 📁 Medical Records",
			AnswerTA: "👋 வணக்கம்! நான் MediQ AI உதவியாளர். இன்று உங்களுக்கு எப்படி உதவலாம்?\n\nநீங்கள் கேட்கலாம்:\n• 📅 சந்திப்பு பதிவு செய்தல்\n• 🏥 OPD வரிசை நிலை\n• 🚪 அறைகள் & மருத்துவர்கள்\n• 💊 மருந்துகள்\n• 📁 மருத்துவ பதிவுகள்",
			Priority: 10,
			IsActive: true,
		},
		// ── Appointments ──────────────────────────────────────────────────────────
		{
			Category:     "appointment",
			Keywords:     "book,appointment,channel,reserve,schedule,appoint,slot,date,time,apa,channeling,booking,apointment,appoinment,apeoinment,aponiment,book appointment,doctor appointment,රෝගී,appointment book,சந்திப்பு,பதிவு,appointment எක",
			AnswerEN:     "📅 **Booking a Doctor Appointment:**\n\n1. Tap **'Book Appointment'** on the home screen\n2. Select your preferred **OPD Room** & **Doctor**\n3. Pick a **date** and **time slot**\n4. Confirm — you'll get a **QR token** instantly!\n\n💡 *Use the live data below to see available rooms and doctors right now.*",
			AnswerSI:     "📅 **Doctor Appointment Book කරන ආකාරය:**\n\n1. Home screen ෙකහි **'Book Appointment'** button eka tap කරන්න\n2. ඔබට අවශ්‍ය **OPD Room** සහ **Doctor** select කරන්න\n3. **Date** සහ **Time slot** select කරන්න\n4. Confirm කරන්න — ඔබට **QR token** එකක් ලැබේ!\n\n💡 *Available rooms සහ doctors දැන් live ෙලස බලන්නට පහත data use කරන්න.*",
			AnswerTA:     "📅 **மருத்துவர் சந்திப்பு பதிவு செய்வது எப்படி:**\n\n1. முகப்புத்திரையில் **'Book Appointment'** தட்டவும்\n2. **OPD அறை** மற்றும் **மருத்துவர்** தேர்வு செய்யவும்\n3. **தேதி** மற்றும் **நேர வாய்ப்பு** தேர்வு செய்யவும்\n4. உறுதிப்படுத்தவும் — **QR token** உடனடியாக கிடைக்கும்!",
			IsLiveData:   true,
			LiveDataType: "doctors",
			Priority:     9,
			IsActive:     true,
		},
		// ── OPD Queue ─────────────────────────────────────────────────────────────
		{
			Category:     "queue",
			Keywords:     "queue,ticket,token,waiting,opd,live queue,turn,number,queue status,my turn,when,waiting time,number,queue eka,queue number,queue tiket,waiiting,opa,opa queue,opd queue,queue ekata,queues,opd ticket,qdl,wait,ticket number,රෝගී queue,பொது நடைமுறை,வரிசை,வரிசை நிலை",
			AnswerEN:     "🏥 **OPD Live Queue:**\n\n• Open the **'Patient Live Queue'** screen from the home page\n• Scan your **QR code** or enter your **token number** to track your position\n• The queue updates **in real-time** so you know exactly when it's your turn!\n\n📍 Check the live room data below for current queue numbers.",
			AnswerSI:     "🏥 **OPD Live Queue:**\n\n• Home page ෙකහි **'Patient Live Queue'** screen open කරන්න\n• ඔබේ **QR code** scan කරන්න හෝ **token number** enter කරන්න\n• Queue **real-time** ෙලස update ෙවනවා!\n\n📍 Live room data සඳහා පහත data බලන්න.",
			AnswerTA:     "🏥 **OPD நேரடி வரிசை:**\n\n• முகப்புத்திரையிலிருந்து **'Patient Live Queue'** திரை திறக்கவும்\n• உங்கள் **QR குறியீடு** ஸ்கேன் செய்யவும் அல்லது **டோக்கன் எண்** உள்ளிடவும்\n• வரிசை **நேரடியாக** புதுப்பிக்கப்படுகிறது!",
			IsLiveData:   true,
			LiveDataType: "queue",
			Priority:     9,
			IsActive:     true,
		},
		// ── Available Rooms ───────────────────────────────────────────────────────
		{
			Category:     "rooms",
			Keywords:     "room,rooms,available room,which room,opd room,dressing,injection,bleeding,animal bite,dispensary,clinic,ward,what rooms,room list,room type,rooms available,room available,room booking,room reservation,available rooms,rooms,room details,room list,room eka,room data,room wl,rooms list,அறை,அறைகள்,rooms ekata,anantharoom,klng room,anantharoom,rooms wla,room wlin,anantharoom krnna,rooms wlin book",
			AnswerEN:     "🚪 **Available OPD Rooms:**\n\nHere are the OPD rooms at MediQ:\n\n• 🩹 **Dressing Room** — Wound dressing & minor procedures\n• 💉 **Injection Room** — Injections & IV treatments\n• 🩸 **Bleeding Room** — Bleeding control & urgent care\n• 🐾 **Animal Bite Room** — Animal bite treatment & vaccination\n• 🏥 **OPD Clinic Room** — General OPD consultations\n• 💊 **Dispensary Room** — Medicine dispensing\n\n📍 Check live room data below for current availability.",
			AnswerSI:     "🚪 **MediQ OPD Rooms:**\n\n• 🩹 **Dressing Room** — Wound dressing\n• 💉 **Injection Room** — Injections & IV\n• 🩸 **Bleeding Room** — Bleeding control\n• 🐾 **Animal Bite Room** — Animal bite & vaccine\n• 🏥 **OPD Clinic Room** — General OPD\n• 💊 **Dispensary Room** — Medicines\n\n📍 Live availability data පහතින් බලන්න.",
			AnswerTA:     "🚪 **MediQ OPD அறைகள்:**\n\n• 🩹 **ஆடை அறை** — காயம் கட்டுவது\n• 💉 **ஊசி அறை** — ஊசிகள் & IV\n• 🩸 **இரத்தப்போக்கு அறை** — இரத்தப்போக்கு கட்டுப்பாடு\n• 🐾 **விலங்கு கடி அறை** — சிகிச்சை & தடுப்பூசி\n• 🏥 **OPD கிளினிக் அறை** — பொது OPD\n• 💊 **மருந்து அறை** — மருந்து வழங்கல்",
			IsLiveData:   true,
			LiveDataType: "rooms",
			Priority:     8,
			IsActive:     true,
		},
		// ── Doctors ───────────────────────────────────────────────────────────────
		{
			Category:     "doctors",
			Keywords:     "doctor,doctors,doctor available,which doctor,available doctor,specialist,specialization,doctor list,doctor details,doctor name,doctor info,see doctor,which doctors,doctor wl,doctors list,available doctors,find doctor,see a doctor,consult,consultation,doctor wlin,doctors data,doctor today,doctor eka,doctor neme,doctor kiyala,doctor kiyanne,find a doctor,மருத்துவர்,மருத்துவர்கள்",
			AnswerEN:     "👨‍⚕️ **Available Doctors:**\n\nCheck the live doctor data below for:\n• Doctor names & specializations\n• Which OPD room they're in\n• Current availability status\n\n💡 You can book an appointment with any available doctor from the **'Book Appointment'** screen.",
			AnswerSI:     "👨‍⚕️ **Available Doctors:**\n\nLive doctor data සඳහා පහත බලන්න:\n• Doctor names & specializations\n• ඔවුන් සිටින OPD room\n• Availability status\n\n💡 **'Book Appointment'** screen ෙකන් available doctor ෙකක් book කරන්න.",
			AnswerTA:     "👨‍⚕️ **கிடைக்கக்கூடிய மருத்துவர்கள்:**\n\nகீழே நேரடி தரவு காண்க:\n• மருத்துவர் பெயர்கள் & சிறப்பு\n• OPD அறை\n• தற்போதைய கிடைக்கும் தன்மை\n\n💡 **'Book Appointment'** திரையில் பதிவு செய்யலாம்.",
			IsLiveData:   true,
			LiveDataType: "doctors",
			Priority:     8,
			IsActive:     true,
		},
		// ── My Appointments ───────────────────────────────────────────────────────
		{
			Category:     "my_appointments",
			Keywords:     "my appointment,my booking,my appointments,view my appointment,cancel appointment,appointment cancel,upcoming appointment,my ticket,my token,my reservations,ape apointment,mata appointment,mama book kala,my appt,cancel,cancel appointment,my appointment details,cancel booking,cancel my appointment,appointment cancel krnna,appointment eka cancel,cancel krnna,cancel ekata,cancel my,appointment cancel krl,ennda appointment,ennda booking,ennda ticket,ennda token,ennda token number,ennda token eka,ennda apa,my appointment eka,my apointment,எனது சந்திப்பு",
			AnswerEN:     "📋 **Your Appointments:**\n\n• Tap **'My Appointments'** from the home screen to view all bookings\n• You can **cancel** an upcoming appointment from there\n• Your **QR code token** is also available for check-in\n\n⚠️ *Please cancel at least 1 hour before your scheduled time if you cannot attend.*",
			AnswerSI:     "📋 **ඔබේ Appointments:**\n\n• Home screen ෙකහි **'My Appointments'** open කරන්න\n• Upcoming appointments **cancel** කළ හැකිය\n• **QR code token** check-in සඳහා use කරන්න\n\n⚠️ *ඔබට එන්නට නොහැකි නම් අවම වශෙයන් 1 ෙගාඩක් කලින් cancel කරන්න.*",
			AnswerTA:     "📋 **உங்கள் சந்திப்புகள்:**\n\n• முகப்புத்திரையிலிருந்து **'My Appointments'** திறக்கவும்\n• வரவிருக்கும் சந்திப்புகளை **ரத்து** செய்யலாம்\n• **QR குறியீடு** உள்நுழைவிற்கு பயன்படுத்தலாம்\n\n⚠️ *தயவுசெய்து கலந்துகொள்ள முடியாவிட்டால் 1 மணி நேரத்திற்கு முன்னர் ரத்து செய்யுங்கள்.*",
			Priority:     7,
			IsActive:     true,
		},
		// ── Prescriptions & Pill Tracker ─────────────────────────────────────────
		{
			Category: "medications",
			Keywords: "pill,medicine,prescription,remind,medication,dosage,drug,tablet,capsule,pill tracker,pill reminder,medicines,panadol,paracetamol,drug reminder,medication reminder,take medicine,pill schedule,medicine time,pill time,pill timing,medicine timing,dose,pills,medicines,medicine list,pill list,pill track,pill trcker,pill trackr,pill tracer,pill trkr,medicines reminder,medicine alert,pill alert,pill notification,medicine notification,tablet,pill ek,medicine ek,prescription eka,eka pill,pills eka,மருந்து,மாத்திரை",
			AnswerEN: "💊 **Medications & Pill Tracker:**\n\n• Access **'Pill Tracker'** from the home screen\n• Add your medications with **dosage** and **schedule**\n• Enable **push notifications** for timely reminders\n• View past prescriptions in **'Medical Records'**\n\n💡 Never miss a dose again!",
			AnswerSI: "💊 **Medications & Pill Tracker:**\n\n• Home screen ෙකහි **'Pill Tracker'** open කරන්න\n• ඔබේ medicines **dosage** සහ **schedule** සමඟ add කරන්න\n• Timely reminders සඳහා **push notifications** enable කරන්න\n• **'Medical Records'** ෙකහි past prescriptions බලන්න\n\n💡 කිෙසදාවත් dose miss ෙනෙකරන්න!",
			AnswerTA: "💊 **மருந்துகள் & மாத்திரை ட்ராக்கர்:**\n\n• முகப்புத்திரையிலிருந்து **'Pill Tracker'** திறக்கவும்\n• **அளவு** மற்றும் **அட்டவணையுடன்** மருந்துகளை சேர்க்கவும்\n• **புஷ் அறிவிப்புகளை** இயக்கவும்\n• **'Medical Records'** இல் கடந்த மருந்துச் சீட்டுகளை காண்க",
			Priority: 7,
			IsActive: true,
		},
		// ── Medical Records ───────────────────────────────────────────────────────
		{
			Category: "records",
			Keywords: "record,lab,report,history,medical record,lab report,test result,prescription history,past visit,medical history,health record,lab test,blood test,scan,x-ray,mri,ct scan,upload report,upload prescription,digital record,records,medical records,lab results,health history,health data,reports,tests,record eka,records eka,lab eka,lab report eka,report eka,report wl,record wl,lab report wl,lab reports,health reports,health data eka,records wl,medical records ekata,medical records wl,test reports,மருத்துவ பதிவுகள்,ஆய்வக அறிக்கை",
			AnswerEN: "📁 **Medical Records:**\n\n• Go to **'Medical Records'** from the home screen\n• View **digital prescriptions**, **lab reports**, and consultation notes\n• **Upload** doctor notes or PDF reports securely\n• All records are **encrypted** and private\n\n🔒 Your medical data is always safe with MediQ.",
			AnswerSI: "📁 **Medical Records:**\n\n• Home screen ෙකහි **'Medical Records'** open කරන්න\n• **Digital prescriptions**, **lab reports** සහ consultation notes බලන්න\n• Doctor notes හෝ PDF reports **upload** කරන්න\n• සියලු records **encrypted** ෙලස safe\n\n🔒 ඔබේ medical data MediQ සමඟ සෑමෙවලාෙව්ම safe.",
			AnswerTA: "📁 **மருத்துவ பதிவுகள்:**\n\n• முகப்புத்திரையிலிருந்து **'Medical Records'** திறக்கவும்\n• **டிஜிட்டல் மருந்துச் சீட்டுகள்** மற்றும் **ஆய்வக அறிக்கைகளை** காண்க\n• மருத்துவர் குறிப்புகள் அல்லது PDF **பதிவேற்றவும்**\n• அனைத்து பதிவுகளும் **என்கிரிப்ட்** செய்யப்பட்டவை",
			Priority: 6,
			IsActive: true,
		},
		// ── Symptoms ──────────────────────────────────────────────────────────────
		{
			Category: "symptoms",
			Keywords: "fever,headache,cold,cough,symptom,pain,sick,illness,disease,vomit,nausea,dizzy,rash,allergy,infection,stomach,chest pain,breathing,shortness of breath,sore throat,runny nose,body pain,back pain,joint pain,what to do,health advice,symptoms,feel sick,not well,unwell,health problem,health issue,health concern,ලෙඩය,ලෙඩ,ලෙඩ ලක්ෂණ,symptom checker,symptoms checker,நோய் அறிகுறிகள்",
			AnswerEN: "🌡️ **Symptom Guidance:**\n\n• Use the **'Symptom Checker'** on the home screen for automated triage\n• For **mild symptoms** (cold, headache): stay hydrated, rest, and monitor\n• For **moderate symptoms**: book an OPD appointment with a doctor\n\n⚠️ **Seek emergency care immediately for:**\n• High fever (>102°F / >39°C)\n• Chest pain or difficulty breathing\n• Severe head injury or trauma\n• Loss of consciousness",
			AnswerSI: "🌡️ **Symptom Guidance:**\n\n• Home screen ෙකහි **'Symptom Checker'** use කරන්න\n• **Mild symptoms** (cold, headache): hydration, rest\n• **Moderate symptoms**: OPD doctor appointment book කරන්න\n\n⚠️ **Emergency care ෙතොරාගන්න:**\n• High fever (>102°F)\n• Chest pain හෝ breathing ගැටළු\n• Severe head injury\n• Unconsciousness",
			AnswerTA: "🌡️ **நோய் அறிகுறி வழிகாட்டல்:**\n\n• முகப்புத்திரையில் **'Symptom Checker'** பயன்படுத்தவும்\n• **லேசான அறிகுறிகள்**: நீர்ப்பசை, ஓய்வு\n• **மிதமான அறிகுறிகள்**: OPD சந்திப்பு பதிவு செய்யவும்\n\n⚠️ **உடனடி அவசர சிகிச்சை:**\n• அதிக காய்ச்சல் (>102°F)\n• மார்பு வலி அல்லது சுவாசக் கஷ்டம்",
			Priority: 6,
			IsActive: true,
		},
		// ── Emergency ─────────────────────────────────────────────────────────────
		{
			Category: "emergency",
			Keywords: "emergency,urgent,help,ambulance,911,1990,accident,critical,life threatening,emergency line,emergency contact,call ambulance,urgent help,emergency number,call help,suwa seriya,urgent care,please help,danger,emergency ek,emergency ekata,ambulance eka,ambulance ekata,ambulance call,call ambulance,urgent situation,அவசரநிலை,அவசர",
			AnswerEN: "🚨 **Emergency Contacts:**\n\n• 🚑 **Suwa Seriya Ambulance:** 1990 (24/7 Free)\n• 🏥 **MediQ Emergency Line:** 011-234-5678\n• 🚒 **Police:** 119\n• 🔥 **Fire & Rescue:** 110\n\n⚠️ **Call 1990 immediately for:**\n• Chest pain / Heart attack\n• Severe breathing difficulty\n• Major accident / trauma\n• Loss of consciousness",
			AnswerSI: "🚨 **Emergency Contacts:**\n\n• 🚑 **Suwa Seriya Ambulance:** 1990 (24/7 Free)\n• 🏥 **MediQ Emergency Line:** 011-234-5678\n• 🚒 **Police:** 119\n• 🔥 **Fire & Rescue:** 110\n\n⚠️ **1990 dial කරන්න:**\n• Chest pain / Heart attack\n• Severe breathing difficulty\n• Major accident\n• Unconsciousness",
			AnswerTA: "🚨 **அவசர தொடர்புகள்:**\n\n• 🚑 **சுவ சேரியா ஆம்புலன்ஸ்:** 1990 (24/7)\n• 🏥 **MediQ அவசர எண்:** 011-234-5678\n• 🚒 **காவல்துறை:** 119\n• 🔥 **தீயணைப்பு:** 110\n\n⚠️ **உடனடியாக 1990 அழைக்கவும்:**\n• மார்பு வலி\n• சுவாசக் கஷ்டம்\n• விபத்து\n• மயக்கம்",
			Priority: 10,
			IsActive: true,
		},
		// ── Profile & Account ─────────────────────────────────────────────────────
		{
			Category: "profile",
			Keywords: "profile,nic,account,personal details,update profile,change password,edit profile,user profile,account settings,name,phone,address,contact,change name,change phone,change number,edit account,account info,profile update,profile edit,profile details,profile eka,profile eka change,profile eka edit,profile details eka,profile eka update,my profile,my account,my details,என் சுயவிவரம்",
			AnswerEN: "👤 **User Profile:**\n\n• Tap your **profile picture** or **'Profile'** from the home screen\n• You can update: Name, NIC, Phone, Address, Emergency contact\n• Change your **password** securely from the profile settings\n• Your data is always **private** and **encrypted**",
			AnswerSI: "👤 **User Profile:**\n\n• Home screen ෙකහි **profile picture** හෝ **'Profile'** tap කරන්න\n• Update කළ හැකිය: Name, NIC, Phone, Address, Emergency contact\n• Profile settings ෙකන් **password** change කරන්න\n• ඔබේ data සෑමෙවලාෙව්ම **private** සහ **encrypted**",
			AnswerTA: "👤 **பயனர் சுயவிவரம்:**\n\n• முகப்புத்திரையிலிருந்து **சுயவிவரப் படத்தை** தட்டவும்\n• பெயர், NIC, தொலைபேசி, முகவரி புதுப்பிக்கலாம்\n• **கடவுச்சொல்** மாற்றலாம்\n• உங்கள் தரவு **தனிப்பட்டது** மற்றும் **என்கிரிப்ட்** செய்யப்பட்டது",
			Priority: 5,
			IsActive: true,
		},
		// ── Working Hours ─────────────────────────────────────────────────────────
		{
			Category: "hours",
			Keywords: "hour,open,time,working hours,location,address,when open,opd hours,clinic hours,working time,open time,what time,hospital hours,pharmacy hours,lab hours,dispensary hours,operating hours,hospital time,hours,open hours,clinic open,hospital open,location eka,address eka,hospital ekata,hospital kiyanne,hospital yata,hospital details,hospital info,hospital location,hospital address,மருத்துவமனை நேரம்",
			AnswerEN: "🕒 **MediQ Working Hours:**\n\n| Department | Hours |\n|---|---|\n| 🏥 OPD Consultation | Mon - Sun: 7:00 AM – 9:00 PM |\n| 🚨 Emergency & Admissions | 24/7 Open |\n| 💊 Pharmacy & Lab | 24/7 Available |\n| 🩺 Specialist Clinics | By appointment only |\n\n📍 **Location:** MediQ Hospital, Colombo",
			AnswerSI: "🕒 **MediQ Working Hours:**\n\n| Department | Hours |\n|---|---|\n| 🏥 OPD Consultation | Mon - Sun: 7:00 AM – 9:00 PM |\n| 🚨 Emergency & Admissions | 24/7 Open |\n| 💊 Pharmacy & Lab | 24/7 |\n| 🩺 Specialist Clinics | Appointment only |\n\n📍 **Location:** MediQ Hospital, Colombo",
			AnswerTA: "🕒 **MediQ இயக்க நேரம்:**\n\n| துறை | நேரம் |\n|---|---|\n| 🏥 OPD ஆலோசனை | திங்கள் - ஞாயிறு: 7:00 AM – 9:00 PM |\n| 🚨 அவசர & அனுமதி | 24/7 |\n| 💊 மருந்தகம் & ஆய்வகம் | 24/7 |\n| 🩺 நிபுணர் கிளினிக் | சந்திப்பு மட்டும் |",
			Priority: 5,
			IsActive: true,
		},
		// ── Health Vitals ──────────────────────────────────────────────────────────
		{
			Category: "vitals",
			Keywords: "vital,blood pressure,bp,heart rate,weight,bmi,health check,vitals,health vitals,health data,blood sugar,sugar level,oxygen,spo2,temperature,pulse,health monitoring,vitals tracking,vitals eka,vitals data,vitals check,health vitals eka,health vitals data,health vitals check,health vitals tracking,health check up,vitals record,vital signs,ஆரோக்கிய அறிகுறிகள்,இரத்த அழுத்தம்",
			AnswerEN: "❤️ **Health Vitals Tracking:**\n\n• Access **'Health Vitals'** from the home screen\n• Track: Blood Pressure, Heart Rate, Weight/BMI, Blood Sugar, SpO2, Temperature\n• View your **health history graphs** over time\n• Share vitals with your doctor during consultations",
			AnswerSI: "❤️ **Health Vitals Tracking:**\n\n• Home screen ෙකහි **'Health Vitals'** open කරන්න\n• Track කළ හැකිය: Blood Pressure, Heart Rate, Weight/BMI, Blood Sugar, SpO2, Temperature\n• **History graphs** view කරන්න\n• Consultation ෙකදී doctor ෙකළ vitals share කරන්න",
			AnswerTA: "❤️ **ஆரோக்கிய அறிகுறி கண்காணிப்பு:**\n\n• முகப்புத்திரையிலிருந்து **'Health Vitals'** திறக்கவும்\n• இரத்த அழுத்தம், இதயத் துடிப்பு, எடை/BMI, இரத்த சர்க்கரை, SpO2 கண்காணிக்கவும்\n• **வரலாற்று வரைபடங்களை** காண்க",
			Priority: 5,
			IsActive: true,
		},
	}

	// Use bool pointer for IsActive field
	seeded := 0
	for _, faq := range defaults {
		faqCopy := faq
		if err := database.DB.Create(&faqCopy).Error; err == nil {
			seeded++
		}
	}

	return seeded, nil
}
