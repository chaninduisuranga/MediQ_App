package handlers

import (
	"net/http"
	"strconv"
	"strings"
	"time"

	"mediq-backend/internal/database"
	"mediq-backend/internal/models"
	"mediq-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type DoctorHandler struct{}

func NewDoctorHandler() *DoctorHandler {
	return &DoctorHandler{}
}

// GetTodayQueue returns today's OPD appointments for the authenticated Doctor.
// The doctor's assigned room is read from their Doctor record.
// GET /doctor/queue/today
func (h *DoctorHandler) GetTodayQueue(c *gin.Context) {
	userIDVal, exists := c.Get("userID")
	if !exists {
		utils.SendError(c, http.StatusUnauthorized, "Unauthorized")
		return
	}
	userID := userIDVal.(uint)

	// Resolve doctor record to get assigned room
	var doctor models.Doctor
	if err := database.DB.Where("user_id = ?", userID).First(&doctor).Error; err != nil {
		// Doctor record not found — return empty queue rather than error
		utils.SendSuccess(c, http.StatusOK, "No doctor assignment found", []interface{}{})
		return
	}

	loc := time.FixedZone("IST", 5*3600+30*60)
	today := time.Now().In(loc).Format("2006-01-02")

	// Optional date override via query param ?date=YYYY-MM-DD
	if d := strings.TrimSpace(c.Query("date")); d != "" {
		today = d
	}

	var appointments []models.OPDAppointment
	query := database.DB.Preload("AssignedDoctor.User").
		Where("appointment_date = ? AND status NOT IN ('CANCELLED')", today).
		Order("queue_number ASC")

	// Filter by doctor's assigned room if set
	if doctor.Room != "" {
		query = query.Where("room = ?", doctor.Room)
	}

	if err := query.Find(&appointments).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to fetch queue: "+err.Error())
		return
	}

	type QueueItem struct {
		ID              uint   `json:"id"`
		QueueNumber     int    `json:"queue_number"`
		QueueToken      string `json:"queue_token"`
		PatientID       uint   `json:"patient_id"`
		PatientName     string `json:"patient_name"`
		PatientNIC      string `json:"patient_nic"`
		PatientPhone    string `json:"patient_phone"`
		AppointmentDate string `json:"appointment_date"`
		AppointmentTime string `json:"appointment_time"`
		Room            string `json:"room"`
		RoomDisplayName string `json:"room_display_name"`
		Status          string `json:"status"`
		IsPriority      bool   `json:"is_priority"`
		Notes           string `json:"notes"`
		AssignedDoctor  string `json:"assigned_doctor,omitempty"`
	}

	items := make([]QueueItem, 0, len(appointments))
	for _, appt := range appointments {
		roomName := validRooms[appt.Room]
		if roomName == "" {
			roomName = string(appt.Room)
		}
		prefix := roomTokenPrefix(appt.Room)
		token := prefix + strconv.Itoa(appt.QueueNumber)

		docName := ""
		if appt.AssignedDoctor != nil && appt.AssignedDoctor.User.FullName != "" {
			docName = appt.AssignedDoctor.User.FullName
		}

		items = append(items, QueueItem{
			ID:              appt.ID,
			QueueNumber:     appt.QueueNumber,
			QueueToken:      token,
			PatientID:       appt.PatientID,
			PatientName:     appt.PatientName,
			PatientNIC:      appt.PatientNIC,
			PatientPhone:    appt.PatientPhone,
			AppointmentDate: appt.AppointmentDate,
			AppointmentTime: appt.AppointmentTime,
			Room:            string(appt.Room),
			RoomDisplayName: roomName,
			Status:          string(appt.Status),
			IsPriority:      appt.IsPriority,
			Notes:           appt.Notes,
			AssignedDoctor:  docName,
		})
	}

	utils.SendSuccess(c, http.StatusOK, "Today's doctor queue", gin.H{
		"date":      today,
		"room":      string(doctor.Room),
		"total":     len(items),
		"queue":     items,
	})
}

// UpdateAppointmentStatus lets a doctor change an appointment's status.
// PATCH /doctor/queue/:id/status
// Body: { "status": "SERVING" | "COMPLETED" | "NO_SHOW" | "PENDING" }
func (h *DoctorHandler) UpdateAppointmentStatus(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.Atoi(idStr)
	if err != nil || id <= 0 {
		utils.SendError(c, http.StatusBadRequest, "Invalid appointment ID")
		return
	}

	var req struct {
		Status string `json:"status" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.SendError(c, http.StatusBadRequest, "status is required")
		return
	}

	allowedStatuses := map[string]models.AppointmentStatus{
		"SERVING":   models.AppointmentServing,
		"COMPLETED": models.AppointmentCompleted,
		"NO_SHOW":   models.AppointmentNoShow,
		"PENDING":   models.AppointmentPending,
		"CANCELLED": models.AppointmentCancelled,
	}

	newStatus, ok := allowedStatuses[strings.ToUpper(strings.TrimSpace(req.Status))]
	if !ok {
		utils.SendError(c, http.StatusBadRequest, "Invalid status. Allowed: SERVING, COMPLETED, NO_SHOW, PENDING, CANCELLED")
		return
	}

	var appt models.OPDAppointment
	if err := database.DB.First(&appt, id).Error; err != nil {
		utils.SendError(c, http.StatusNotFound, "Appointment not found")
		return
	}

	appt.Status = newStatus
	if newStatus == models.AppointmentCompleted {
		loc := time.FixedZone("IST", 5*3600+30*60)
		now := time.Now().In(loc)
		appt.CompletedAt = &now
	}

	if err := database.DB.Save(&appt).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to update status: "+err.Error())
		return
	}

	utils.SendSuccess(c, http.StatusOK, "Appointment status updated", gin.H{
		"id":     appt.ID,
		"status": string(appt.Status),
	})
}

// GetQueueStats returns summary stats for the doctor's room today.
// GET /doctor/queue/stats
func (h *DoctorHandler) GetQueueStats(c *gin.Context) {
	userIDVal, exists := c.Get("userID")
	if !exists {
		utils.SendError(c, http.StatusUnauthorized, "Unauthorized")
		return
	}
	userID := userIDVal.(uint)

	var doctor models.Doctor
	if err := database.DB.Where("user_id = ?", userID).First(&doctor).Error; err != nil {
		utils.SendSuccess(c, http.StatusOK, "No doctor assignment", gin.H{"total": 0, "waiting": 0, "serving": 0, "completed": 0})
		return
	}

	loc := time.FixedZone("IST", 5*3600+30*60)
	today := time.Now().In(loc).Format("2006-01-02")

	type Stats struct {
		Total     int64
		Waiting   int64
		Serving   int64
		Completed int64
	}

	var total, waiting, serving, completed int64
	baseQ := database.DB.Model(&models.OPDAppointment{}).
		Where("appointment_date = ? AND room = ? AND status != 'CANCELLED'", today, doctor.Room)

	baseQ.Count(&total)
	database.DB.Model(&models.OPDAppointment{}).
		Where("appointment_date = ? AND room = ? AND status = 'PENDING'", today, doctor.Room).Count(&waiting)
	database.DB.Model(&models.OPDAppointment{}).
		Where("appointment_date = ? AND room = ? AND status = 'SERVING'", today, doctor.Room).Count(&serving)
	database.DB.Model(&models.OPDAppointment{}).
		Where("appointment_date = ? AND room = ? AND status = 'COMPLETED'", today, doctor.Room).Count(&completed)

	utils.SendSuccess(c, http.StatusOK, "Queue stats", gin.H{
		"date":      today,
		"room":      string(doctor.Room),
		"total":     total,
		"waiting":   waiting,
		"serving":   serving,
		"completed": completed,
	})
}

// roomTokenPrefix returns a short letter prefix for a room's queue token display
func roomTokenPrefix(room models.OPDRoom) string {
	switch room {
	case models.RoomDressing:
		return "D-"
	case models.RoomInjection:
		return "I-"
	case models.RoomBleeding:
		return "B-"
	case models.RoomAnimalBite:
		return "A-"
	case models.RoomOPDClinic:
		return "G-"
	case models.RoomDispensary:
		return "P-"
	default:
		return "Q-"
	}
}
