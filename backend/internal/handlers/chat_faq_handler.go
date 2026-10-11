package handlers

import (
	"log"
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
// Seeds or updates the default FAQ set into the database
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
		"message": "Default FAQs seeded & updated successfully",
		"seeded":  count,
	})
}

// InitChatFAQs initializes or updates the built-in FAQ set on server startup.
func InitChatFAQs() {
	if database.DB != nil {
		count, err := seedDefaultChatFAQs()
		if err != nil {
			log.Printf("[ChatFAQ] Failed to seed default FAQs: %v", err)
		} else {
			log.Printf("[ChatFAQ] Initialized/updated %d default FAQs", count)
		}
	}
}

// seedDefaultChatFAQs inserts or updates built-in FAQ records.
func seedDefaultChatFAQs() (int, error) {
	defaults := []models.ChatFAQ{
		// ── Greetings ──────────────────────────────────────────────────────────────
		{
			Category: "greeting",
			Keywords: "hello,hi,hey,ayubowan,vanakkam,good morning,good afternoon,good evening,ආයුබෝවන්,வணக்கம்,halaw,hallo",
			AnswerEN: "👋 Hello! I am MediQ AI Assistant. How can I help you today?\n\nYou can ask me about:\n• 👨‍⚕️ Available Doctors\n• 📅 Booking appointments\n• 🏥 OPD queue status\n• 🚪 Available rooms & doctors\n• 💊 Medications & prescriptions\n• 📁 Medical records",
			AnswerSI: "👋 ආයුබෝවන්! මම MediQ AI සහකාරයයි. අද ඔබට කෙසේ උදව් කළ හැකිද?\n\nඔබට මෙසේ ඇසිය හැකිය:\n• 👨‍⚕️ වෛද්‍යවරුන් කවුද? (Doctors List)\n• 📅 Appointments book කරන්නේ කොහොමද?\n• 🏥 OPD queue status\n• 🚪 Rooms & Doctors ලැයිස්තුව\n• 💊 Medicines & Prescriptions\n• 📁 Medical Records",
			AnswerTA: "👋 வணக்கம்! நான் MediQ AI உதவியாளர். இன்று உங்களுக்கு எப்படி உதவலாம்?\n\nநீங்கள் கேட்கலாம்:\n• 👨‍⚕️ மருத்துவர்கள் பட்டியல்\n• 📅 சந்திப்பு பதிவு செய்தல்\n• 🏥 OPD வரிசை நிலை\n• 🚪 அறைகள் & மருத்துவர்கள்\n• 💊 மருந்துகள்\n• 📁 மருத்துவ பதிவுகள்",
			Priority: 10,
			IsActive: true,
		},
		// ── Doctors ───────────────────────────────────────────────────────────────
		{
			Category:     "doctors",
			Keywords:     "doctor,doctors,doctersla,doctorla,doctala,dokthala,drla,docla,dokta,doc,docs,who,kwd,kwda,kawda,kuda,inwda,inawada,specialist,specialization,doctor list,doctor details,doctor name,doctor info,see doctor,which doctors,doctor wl,doctors list,available doctors,find doctor,see a doctor,consult,consultation,doctor wlin,doctors data,doctor today,doctor eka,doctor neme,doctor kiyala,doctor kiyanne,find a doctor,වෛද්‍යවරයා,වෛද්‍යවරු,ඩොක්ටර්,ඩොක්ටර්ස්ලා,ඩොක්ටර්ලා,மருத்துவர்,மருத்துவர்கள்",
			AnswerEN:     "👨‍⚕️ **MediQ Live Doctors List:**\n\nBelow is the live list of registered doctors at MediQ with their specialization, room, and working hours.\n\n💡 You can book an appointment with any available doctor directly from **'Book Appointment'** on the Home Screen.",
			AnswerSI:     "👨‍⚕️ **MediQ රෝහලේ වෛද්‍යවරුන්ගේ සජීවී තොරතුරු (Live Doctors List):**\n\nපහත දැක්වෙන්නේ MediQ රෝහලේ දැනට සිටින වෛද්‍යවරුන්, ඔවුන්ගේ විශේ්ෂඥතාවය, කාමර සහ සේවා කාලයන් වේ.\n\n💡 **'Book Appointment'** Screen එකෙන් ඔබට අවශ්‍ය වෛද්‍යවරයා පහසුවෙන්ම බුක් කරගත හැක.",
			AnswerTA:     "👨‍⚕️ **MediQ நேரடி மருத்துவர்கள் பட்டியல்:**\n\nகீழே நேரடி தரவு காண்க:\n• மருத்துவர் பெயர்கள் & சிறப்பு\n• OPD அறை\n• தற்போதைய கிடைக்கும் தன்மை\n\n💡 **'Book Appointment'** திரையில் பதிவு செய்யலாம்.",
			IsLiveData:   true,
			LiveDataType: "doctors",
			Priority:     10,
			IsActive:     true,
		},
		// ── Appointments ──────────────────────────────────────────────────────────
		{
			Category:     "appointment",
			Keywords:     "book,booking,boking,buking,bookin,appointment,apoinment,appoinment,apeoinment,aponiment,appoint,channel,channeling,reserve,schedule,slot,date,time,danne,karanne,krnne,ganne,gnn,ekak,kadamad,kohomad,kohomada,komada,how to book,book appointment,doctor appointment,ඇපොයින්ට්මන්ට්,බුකින්,බුක්,රෝගී,appointment book,සන්තිප්පු,பதிவு,appointment eka",
			AnswerEN:     "📅 **Step-by-Step Guide to Booking an Appointment:**\n\n1. Go to the Home Screen and tap **'Book Appointment'**\n2. Select your desired **OPD Room** (e.g. OPD Clinic, Dressing Room, Injection Room)\n3. Choose your preferred **Doctor**\n4. Pick a **Date** and **Time Slot**\n5. Tap **'Confirm Booking'** — You'll get your **Digital QR Token & Queue Number** instantly!\n\n💡 *Check live doctor availability below:*",
			AnswerSI:     "📅 **Appointment එකක් හරිම ලේසියෙන් Book කරන ආකාරය:**\n\n1️⃣ Home screen එකෙහි **'Book Appointment'** button එක tap කරන්න.\n2️⃣ ඔබට අවශ්‍ය **OPD Room එක** select කරන්න (උදා: OPD Clinic, Dressing Room, Injection Room).\n3️⃣ ඔබ හමුවීමට කැමති **Doctor** තෝරන්න.\n4️⃣ ඔබට පහසු **Date** සහ **Time Slot** තෝරන්න.\n5️⃣ **'Confirm Booking'** tap කරන්න — ඔබට සැනෙකින් **Digital QR Token** එක සහ Queue Number එක ලැබේ!\n\n💡 *දැනට සිටින doctors ලැයිස්තුව පහතින් බලන්න:*",
			AnswerTA:     "📅 **மருத்துவர் சந்திப்பு பதிவு செய்வது எப்படி:**\n\n1. முகப்புத்திரையில் **'Book Appointment'** தட்டவும்\n2. **OPD அறை** மற்றும் **மருத்துவர்** தேர்வு செய்யவும்\n3. **தேதி** மற்றும் **நேர வாய்ப்பு** தேர்வு செய்யவும்\n4. உறுதிப்படுத்தவும் — **QR token** உடனடியாக கிடைக்கும்!",
			IsLiveData:   true,
			LiveDataType: "doctors",
			Priority:     9,
			IsActive:     true,
		},
		// ── OPD Queue ─────────────────────────────────────────────────────────────
		{
			Category:     "queue",
			Keywords:     "queue,ticket,token,waiting,opd,live queue,turn,number,queue status,my turn,when,waiting time,number,queue eka,queue number,queue tiket,waiiting,opa,opa queue,opd queue,queue ekata,queues,opd ticket,qdl,wait,ticket number,පෝලිම,ටෝකන්,රෝගී queue,பொது நடைமுறை,வரிசை,வரிசை நிலை",
			AnswerEN:     "🏥 **OPD Live Queue Tracking:**\n\n• Open **'Patient Live Queue'** from the Home Screen\n• Scan your **QR Code** or type your **Token Number**\n• Watch your queue position update in **real-time**!\n\n📍 Check current queue numbers across OPD rooms below:",
			AnswerSI:     "🏥 **OPD Live Queue පරීක්ෂා කිරීම:**\n\n• Home page එකෙහි **'Patient Live Queue'** screen එක open කරන්න.\n• ඔබේ **QR code එක Scan කරන්න** හෝ **Token number එක Enter කරන්න**.\n• Queue එක **real-time** ලෙස update වේ!\n\n📍 දැනට කාමරවල පෝලිම් තත්ත්වය පහතින් බලන්න:",
			AnswerTA:     "🏥 **OPD நேரடி வரிசை:**\n\n• முகப்புத்திரையிலிருந்து **'Patient Live Queue'** திரை திறக்கவும்\n• உங்கள் **QR குறியீடு** ஸ்கேன் செய்யவும் அல்லது **டோக்கன் எண்** உள்ளிடவும்\n• வரிசை **நேரடியாக** புதுப்பிக்கப்படுகிறது!",
			IsLiveData:   true,
			LiveDataType: "queue",
			Priority:     9,
			IsActive:     true,
		},
		// ── Available Rooms ───────────────────────────────────────────────────────
		{
			Category:     "rooms",
			Keywords:     "room,rooms,available room,which room,opd room,dressing,injection,bleeding,animal bite,dispensary,clinic,ward,what rooms,room list,room type,rooms available,room available,room booking,room reservation,available rooms,rooms,room details,room list,room eka,room data,room wl,rooms list,කාමර,කාමරේ,අறை,அறைகள்,rooms ekata,anantharoom,klng room,rooms wla,room wlin,rooms wlin book",
			AnswerEN:     "🚪 **MediQ OPD Rooms & Services:**\n\n• 🩹 **Dressing Room** — Wound dressing & minor surgical procedures\n• 💉 **Injection Room** — Injections & IV medication\n• 🩸 **Bleeding Room** — Blood sampling & urgent care\n• 🐾 **Animal Bite Room** — Rabies vaccine & bite treatment\n• 🏥 **OPD Clinic Room** — General OPD doctor consultations\n• 💊 **Dispensary Room** — Pharmacy & medicine distribution\n\n📍 Check live room queue status below:",
			AnswerSI:     "🚪 **MediQ OPD කාමර පද්ධතිය:**\n\n• 🩹 **Dressing Room** — තුවාල සුවකිරීම සහ මයිනර් සර්ජරි\n• 💉 **Injection Room** — ඉන්ජෙක්ෂන් සහ IV ඖෂධ ලබාදීම\n• 🩸 **Bleeding Room** — රුධිර සාම්පල ලබාගැනීම සහ හදිසි සත්කාර\n• 🐾 **Animal Bite Room** — සත්ව සෑපීම් සහ එන්නත් ලබාදීම\n• 🏥 **OPD Clinic Room** — සාමාන්‍ය OPD වෛද්‍ය පරීක්ෂණ\n• 💊 **Dispensary Room** — ඖෂධ නිකුත් කිරීමේ ෆාමසිය\n\n📍 සජීවී කාමර තත්ත්වය පහතින් බලන්න:",
			AnswerTA:     "🚪 **MediQ OPD அறைகள்:**\n\n• 🩹 **ஆடை அறை** — காயம் கட்டுவது\n• 💉 **ஊசி அறை** — ஊசிகள் & IV\n• 🩸 **இரத்தப்போக்கு அறை** — இரத்தப்போக்கு கட்டுப்பாடு\n• 🐾 **விலங்கு கடி அறை** — சிகிச்சை & தடுப்பூசி\n• 🏥 **OPD கிளினிக் அறை** — பொது OPD\n• 💊 **மருந்து அறை** — மருந்து வழங்கல்",
			IsLiveData:   true,
			LiveDataType: "rooms",
			Priority:     8,
			IsActive:     true,
		},
		// ── My Appointments ───────────────────────────────────────────────────────
		{
			Category:     "my_appointments",
			Keywords:     "my appointment,my booking,my appointments,view my appointment,cancel appointment,appointment cancel,upcoming appointment,my ticket,my token,my reservations,ape apointment,mata appointment,mama book kala,my appt,cancel,cancel appointment,my appointment details,cancel booking,cancel my appointment,appointment cancel krnna,appointment eka cancel,cancel krnna,cancel ekata,cancel my,appointment cancel krl,ennda appointment,ennda booking,ennda ticket,ennda token,ennda token number,ennda token eka,ennda apa,my appointment eka,my apointment,මගේ ඇපොයින්ට්මන්ට්,කැන්සල්,எனது சந்திப்பு",
			AnswerEN:     "📋 **Managing Your Appointments:**\n\n• Tap **'My Appointments'** on the Home Screen to view your upcoming bookings\n• You can **cancel** an appointment if you cannot attend\n• Your **QR Code Token** is ready for scanning when you arrive at the hospital\n\n⚠️ *Please cancel at least 1 hour in advance so other patients can take the slot.*",
			AnswerSI:     "📋 **ඔබේ Appointments කළමනාකරණය:**\n\n• Home screen එකෙහි **'My Appointments'** වෙත යන්න.\n• ඔබට පැමිණීමට නොහැකි නම් **Cancel Appointment** ක්ලික් කර කැන්සල් කරන්න.\n• රෝහලට පැමිණි පසු QR scan කිරීම සඳහා **QR Token එක** මෙහි ඇත.\n\n⚠️ *කරුණාකර පැමිණීමට නොහැකි නම් පැයකට පෙර කැන්සල් කරන්න.*",
			AnswerTA:     "📋 **உங்கள் சந்திப்புகள்:**\n\n• முகப்புத்திரையிலிருந்து **'My Appointments'** திறக்கவும்\n• வரவிருக்கும் சந்திப்புகளை **ரத்து** செய்யலாம்\n• **QR குறியீடு** உள்நுழைவிற்கு பயன்படுத்தலாம்",
			Priority:     7,
			IsActive:     true,
		},
		// ── Prescriptions & Pill Tracker ─────────────────────────────────────────
		{
			Category: "medications",
			Keywords: "pill,medicine,prescription,remind,medication,dosage,drug,tablet,capsule,pill tracker,pill reminder,medicines,panadol,paracetamol,drug reminder,medication reminder,take medicine,pill schedule,medicine time,pill time,pill timing,medicine timing,dose,pills,medicines,medicine list,pill list,pill track,pill trcker,pill trackr,pill tracer,pill trkr,medicines reminder,medicine alert,pill alert,pill notification,medicine notification,tablet,pill ek,medicine ek,prescription eka,eka pill,pills eka,බෙහෙත්,පෙති,පෙති මතක්,மருந்து,மாத்திரை",
			AnswerEN: "💊 **Medications & Pill Tracker:**\n\n• Tap **'Pill Tracker'** on the Home Screen\n• Add your prescribed medicines, dosage, and time schedule\n• Receive **push notification alerts** so you never miss a dose!\n• View past prescriptions under **'Medical Records'**",
			AnswerSI: "💊 **Medications & Pill Tracker (බෙහෙත් මතක් කිරීමේ පද්ධතිය):**\n\n• Home screen එකෙහි **'Pill Tracker'** open කරන්න.\n• ඔබේ ඖෂධවල නම, මාත්‍රාව (dosage) සහ වේලාවන් ඇතුළත් කරන්න.\n• නිවැරදි වේලාවට බෙහෙත් ගැනීමට **Push Notifications** මගින් මතක් කරදෙනු ඇත!\n• පරණ බෙහෙත් තුණ්ඩු බලන්න **'Medical Records'** වෙත යන්න.",
			AnswerTA: "💊 **மருந்துகள் & மாத்திரை ட்ராக்கர்:**\n\n• முகப்புத்திரையிலிருந்து **'Pill Tracker'** திறக்கவும்\n• **அளவு** மற்றும் **அட்டவணையுடன்** மருந்துகளை சேர்க்கவும்\n• **புஷ் அறிவிப்புகளை** இயக்கவும்",
			Priority: 7,
			IsActive: true,
		},
		// ── Medical Records ───────────────────────────────────────────────────────
		{
			Category: "records",
			Keywords: "record,lab,report,history,medical record,lab report,test result,prescription history,past visit,medical history,health record,lab test,blood test,scan,x-ray,mri,ct scan,upload report,upload prescription,digital record,records,medical records,lab results,health history,health data,reports,tests,record eka,records eka,lab eka,lab report eka,report eka,report wl,record wl,lab report wl,lab reports,health reports,health data eka,records wl,medical records ekata,medical records wl,test reports,වාර්තා,ලැබ් රිපෝට්,ලැබ්,மருத்துவ பதிவுகள்,ஆய்வக அறிக்கை",
			AnswerEN: "📁 **Digital Medical Records:**\n\n• Access **'Medical Records'** from the Home Screen\n• View **digital prescriptions**, **lab test reports**, and doctor notes\n• Safely **upload** your own PDF reports or prescriptions\n• Encrypted & stored securely with privacy protection!",
			AnswerSI: "📁 **ඩිජිටල් Medical Records පද්ධතිය:**\n\n• Home screen එකෙහි **'Medical Records'** වෙත යන්න.\n• ඔබේ **Digital Prescriptions**, **ලැබ් රිපෝට්** සහ වෛද්‍ය සටහන් නැරඹිය හැක.\n• ඔබේ ළඟ ඇති PDF හෝ ඡායාරූප ආරක්‍ෂිතව **Upload** කළ හැක.\n• ඔබේ සියලුම සෞඛ්‍ය වාර්තා ආරක්‍ෂිතව encrypted කර තැබේ!",
			AnswerTA: "📁 **மருத்துவ பதிவுகள்:**\n\n• முகப்புத்திரையிலிருந்து **'Medical Records'** திறக்கவும்\n• **டிஜிட்டல் மருந்துச் சீட்டுகள்** மற்றும் **ஆய்வக அறிக்கைகளை** காண்க\n• மருத்துவர் குறிப்புகள் அல்லது PDF **பதிவேற்றவும்**",
			Priority: 6,
			IsActive: true,
		},
		// ── Emergency ─────────────────────────────────────────────────────────────
		{
			Category: "emergency",
			Keywords: "emergency,urgent,help,ambulance,911,1990,accident,critical,life threatening,emergency line,emergency contact,call ambulance,urgent help,emergency number,call help,suwa seriya,urgent care,please help,danger,emergency ek,emergency ekata,ambulance eka,ambulance ekata,ambulance call,call ambulance,urgent situation,හදිසි,ඇම්බියුලන්ස්,අනතුර,අනතුරක්,அவசரநிலை,அவசர",
			AnswerEN: "🚨 **Emergency Contacts:**\n\n• 🚑 **Suwa Seriya Ambulance:** 1990 (24/7 Toll-Free)\n• 🏥 **MediQ Emergency Hotline:** 011-234-5678\n• 🚒 **Police Hotline:** 119\n• 🔥 **Fire & Rescue:** 110",
			AnswerSI: "🚨 **හදිසි ඇමතුම් සහ සේවාවන් (Emergency Services):**\n\n• 🚑 **සුව සැරිය ගිලන්රථ සේවය:** 1990 (24/7 නොමිලේ)\n• 🏥 **MediQ හදිසි සේවා අංකය:** 011-234-5678\n• 🚒 **පොලිසිය:** 119\n• 🔥 **ගිනි නිවීම්:** 110\n\n⚠️ *හෘදයාබාධ, දැඩි ශ්වසන අපහසුතා හෝ අනතුරකදී වහාම 1990 අමතන්න.*",
			AnswerTA: "🚨 **அவசர தொடர்புகள்:**\n\n• 🚑 **சுவ சேரியா ஆம்புலன்ஸ்:** 1990 (24/7)\n• 🏥 **MediQ அவசர எண்:** 011-234-5678\n• 🚒 **காவல்துறை:** 119",
			Priority: 10,
			IsActive: true,
		},
	}

	seeded := 0
	for _, faq := range defaults {
		var existing models.ChatFAQ
		if err := database.DB.Where("category = ?", faq.Category).First(&existing).Error; err == nil {
			// Update existing record with updated keywords and answers
			database.DB.Model(&existing).Updates(map[string]interface{}{
				"keywords":       faq.Keywords,
				"answer_en":      faq.AnswerEN,
				"answer_si":      faq.AnswerSI,
				"answer_ta":      faq.AnswerTA,
				"is_live_data":   faq.IsLiveData,
				"live_data_type": faq.LiveDataType,
				"priority":       faq.Priority,
				"is_active":      true,
			})
			seeded++
		} else {
			// Create new record
			faqCopy := faq
			if err := database.DB.Create(&faqCopy).Error; err == nil {
				seeded++
			}
		}
	}

	return seeded, nil
}
