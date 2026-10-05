package handlers

import (
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"mediq-backend/internal/database"
	"mediq-backend/internal/models"
	"mediq-backend/internal/utils"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type StaffQueueHandler struct{}

func NewStaffQueueHandler() *StaffQueueHandler {
	return &StaffQueueHandler{}
}

func (h *StaffQueueHandler) ensureDatabase(c *gin.Context) bool {
	if database.DB == nil {
		utils.SendError(c, http.StatusInternalServerError, "Database connection not initialized")
		return false
	}
	return true
}

// GetProfile returns the authenticated Staff member's assignment details.
func (h *StaffQueueHandler) GetProfile(c *gin.Context) {
	if !h.ensureDatabase(c) {
		return
	}

	userIDVal, exists := c.Get("userID")
	if !exists {
		utils.SendError(c, http.StatusUnauthorized, "Unauthorized")
		return
	}
	userID, ok := userIDVal.(uint)
	if !ok {
		utils.SendError(c, http.StatusUnauthorized, "Unauthorized")
		return
	}

	var assignment models.AdminStaffAssignment
	if err := database.DB.
		Select([]string{"assigned_room", "function", "is_available"}).
		Where("user_id = ?", userID).
		First(&assignment).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			utils.SendError(c, http.StatusNotFound, "Staff assignment not found")
			return
		}
		utils.SendError(c, http.StatusInternalServerError, "Failed to load Staff assignment")
		return
	}

	utils.SendSuccess(c, http.StatusOK, "Staff profile retrieved", gin.H{
		"assigned_room": assignment.AssignedRoom,
		"function":      assignment.Function,
		"is_available":  assignment.IsAvailable,
	})
}

func (h *StaffQueueHandler) getAssignedRoom(c *gin.Context) (models.OPDRoom, error) {
	userIDVal, exists := c.Get("userID")
	if !exists {
		return "", fmt.Errorf("unauthorized")
	}
	userID := userIDVal.(uint)

	var assignment models.AdminStaffAssignment
	if err := database.DB.Where("user_id = ?", userID).First(&assignment).Error; err != nil {
		return "", fmt.Errorf("staff assignment not found")
	}
	return assignment.AssignedRoom, nil
}

// GetQueueList returns today's queue for the staff member's assigned room
func (h *StaffQueueHandler) GetQueueList(c *gin.Context) {
	if !h.ensureDatabase(c) {
		return
	}

	room, err := h.getAssignedRoom(c)
	if err != nil {
		utils.SendError(c, http.StatusForbidden, "You are not assigned to any room")
		return
	}

	loc := time.FixedZone("IST", 5*3600+30*60)
	today := time.Now().In(loc).Format("2006-01-02")

	var appointments []models.OPDAppointment
	if err := database.DB.Preload("AssignedDoctor.User").
		Where("room = ? AND appointment_date = ?", room, today).
		Order("is_priority DESC, queue_number ASC").
		Find(&appointments).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to load queue")
		return
	}

	utils.SendSuccess(c, http.StatusOK, "Queue list retrieved", appointments)
}

// GetQueueHistory returns history only for the authenticated Staff member's assigned room.
func (h *StaffQueueHandler) GetQueueHistory(c *gin.Context) {
	if !h.ensureDatabase(c) {
		return
	}

	room, err := h.getAssignedRoom(c)
	if err != nil {
		utils.SendError(c, http.StatusForbidden, "You are not assigned to any room")
		return
	}

	loc := time.FixedZone("IST", 5*3600+30*60)
	now := time.Now().In(loc)
	filterTime := c.DefaultQuery("filter_time", "Today")
	var start, end time.Time
	switch filterTime {
	case "Today":
		start = time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, loc)
		end = start.AddDate(0, 0, 1)
	case "This Week":
		today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, loc)
		daysSinceMonday := (int(today.Weekday()) + 6) % 7
		start = today.AddDate(0, 0, -daysSinceMonday)
		end = start.AddDate(0, 0, 7)
	case "This Month":
		start = time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, loc)
		end = start.AddDate(0, 1, 0)
	default:
		utils.SendError(c, http.StatusBadRequest, "Invalid history time filter")
		return
	}

	type historyItem struct {
		ID          uint    `json:"id"`
		Token       string  `json:"token"`
		PatientName string  `json:"patient_name"`
		Room        string  `json:"room"`
		Action      string  `json:"action"`
		Status      string  `json:"status"`
		Timestamp   string  `json:"timestamp"`
		Date        string  `json:"date"`
		Details     *string `json:"details"`
	}
	type historyRecord struct {
		ID          uint
		Action      string
		Status      models.AppointmentStatus
		Room        models.OPDRoom
		Details     *string
		OccurredAt  time.Time
		QueueNumber int
		PatientName string
	}
	var events []historyRecord
	query := database.DB.Table("staff_queue_activity_histories AS history").
		Select("history.id, history.action, history.status, history.room, history.details, history.occurred_at, appointments.queue_number, appointments.patient_name").
		Joins("JOIN opd_appointments AS appointments ON appointments.id = history.appointment_id").
		Where("history.room = ? AND history.occurred_at >= ? AND history.occurred_at < ?", room, start, end)
	roomFilter := c.Query("room")
	if roomFilter != "" && roomFilter != "ALL" {
		if models.OPDRoom(roomFilter) != room {
			utils.SendSuccess(c, http.StatusOK, "Queue history retrieved", []historyItem{})
			return
		}
		query = query.Where("history.room = ?", models.OPDRoom(roomFilter))
	}
	if err := query.Order("history.occurred_at DESC").Find(&events).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to load queue history")
		return
	}

	items := make([]historyItem, 0, len(events))
	actionLabels := map[string]string{
		"CHECK_IN":         "Checked In",
		"CALL":             "Called",
		"COMPLETE":         "Completed",
		"SKIP":             "Skipped",
		"NO_SHOW":          "No Show",
		"RECALL":           "Recalled",
		"PRIORITY_UPDATED": "Priority Updated",
		"DOCTOR_ALLOCATED": "Doctor Allocated",
	}
	for _, event := range events {
		status := string(event.Status)
		switch status {
		case string(models.AppointmentConfirmed):
			status = "CHECKED_IN"
		case string(models.AppointmentServing):
			status = "IN_PROGRESS"
		}
		occurredAt := event.OccurredAt.In(loc)
		items = append(items, historyItem{
			ID:          event.ID,
			Token:       fmt.Sprintf("%d", event.QueueNumber),
			PatientName: event.PatientName,
			Room:        string(event.Room),
			Action:      actionLabels[event.Action],
			Status:      status,
			Timestamp:   occurredAt.Format("03:04 PM"),
			Date:        occurredAt.Format("2006-01-02"),
			Details:     event.Details,
		})
	}

	utils.SendSuccess(c, http.StatusOK, "Queue history retrieved", items)
}

// SearchQueue searches by queue/token number, NIC, or phone in the assigned room
func (h *StaffQueueHandler) SearchQueue(c *gin.Context) {
	if !h.ensureDatabase(c) {
		return
	}

	room, err := h.getAssignedRoom(c)
	if err != nil {
		utils.SendError(c, http.StatusForbidden, "You are not assigned to any room")
		return
	}

	query := strings.TrimSpace(c.Query("q"))
	if query == "" {
		utils.SendError(c, http.StatusBadRequest, "Search query is required")
		return
	}

	loc := time.FixedZone("IST", 5*3600+30*60)
	today := time.Now().In(loc).Format("2006-01-02")

	var appointments []models.OPDAppointment
	dbQuery := database.DB.Preload("AssignedDoctor.User").Where("room = ? AND appointment_date = ?", room, today)

	if qNum, err := strconv.Atoi(query); err == nil {
		dbQuery = dbQuery.Where("(queue_number = ? OR patient_nic ILIKE ? OR patient_phone ILIKE ?)", qNum, "%"+query+"%", "%"+query+"%")
	} else {
		dbQuery = dbQuery.Where("(patient_nic ILIKE ? OR patient_phone ILIKE ?)", "%"+query+"%", "%"+query+"%")
	}

	if err := dbQuery.Order("queue_number ASC").Find(&appointments).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Search failed")
		return
	}

	utils.SendSuccess(c, http.StatusOK, "Search results", appointments)
}

// CheckIn marks the patient as confirmed (checked in)
func (h *StaffQueueHandler) CheckIn(c *gin.Context) {
	if !h.ensureDatabase(c) {
		return
	}

	h.updateStatusWithValidation(c, models.AppointmentConfirmed)
}

// CallNext sets the appointment status to SERVING
func (h *StaffQueueHandler) CallNext(c *gin.Context) {
	if !h.ensureDatabase(c) {
		return
	}

	appointment, err := h.validateAppointment(c)
	if err != nil {
		return
	}

	loc := time.FixedZone("IST", 5*3600+30*60)
	now := time.Now().In(loc)

	appointment.Status = models.AppointmentServing
	appointment.StartedAt = &now

	if err := h.saveStaffQueueAction(c, &appointment, "CALL", nil); err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to call next patient")
		return
	}
	utils.SendSuccess(c, http.StatusOK, "Patient called", appointment)
}

// UpdateStatus sets status (COMPLETED, SKIPPED, NO_SHOW, RECALL)
func (h *StaffQueueHandler) UpdateStatus(c *gin.Context) {
	if !h.ensureDatabase(c) {
		return
	}

	type StatusRequest struct {
		Status string `json:"status" binding:"required"`
	}
	var req StatusRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.SendError(c, http.StatusBadRequest, "Invalid status")
		return
	}

	appointment, err := h.validateAppointment(c)
	if err != nil {
		return
	}

	loc := time.FixedZone("IST", 5*3600+30*60)
	now := time.Now().In(loc)
	action := ""

	switch strings.ToUpper(req.Status) {
	case "COMPLETED":
		appointment.Status = models.AppointmentCompleted
		appointment.CompletedAt = &now
		action = "COMPLETE"
	case "SKIPPED":
		appointment.Status = models.AppointmentSkipped
		action = "SKIP"
	case "NO_SHOW":
		appointment.Status = models.AppointmentNoShow
		action = "NO_SHOW"
	case "RECALL":
		appointment.Status = models.AppointmentConfirmed // Reset to waiting queue
		action = "RECALL"
	default:
		utils.SendError(c, http.StatusBadRequest, "Invalid status provided")
		return
	}

	if err := h.saveStaffQueueAction(c, &appointment, action, nil); err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to update status")
		return
	}
	utils.SendSuccess(c, http.StatusOK, "Status updated", appointment)
}

// TogglePriority toggles priority
func (h *StaffQueueHandler) TogglePriority(c *gin.Context) {
	if !h.ensureDatabase(c) {
		return
	}

	appointment, err := h.validateAppointment(c)
	if err != nil {
		return
	}

	type PriorityReq struct {
		IsPriority bool `json:"is_priority"`
	}
	var req PriorityReq
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.SendError(c, http.StatusBadRequest, "Invalid request")
		return
	}

	appointment.IsPriority = req.IsPriority
	details := "Priority disabled"
	if req.IsPriority {
		details = "Priority enabled"
	}
	if err := h.saveStaffQueueAction(c, &appointment, "PRIORITY_UPDATED", &details); err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to update priority")
		return
	}
	utils.SendSuccess(c, http.StatusOK, "Priority updated", appointment)
}

// GetDoctors returns doctors assigned to the room
func (h *StaffQueueHandler) GetDoctors(c *gin.Context) {
	if !h.ensureDatabase(c) {
		return
	}

	room, err := h.getAssignedRoom(c)
	if err != nil {
		utils.SendError(c, http.StatusForbidden, "You are not assigned to any room")
		return
	}

	var doctors []models.Doctor
	if err := database.DB.Preload("User").Where("room = ?", room).Find(&doctors).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to fetch doctors")
		return
	}
	utils.SendSuccess(c, http.StatusOK, "Doctors retrieved", doctors)
}

// AllocateDoctor assigns a doctor to an appointment
func (h *StaffQueueHandler) AllocateDoctor(c *gin.Context) {
	if !h.ensureDatabase(c) {
		return
	}

	type AllocateReq struct {
		DoctorID uint `json:"doctor_id" binding:"required"`
	}
	var req AllocateReq
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.SendError(c, http.StatusBadRequest, "Invalid request")
		return
	}

	appointment, err := h.validateAppointment(c)
	if err != nil {
		return
	}

	// Validate doctor
	var doctor models.Doctor
	if err := database.DB.First(&doctor, req.DoctorID).Error; err != nil {
		utils.SendError(c, http.StatusNotFound, "Doctor not found")
		return
	}
	if doctor.Room != appointment.Room {
		utils.SendError(c, http.StatusBadRequest, "Doctor is not assigned to this room")
		return
	}

	appointment.AssignedDoctorID = &req.DoctorID
	details := fmt.Sprintf("Doctor ID: %d", req.DoctorID)
	if err := h.saveStaffQueueAction(c, &appointment, "DOCTOR_ALLOCATED", &details); err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to allocate doctor")
		return
	}
	utils.SendSuccess(c, http.StatusOK, "Doctor allocated", appointment)
}

// Helper methods
func (h *StaffQueueHandler) updateStatusWithValidation(c *gin.Context, status models.AppointmentStatus) {
	appointment, err := h.validateAppointment(c)
	if err != nil {
		return
	}
	appointment.Status = status
	if err := h.saveStaffQueueAction(c, &appointment, "CHECK_IN", nil); err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to update status")
		return
	}
	utils.SendSuccess(c, http.StatusOK, "Success", appointment)
}

func (h *StaffQueueHandler) saveStaffQueueAction(c *gin.Context, appointment *models.OPDAppointment, action string, details *string) error {
	userIDValue, exists := c.Get("userID")
	if !exists {
		return fmt.Errorf("authenticated Staff user ID is missing")
	}
	userID, ok := userIDValue.(uint)
	if !ok {
		return fmt.Errorf("authenticated Staff user ID has an invalid type")
	}
	occurredAt := time.Now().In(time.FixedZone("IST", 5*3600+30*60))
	history := models.QueueActivityHistory{
		AppointmentID: appointment.ID,
		StaffUserID:   userID,
		Room:          appointment.Room,
		Action:        action,
		Status:        appointment.Status,
		Details:       details,
		OccurredAt:    occurredAt,
	}
	return database.DB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Save(appointment).Error; err != nil {
			return err
		}
		return tx.Create(&history).Error
	})
}

func (h *StaffQueueHandler) validateAppointment(c *gin.Context) (models.OPDAppointment, error) {
	room, err := h.getAssignedRoom(c)
	var appointment models.OPDAppointment
	if err != nil {
		utils.SendError(c, http.StatusForbidden, "You are not assigned to any room")
		return appointment, err
	}

	id := c.Param("id")
	if err := database.DB.Where("id = ? AND room = ?", id, room).First(&appointment).Error; err != nil {
		utils.SendError(c, http.StatusNotFound, "Appointment not found in your assigned room")
		return appointment, err
	}
	return appointment, nil
}
