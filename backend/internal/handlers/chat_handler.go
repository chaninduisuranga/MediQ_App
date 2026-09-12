package handlers

import (
	"net/http"
	"strings"

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

	reply := generateAIResponse(userMsgText, userName)

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

func generateAIResponse(query, userName string) string {
	q := strings.ToLower(query)
	greetingName := "there"
	if userName != "" {
		greetingName = strings.Split(userName, " ")[0]
	}

	switch {
	case strings.Contains(q, "opd") || strings.Contains(q, "queue") || strings.Contains(q, "ticket"):
		return "🏥 MediQ OPD Live Queue Status:\n• Real-time queue updates are available on the home screen.\n• You can scan your token QR code or enter your ticket number to track your turn live!"

	case strings.Contains(q, "book") || strings.Contains(q, "appointment") || strings.Contains(q, "channel") || strings.Contains(q, "doctor"):
		return "📅 Booking an Appointment:\n1. Tap 'Book Appointment' on the main dashboard.\n2. Select your preferred doctor and OPD room.\n3. Choose your date & time slot to confirm your token instantly!"

	case strings.Contains(q, "pill") || strings.Contains(q, "medicine") || strings.Contains(q, "remind") || strings.Contains(q, "prescription"):
		return "💊 Medication & Pill Tracker:\n• Track your daily prescriptions and dosages.\n• Enable notifications to get timely pill reminders!\n• View past prescriptions in the 'Medical Records' section."

	case strings.Contains(q, "record") || strings.Contains(q, "lab") || strings.Contains(q, "report") || strings.Contains(q, "history"):
		return "📁 Medical Records:\n• Access your digital prescriptions and lab reports anytime under 'Medical Records'.\n• Upload doctor notes or PDF reports securely to your profile."

	case strings.Contains(q, "fever") || strings.Contains(q, "headache") || strings.Contains(q, "cold") || strings.Contains(q, "symptom"):
		return "🌡️ Symptom Checker Guidance:\n• For common mild symptoms, stay hydrated and get plenty of rest.\n• Use our built-in 'Symptom Checker' on the home page for automated triage.\n⚠️ If experiencing high fever (>102°F) or severe pain, please consult an OPD doctor immediately."

	case strings.Contains(q, "emergency") || strings.Contains(q, "urgent") || strings.Contains(q, "help") || strings.Contains(q, "ambulance"):
		return "🚨 Emergency Contacts:\n• National Emergency Ambulance: 1990 (Suwa Seriya)\n• MediQ Emergency Line: 011-234-5678\n⚠️ If you have chest pain, shortness of breath, or severe trauma, please seek immediate emergency care!"

	case strings.Contains(q, "hello") || strings.Contains(q, "hi") || strings.Contains(q, "hey") || strings.Contains(q, "ayubowan"):
		return "Hello " + greetingName + "! 👋 I am your MediQ AI Health Assistant. How can I assist you with your health, appointments, or prescriptions today?"

	case strings.Contains(q, "profile") || strings.Contains(q, "nic") || strings.Contains(q, "account"):
		return "👤 User Profile:\n• You can view and update your personal details, NIC, phone number, and emergency contact in the 'Profile' section."

	case strings.Contains(q, "hour") || strings.Contains(q, "time") || strings.Contains(q, "open") || strings.Contains(q, "location"):
		return "🕒 Hospital Working Hours:\n• OPD Consultation: Mon - Sun (7:00 AM - 9:00 PM)\n• Emergency & Admissions: 24/7 Open\n• Pharmacy & Lab: 24/7 Available"

	default:
		return "Hello " + greetingName + "! I'm MediQ AI Assistant. You can ask me about:\n• 📅 Booking Doctor Appointments\n• 🏥 OPD Live Queue Status\n• 💊 Pill Reminders & Prescriptions\n• 📁 Digital Medical Records\n• 🌡️ General Symptom Checker & Emergency Contacts"
	}
}
