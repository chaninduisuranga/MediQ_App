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
	"gorm.io/gorm"
)

type StaffQueueHandler struct{}

const staffHighQueueThreshold = 15

var staffRoomAliases = map[models.OPDRoom][]models.OPDRoom{
	models.RoomOPDClinic:  {models.RoomOPDClinic, "GENERAL_OPD"},
	models.RoomDressing:   {models.RoomDressing},
	models.RoomInjection:  {models.RoomInjection},
	models.RoomAnimalBite: {models.RoomAnimalBite},
	models.RoomBleeding:   {models.RoomBleeding},
	models.RoomDispensary: {models.RoomDispensary},
}

func NewStaffQueueHandler() *StaffQueueHandler {
	return &StaffQueueHandler{}
}

func canonicalStaffRoom(room string) (models.OPDRoom, bool) {
	key := models.OPDRoom(strings.TrimSpace(room))
	if key == "GENERAL_OPD" {
		key = models.RoomOPDClinic
	}
	_, ok := staffRoomAliases[key]
	return key, ok
}

func staffRoomValues(room models.OPDRoom) []models.OPDRoom {
	return staffRoomAliases[room]
}

func allStaffRoomValues() []models.OPDRoom {
	rooms := []models.OPDRoom{
		models.RoomOPDClinic,
		models.RoomDressing,
		models.RoomInjection,
		models.RoomAnimalBite,
		models.RoomBleeding,
		models.RoomDispensary,
	}
	values := make([]models.OPDRoom, 0, len(rooms)+1)
	for _, room := range rooms {
		values = append(values, staffRoomValues(room)...)
	}
	return values
}

func selectedStaffRoom(c *gin.Context) (models.OPDRoom, bool) {
	return canonicalStaffRoom(c.Query("room"))
}

func filterStaffRoom(query *gorm.DB, column string, rooms []models.OPDRoom) *gorm.DB {
	return query.Where("regexp_replace("+column+", '[[:space:]]+$', '') IN ?", rooms)
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

// GetQueueList returns today's queue for the selected Staff room.
func (h *StaffQueueHandler) GetQueueList(c *gin.Context) {
	if !h.ensureDatabase(c) {
		return
	}

	room, ok := selectedStaffRoom(c)
	if !ok {
		utils.SendError(c, http.StatusBadRequest, "Invalid or missing room")
		return
	}

	loc := time.FixedZone("IST", 5*3600+30*60)
	today := time.Now().In(loc).Format("2006-01-02")

	var appointments []models.OPDAppointment
	query := database.DB.Preload("AssignedDoctor.User").
		Where("appointment_date = ?", today)
	if err := filterStaffRoom(query, "room", staffRoomValues(room)).
		Order("is_priority DESC, queue_number ASC").
		Find(&appointments).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to load queue")
		return
	}

	utils.SendSuccess(c, http.StatusOK, "Queue list retrieved", appointments)
}

// LookupQrAppointment resolves a Patient ticket ID in any supported Staff room.
func (h *StaffQueueHandler) LookupQrAppointment(c *gin.Context) {
	if !h.ensureDatabase(c) {
		return
	}
	if !requireQrStaff(c) {
		return
	}
	appointment, ok := h.loadQrAppointment(c)
	if !ok {
		return
	}
	utils.SendSuccess(c, http.StatusOK, "Appointment retrieved", appointment)
}

// CheckInQrAppointment checks in an eligible appointment from any supported Staff room.
func (h *StaffQueueHandler) CheckInQrAppointment(c *gin.Context) {
	if !h.ensureDatabase(c) {
		return
	}
	if !requireQrStaff(c) {
		return
	}
	appointment, ok := h.loadQrAppointment(c)
	if !ok {
		return
	}
	if appointment.Status != models.AppointmentPending {
		if appointment.Status == models.AppointmentConfirmed {
			utils.SendError(c, http.StatusConflict, "Appointment has already been checked in")
		} else {
			utils.SendError(c, http.StatusConflict, fmt.Sprintf(
				"Appointment is not eligible for QR check-in from status %s",
				appointment.Status,
			))
		}
		return
	}
	checkedIn, err := h.saveQrCheckIn(c, &appointment)
	if err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to update status")
		return
	}
	if !checkedIn {
		utils.SendError(c, http.StatusConflict, "Appointment was already checked in or is no longer eligible")
		return
	}
	utils.SendSuccess(c, http.StatusOK, "Success", appointment)
}

// GetQueueHistory returns history for the selected Staff room or all supported rooms.
func (h *StaffQueueHandler) GetQueueHistory(c *gin.Context) {
	if !h.ensureDatabase(c) {
		return
	}

	roomFilter := strings.TrimSpace(c.DefaultQuery("room", "ALL"))
	var roomValues []models.OPDRoom
	if roomFilter == "ALL" {
		roomValues = allStaffRoomValues()
	} else {
		room, ok := canonicalStaffRoom(roomFilter)
		if !ok {
			utils.SendError(c, http.StatusBadRequest, "Invalid room")
			return
		}
		roomValues = staffRoomValues(room)
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
		Where("history.deleted_at IS NULL").
		Where("history.occurred_at >= ? AND history.occurred_at < ?", start, end)
	query = filterStaffRoom(query, "history.room", roomValues)
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
		room := strings.TrimRight(string(event.Room), " \t\r\n")
		if canonicalRoom, ok := canonicalStaffRoom(room); ok {
			room = string(canonicalRoom)
		}
		occurredAt := event.OccurredAt.In(loc)
		items = append(items, historyItem{
			ID:          event.ID,
			Token:       fmt.Sprintf("%d", event.QueueNumber),
			PatientName: event.PatientName,
			Room:        room,
			Action:      actionLabels[event.Action],
			Status:      status,
			Timestamp:   occurredAt.Format("03:04 PM"),
			Date:        occurredAt.Format("2006-01-02"),
			Details:     event.Details,
		})
	}

	utils.SendSuccess(c, http.StatusOK, "Queue history retrieved", items)
}

// DeleteQueueHistory soft-deletes one Staff queue activity history record.
func (h *StaffQueueHandler) DeleteQueueHistory(c *gin.Context) {
	if !h.ensureDatabase(c) {
		return
	}

	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil || id == 0 {
		utils.SendError(c, http.StatusBadRequest, "Invalid queue history ID")
		return
	}

	result := database.DB.Delete(&models.QueueActivityHistory{}, uint(id))
	if result.Error != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to delete queue history record")
		return
	}
	if result.RowsAffected == 0 {
		utils.SendError(c, http.StatusNotFound, "Queue history record not found")
		return
	}

	utils.SendSuccess(c, http.StatusOK, "Queue history record deleted", gin.H{"id": id})
}

// SearchQueue searches by queue/token number, NIC, or phone in the selected room.
func (h *StaffQueueHandler) SearchQueue(c *gin.Context) {
	if !h.ensureDatabase(c) {
		return
	}

	room, ok := selectedStaffRoom(c)
	if !ok {
		utils.SendError(c, http.StatusBadRequest, "Invalid or missing room")
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
	dbQuery := database.DB.Preload("AssignedDoctor.User").Where("appointment_date = ?", today)
	dbQuery = filterStaffRoom(dbQuery, "room", staffRoomValues(room))

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

	priorityWasSet := appointment.IsPriority
	appointment.IsPriority = req.IsPriority
	details := "Priority disabled"
	if req.IsPriority {
		details = "Priority enabled"
	}
	if err := h.saveStaffQueueAction(c, &appointment, "PRIORITY_UPDATED", &details); err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to update priority")
		return
	}
	if req.IsPriority && !priorityWasSet {
		h.createStaffNotification(c, "Priority Patient Alert", fmt.Sprintf(
			"Priority patient Token #%s has been added to the %s queue.",
			staffQueueToken(appointment.Room, appointment.QueueNumber),
			staffRoomName(appointment.Room),
		), "PRIORITY")
	}
	utils.SendSuccess(c, http.StatusOK, "Priority updated", appointment)
}

// GetDoctors returns doctors assigned to the room
func (h *StaffQueueHandler) GetDoctors(c *gin.Context) {
	if !h.ensureDatabase(c) {
		return
	}

	room, ok := selectedStaffRoom(c)
	if !ok {
		utils.SendError(c, http.StatusBadRequest, "Invalid or missing room")
		return
	}

	var doctors []models.Doctor
	if err := filterStaffRoom(database.DB.Preload("User"), "room", staffRoomValues(room)).Find(&doctors).Error; err != nil {
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
	if err := database.DB.Preload("User").First(&doctor, req.DoctorID).Error; err != nil {
		utils.SendError(c, http.StatusNotFound, "Doctor not found")
		return
	}
	doctorRoom, doctorRoomOK := canonicalStaffRoom(string(doctor.Room))
	appointmentRoom, appointmentRoomOK := canonicalStaffRoom(string(appointment.Room))
	if !doctorRoomOK || !appointmentRoomOK || doctorRoom != appointmentRoom {
		utils.SendError(c, http.StatusBadRequest, "Doctor is not assigned to this room")
		return
	}

	allocationChanged := appointment.AssignedDoctorID == nil ||
		*appointment.AssignedDoctorID != req.DoctorID
	appointment.AssignedDoctorID = &req.DoctorID
	details := fmt.Sprintf("Doctor ID: %d", req.DoctorID)
	if err := h.saveStaffQueueAction(c, &appointment, "DOCTOR_ALLOCATED", &details); err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to allocate doctor")
		return
	}
	if allocationChanged {
		doctorName := strings.TrimSpace(doctor.User.FullName)
		if doctorName == "" {
			doctorName = "the allocated doctor"
		}
		h.createStaffNotification(c, "Patient Allocation Completed", fmt.Sprintf(
			"1 waiting patient was allocated to %s.",
			doctorName,
		), "ALLOCATION")
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
	if err := database.DB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Save(appointment).Error; err != nil {
			return err
		}
		return tx.Create(&history).Error
	}); err != nil {
		return err
	}

	h.maybeCreateHighQueueNotification(c, appointment.Room)
	return nil
}

func (h *StaffQueueHandler) maybeCreateHighQueueNotification(c *gin.Context, room models.OPDRoom) {
	canonicalRoom, ok := canonicalStaffRoom(string(room))
	if !ok || canonicalRoom != models.RoomOPDClinic {
		return
	}

	userID, ok := staffNotificationUserID(c)
	if !ok {
		log.Printf("Staff high-queue notification skipped: authenticated user ID unavailable")
		return
	}

	loc := time.FixedZone("IST", 5*3600+30*60)
	now := time.Now().In(loc)
	today := now.Format("2006-01-02")
	var waiting int64
	query := database.DB.Model(&models.OPDAppointment{}).
		Where("appointment_date = ? AND status IN ?",
			today,
			[]models.AppointmentStatus{models.AppointmentPending, models.AppointmentConfirmed},
		)
	if err := filterStaffRoom(query, "room", staffRoomValues(models.RoomOPDClinic)).
		Count(&waiting).Error; err != nil {
		log.Printf("Staff high-queue notification check failed: %v", err)
		return
	}
	if waiting < staffHighQueueThreshold {
		return
	}

	startOfDay := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, loc)
	var existing int64
	if err := database.DB.Model(&models.StaffNotification{}).
		Where("staff_user_id = ? AND type = ? AND title = ? AND created_at >= ? AND created_at < ?",
			userID,
			"QUEUE",
			"High Queue Alert",
			startOfDay,
			startOfDay.AddDate(0, 0, 1),
		).
		Count(&existing).Error; err != nil {
		log.Printf("Staff high-queue notification duplicate check failed: %v", err)
		return
	}
	if existing > 0 {
		return
	}

	h.createStaffNotification(c, "High Queue Alert", fmt.Sprintf(
		"General OPD queue is getting crowded. %d patients are currently waiting.",
		waiting,
	), "QUEUE")
}

func (h *StaffQueueHandler) createStaffNotification(c *gin.Context, title, message, notificationType string) {
	userID, ok := staffNotificationUserID(c)
	if !ok {
		log.Printf("Staff notification %q skipped: authenticated user ID unavailable", title)
		return
	}

	notification := models.StaffNotification{
		StaffUserID: userID,
		Title:       title,
		Message:     message,
		Type:        notificationType,
		CreatedAt:   time.Now(),
	}
	if err := database.DB.Create(&notification).Error; err != nil {
		log.Printf("Failed to create Staff notification %q for user %d: %v", title, userID, err)
	}
}

func staffQueueToken(room models.OPDRoom, queueNumber int) string {
	if canonicalRoom, ok := canonicalStaffRoom(string(room)); ok {
		room = canonicalRoom
	}
	prefix := "Q"
	switch room {
	case models.RoomOPDClinic:
		prefix = "G"
	case models.RoomDressing:
		prefix = "D"
	case models.RoomInjection:
		prefix = "I"
	case models.RoomAnimalBite:
		prefix = "A"
	case models.RoomBleeding:
		prefix = "B"
	case models.RoomDispensary:
		prefix = "P"
	}
	return fmt.Sprintf("%s%03d", prefix, queueNumber)
}

func staffRoomName(room models.OPDRoom) string {
	if canonicalRoom, ok := canonicalStaffRoom(string(room)); ok {
		room = canonicalRoom
	}
	switch room {
	case models.RoomOPDClinic:
		return "General OPD"
	case models.RoomDressing:
		return "Dressing Room"
	case models.RoomInjection:
		return "Injection Room"
	case models.RoomAnimalBite:
		return "Animal Bite Room"
	case models.RoomBleeding:
		return "Bleeding Room"
	case models.RoomDispensary:
		return "Dispensary"
	default:
		return "OPD"
	}
}

func (h *StaffQueueHandler) validateAppointment(c *gin.Context) (models.OPDAppointment, error) {
	var appointment models.OPDAppointment
	room, ok := selectedStaffRoom(c)
	if !ok {
		utils.SendError(c, http.StatusBadRequest, "Invalid or missing room")
		return appointment, fmt.Errorf("invalid or missing room")
	}

	id := c.Param("id")
	query := database.DB.Where("id = ?", id)
	if err := filterStaffRoom(query, "room", staffRoomValues(room)).First(&appointment).Error; err != nil {
		utils.SendError(c, http.StatusNotFound, "Appointment not found in the selected room")
		return appointment, err
	}
	return appointment, nil
}

func requireQrStaff(c *gin.Context) bool {
	role, exists := c.Get("role")
	roleValue, ok := role.(string)
	if !exists || !ok || roleValue != string(models.RoleStaff) {
		utils.SendError(c, http.StatusForbidden, "Staff access required")
		return false
	}
	return true
}

func (h *StaffQueueHandler) saveQrCheckIn(c *gin.Context, appointment *models.OPDAppointment) (bool, error) {
	userIDValue, exists := c.Get("userID")
	if !exists {
		return false, fmt.Errorf("authenticated Staff user ID is missing")
	}
	userID, ok := userIDValue.(uint)
	if !ok {
		return false, fmt.Errorf("authenticated Staff user ID has an invalid type")
	}

	occurredAt := time.Now().In(time.FixedZone("IST", 5*3600+30*60))
	history := models.QueueActivityHistory{
		AppointmentID: appointment.ID,
		StaffUserID:   userID,
		Room:          appointment.Room,
		Action:        "CHECK_IN",
		Status:        models.AppointmentConfirmed,
		OccurredAt:    occurredAt,
	}
	checkedIn := false
	if err := database.DB.Transaction(func(tx *gorm.DB) error {
		result := tx.Model(&models.OPDAppointment{}).
			Where("id = ? AND status = ?", appointment.ID, models.AppointmentPending).
			Update("status", models.AppointmentConfirmed)
		if result.Error != nil {
			return result.Error
		}
		if result.RowsAffected == 0 {
			return nil
		}
		if err := tx.Create(&history).Error; err != nil {
			return err
		}
		appointment.Status = models.AppointmentConfirmed
		checkedIn = true
		return nil
	}); err != nil {
		return false, err
	}
	if checkedIn {
		h.maybeCreateHighQueueNotification(c, appointment.Room)
	}
	return checkedIn, nil
}

func (h *StaffQueueHandler) loadQrAppointment(c *gin.Context) (models.OPDAppointment, bool) {
	var appointment models.OPDAppointment
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil || id == 0 {
		utils.SendError(c, http.StatusBadRequest, "Invalid appointment ID")
		return appointment, false
	}

	query := database.DB.Where("id = ?", id)
	if err := filterStaffRoom(query, "room", allStaffRoomValues()).
		First(&appointment).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			utils.SendError(c, http.StatusNotFound, "Appointment not found in a supported OPD room")
		} else {
			utils.SendError(c, http.StatusInternalServerError, "Failed to load appointment")
		}
		return appointment, false
	}
	if _, ok := canonicalStaffRoom(string(appointment.Room)); !ok {
		utils.SendError(c, http.StatusNotFound, "Appointment does not belong to a supported OPD room")
		return appointment, false
	}
	return appointment, true
}
