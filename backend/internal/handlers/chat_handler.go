package handlers

import (
	"fmt"
	"net/http"
	"regexp"
	"strings"
	"time"

	"mediq-backend/internal/database"
	"mediq-backend/internal/models"

	"github.com/gin-gonic/gin"
)

type ChatHandler struct{}

func NewChatHandler() *ChatHandler {
	return &ChatHandler{}
}

type SendMessageRequest struct {
	Message string `json:"message" binding:"required"`
}

func (h *ChatHandler) GetHistory(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID := userIDVal.(uint)

	if database.DB == nil {
		c.JSON(http.StatusOK, gin.H{"status": "success", "data": []models.ChatMessage{}})
		return
	}

	var msgs []models.ChatMessage
	if err := database.DB.Where("user_id = ?", userID).Order("created_at asc").Find(&msgs).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve history"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status": "success",
		"data":   msgs,
	})
}

func (h *ChatHandler) ClearHistory(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID := userIDVal.(uint)

	if database.DB != nil {
		database.DB.Where("user_id = ?", userID).Delete(&models.ChatMessage{})
	}

	c.JSON(http.StatusOK, gin.H{
		"status":  "success",
		"message": "Chat history cleared successfully",
	})
}

func (h *ChatHandler) SendMessage(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID := userIDVal.(uint)

	var req SendMessageRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Message is required"})
		return
	}

	userMsgText := strings.TrimSpace(req.Message)
	if userMsgText == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Message cannot be empty"})
		return
	}

	var userName string
	if database.DB != nil {
		var user models.User
		if err := database.DB.First(&user, userID).Error; err == nil {
			userName = user.FullName
		}
	}

	userMsg := models.ChatMessage{
		UserID: userID,
		Sender: "user",
		Text:   userMsgText,
	}

	if database.DB != nil {
		database.DB.Create(&userMsg)
	}

	reply := generateSmartAIResponse(userMsgText, userName)

	botMsg := models.ChatMessage{
		UserID: userID,
		Sender: "bot",
		Text:   reply,
	}

	if database.DB != nil {
		database.DB.Create(&botMsg)
	}

	c.JSON(http.StatusOK, gin.H{
		"status": "success",
		"data": gin.H{
			"user_message": userMsg,
			"bot_message":  botMsg,
		},
	})
}

// ─────────────────────────────────────────────────────────────────────────────
// Language Detection & Normalization
// ─────────────────────────────────────────────────────────────────────────────

type detectedLang string

const (
	langEN detectedLang = "en"
	langSI detectedLang = "si"
	langTA detectedLang = "ta"
)

// detectLanguage detects Sinhala Unicode, Tamil Unicode, or Singlish keywords.
func detectLanguage(text string) detectedLang {
	sinhalaCount := 0
	tamilCount := 0
	for _, r := range text {
		// Sinhala: U+0D80–U+0DFF
		if r >= 0x0D80 && r <= 0x0DFF {
			sinhalaCount++
		}
		// Tamil: U+0B80–U+0BFF
		if r >= 0x0B80 && r <= 0x0BFF {
			tamilCount++
		}
	}
	if sinhalaCount > tamilCount && sinhalaCount > 0 {
		return langSI
	}
	if tamilCount > 0 {
		return langTA
	}

	// Singlish detection in Latin script
	low := strings.ToLower(text)
	singlishKeywords := []string{
		"kwd", "kwda", "kawda", "kohomad", "kohomada", "komada", "komad", "inwda", "inawada",
		"danne", "karanne", "krnne", "ganne", "gnn", "ekak", "eka", "dala", "danna", "thiyenne",
		"thiyenawada", "thiyenad", "monawada", "doctersla", "doctorla", "dokthala", "drla", "doctala",
		"puluwanda", "puluwan", "wela", "welawath", "krnna", "eyata", "enna", "ape", "mona",
		"kiyala", "kiyanne", "ada", "mata", "ennda", "apata", "tikak", "magen", "oyata", "kiyanna",
		"nikan", "awlk", "awla", "wla", "wlin", "ekata", "ne", "naha", "na",
	}

	words := strings.Fields(low)
	for _, word := range words {
		// Strip common punctuation from word boundaries
		cleaned := strings.Trim(word, "?!.,;:()[]{}")
		for _, sk := range singlishKeywords {
			if cleaned == sk {
				return langSI
			}
		}
	}

	return langEN
}

// normalizeText cleans text and normalizes common Singlish variations.
func normalizeText(text string) string {
	low := strings.ToLower(text)

	// Replace punctuation with spaces
	reg := regexp.MustCompile(`[^\w\s]`)
	cleaned := reg.ReplaceAllString(low, " ")

	// Normalize common Singlish/English typo variations
	replacements := map[string]string{
		"doctersla": "doctor",
		"docters":   "doctor",
		"doctala":   "doctor",
		"dokthala":  "doctor",
		"doctorla":  "doctor",
		"drla":      "doctor",
		"docla":     "doctor",
		"dokta":     "doctor",
		"docs":      "doctor",
		"doc":       "doctor",

		"boking":     "book",
		"booking":    "book",
		"buking":     "book",
		"bookin":     "book",
		"apoinment":  "appointment",
		"appoinment": "appointment",
		"apeoinment": "appointment",
		"aponiment":  "appointment",
		"appoint":    "appointment",

		"kwd":      "who",
		"kwda":     "who",
		"kawda":    "who",
		"kuda":     "who",
		"kohomad":  "how",
		"kohomada": "how",
		"komada":   "how",
		"komad":    "how",
		"inwda":    "available",
		"inawada":  "available",
	}

	words := strings.Fields(cleaned)
	for i, w := range words {
		if norm, ok := replacements[w]; ok {
			words[i] = norm
		}
	}

	return strings.Join(words, " ")
}

// pickAnswer selects the answer for the detected language, falling back to EN.
func pickAnswer(faq models.ChatFAQ, lang detectedLang) string {
	switch lang {
	case langSI:
		if strings.TrimSpace(faq.AnswerSI) != "" {
			return faq.AnswerSI
		}
	case langTA:
		if strings.TrimSpace(faq.AnswerTA) != "" {
			return faq.AnswerTA
		}
	}
	return faq.AnswerEN
}

// ─────────────────────────────────────────────────────────────────────────────
// Core AI Response Engine
// ─────────────────────────────────────────────────────────────────────────────

func generateSmartAIResponse(query, userName string) string {
	lang := detectLanguage(query)
	normQuery := normalizeText(query)
	rawLowerQuery := strings.ToLower(query)

	greetingName := "there"
	if userName != "" {
		greetingName = strings.Split(userName, " ")[0]
	}

	// ── 1. Try DB-backed FAQ matching with score ──────────────────────────────
	if database.DB != nil {
		var faqs []models.ChatFAQ
		database.DB.Where("is_active = true").Order("priority DESC, id ASC").Find(&faqs)

		var bestFAQ *models.ChatFAQ
		bestScore := 0

		for i := range faqs {
			faq := faqs[i]
			score := scoreFAQ(normQuery, rawLowerQuery, faq.Keywords)
			// Factor in FAQ priority score boost
			totalScore := score*10 + faq.Priority
			if score > 0 && totalScore > bestScore {
				bestScore = totalScore
				bestFAQ = &faq
			}
		}

		if bestFAQ != nil {
			answer := pickAnswer(*bestFAQ, lang)
			answer = strings.ReplaceAll(answer, "{name}", greetingName)

			// Append live data if enabled
			if bestFAQ.IsLiveData && bestFAQ.LiveDataType != "" {
				liveBlock := buildLiveDataBlock(bestFAQ.LiveDataType, lang)
				if liveBlock != "" {
					answer += "\n\n" + liveBlock
				}
			}
			return answer
		}
	}

	// ── 2. Dynamic Fallback Response Engine ───────────────────────────────────
	return generateFallbackResponse(normQuery, rawLowerQuery, greetingName, lang)
}

// scoreFAQ calculates a matching score based on keyword overlap.
func scoreFAQ(normQuery, rawLowerQuery, keywordsCSV string) int {
	keywords := strings.Split(keywordsCSV, ",")
	queryTokens := strings.Fields(normQuery)
	rawTokens := strings.Fields(rawLowerQuery)

	score := 0
	for _, kw := range keywords {
		kw = strings.TrimSpace(strings.ToLower(kw))
		if kw == "" {
			continue
		}

		// Exact phrase match (highest weight)
		if strings.Contains(rawLowerQuery, kw) || strings.Contains(normQuery, kw) {
			score += 3
		}

		// Token match
		for _, qt := range queryTokens {
			if qt == kw {
				score += 2
			} else if len(kw) > 3 && (strings.Contains(qt, kw) || strings.Contains(kw, qt)) {
				score += 1
			}
		}
		for _, rt := range rawTokens {
			if rt == kw {
				score += 2
			}
		}
	}
	return score
}

// ─────────────────────────────────────────────────────────────────────────────
// Live Data Blocks (Fetches directly from DB)
// ─────────────────────────────────────────────────────────────────────────────

func buildLiveDataBlock(dataType string, lang detectedLang) string {
	if database.DB == nil {
		return ""
	}

	switch dataType {
	case "doctors":
		return buildDoctorsBlock(lang)
	case "queue":
		return buildQueueBlock(lang)
	case "rooms":
		return buildRoomsBlock(lang)
	case "appointments":
		return buildAppointmentsBlock(lang)
	}
	return ""
}

func buildDoctorsBlock(lang detectedLang) string {
	var doctors []models.Doctor
	// Fetch all doctors from database with user details
	database.DB.Preload("User").Order("id ASC").Find(&doctors)

	// If no doctor profiles exist in Doctor table, check User table for Role=DOCTOR
	if len(doctors) == 0 {
		var docUsers []models.User
		database.DB.Where("role = ?", models.RoleDoctor).Find(&docUsers)
		if len(docUsers) > 0 {
			var header string
			switch lang {
			case langSI:
				header = "👨‍⚕️ **MediQ රෝහලේ වෛද්‍යවරුන් (Registered Doctors):**\n"
			case langTA:
				header = "👨‍⚕️ **MediQ மருத்துவர்கள் (பதிவுசெய்யப்பட்ட):**\n"
			default:
				header = "👨‍⚕️ **MediQ Registered Doctors:**\n"
			}
			lines := header
			for _, du := range docUsers {
				lines += fmt.Sprintf("• **Dr. %s** — General OPD | 🟢 Available\n", du.FullName)
			}
			return strings.TrimRight(lines, "\n")
		}

		switch lang {
		case langSI:
			return "📋 *දැනට පද්ධතියේ වෛද්‍යවරුන් ලියාපදිංචි වී නොමැත.*"
		case langTA:
			return "📋 *தற்போது அமைப்பில் மருத்துவர்கள் பதிவு செய்யப்படவில்லை.*"
		default:
			return "📋 *No doctor profiles found in the system.*"
		}
	}

	var header string
	switch lang {
	case langSI:
		header = "👨‍⚕️ **MediQ වෛද්‍යවරුන්ගේ සජීවී තොරතුරු (Live Doctors List):**\n"
	case langTA:
		header = "👨‍⚕️ **MediQ மருத்துவர்களின் நேரடிப் பட்டியல்:**\n"
	default:
		header = "👨‍⚕️ **MediQ Live Doctors List:**\n"
	}

	lines := header
	for _, d := range doctors {
		docName := d.User.FullName
		if docName == "" {
			docName = fmt.Sprintf("Doctor #%d", d.ID)
		}
		spec := d.Specialization
		if spec == "" {
			spec = "General OPD Specialist"
		}
		roomName := roomDisplayName(string(d.Room))

		availStatus := "🟢 Available Now"
		if !d.IsAvailable {
			availStatus = "🔴 Currently On Leave / Away"
		}

		hours := "08:00 AM - 04:00 PM"
		if d.WorkingHoursStart != "" && d.WorkingHoursEnd != "" {
			hours = fmt.Sprintf("%s - %s", d.WorkingHoursStart, d.WorkingHoursEnd)
		}

		lines += fmt.Sprintf("• **Dr. %s**\n  Specialization: %s | 🚪 Room: %s\n  🕒 Hours: %s | Status: %s\n",
			docName, spec, roomName, hours, availStatus)
	}

	return strings.TrimRight(lines, "\n")
}

func buildQueueBlock(lang detectedLang) string {
	today := time.Now().Format("2006-01-02")

	rooms := []string{
		"OPD_CLINIC_ROOM", "DRESSING_ROOM", "INJECTION_ROOM",
		"BLEEDING_ROOM", "ANIMAL_BITE_ROOM", "DISPENSARY_ROOM",
	}

	var header string
	switch lang {
	case langSI:
		header = "📊 **අද දින Live OPD Queue තත්ත්වය (Real-Time Queue):**\n"
	case langTA:
		header = "📊 **இன்றைய நேரடி வரிசை நிலை (Live Queue):**\n"
	default:
		header = "📊 **Live OPD Queue Status (Today):**\n"
	}

	lines := header
	totalWaiting := int64(0)

	for _, room := range rooms {
		var pending, serving int64
		database.DB.Model(&models.OPDAppointment{}).
			Where("room = ? AND appointment_date = ? AND status IN ?", room, today, []string{"PENDING", "CONFIRMED"}).
			Count(&pending)
		database.DB.Model(&models.OPDAppointment{}).
			Where("room = ? AND appointment_date = ? AND status = ?", room, today, "SERVING").
			Count(&serving)

		totalWaiting += pending + serving
		roomName := roomDisplayName(room)

		if serving > 0 {
			lines += fmt.Sprintf("• 🚪 **%s** — ⏳ %d Waiting | 👨‍⚕️ 1 Serving\n", roomName, pending)
		} else if pending > 0 {
			lines += fmt.Sprintf("• 🚪 **%s** — ⏳ %d Waiting\n", roomName, pending)
		} else {
			lines += fmt.Sprintf("• 🚪 **%s** — 🟢 Available (0 Waiting)\n", roomName)
		}
	}

	if totalWaiting == 0 {
		switch lang {
		case langSI:
			return lines + "\n💡 *දැනට කිසිදු පෝලිමක් නොමැත. ඔබට වහාම පරීක්ෂාව සඳහා යොමුවිය හැක!*"
		case langTA:
			return lines + "\n💡 *தற்போது வரிசை இல்லை. நீங்கள் உடனடியாக செல்லலாம்!*"
		default:
			return lines + "\n💡 *No queue line currently. You can walk in immediately!*"
		}
	}

	return strings.TrimRight(lines, "\n")
}

func buildRoomsBlock(lang detectedLang) string {
	today := time.Now().Format("2006-01-02")

	type RoomInfo struct {
		Name   string
		RoomID string
		Emoji  string
		Desc   string
	}

	roomInfos := []RoomInfo{
		{Name: "OPD Clinic Room", RoomID: "OPD_CLINIC_ROOM", Emoji: "🏥", Desc: "General Consultation"},
		{Name: "Dressing Room", RoomID: "DRESSING_ROOM", Emoji: "🩹", Desc: "Wound Dressing & Minor Care"},
		{Name: "Injection Room", RoomID: "INJECTION_ROOM", Emoji: "💉", Desc: "Injections & IV Medication"},
		{Name: "Bleeding Room", RoomID: "BLEEDING_ROOM", Emoji: "🩸", Desc: "Blood Sampling & Urgent Care"},
		{Name: "Animal Bite Room", RoomID: "ANIMAL_BITE_ROOM", Emoji: "🐾", Desc: "Bite Treatment & Vaccine"},
		{Name: "Dispensary Room", RoomID: "DISPENSARY_ROOM", Emoji: "💊", Desc: "Pharmacy & Medicine Distribution"},
	}

	var header string
	switch lang {
	case langSI:
		header = "🚪 **MediQ OPD කාමර පද්ධතිය (Live Room Details):**\n"
	case langTA:
		header = "🚪 **MediQ OPD அறைகள் விவரம்:**\n"
	default:
		header = "🚪 **MediQ OPD Rooms Live Status:**\n"
	}

	lines := header
	for _, ri := range roomInfos {
		var count int64
		database.DB.Model(&models.OPDAppointment{}).
			Where("room = ? AND appointment_date = ? AND status IN ?", ri.RoomID, today, []string{"PENDING", "CONFIRMED", "SERVING"}).
			Count(&count)

		var doctorName string
		var doc models.Doctor
		if err := database.DB.Preload("User").Where("room = ?", ri.RoomID).First(&doc).Error; err == nil && doc.User.FullName != "" {
			doctorName = fmt.Sprintf(" • Dr. %s", doc.User.FullName)
		}

		statusBadge := "🟢 Normal"
		if count > 5 {
			statusBadge = "🟡 Busy"
		}
		if count > 15 {
			statusBadge = "🔴 Heavy Congestion"
		}

		lines += fmt.Sprintf("• %s **%s** (%s)\n  Status: %s%s | ⏳ Queue: %d\n",
			ri.Emoji, ri.Name, ri.Desc, statusBadge, doctorName, count)
	}

	return strings.TrimRight(lines, "\n")
}

func buildAppointmentsBlock(lang detectedLang) string {
	today := time.Now().Format("2006-01-02")

	var totalToday, pendingCount, completedCount int64
	database.DB.Model(&models.OPDAppointment{}).Where("appointment_date = ?", today).Count(&totalToday)
	database.DB.Model(&models.OPDAppointment{}).Where("appointment_date = ? AND status IN ?", today, []string{"PENDING", "CONFIRMED"}).Count(&pendingCount)
	database.DB.Model(&models.OPDAppointment{}).Where("appointment_date = ? AND status = ?", today, "COMPLETED").Count(&completedCount)

	switch lang {
	case langSI:
		return fmt.Sprintf("📅 **අද දින ඇපොයින්ට්මන්ට් සංඛ්‍යාලේඛන:**\n• මුළු ඇපොයින්ට්මන්ට්: %d\n• පෝලිමේ සිටින සංඛ්‍යාව: %d\n• අවසන් කළ සංඛ්‍යාව: %d", totalToday, pendingCount, completedCount)
	case langTA:
		return fmt.Sprintf("📅 **இன்றைய சந்திப்புகள் புள்ளிவிவரம்:**\n• மொத்தம்: %d\n• காத்திருப்பு: %d\n• முடிந்தது: %d", totalToday, pendingCount, completedCount)
	default:
		return fmt.Sprintf("📅 **Today's Appointment Stats:**\n• Total Appointments: %d\n• Currently Waiting: %d\n• Completed: %d", totalToday, pendingCount, completedCount)
	}
}

func roomDisplayName(room string) string {
	switch room {
	case "DRESSING_ROOM":
		return "Dressing Room"
	case "INJECTION_ROOM":
		return "Injection Room"
	case "BLEEDING_ROOM":
		return "Bleeding Room"
	case "ANIMAL_BITE_ROOM":
		return "Animal Bite Room"
	case "OPD_CLINIC_ROOM":
		return "OPD Clinic Room"
	case "DISPENSARY_ROOM":
		return "Dispensary Room"
	default:
		if room == "" {
			return "General OPD Clinic"
		}
		return room
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Dynamic Fallback Engine (Detailed Responses)
// ─────────────────────────────────────────────────────────────────────────────

func generateFallbackResponse(normQuery, rawLowerQuery, greetingName string, lang detectedLang) string {
	// 1. Doctors Intent
	if strings.Contains(normQuery, "doctor") || strings.Contains(normQuery, "doc") || strings.Contains(rawLowerQuery, "වෛද්‍ය") || strings.Contains(rawLowerQuery, "ඩොක්ටර්") {
		liveDocs := buildDoctorsBlock(lang)
		switch lang {
		case langSI:
			return "👨‍⚕️ **MediQ හි සිටින වෛද්‍යවරුන් (Doctors Information):**\n\n" + liveDocs + "\n\n💡 *ඔබට අවශ්‍ය වෛද්‍යවරයා හමුවීමට Home Screen හි **'Book Appointment'** මගින් ඇපොයින්ට්මන්ට් එකක් වෙන්කර ගත හැක.*"
		case langTA:
			return "👨‍⚕️ **MediQ மருத்துவர்கள் விவரம்:**\n\n" + liveDocs
		default:
			return "👨‍⚕️ **MediQ Doctors Information:**\n\n" + liveDocs + "\n\n💡 *To schedule a visit, tap **'Book Appointment'** on the Home Screen.*"
		}
	}

	// 2. Booking / Appointment Intent
	if strings.Contains(normQuery, "book") || strings.Contains(normQuery, "appointment") || strings.Contains(rawLowerQuery, "ඇපොයින්ට්මන්ට්") || strings.Contains(rawLowerQuery, "බුකින්") {
		liveDocs := buildDoctorsBlock(lang)
		switch lang {
		case langSI:
			return "📅 **MediQ හි Appointment එකක් හරියටම Book කරන ආකාරය:**\n\n" +
				"1️⃣ App එකේ Home Screen එකට ගොස් **'Book Appointment'** ක්ලික් කරන්න.\n" +
				"2️⃣ ඔබට අවශ්‍ය **OPD Room / Service** එක තෝරන්න (උදා: OPD Clinic, Dressing Room, ආදිය).\n" +
				"3️⃣ ඔබ හමුවීමට කැමති **වෛද්‍යවරයා (Doctor)** තෝරන්න.\n" +
				"4️⃣ ඔබට පහසු **දිනය (Date)** සහ **වේලාව (Time Slot)** තෝරන්න.\n" +
				"5️⃣ **'Confirm Booking'** ක්ලික් කරන්න — ඔබට සැනෙකින් **Digital QR Token** එකක් සහ පෝලිම් අංකයක් ලැබේ!\n\n" +
				liveDocs
		case langTA:
			return "📅 **சந்திப்பு பதிவு செய்யும் படிநிலைகள்:**\n\n1. முகப்புத்திரையில் **'Book Appointment'** தட்டவும்.\n2. OPD அறை மற்றும் மருத்துவர் தேர்வு செய்யவும்.\n3. தேதி மற்றும் நேரம் தேர்வு செய்து உறுதிப்படுத்தவும்!\n\n" + liveDocs
		default:
			return "📅 **Step-by-Step Guide to Booking an Appointment:**\n\n" +
				"1. Go to the Home Screen and tap **'Book Appointment'**.\n" +
				"2. Select your desired **OPD Room** (e.g., OPD Clinic, Injection Room).\n" +
				"3. Choose your preferred **Doctor**.\n" +
				"4. Select the **Date** and **Time Slot**.\n" +
				"5. Tap **'Confirm Booking'** — You'll receive your **QR Token & Queue Number** instantly!\n\n" +
				liveDocs
		}
	}

	// 3. Queue Intent
	if strings.Contains(normQuery, "queue") || strings.Contains(normQuery, "ticket") || strings.Contains(normQuery, "token") || strings.Contains(normQuery, "turn") || strings.Contains(rawLowerQuery, "පෝලිම") || strings.Contains(rawLowerQuery, "ටෝකන්") {
		liveQueue := buildQueueBlock(lang)
		switch lang {
		case langSI:
			return "🏥 **OPD Live Queue තත්ත්වය පරීක්ෂා කිරීම:**\n\n" +
				"• Home Screen හි **'Patient Live Queue'** වෙත යන්න.\n" +
				"• ඔබේ **QR Code එක Scan කරන්න** හෝ **Token Number එක Enter කරන්න**.\n" +
				"• පෝලිමේ ඔබේ වාරය පැමිණෙන තෙක් Real-Time Live Status එක නැරඹිය හැක.\n\n" + liveQueue
		case langTA:
			return "🏥 **OPD நேரடி வரிசை நிலை:**\n\n" + liveQueue
		default:
			return "🏥 **OPD Live Queue Tracking:**\n\n" +
				"• Go to **'Patient Live Queue'** on the Home Screen.\n" +
				"• Scan your **QR Code** or type your **Token Number**.\n" +
				"• Track your position in real-time!\n\n" + liveQueue
		}
	}

	// 4. Rooms Intent
	if strings.Contains(normQuery, "room") || strings.Contains(rawLowerQuery, "කාමර") {
		return buildRoomsBlock(lang)
	}

	// 5. Emergency Intent
	if strings.Contains(normQuery, "emergency") || strings.Contains(normQuery, "urgent") || strings.Contains(normQuery, "ambulance") || strings.Contains(normQuery, "1990") || strings.Contains(rawLowerQuery, "අනතුර") {
		switch lang {
		case langSI:
			return "🚨 **හදිසි වෛද්‍ය ආධාර (Emergency Contacts):**\n\n• 🚑 **සුව සැරිය ගිලන්රථ සේවය:** 1990 (නොමිලේ 24/7)\n• 🏥 **MediQ හදිසි ඇමතුම්:** 011-234-5678\n• 🚒 **පොලිසිය:** 119"
		case langTA:
			return "🚨 **அவசர தொடர்புகள்:**\n\n• 🚑 **சுவ சேரியா ஆம்புலன்ஸ்:** 1990\n• 🏥 **MediQ அவசர எண்:** 011-234-5678"
		default:
			return "🚨 **Emergency Medical Support:**\n\n• 🚑 **Suwa Seriya Free Ambulance:** 1990 (24/7)\n• 🏥 **MediQ Emergency Line:** 011-234-5678\n• 🚒 **Police Hotline:** 119"
		}
	}

	// 6. Generic Welcome / Help Response
	switch lang {
	case langSI:
		return "👋 ආයුබෝවන් " + greetingName + "! මම MediQ AI සහකාරයයි.\n\n" +
			"ඔබට මාගෙන් පහත දෑ පිළිබඳ ඇසිය හැක:\n" +
			"• 👨‍⚕️ **වෛද්‍යවරුන් කවුද?** (Who are the doctors?)\n" +
			"• 📅 **Appointment බුක් කරන්නේ කොහොමද?** (How to book an appointment)\n" +
			"• 🏥 **OPD Live Queue තත්ත්වය** (Live Queue status)\n" +
			"• 🚪 **රෝහලේ කාමර (OPD Rooms)**\n" +
			"• 💊 **බෙහෙත් සහ Pill Tracker**\n" +
			"• 📁 **Medical Records සහ Lab Reports**"
	case langTA:
		return "👋 வணக்கம் " + greetingName + "! நான் MediQ AI உதவியாளர்.\n\n" +
			"நீங்கள் கேட்கலாம்:\n" +
			"• 👨‍⚕️ மருத்துவர்கள் விவரம்\n" +
			"• 📅 சந்திப்பு பதிவு செய்யும் முறை\n" +
			"• 🏥 OPD நேரடி வரிசை நிலை\n" +
			"• 🚪 அறைகள் விவரம்"
	default:
		return "👋 Hello " + greetingName + "! I am MediQ AI Assistant.\n\n" +
			"You can ask me about:\n" +
			"• 👨‍⚕️ **Who are the doctors?** (Available doctors & specs)\n" +
			"• 📅 **How to book an appointment?** (Step-by-step guide)\n" +
			"• 🏥 **OPD Live Queue status** (Real-time queue tracking)\n" +
			"• 🚪 **OPD Rooms & Clinic Info**\n" +
			"• 💊 **Medications & Pill Reminders**\n" +
			"• 📁 **Medical Records & Lab Reports**"
	}
}
