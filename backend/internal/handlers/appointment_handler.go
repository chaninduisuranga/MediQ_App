package handlers

import (
	"fmt"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"mediq-backend/internal/database"
	"mediq-backend/internal/models"
	"mediq-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type AppointmentHandler struct{}

func NewAppointmentHandler() *AppointmentHandler {
	return &AppointmentHandler{}
}

// Valid OPD rooms
var validRooms = map[models.OPDRoom]string{
	models.RoomDressing:   "Dressing Room (Wound Care)",
	models.RoomInjection:  "Injection Room",
	models.RoomBleeding:   "Bleeding Room",
	models.RoomAnimalBite: "Animal Bite Room",
	models.RoomOPDClinic:  "OPD Clinic Room",
	models.RoomDispensary: "Dispensary",
}

// GetRooms returns all available OPD rooms
func (h *AppointmentHandler) GetRooms(c *gin.Context) {
	type RoomInfo struct {
		Key  string `json:"key"`
		Name string `json:"name"`
	}

	rooms := []RoomInfo{
		{Key: string(models.RoomDressing), Name: "Dressing Room (Wound Care)"},
		{Key: string(models.RoomInjection), Name: "Injection Room"},
		{Key: string(models.RoomBleeding), Name: "Bleeding Room"},
		{Key: string(models.RoomAnimalBite), Name: "Animal Bite Room"},
		{Key: string(models.RoomOPDClinic), Name: "OPD Clinic Room"},
		{Key: string(models.RoomDispensary), Name: "Dispensary"},
	}

	utils.SendSuccess(c, http.StatusOK, "Available OPD rooms", rooms)
}

// BookAppointment books an OPD appointment for the authenticated patient
func (h *AppointmentHandler) BookAppointment(c *gin.Context) {
	userIDVal, exists := c.Get("userID")
	if !exists {
		utils.SendError(c, http.StatusUnauthorized, "Unauthorized")
		return
	}
	userID := userIDVal.(uint)

	type BookRequest struct {
		Room  string `json:"room" binding:"required"`
		Date  string `json:"date"` // Format: YYYY-MM-DD (optional, defaults to today)
		Notes string `json:"notes"`
	}

	var req BookRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.SendError(c, http.StatusBadRequest, "Please select an OPD room: "+err.Error())
		return
	}

	room := models.OPDRoom(strings.ToUpper(strings.TrimSpace(req.Room)))
	if _, ok := validRooms[room]; !ok {
		utils.SendError(c, http.StatusBadRequest, "Invalid OPD room. Choose from: DRESSING_ROOM, INJECTION_ROOM, BLEEDING_ROOM, ANIMAL_BITE_ROOM, OPD_CLINIC_ROOM")
		return
	}

	// Get current user details
	var user models.User
	if err := database.DB.First(&user, userID).Error; err != nil {
		utils.SendError(c, http.StatusNotFound, "Patient profile not found")
		return
	}

	// Timezone (Sri Lanka time: UTC+5:30)
	loc := time.FixedZone("IST", 5*3600+30*60)
	now := time.Now().In(loc)
	todayStr := now.Format("2006-01-02")
	day1Str := now.AddDate(0, 0, 1).Format("2006-01-02")
	day2Str := now.AddDate(0, 0, 2).Format("2006-01-02")

	// Determine selected date
	selectedDate := strings.TrimSpace(req.Date)
	if selectedDate == "" {
		selectedDate = todayStr
	}

	// Validate date is within 3 days from today (today, tomorrow, day after tomorrow)
	if selectedDate != todayStr && selectedDate != day1Str && selectedDate != day2Str {
		utils.SendError(c, http.StatusBadRequest, fmt.Sprintf("Appointments can only be booked for today (%s) or within the next 2 days (%s, %s)", todayStr, day1Str, day2Str))
		return
	}

	// 10:00 AM cutoff for TODAY's appointments
	if selectedDate == todayStr {
		cutoffTime := time.Date(now.Year(), now.Month(), now.Day(), 10, 0, 0, 0, loc)
		if now.After(cutoffTime) {
			utils.SendError(c, http.StatusBadRequest, "Same-day OPD appointment booking closes at 10:00 AM. Please select Tomorrow or the next available day.")
			return
		}
	}

	// Check if patient already has an appointment for this room on selected date
	var existingCount int64
	database.DB.Model(&models.OPDAppointment{}).
		Where("patient_id = ? AND room = ? AND appointment_date = ? AND status != ?",
			userID, room, selectedDate, models.AppointmentCancelled).
		Count(&existingCount)

	if existingCount > 0 {
		utils.SendError(c, http.StatusConflict, fmt.Sprintf("You already have an active appointment for %s on %s", validRooms[room], selectedDate))
		return
	}

	// Calculate queue number: MAX queue number for this room on selectedDate + 1
	var maxQueue int
	database.DB.Model(&models.OPDAppointment{}).
		Where("room = ? AND appointment_date = ?", room, selectedDate).
		Select("COALESCE(MAX(queue_number), 0)").
		Scan(&maxQueue)

	newQueueNumber := maxQueue + 1
	appointmentTime := time.Date(2000, 1, 1, 8, 0, 0, 0, loc).
		Add(time.Duration(newQueueNumber-1) * 15 * time.Minute)

	appointment := models.OPDAppointment{
		PatientID:       userID,
		Room:            room,
		QueueNumber:     newQueueNumber,
		AppointmentDate: selectedDate,
		AppointmentTime: appointmentTime.Format("15:04"),
		PatientName:     user.FullName,
		PatientNIC:      user.NIC,
		PatientPhone:    user.Phone,
		Notes:           strings.TrimSpace(req.Notes),
		Status:          models.AppointmentPending,
		QRCodeData:      "",
	}

	if err := database.DB.Create(&appointment).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to book appointment: "+err.Error())
		return
	}

	// Notify doctor for this room about the new appointment
	utils.NotifyDoctorForRoom(
		database.DB,
		room,
		"NEW_APPOINTMENT",
		"New Appointment Booked",
		fmt.Sprintf("%s booked appointment #%d for %s.", user.FullName, newQueueNumber, selectedDate),
	)

	// Construct Web View URL for QR scan redirection
	scheme := "http"
	if c.Request.TLS != nil || c.GetHeader("X-Forwarded-Proto") == "https" {
		scheme = "https"
	}
	host := c.Request.Host
	if host == "" {
		host = "localhost:8085"
	}
	viewURL := fmt.Sprintf("%s://%s/api/v1/appointments/view/%d", scheme, host, appointment.ID)

	// Update appointment with QR view URL
	appointment.QRCodeData = viewURL
	database.DB.Model(&appointment).Update("qr_code_data", viewURL)

	// Build response with room display name
	type BookResponse struct {
		models.OPDAppointment
		RoomDisplayName string `json:"room_display_name"`
	}

	utils.SendSuccess(c, http.StatusCreated, fmt.Sprintf("Appointment booked for %s! Your queue number is %d", selectedDate, newQueueNumber), BookResponse{
		OPDAppointment:  appointment,
		RoomDisplayName: validRooms[room],
	})
}

// GetPatientHistory returns COMPLETED OPD consultations for the authenticated patient (Doctor History).
// Optional query param: ?month=YYYY-MM  e.g. ?month=2026-10
func (h *AppointmentHandler) GetPatientHistory(c *gin.Context) {
	userIDVal, exists := c.Get("userID")
	if !exists {
		utils.SendError(c, http.StatusUnauthorized, "Unauthorized")
		return
	}
	userID := userIDVal.(uint)

	monthFilter := strings.TrimSpace(c.Query("month")) // e.g. "2026-10"

	query := database.DB.Preload("AssignedDoctor.User").
		Where("patient_id = ? AND status = ?", userID, models.AppointmentCompleted)

	if monthFilter != "" {
		// appointment_date is stored as YYYY-MM-DD, filter by prefix match
		query = query.Where("appointment_date LIKE ?", monthFilter+"%")
	}

	var appointments []models.OPDAppointment
	if err := query.Order("appointment_date DESC, queue_number DESC").
		Find(&appointments).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to retrieve history: "+err.Error())
		return
	}

	type HistoryItem struct {
		ID              uint   `json:"id"`
		AppointmentDate string `json:"appointment_date"`
		AppointmentTime string `json:"appointment_time"`
		Room            string `json:"room"`
		RoomDisplayName string `json:"room_display_name"`
		QueueNumber     int    `json:"queue_number"`
		DoctorName      string `json:"doctor_name"`
		Notes           string `json:"notes"`
		CompletedAt     string `json:"completed_at,omitempty"`
	}

	items := make([]HistoryItem, 0, len(appointments))
	for _, appt := range appointments {
		doctorName := "OPD Doctor"
		if appt.AssignedDoctor != nil && appt.AssignedDoctor.User.FullName != "" {
			doctorName = appt.AssignedDoctor.User.FullName
		}
		completedAt := ""
		if appt.CompletedAt != nil {
			loc := time.FixedZone("IST", 5*3600+30*60)
			completedAt = appt.CompletedAt.In(loc).Format("2006-01-02 15:04")
		}
		roomName := validRooms[appt.Room]
		if roomName == "" {
			roomName = string(appt.Room)
		}
		items = append(items, HistoryItem{
			ID:              appt.ID,
			AppointmentDate: appt.AppointmentDate,
			AppointmentTime: appt.AppointmentTime,
			Room:            string(appt.Room),
			RoomDisplayName: roomName,
			QueueNumber:     appt.QueueNumber,
			DoctorName:      doctorName,
			Notes:           appt.Notes,
			CompletedAt:     completedAt,
		})
	}

	utils.SendSuccess(c, http.StatusOK, "Patient OPD history retrieved", items)
}

// GetMyAppointments returns active (non-completed, non-cancelled) appointments for the authenticated patient
func (h *AppointmentHandler) GetMyAppointments(c *gin.Context) {
	userIDVal, exists := c.Get("userID")
	if !exists {
		utils.SendError(c, http.StatusUnauthorized, "Unauthorized")
		return
	}
	userID := userIDVal.(uint)

	var appointments []models.OPDAppointment
	if err := database.DB.Where("patient_id = ? AND status NOT IN ('COMPLETED', 'CANCELLED')", userID).
		Order("appointment_date ASC, queue_number ASC").
		Find(&appointments).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to retrieve appointments: "+err.Error())
		return
	}

	utils.SendSuccess(c, http.StatusOK, "Appointments retrieved successfully", appointments)
}

// GetQueueStatus returns the current queue count and live token breakdown for a specific room on a given date (default today)
func (h *AppointmentHandler) GetQueueStatus(c *gin.Context) {
	roomKey := c.Param("room")
	room := models.OPDRoom(strings.ToUpper(strings.TrimSpace(roomKey)))

	if _, ok := validRooms[room]; !ok {
		utils.SendError(c, http.StatusBadRequest, "Invalid room key")
		return
	}

	loc := time.FixedZone("IST", 5*3600+30*60)
	targetDate := strings.TrimSpace(c.Query("date"))
	if targetDate == "" {
		targetDate = time.Now().In(loc).Format("2006-01-02")
	}

	var maxQueue int
	database.DB.Model(&models.OPDAppointment{}).
		Where("room = ? AND appointment_date = ? AND status != ?", room, targetDate, models.AppointmentCancelled).
		Select("COALESCE(MAX(queue_number), 0)").
		Scan(&maxQueue)

	var appointments []models.OPDAppointment
	database.DB.Preload("AssignedDoctor.User").
		Where("room = ? AND appointment_date = ? AND status != ?", room, targetDate, models.AppointmentCancelled).
		Order("queue_number ASC").
		Find(&appointments)

	nowServing := 0
	servingDoctorName := ""
	var servingPatientID uint

	type QueueItemResponse struct {
		ID          uint   `json:"id"`
		QueueNumber int    `json:"queue_number"`
		Status      string `json:"status"`
		IsPriority  bool   `json:"is_priority"`
		PatientID   uint   `json:"patient_id"`
		PatientName string `json:"patient_name"`
		DoctorName  string `json:"doctor_name,omitempty"`
	}

	queueList := make([]QueueItemResponse, 0, len(appointments))
	for _, appt := range appointments {
		docName := ""
		if appt.AssignedDoctor != nil && appt.AssignedDoctor.User.FullName != "" {
			docName = appt.AssignedDoctor.User.FullName
		}
		if appt.Status == models.AppointmentServing {
			nowServing = appt.QueueNumber
			servingDoctorName = docName
			servingPatientID = appt.PatientID
		}
		queueList = append(queueList, QueueItemResponse{
			ID:          appt.ID,
			QueueNumber: appt.QueueNumber,
			Status:      string(appt.Status),
			IsPriority:  appt.IsPriority,
			PatientID:   appt.PatientID,
			PatientName: appt.PatientName,
			DoctorName:  docName,
		})
	}

	type QueueStatusResponse struct {
		Room              string              `json:"room"`
		RoomDisplayName   string              `json:"room_display_name"`
		Date              string              `json:"date"`
		CurrentMax        int                 `json:"current_max"`
		NextNumber        int                 `json:"next_number"`
		NowServing        int                 `json:"now_serving"`
		ServingDoctorName string              `json:"serving_doctor_name,omitempty"`
		ServingPatientID  uint                `json:"serving_patient_id,omitempty"`
		TotalBooked       int                 `json:"total_booked"`
		QueueTokens       []QueueItemResponse `json:"queue_tokens"`
	}

	utils.SendSuccess(c, http.StatusOK, "Queue status", QueueStatusResponse{
		Room:              string(room),
		RoomDisplayName:   validRooms[room],
		Date:              targetDate,
		CurrentMax:        maxQueue,
		NextNumber:        maxQueue + 1,
		NowServing:        nowServing,
		ServingDoctorName: servingDoctorName,
		ServingPatientID:  servingPatientID,
		TotalBooked:       len(appointments),
		QueueTokens:       queueList,
	})
}

// CancelAppointment cancels a patient's appointment
func (h *AppointmentHandler) CancelAppointment(c *gin.Context) {
	userIDVal, exists := c.Get("userID")
	if !exists {
		utils.SendError(c, http.StatusUnauthorized, "Unauthorized")
		return
	}
	userID := userIDVal.(uint)
	appointmentID := c.Param("id")

	var appt models.OPDAppointment
	if err := database.DB.Where("id = ? AND patient_id = ?", appointmentID, userID).First(&appt).Error; err != nil {
		utils.SendError(c, http.StatusNotFound, "Appointment not found")
		return
	}

	appt.Status = models.AppointmentCancelled
	if err := database.DB.Save(&appt).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to cancel appointment: "+err.Error())
		return
	}

	// Notify doctor about cancellation
	utils.NotifyDoctorForRoom(
		database.DB,
		appt.Room,
		"APPOINTMENT_CANCELLED",
		"Appointment Cancelled",
		fmt.Sprintf("Appointment #%d for %s on %s was cancelled by patient.", appt.QueueNumber, appt.PatientName, appt.AppointmentDate),
	)

	utils.SendSuccess(c, http.StatusOK, "Appointment cancelled successfully", nil)
}

// ViewAppointment renders an advanced HTML webpage when QR code is scanned
func (h *AppointmentHandler) ViewAppointment(c *gin.Context) {
	idParam := c.Param("id")
	id, err := strconv.Atoi(idParam)
	if err != nil {
		c.Header("Content-Type", "text/html; charset=utf-8")
		c.String(http.StatusBadRequest, renderErrorPage("Invalid Ticket ID"))
		return
	}

	var appt models.OPDAppointment
	if err := database.DB.First(&appt, id).Error; err != nil {
		c.Header("Content-Type", "text/html; charset=utf-8")
		c.String(http.StatusNotFound, renderErrorPage("Appointment Ticket Not Found or Expired"))
		return
	}

	roomDisplayName := validRooms[appt.Room]
	if roomDisplayName == "" {
		roomDisplayName = string(appt.Room)
	}

	html := renderTicketPage(appt, roomDisplayName)
	c.Header("Content-Type", "text/html; charset=utf-8")
	c.String(http.StatusOK, html)
}

// CleanupExpiredAppointments deletes appointments that have passed (date < today)
func CleanupExpiredAppointments() {
	// Auto-cleanup disabled to preserve appointment records for doctor queue review
	log.Println("[Cleanup] Auto-cleanup of expired appointments is disabled")
}

// Helper function to render a beautiful HTML Ticket Page for QR scan
func renderTicketPage(appt models.OPDAppointment, roomName string) string {
	statusColor := "#02C39A"
	if appt.Status == models.AppointmentCancelled {
		statusColor = "#EF4444"
	} else if appt.Status == models.AppointmentCompleted {
		statusColor = "#3B82F6"
	}

	notesHTML := ""
	if appt.Notes != "" {
		notesHTML = fmt.Sprintf(`
			<div class="info-row">
				<span class="info-label">Notes:</span>
				<span class="info-value">%s</span>
			</div>`, appt.Notes)
	}

	return fmt.Sprintf(`<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MediQ OPD Appointment Ticket - #%d</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; font-family: 'Segoe UI', Roboto, sans-serif; }
        body {
            background: linear-gradient(135deg, #0f172a 0%%, #1e293b 50%%, #0f766e 100%%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 20px;
            color: #f8fafc;
        }
        .ticket-card {
            background: rgba(30, 41, 59, 0.85);
            backdrop-filter: blur(16px);
            border: 1px solid rgba(255, 255, 255, 0.15);
            border-radius: 28px;
            width: 100%%;
            max-width: 440px;
            box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5), 0 0 30px rgba(2, 195, 154, 0.2);
            overflow: hidden;
            animation: fadeIn 0.5s ease-out;
        }
        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(20px); }
            to { opacity: 1; transform: translateY(0); }
        }
        .header {
            background: linear-gradient(135deg, #0077b6, #00a896);
            padding: 24px 20px;
            text-align: center;
            position: relative;
        }
        .header h1 { font-size: 22px; font-weight: 800; letter-spacing: 0.5px; margin-bottom: 4px; }
        .header p { font-size: 13px; opacity: 0.9; font-weight: 500; }
        .queue-container {
            text-align: center;
            padding: 30px 20px 20px;
            background: rgba(0, 168, 150, 0.08);
            border-bottom: 1px dashed rgba(255, 255, 255, 0.15);
        }
        .queue-title { font-size: 13px; text-transform: uppercase; letter-spacing: 1.5px; color: #2dd4bf; font-weight: 700; margin-bottom: 8px; }
        .queue-number {
            font-size: 88px;
            font-weight: 900;
            line-height: 1;
            background: linear-gradient(180deg, #ffffff 0%%, #2dd4bf 100%%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            text-shadow: 0 10px 20px rgba(45, 212, 191, 0.3);
        }
        .room-badge {
            display: inline-block;
            margin-top: 14px;
            padding: 8px 18px;
            background: rgba(45, 212, 191, 0.15);
            border: 1px solid rgba(45, 212, 191, 0.4);
            border-radius: 20px;
            font-size: 14px;
            font-weight: 700;
            color: #5eead4;
        }
        .details-body { padding: 24px 24px 30px; }
        .info-row {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 12px 0;
            border-bottom: 1px solid rgba(255, 255, 255, 0.08);
        }
        .info-row:last-child { border-bottom: none; }
        .info-label { font-size: 13px; color: #94a3b8; font-weight: 500; }
        .info-value { font-size: 14px; color: #f8fafc; font-weight: 600; text-align: right; }
        .status-pill {
            padding: 4px 12px;
            border-radius: 12px;
            font-size: 12px;
            font-weight: 800;
            background: %s;
            color: #fff;
        }
        .footer-note {
            text-align: center;
            padding: 16px;
            background: rgba(15, 23, 42, 0.6);
            font-size: 11px;
            color: #64748b;
            border-top: 1px solid rgba(255, 255, 255, 0.05);
        }
    </style>
</head>
<body>
    <div class="ticket-card">
        <div class="header">
            <h1>MediQ OPD Portal</h1>
            <p>Official Digital Queue Ticket</p>
        </div>
        <div class="queue-container">
            <div class="queue-title">Your Queue Number</div>
            <div class="queue-number">#%d</div>
            <div class="room-badge">%s</div>
        </div>
        <div class="details-body">
            <div class="info-row">
                <span class="info-label">Appointment Date</span>
                <span class="info-value" style="color: #2dd4bf; font-weight: 700;">%s</span>
            </div>
            <div class="info-row">
                <span class="info-label">Patient Name</span>
                <span class="info-value">%s</span>
            </div>
            <div class="info-row">
                <span class="info-label">NIC Number</span>
                <span class="info-value">%s</span>
            </div>
            <div class="info-row">
                <span class="info-label">Phone</span>
                <span class="info-value">%s</span>
            </div>
            <div class="info-row">
                <span class="info-label">Ticket Status</span>
                <span class="info-value"><span class="status-pill">%s</span></span>
            </div>
            %s
            <div class="info-row">
                <span class="info-label">Booked Date</span>
                <span class="info-value" style="font-size: 12px; color: #94a3b8;">%s</span>
            </div>
        </div>
        <div class="footer-note">
            Please display this ticket at the OPD Counter when your number is called.
            <br>&copy; 2026 MediQ Health System. All rights reserved.
        </div>
    </div>
</body>
</html>`, appt.ID, statusColor, appt.QueueNumber, roomName, appt.AppointmentDate, appt.PatientName, appt.PatientNIC, appt.PatientPhone, appt.Status, notesHTML, appt.CreatedAt.Format("2006-01-02 15:04"))
}

func renderErrorPage(msg string) string {
	return fmt.Sprintf(`<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Ticket Not Found - MediQ</title>
    <style>
        body { background: #0f172a; color: #fff; font-family: sans-serif; display: flex; height: 100vh; justify-content: center; align-items: center; text-align: center; }
        .card { background: #1e293b; padding: 40px; border-radius: 20px; border: 1px solid #334155; }
        h1 { color: #ef4444; font-size: 24px; margin-bottom: 10px; }
        p { color: #94a3b8; }
    </style>
</head>
<body>
    <div class="card">
        <h1>Ticket Error</h1>
        <p>%s</p>
    </div>
</body>
</html>`, msg)
}
