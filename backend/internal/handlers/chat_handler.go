package handlers

import (
	"fmt"
	"net/http"
	"strings"
	"time"
	"unicode"

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
// Language Detection
// ─────────────────────────────────────────────────────────────────────────────

type detectedLang string

const (
	langEN detectedLang = "en"
	langSI detectedLang = "si"
	langTA detectedLang = "ta"
)

// detectLanguage detects Sinhala or Tamil unicode presence; defaults to English.
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
		_ = unicode.IsLetter(r)
	}
	if sinhalaCount > tamilCount && sinhalaCount > 0 {
		return langSI
	}
	if tamilCount > 0 {
		return langTA
	}
	// Also check for explicit language keywords in mixed messages
	low := strings.ToLower(text)
	siKeywords := []string{"apa", "mama", "eka", "krnna", "eyata", "enna", "ape", "mona", "kiyala", "ape", "wl", "wlin", "ekata", "kiyanne", "ada", "danna", "mata", "ennda", "apata", "tikak"}
	for _, kw := range siKeywords {
		if strings.Contains(low, " "+kw+" ") || strings.HasSuffix(low, " "+kw) || strings.HasPrefix(low, kw+" ") {
			return langSI
		}
	}
	return langEN
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
	q := strings.ToLower(query)
	lang := detectLanguage(query)
	greetingName := "there"
	if userName != "" {
		greetingName = strings.Split(userName, " ")[0]
	}

	// ── 1. Try DB-backed FAQ matching ────────────────────────────────────────
	if database.DB != nil {
		var faqs []models.ChatFAQ
		database.DB.Where("is_active = true").Order("priority DESC").Find(&faqs)

		for _, faq := range faqs {
			if matchesKeywords(q, faq.Keywords) {
				answer := pickAnswer(faq, lang)
				// Replace greeting placeholder
				answer = strings.ReplaceAll(answer, "{name}", greetingName)

				// Append live data if enabled
				if faq.IsLiveData && faq.LiveDataType != "" {
					liveBlock := buildLiveDataBlock(faq.LiveDataType, lang)
					if liveBlock != "" {
						answer += "\n\n" + liveBlock
					}
				}
				return answer
			}
		}
	}

	// ── 2. Hardcoded fallbacks (if DB is empty or unavailable) ────────────────
	return generateFallbackResponse(q, greetingName, lang)
}

// matchesKeywords checks if any keyword from the comma-separated list appears in query.
func matchesKeywords(query, keywords string) bool {
	parts := strings.Split(keywords, ",")
	for _, kw := range parts {
		kw = strings.TrimSpace(strings.ToLower(kw))
		if kw == "" {
			continue
		}
		if strings.Contains(query, kw) {
			return true
		}
	}
	return false
}

// ─────────────────────────────────────────────────────────────────────────────
// Live Data Blocks
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
	database.DB.Preload("User").Where("is_available = true").Find(&doctors)

	if len(doctors) == 0 {
		switch lang {
		case langSI:
			return "📋 *දැනට available doctors නොමැත.*"
		case langTA:
			return "📋 *தற்போது கிடைக்கக்கூடிய மருத்துவர்கள் இல்லை.*"
		default:
			return "📋 *No doctors are currently available.*"
		}
	}

	var header string
	switch lang {
	case langSI:
		header = "👨‍⚕️ **Available Doctors (Live):**\n"
	case langTA:
		header = "👨‍⚕️ **கிடைக்கக்கூடிய மருத்துவர்கள் (நேரடி):**\n"
	default:
		header = "👨‍⚕️ **Available Doctors (Live):**\n"
	}

	lines := header
	for _, d := range doctors {
		roomDisplay := roomDisplayName(string(d.Room))
		if d.User.FullName != "" {
			lines += fmt.Sprintf("• Dr. %s — %s | 🚪 %s\n", d.User.FullName, d.Specialization, roomDisplay)
		}
	}
	return strings.TrimRight(lines, "\n")
}

func buildQueueBlock(lang detectedLang) string {
	today := time.Now().Format("2006-01-02")

	type QueueSummary struct {
		Room    string
		Pending int64
		Serving int64
	}

	rooms := []string{
		"DRESSING_ROOM", "INJECTION_ROOM", "BLEEDING_ROOM",
		"ANIMAL_BITE_ROOM", "OPD_CLINIC_ROOM", "DISPENSARY_ROOM",
	}

	var header string
	switch lang {
	case langSI:
		header = "📊 **Live Queue Status (අද):**\n"
	case langTA:
		header = "📊 **நேரடி வரிசை நிலை (இன்று):**\n"
	default:
		header = "📊 **Live Queue Status (Today):**\n"
	}

	lines := header
	hasData := false
	for _, room := range rooms {
		var pending, serving int64
		database.DB.Model(&models.OPDAppointment{}).
			Where("room = ? AND appointment_date = ? AND status IN ?", room, today, []string{"PENDING", "CONFIRMED"}).
			Count(&pending)
		database.DB.Model(&models.OPDAppointment{}).
			Where("room = ? AND appointment_date = ? AND status = ?", room, today, "SERVING").
			Count(&serving)

		if pending+serving > 0 {
			hasData = true
			roomName := roomDisplayName(room)
			if serving > 0 {
				lines += fmt.Sprintf("• 🚪 **%s** — %d waiting, 1 serving\n", roomName, pending)
			} else {
				lines += fmt.Sprintf("• 🚪 **%s** — %d waiting\n", roomName, pending)
			}
		}
	}

	if !hasData {
		switch lang {
		case langSI:
			return "📊 *අද queue ෙකහි කිසිෙදනෙක් නොමැත.*"
		case langTA:
			return "📊 *இன்று வரிசையில் யாரும் இல்லை.*"
		default:
			return "📊 *No active queue entries for today.*"
		}
	}

	return strings.TrimRight(lines, "\n")
}

func buildRoomsBlock(lang detectedLang) string {
	today := time.Now().Format("2006-01-02")

	type RoomInfo struct {
		Name    string
		RoomID  string
		Emoji   string
	}

	roomInfos := []RoomInfo{
		{Name: "Dressing Room", RoomID: "DRESSING_ROOM", Emoji: "🩹"},
		{Name: "Injection Room", RoomID: "INJECTION_ROOM", Emoji: "💉"},
		{Name: "Bleeding Room", RoomID: "BLEEDING_ROOM", Emoji: "🩸"},
		{Name: "Animal Bite Room", RoomID: "ANIMAL_BITE_ROOM", Emoji: "🐾"},
		{Name: "OPD Clinic Room", RoomID: "OPD_CLINIC_ROOM", Emoji: "🏥"},
		{Name: "Dispensary Room", RoomID: "DISPENSARY_ROOM", Emoji: "💊"},
	}

	var header string
	switch lang {
	case langSI:
		header = "🚪 **OPD Rooms — Live Availability:**\n"
	case langTA:
		header = "🚪 **OPD அறைகள் — நேரடி தகவல்:**\n"
	default:
		header = "🚪 **OPD Rooms — Live Availability:**\n"
	}

	lines := header
	for _, ri := range roomInfos {
		var count int64
		database.DB.Model(&models.OPDAppointment{}).
			Where("room = ? AND appointment_date = ? AND status IN ?", ri.RoomID, today, []string{"PENDING", "CONFIRMED", "SERVING"}).
			Count(&count)

		var doctorName string
		var doc models.Doctor
		if err := database.DB.Preload("User").Where("room = ? AND is_available = true", ri.RoomID).First(&doc).Error; err == nil && doc.User.FullName != "" {
			doctorName = " • Dr. " + doc.User.FullName
		}

		statusEmoji := "🟢"
		if count > 5 {
			statusEmoji = "🟡"
		}
		if count > 15 {
			statusEmoji = "🔴"
		}

		lines += fmt.Sprintf("• %s **%s** %s%s — %d in queue\n", ri.Emoji, ri.Name, statusEmoji, doctorName, count)
	}

	return strings.TrimRight(lines, "\n")
}

func buildAppointmentsBlock(lang detectedLang) string {
	today := time.Now().Format("2006-01-02")

	var count int64
	database.DB.Model(&models.OPDAppointment{}).
		Where("appointment_date = ? AND status IN ?", today, []string{"PENDING", "CONFIRMED"}).
		Count(&count)

	switch lang {
	case langSI:
		return fmt.Sprintf("📅 *අද appointments: %d*", count)
	case langTA:
		return fmt.Sprintf("📅 *இன்று சந்திப்புகள்: %d*", count)
	default:
		return fmt.Sprintf("📅 *Today's total appointments: %d*", count)
	}
}

// roomDisplayName converts room DB enum to a human-readable name.
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
		return room
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Hardcoded Fallback (if DB FAQ table is empty)
// ─────────────────────────────────────────────────────────────────────────────

func generateFallbackResponse(q, greetingName string, lang detectedLang) string {
	switch {
	case strings.Contains(q, "hello") || strings.Contains(q, "hi") || strings.Contains(q, "hey") || strings.Contains(q, "ayubowan") || strings.Contains(q, "vanakkam"):
		switch lang {
		case langSI:
			return "👋 ආයුබෝවන් " + greetingName + "! මම MediQ AI Assistant. ඔබට කෙසේ උදව් කළ හැකිද?"
		case langTA:
			return "👋 வணக்கம் " + greetingName + "! நான் MediQ AI உதவியாளர். உங்களுக்கு எப்படி உதவலாம்?"
		default:
			return "👋 Hello " + greetingName + "! I am MediQ AI Assistant. How can I help you today?"
		}

	case strings.Contains(q, "opd") || strings.Contains(q, "queue") || strings.Contains(q, "ticket") || strings.Contains(q, "token") || strings.Contains(q, "waiting"):
		liveQueue := buildQueueBlock(lang)
		switch lang {
		case langSI:
			return "🏥 OPD Live Queue status home screen ෙකහි ඇත. ඔබේ QR code scan කරන්න හෝ token number enter කරන්න.\n\n" + liveQueue
		case langTA:
			return "🏥 OPD நேரடி வரிசை முகப்புத்திரையில் உள்ளது. உங்கள் QR குறியீட்டை ஸ்கேன் செய்யவும்.\n\n" + liveQueue
		default:
			return "🏥 OPD Live Queue is available on the home screen. Scan your QR or enter your token.\n\n" + liveQueue
		}

	case strings.Contains(q, "book") || strings.Contains(q, "appointment") || strings.Contains(q, "channel") || strings.Contains(q, "doctor"):
		liveDoctors := buildDoctorsBlock(lang)
		switch lang {
		case langSI:
			return "📅 Appointment book කිරීමට home screen ෙකහි 'Book Appointment' tap කරන්න. Room සහ Doctor select කරන්න.\n\n" + liveDoctors
		case langTA:
			return "📅 சந்திப்பு பதிவு செய்ய முகப்புத்திரையில் 'Book Appointment' தட்டவும்.\n\n" + liveDoctors
		default:
			return "📅 To book an appointment, tap 'Book Appointment' on the home screen. Select a room and doctor.\n\n" + liveDoctors
		}

	case strings.Contains(q, "room") || strings.Contains(q, "rooms"):
		return buildRoomsBlock(lang)

	case strings.Contains(q, "emergency") || strings.Contains(q, "urgent") || strings.Contains(q, "ambulance") || strings.Contains(q, "1990"):
		switch lang {
		case langSI:
			return "🚨 Emergency: Suwa Seriya - 1990 | MediQ - 011-234-5678 | Police - 119"
		case langTA:
			return "🚨 அவசரம்: Suwa Seriya - 1990 | MediQ - 011-234-5678 | காவல்துறை - 119"
		default:
			return "🚨 Emergency: Suwa Seriya Ambulance - 1990 | MediQ - 011-234-5678 | Police - 119"
		}

	default:
		switch lang {
		case langSI:
			return "👋 ආයුබෝවන් " + greetingName + "! MediQ AI Assistant.\n\nඔබට ඇසිය හැකිය:\n• 📅 Appointment book කිරීම\n• 🏥 OPD Queue Status\n• 🚪 Available Rooms & Doctors\n• 💊 Medications\n• 📁 Medical Records\n• 🚨 Emergency Contacts"
		case langTA:
			return "👋 வணக்கம் " + greetingName + "! MediQ AI உதவியாளர்.\n\nநீங்கள் கேட்கலாம்:\n• 📅 சந்திப்பு பதிவு\n• 🏥 OPD வரிசை\n• 🚪 அறைகள் & மருத்துவர்கள்\n• 💊 மருந்துகள்\n• 📁 பதிவுகள்\n• 🚨 அவசர தொடர்பு"
		default:
			return "👋 Hello " + greetingName + "! I'm MediQ AI Assistant.\n\nYou can ask me about:\n• 📅 Booking appointments\n• 🏥 OPD live queue status\n• 🚪 Available rooms & doctors\n• 💊 Medications & prescriptions\n• 📁 Medical records\n• 🚨 Emergency contacts"
		}
	}
}
