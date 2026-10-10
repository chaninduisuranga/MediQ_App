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

type DoctorHandler struct{}

func NewDoctorHandler() *DoctorHandler {
	return &DoctorHandler{}
}

type DoctorAppointmentResponse struct {
	ID                 uint   `json:"id"`
	QueueNumber        string `json:"queue_number"`
	RawNumber          int    `json:"raw_number"`
	Status             string `json:"status"`
	PatientName        string `json:"patient_name"`
	PatientID          string `json:"patient_id"`
	PatientNIC         string `json:"patient_nic"`
	PatientPhone       string `json:"patient_phone"`
	PatientAge         *int   `json:"patient_age"`
	PatientGender      string `json:"patient_gender"`
	AppointmentTime    string `json:"appointment_time"`
	AppointmentDate    string `json:"appointment_date"`
	Room               string `json:"room"`
	AppointmentStatus  string `json:"appointment_status"`
	ConsultationStatus string `json:"consultation_status"`
	QueueStatus        string `json:"queue_status"`
	Notes              string `json:"notes"`
}

type DoctorQueueResponse struct {
	Room            string                      `json:"room"`
	RoomDisplayName string                      `json:"room_display_name"`
	Date            string                      `json:"date"`
	CurrentMax      int                         `json:"current_max"`
	NextNumber      int                         `json:"next_number"`
	Appointments    []DoctorAppointmentResponse `json:"appointments"`
}

func (h *DoctorHandler) GetTodayAppointments(c *gin.Context) {
	doctor, ok := h.currentDoctor(c)
	if !ok {
		return
	}
	roomValues := appointmentRoomAliases(doctor.Room)
	query := database.DB.Unscoped().Preload("Patient").
		Where("(room IN ? OR room = ? OR room = ?)", roomValues, "GENERAL_OPD", "OPD_CLINIC_ROOM")

	filterDate := strings.TrimSpace(c.Query("date"))
	if filterDate != "" {
		if _, err := time.Parse("2006-01-02", filterDate); err == nil {
			query = query.Where("(appointment_date = ? OR appointment_date IN ? OR appointment_date = CURRENT_DATE::text)", filterDate, todayDateCandidates())
		} else {
			query = query.Where("(appointment_date IN ? OR appointment_date = CURRENT_DATE::text)", todayDateCandidates())
		}
	} else {
		query = query.Where("(appointment_date IN ? OR appointment_date = CURRENT_DATE::text)", todayDateCandidates())
	}

	if filterStatus := strings.TrimSpace(c.Query("status")); filterStatus != "" && !strings.EqualFold(filterStatus, "ALL") {
		status, valid := appointmentStatusFromClient(filterStatus)
		if valid {
			query = query.Where("status = ?", status)
		}
	}

	var appointments []models.OPDAppointment
	if err := query.Order("queue_number ASC, created_at ASC, id ASC").Find(&appointments).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to load today's appointments")
		return
	}

	utils.SendSuccess(c, http.StatusOK, "Today's appointments retrieved successfully", appointmentResponses(appointments))
}

func (h *DoctorHandler) GetPreviousAppointments(c *gin.Context) {
	doctor, ok := h.currentDoctor(c)
	if !ok {
		return
	}

	var appointments []models.OPDAppointment
	if err := database.DB.Unscoped().
		Where("(assigned_doctor_id = ? OR doctor_id = ?) AND UPPER(status) IN ?",
			doctor.ID,
			doctor.ID,
			[]string{"COMPLETED", "NO_SHOW", "CANCELLED"},
		).
		Order("appointment_date DESC, queue_number ASC").
		Find(&appointments).Error; err != nil {
		log.Printf("GetPreviousAppointments: failed to load appointments for doctor %d: %v", doctor.ID, err)
		utils.SendError(c, http.StatusInternalServerError, "Failed to load previous appointments")
		return
	}
	utils.SendSuccess(c, http.StatusOK, "Previous appointments retrieved successfully", appointmentResponses(appointments))
}

func (h *DoctorHandler) UpdateAppointmentStatus(c *gin.Context) {
	doctor, ok := h.currentDoctor(c)
	if !ok {
		return
	}

	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil || id == 0 {
		utils.SendError(c, http.StatusBadRequest, "Invalid appointment ID")
		return
	}

	var request struct {
		Status string `json:"status" binding:"required"`
		Notes  string `json:"notes"`
	}
	if err := c.ShouldBindJSON(&request); err != nil {
		log.Printf("UpdateAppointmentStatus: invalid request for appointment %d: %v", id, err)
		utils.SendError(c, http.StatusBadRequest, "Invalid appointment status: "+err.Error())
		return
	}
	status, valid := appointmentStatusFromClient(request.Status)
	if !valid {
		utils.SendError(c, http.StatusBadRequest, "Unsupported appointment status")
		return
	}

	var appointment models.OPDAppointment
	if err := database.DB.Where("id = ? AND room IN ?", id, appointmentRoomAliases(doctor.Room)).First(&appointment).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			utils.SendError(c, http.StatusNotFound, "Appointment not found")
		} else {
			log.Printf("UpdateAppointmentStatus: failed to load appointment %d for doctor %d: %v", id, doctor.ID, err)
			utils.SendError(c, http.StatusInternalServerError, "Failed to load appointment: "+err.Error())
		}
		return
	}

	now := time.Now()
	updateData := map[string]interface{}{
		"status":     status,
		"updated_at": now,
	}
	if notes := strings.TrimSpace(request.Notes); notes != "" {
		updateData["notes"] = notes
	}
	switch status {
	case models.AppointmentServing:
		updateData["started_at"] = now
	case models.AppointmentCompleted, models.AppointmentNoShow:
		updateData["completed_at"] = now
	}

	if err := database.DB.Model(&models.OPDAppointment{}).Where("id = ?", id).Updates(updateData).Error; err != nil {
		log.Printf("UpdateAppointmentStatus: failed to save appointment %d with status %q: %v", id, status, err)
		utils.SendError(c, http.StatusInternalServerError, "Failed to update appointment status: "+err.Error())
		return
	}

	utils.SendSuccess(c, http.StatusOK, "Appointment status updated successfully", map[string]string{"status": clientAppointmentStatus(status)})
}

func (h *DoctorHandler) GetConsultationDetails(c *gin.Context) {
	doctor, ok := h.currentDoctor(c)
	if !ok {
		return
	}

	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil || id == 0 {
		utils.SendError(c, http.StatusBadRequest, "Invalid appointment ID")
		return
	}

	var appointment models.OPDAppointment
	if err := database.DB.Preload("Patient").Where("id = ? AND room IN ?", id, appointmentRoomAliases(doctor.Room)).First(&appointment).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			utils.SendError(c, http.StatusNotFound, "Appointment not found")
		} else {
			utils.SendError(c, http.StatusInternalServerError, "Failed to load appointment details")
		}
		return
	}

	utils.SendSuccess(c, http.StatusOK, "Consultation details retrieved successfully", map[string]string{
		"time":               appointment.AppointmentTime,
		"date":               appointment.AppointmentDate,
		"notes":              notProvided(appointment.Notes),
		"blood_group":        notProvided(appointment.Patient.BloodGroup),
		"allergies":          notProvided(appointment.Patient.Allergies),
		"medical_conditions": notProvided(appointment.Patient.MedicalConditions),
		"address":            notProvided(appointment.Patient.Address),
	})
}

func (h *DoctorHandler) GetAvailability(c *gin.Context) {
	doctor, ok := h.currentDoctor(c)
	if !ok {
		return
	}

	days := []string{}
	if strings.TrimSpace(doctor.WorkingDays) != "" {
		for _, d := range strings.Split(doctor.WorkingDays, ",") {
			d = strings.TrimSpace(d)
			if d != "" {
				days = append(days, d)
			}
		}
	}
	if len(days) == 0 {
		days = []string{"Monday", "Tuesday", "Wednesday", "Thursday", "Friday"}
	}

	sessionType := doctor.SessionType
	if sessionType == "" {
		sessionType = "Morning OPD"
	}
	start := doctor.WorkingHoursStart
	if start == "" {
		start = "08:00 AM"
	}
	end := doctor.WorkingHoursEnd
	if end == "" {
		end = "04:00 PM"
	}
	maxPatients := doctor.MaxPatientsPerDay
	if maxPatients <= 0 {
		maxPatients = 30
	}

	utils.SendSuccess(c, http.StatusOK, "Availability retrieved successfully", map[string]interface{}{
		"is_available":         doctor.IsAvailable,
		"clinic":               doctor.ClinicName,
		"room":                 doctor.Room,
		"working_days":         days,
		"session_type":         sessionType,
		"working_hours_start":  start,
		"working_hours_end":    end,
		"max_patients_per_day": maxPatients,
	})
}

func (h *DoctorHandler) UpdateAvailability(c *gin.Context) {
	doctor, ok := h.currentDoctor(c)
	if !ok {
		return
	}

	var request struct {
		IsAvailable       *bool       `json:"is_available"`
		WorkingDays       interface{} `json:"working_days"`
		SessionType       *string     `json:"session_type"`
		StartTime         *string     `json:"start_time"`
		WorkingHoursStart *string     `json:"working_hours_start"`
		EndTime           *string     `json:"end_time"`
		WorkingHoursEnd   *string     `json:"working_hours_end"`
		MaxPatients       interface{} `json:"max_patients"`
		MaxPatientsPerDay interface{} `json:"max_patients_per_day"`
		ClinicName        *string     `json:"clinic_name"`
		Clinic            *string     `json:"clinic"`
	}
	if err := c.ShouldBindJSON(&request); err != nil {
		log.Printf("UpdateAvailability: failed to bind request JSON: %v", err)
		utils.SendError(c, http.StatusBadRequest, "Invalid request body")
		return
	}

	updates := make(map[string]interface{})
	if request.IsAvailable != nil {
		updates["is_available"] = *request.IsAvailable
		doctor.IsAvailable = *request.IsAvailable
	}
	if request.WorkingDays != nil {
		var daysStr string
		switch v := request.WorkingDays.(type) {
		case []string:
			daysStr = strings.Join(v, ",")
		case []interface{}:
			var list []string
			for _, item := range v {
				day, ok := item.(string)
				if !ok {
					log.Printf("UpdateAvailability: working_days contains a non-string value: %T", item)
					utils.SendError(c, http.StatusBadRequest, "working_days must contain strings")
					return
				}
				list = append(list, day)
			}
			daysStr = strings.Join(list, ",")
		case string:
			daysStr = v
		default:
			log.Printf("UpdateAvailability: unsupported working_days value: %T", v)
			utils.SendError(c, http.StatusBadRequest, "working_days must be an array or comma-separated string")
			return
		}
		updates["working_days"] = daysStr
		doctor.WorkingDays = daysStr
	}
	if request.SessionType != nil {
		updates["session_type"] = strings.TrimSpace(*request.SessionType)
		doctor.SessionType = strings.TrimSpace(*request.SessionType)
	}
	startTime := request.WorkingHoursStart
	if startTime == nil {
		startTime = request.StartTime
	}
	if startTime != nil {
		updates["working_hours_start"] = strings.TrimSpace(*startTime)
		doctor.WorkingHoursStart = strings.TrimSpace(*startTime)
	}
	endTime := request.WorkingHoursEnd
	if endTime == nil {
		endTime = request.EndTime
	}
	if endTime != nil {
		updates["working_hours_end"] = strings.TrimSpace(*endTime)
		doctor.WorkingHoursEnd = strings.TrimSpace(*endTime)
	}
	maxPatientsValue := request.MaxPatientsPerDay
	if maxPatientsValue == nil {
		maxPatientsValue = request.MaxPatients
	}
	if maxPatientsValue != nil {
		var maxPatients int
		switch value := maxPatientsValue.(type) {
		case float64:
			if value != float64(int(value)) {
				log.Printf("UpdateAvailability: max_patients must be an integer: %v", value)
				utils.SendError(c, http.StatusBadRequest, "max_patients must be an integer")
				return
			}
			maxPatients = int(value)
		case int:
			maxPatients = value
		case string:
			parsed, err := strconv.Atoi(strings.TrimSpace(value))
			if err != nil {
				log.Printf("UpdateAvailability: invalid max_patients value %q: %v", value, err)
				utils.SendError(c, http.StatusBadRequest, "max_patients must be an integer")
				return
			}
			maxPatients = parsed
		default:
			log.Printf("UpdateAvailability: unsupported max_patients value: %T", value)
			utils.SendError(c, http.StatusBadRequest, "max_patients must be an integer")
			return
		}
		updates["max_patients"] = maxPatients
		doctor.MaxPatientsPerDay = maxPatients
	}
	clinicName := request.ClinicName
	if clinicName == nil {
		clinicName = request.Clinic
	}
	if clinicName != nil && strings.TrimSpace(*clinicName) != "" {
		updates["clinic_name"] = strings.TrimSpace(*clinicName)
		doctor.ClinicName = strings.TrimSpace(*clinicName)
	}

	if len(updates) > 0 {
		var existing models.Doctor
		err := database.DB.Where("id = ?", doctor.ID).First(&existing).Error
		switch {
		case err == nil:
			if err := database.DB.Model(&existing).Updates(updates).Error; err != nil {
				log.Printf("UpdateAvailability: failed to update doctor %d: %v", doctor.ID, err)
				utils.SendError(c, http.StatusInternalServerError, "Failed to update availability")
				return
			}
		case err == gorm.ErrRecordNotFound:
			if err := database.DB.Create(&doctor).Error; err != nil {
				log.Printf("UpdateAvailability: failed to create doctor availability for doctor %d: %v", doctor.ID, err)
				utils.SendError(c, http.StatusInternalServerError, "Failed to update availability")
				return
			}
		default:
			log.Printf("UpdateAvailability: failed to find doctor %d: %v", doctor.ID, err)
			utils.SendError(c, http.StatusInternalServerError, "Failed to update availability")
			return
		}
	}

	h.GetAvailability(c)
}

func (h *DoctorHandler) GetNotifications(c *gin.Context) {
	doctor, ok := h.currentDoctor(c)
	if !ok {
		return
	}

	var notifications []models.Notification
	if err := database.DB.Where("user_id = ?", doctor.UserID).Order("created_at DESC").Find(&notifications).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to load notifications")
		return
	}

	if len(notifications) == 0 {
		welcome := models.Notification{
			UserID:    doctor.UserID,
			Type:      "ADMIN_ANNOUNCEMENT",
			Title:     "Welcome to Doctor Portal",
			Message:   "You are logged in and connected to the MediQ real-time queue notification service.",
			IsRead:    false,
			CreatedAt: time.Now(),
		}
		database.DB.Create(&welcome)
		notifications = append(notifications, welcome)
	}

	utils.SendSuccess(c, http.StatusOK, "Notifications retrieved successfully", notifications)
}

func (h *DoctorHandler) MarkNotificationRead(c *gin.Context) {
	doctor, ok := h.currentDoctor(c)
	if !ok {
		return
	}

	idParam := c.Param("id")
	id, err := strconv.ParseUint(idParam, 10, 64)
	if err != nil || id == 0 {
		utils.SendError(c, http.StatusBadRequest, "Invalid notification ID")
		return
	}

	if err := database.DB.Model(&models.Notification{}).Where("id = ? AND user_id = ?", id, doctor.UserID).Update("is_read", true).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to update notification")
		return
	}

	utils.SendSuccess(c, http.StatusOK, "Notification marked as read", nil)
}

func (h *DoctorHandler) GetDoctorProfile(c *gin.Context) {
	doctor, ok := h.currentDoctor(c)
	if !ok {
		return
	}
	var user models.User
	if err := database.DB.First(&user, doctor.UserID).Error; err != nil {
		utils.SendError(c, http.StatusNotFound, "User account not found")
		return
	}

	utils.SendSuccess(c, http.StatusOK, "Doctor profile retrieved", map[string]interface{}{
		"id":             doctor.ID,
		"user_id":        user.ID,
		"full_name":      user.FullName,
		"email":          user.Email,
		"phone":          user.Phone,
		"nic":            user.NIC,
		"specialization": doctor.Specialization,
		"department":     doctor.Specialization,
		"clinic_name":    doctor.ClinicName,
		"room":           doctor.Room,
		"slmc_number":    doctor.SLMCNumber,
	})
}

func (h *DoctorHandler) UpdateDoctorProfile(c *gin.Context) {
	doctor, ok := h.currentDoctor(c)
	if !ok {
		return
	}
	var user models.User
	if err := database.DB.First(&user, doctor.UserID).Error; err != nil {
		utils.SendError(c, http.StatusNotFound, "User account not found")
		return
	}

	var req struct {
		Email      string `json:"email"`
		Phone      string `json:"phone"`
		Department string `json:"department"`
		Room       string `json:"room"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.SendError(c, http.StatusBadRequest, "Invalid profile payload")
		return
	}

	if email := strings.TrimSpace(req.Email); email != "" {
		user.Email = email
	}
	if phone := strings.TrimSpace(req.Phone); phone != "" {
		user.Phone = phone
	}
	if err := database.DB.Save(&user).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to update user profile")
		return
	}

	docUpdates := make(map[string]interface{})
	if dept := strings.TrimSpace(req.Department); dept != "" {
		docUpdates["specialization"] = dept
	}
	if room := strings.ToUpper(strings.TrimSpace(req.Room)); room != "" {
		docUpdates["room"] = room
	}
	if len(docUpdates) > 0 {
		if err := database.DB.Model(&doctor).Updates(docUpdates).Error; err != nil {
			utils.SendError(c, http.StatusInternalServerError, "Failed to update doctor details")
			return
		}
	}

	h.GetDoctorProfile(c)
}

func (h *DoctorHandler) GetPatientHistory(c *gin.Context) {
	patientIDParam := c.Param("patient_id")
	patientID, err := strconv.ParseUint(patientIDParam, 10, 64)
	if err != nil || patientID == 0 {
		utils.SendError(c, http.StatusBadRequest, "Invalid patient ID")
		return
	}

	var appointments []models.OPDAppointment
	if err := database.DB.Where("patient_id = ? AND status = ?", patientID, models.AppointmentCompleted).Order("appointment_date DESC").Limit(10).Find(&appointments).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to load patient history")
		return
	}

	utils.SendSuccess(c, http.StatusOK, "Patient history retrieved", appointmentResponses(appointments))
}

func (h *DoctorHandler) GetQueueByRoom(c *gin.Context) {
	if database.DB == nil {
		utils.SendError(c, http.StatusInternalServerError, "Database connection not initialized")
		return
	}

	roomKey := strings.ToUpper(strings.TrimSpace(c.Param("room")))
	room := normalizeQueueRoom(roomKey)
	if _, valid := validRooms[room]; !valid {
		utils.SendError(c, http.StatusBadRequest, "Invalid room key")
		return
	}

	role, _ := c.Get("role")
	includeAppointments := false
	if role == string(models.RoleDoctor) {
		userID, exists := c.Get("userID")
		if !exists {
			utils.SendError(c, http.StatusUnauthorized, "Unauthorized")
			return
		}
		var doctor models.Doctor
		if err := database.DB.Where("user_id = ?", userID).First(&doctor).Error; err != nil {
			utils.SendError(c, http.StatusNotFound, "Doctor profile not found")
			return
		}
		doctorRoom := normalizeQueueRoom(strings.ToUpper(strings.TrimSpace(string(doctor.Room))))
		if doctorRoom != room && room != models.RoomOPDClinic {
			utils.SendError(c, http.StatusForbidden, "Doctors may only view their assigned room")
			return
		}
		includeAppointments = true
	} else if role == string(models.RoleStaff) || role == string(models.RoleAdmin) || role == "SUPER_ADMIN" {
		includeAppointments = true
	}

	targetDate := strings.TrimSpace(c.Query("date"))
	roomAliases := appointmentRoomAliases(room)

	maxQuery := database.DB.Unscoped().Model(&models.OPDAppointment{}).
		Where("(room IN ? OR room = ? OR room = ?)", roomAliases, "GENERAL_OPD", "OPD_CLINIC_ROOM")

	if targetDate != "" {
		if _, err := time.Parse("2006-01-02", targetDate); err == nil {
			maxQuery = maxQuery.Where("(appointment_date = ? OR appointment_date IN ? OR appointment_date = CURRENT_DATE::text)", targetDate, todayDateCandidates())
		} else {
			maxQuery = maxQuery.Where("(appointment_date IN ? OR appointment_date = CURRENT_DATE::text)", todayDateCandidates())
			targetDate = todayInSriLanka()
		}
	} else {
		maxQuery = maxQuery.Where("(appointment_date IN ? OR appointment_date = CURRENT_DATE::text)", todayDateCandidates())
		targetDate = todayInSriLanka()
	}

	var maxQueue int
	if err := maxQuery.Select("COALESCE(MAX(queue_number), 0)").Scan(&maxQueue).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to load room queue status")
		return
	}

	response := DoctorQueueResponse{
		Room:            string(room),
		RoomDisplayName: validRooms[room],
		Date:            targetDate,
		CurrentMax:      maxQueue,
		NextNumber:      maxQueue + 1,
	}
	if includeAppointments {
		var appointments []models.OPDAppointment
		apptQuery := database.DB.Unscoped().Preload("Patient").
			Where("(room IN ? OR room = ? OR room = ?)", roomAliases, "GENERAL_OPD", "OPD_CLINIC_ROOM")

		filterTargetDate := strings.TrimSpace(c.Query("date"))
		if filterTargetDate != "" {
			if _, err := time.Parse("2006-01-02", filterTargetDate); err == nil {
				apptQuery = apptQuery.Where("(appointment_date = ? OR appointment_date IN ? OR appointment_date = CURRENT_DATE::text)", filterTargetDate, todayDateCandidates())
			} else {
				apptQuery = apptQuery.Where("(appointment_date IN ? OR appointment_date = CURRENT_DATE::text)", todayDateCandidates())
			}
		} else {
			apptQuery = apptQuery.Where("(appointment_date IN ? OR appointment_date = CURRENT_DATE::text)", todayDateCandidates())
		}

		if err := apptQuery.Order("queue_number ASC, created_at ASC, id ASC").Find(&appointments).Error; err != nil {
			utils.SendError(c, http.StatusInternalServerError, "Failed to load room queue")
			return
		}
		response.Appointments = appointmentResponses(appointments)
	}
	utils.SendSuccess(c, http.StatusOK, "Room queue retrieved successfully", response)
}

func (h *DoctorHandler) GetAppointmentByID(c *gin.Context) {
	if database.DB == nil {
		utils.SendError(c, http.StatusInternalServerError, "Database connection not initialized")
		return
	}
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil || id == 0 {
		utils.SendError(c, http.StatusBadRequest, "Invalid appointment ID")
		return
	}

	var appointment models.OPDAppointment
	if err := database.DB.Preload("Patient").First(&appointment, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			utils.SendError(c, http.StatusNotFound, "Appointment not found")
		} else {
			utils.SendError(c, http.StatusInternalServerError, "Failed to load appointment")
		}
		return
	}

	role, _ := c.Get("role")
	userID, exists := c.Get("userID")
	if !exists {
		utils.SendError(c, http.StatusUnauthorized, "Unauthorized")
		return
	}
	switch role {
	case string(models.RolePatient):
		if fmt.Sprint(userID) != fmt.Sprint(appointment.PatientID) {
			utils.SendError(c, http.StatusForbidden, "You may only view your own appointment")
			return
		}
	case string(models.RoleDoctor):
		var doctor models.Doctor
		if err := database.DB.Where("user_id = ?", userID).First(&doctor).Error; err != nil || doctor.Room != appointment.Room {
			utils.SendError(c, http.StatusForbidden, "Appointment is not in your assigned room")
			return
		}
	case string(models.RoleStaff), string(models.RoleAdmin), "SUPER_ADMIN":
	default:
		utils.SendError(c, http.StatusForbidden, "Appointment access denied")
		return
	}

	response := appointmentResponses([]models.OPDAppointment{appointment})
	utils.SendSuccess(c, http.StatusOK, "Appointment retrieved successfully", response[0])
}

func (h *DoctorHandler) CheckInAppointment(c *gin.Context) {
	if database.DB == nil {
		utils.SendError(c, http.StatusInternalServerError, "Database connection not initialized")
		return
	}
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil || id == 0 {
		utils.SendError(c, http.StatusBadRequest, "Invalid appointment ID")
		return
	}

	var appointment models.OPDAppointment
	if err := database.DB.First(&appointment, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			utils.SendError(c, http.StatusNotFound, "Appointment not found")
		} else {
			utils.SendError(c, http.StatusInternalServerError, "Failed to load appointment")
		}
		return
	}
	role, _ := c.Get("role")
	userID, exists := c.Get("userID")
	if !exists {
		utils.SendError(c, http.StatusUnauthorized, "Unauthorized")
		return
	}
	if role == string(models.RolePatient) {
		if fmt.Sprint(userID) != fmt.Sprint(appointment.PatientID) {
			utils.SendError(c, http.StatusForbidden, "You may only check in to your own appointment")
			return
		}
	} else if role != string(models.RoleStaff) && role != string(models.RoleAdmin) && role != "SUPER_ADMIN" {
		utils.SendError(c, http.StatusForbidden, "Staff access required")
		return
	}

	if appointment.Status != models.AppointmentCancelled && appointment.Status != models.AppointmentCompleted {
		if err := database.DB.Model(&models.OPDAppointment{}).Where("id = ?", id).Updates(map[string]interface{}{
			"status":     models.AppointmentConfirmed,
			"updated_at": time.Now(),
		}).Error; err != nil {
			utils.SendError(c, http.StatusInternalServerError, "Failed to check in appointment")
			return
		}
		utils.NotifyDoctorForRoom(
			database.DB,
			appointment.Room,
			"QUEUE_UPDATE",
			"Patient Checked In",
			fmt.Sprintf("%s checked in for appointment #%d.", appointment.PatientName, appointment.QueueNumber),
		)
	}
	utils.SendSuccess(c, http.StatusOK, "Appointment checked in successfully", nil)
}

func (h *DoctorHandler) currentDoctor(c *gin.Context) (models.Doctor, bool) {
	if database.DB == nil {
		utils.SendError(c, http.StatusInternalServerError, "Database connection not initialized")
		return models.Doctor{}, false
	}
	userID, exists := c.Get("userID")
	if !exists {
		utils.SendError(c, http.StatusUnauthorized, "Unauthorized")
		return models.Doctor{}, false
	}
	var doctor models.Doctor
	if err := database.DB.Where("user_id = ?", userID).First(&doctor).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			utils.SendError(c, http.StatusNotFound, "Doctor profile not found")
		} else {
			utils.SendError(c, http.StatusInternalServerError, "Failed to load doctor profile")
		}
		return models.Doctor{}, false
	}
	if strings.TrimSpace(string(doctor.Room)) == "" {
		doctor.Room = models.RoomOPDClinic
	} else {
		doctor.Room = normalizeQueueRoom(strings.ToUpper(strings.TrimSpace(string(doctor.Room))))
	}
	if _, valid := validRooms[doctor.Room]; !valid {
		doctor.Room = models.RoomOPDClinic
	}
	return doctor, true
}

func appointmentRoomAliases(room models.OPDRoom) []models.OPDRoom {
	room = normalizeQueueRoom(strings.ToUpper(strings.TrimSpace(string(room))))
	rooms := []models.OPDRoom{room}
	switch room {
	case models.RoomOPDClinic:
		rooms = append(rooms, models.OPDRoom("GENERAL_OPD"), models.OPDRoom("OPD_CLINIC"), models.OPDRoom("OPD_CLINIC_ROOM"), models.OPDRoom("OPD"))
	case models.RoomDispensary:
		rooms = append(rooms, models.OPDRoom("PHARMACY"), models.OPDRoom("DISPENSARY"), models.OPDRoom("DISPENSARY_ROOM"))
	}
	uniqueRooms := make([]models.OPDRoom, 0, len(rooms))
	seen := make(map[models.OPDRoom]bool)
	for _, r := range rooms {
		if r != "" && !seen[r] {
			seen[r] = true
			uniqueRooms = append(uniqueRooms, r)
		}
	}
	return uniqueRooms
}

func appointmentResponses(appointments []models.OPDAppointment) []DoctorAppointmentResponse {
	response := make([]DoctorAppointmentResponse, 0, len(appointments))
	for _, appointment := range appointments {
		room := normalizeQueueRoom(string(appointment.Room))
		prefix := queuePrefix(room)
		patientName := strings.TrimSpace(appointment.PatientName)
		if patientName == "" {
			patientName = strings.TrimSpace(appointment.Patient.FullName)
		}
		patientNIC := strings.TrimSpace(appointment.PatientNIC)
		if patientNIC == "" {
			patientNIC = strings.TrimSpace(appointment.Patient.NIC)
		}
		patientPhone := strings.TrimSpace(appointment.PatientPhone)
		if patientPhone == "" {
			patientPhone = strings.TrimSpace(appointment.Patient.Phone)
		}
		response = append(response, DoctorAppointmentResponse{
			ID:                 appointment.ID,
			QueueNumber:        fmt.Sprintf("%s%03d", prefix, appointment.QueueNumber),
			RawNumber:          appointment.QueueNumber,
			Status:             clientQueueStatus(appointment.Status),
			PatientName:        patientName,
			PatientID:          fmt.Sprintf("PAT-%d", appointment.PatientID),
			PatientNIC:         patientNIC,
			PatientPhone:       patientPhone,
			PatientAge:         patientAge(appointment.Patient.DateOfBirth),
			PatientGender:      appointment.Patient.Gender,
			AppointmentTime:    formatAppointmentTime(appointment.AppointmentTime),
			AppointmentDate:    appointment.AppointmentDate,
			Room:               string(room),
			AppointmentStatus:  clientAppointmentStatus(appointment.Status),
			ConsultationStatus: clientAppointmentStatus(appointment.Status),
			QueueStatus:        clientQueueStatus(appointment.Status),
			Notes:              appointment.Notes,
		})
	}
	return response
}

func appointmentStatusFromClient(status string) (models.AppointmentStatus, bool) {
	normalized := strings.ToUpper(strings.TrimSpace(strings.ReplaceAll(strings.ReplaceAll(status, "-", "_"), " ", "_")))
	switch normalized {
	case "WAITING", "SCHEDULED", "PENDING", "CHECKED_IN", "CALLED":
		return models.AppointmentConfirmed, true
	case "IN_CONSULTATION", "IN_PROGRESS", "SERVING", "CONSULTING", "ONGOING":
		return models.AppointmentServing, true
	case "COMPLETED", "DONE", "FINISHED", "CLOSED":
		return models.AppointmentCompleted, true
	case "CANCELLED", "CANCELED":
		return models.AppointmentCancelled, true
	case "NO_SHOW", "SKIPPED", "MISSED":
		return models.AppointmentNoShow, true
	default:
		return "", false
	}
}

func clientAppointmentStatus(status models.AppointmentStatus) string {
	switch status {
	case models.AppointmentPending, models.AppointmentConfirmed:
		return "WAITING"
	case models.AppointmentServing:
		return "IN_CONSULTATION"
	case models.AppointmentNoShow:
		return "NO_SHOW"
	default:
		return string(status)
	}
}

func clientQueueStatus(status models.AppointmentStatus) string {
	switch status {
	case models.AppointmentPending, models.AppointmentConfirmed:
		return "CHECKED_IN"
	case models.AppointmentServing:
		return "IN_PROGRESS"
	default:
		return string(status)
	}
}

func normalizeQueueRoom(room string) models.OPDRoom {
	switch strings.ToUpper(strings.TrimSpace(room)) {
	case "GENERAL_OPD", "OPD_CLINIC", "OPD", "OPD_CLINIC_ROOM":
		return models.RoomOPDClinic
	case "PHARMACY", "DISPENSARY", "DISPENSARY_ROOM":
		return models.RoomDispensary
	default:
		return models.OPDRoom(room)
	}
}

func queuePrefix(room models.OPDRoom) string {
	room = normalizeQueueRoom(strings.ToUpper(strings.TrimSpace(string(room))))
	switch room {
	case models.RoomOPDClinic:
		return "G-"
	case models.RoomDressing:
		return "D-"
	case models.RoomInjection:
		return "I-"
	case models.RoomBleeding:
		return "B-"
	case models.RoomAnimalBite:
		return "A-"
	case models.RoomDispensary:
		return "P-"
	default:
		return "Q-"
	}
}

func todayInSriLanka() string {
	return time.Now().In(time.FixedZone("IST", 5*3600+30*60)).Format("2006-01-02")
}

func patientAge(dateOfBirth string) *int {
	birthDate, err := time.Parse("2006-01-02", strings.TrimSpace(dateOfBirth))
	if err != nil {
		return nil
	}
	now := time.Now().In(time.FixedZone("IST", 5*3600+30*60))
	age := now.Year() - birthDate.Year()
	if now.YearDay() < birthDate.YearDay() {
		age--
	}
	return &age
}

func formatAppointmentTime(value string) string {
	layouts := []string{
		"15:04",
		"15:04:05",
		time.RFC3339Nano,
		"2006-01-02 15:04:05-07:00",
		"2006-01-02 15:04:05-07",
		"2006-01-02 15:04:05",
	}
	for _, layout := range layouts {
		parsed, err := time.Parse(layout, strings.TrimSpace(value))
		if err == nil {
			return parsed.In(time.FixedZone("IST", 5*3600+30*60)).Format("03:04 PM")
		}
	}
	return value
}

func notProvided(value string) string {
	if strings.TrimSpace(value) == "" {
		return "Not provided"
	}
	return value
}

func todayDateCandidates() []string {
	now := time.Now()
	ist := now.In(time.FixedZone("IST", 5*3600+30*60)).Format("2006-01-02")
	utc := now.UTC().Format("2006-01-02")
	local := now.Format("2006-01-02")

	candidates := []string{ist}
	seen := map[string]bool{ist: true}
	if !seen[utc] {
		candidates = append(candidates, utc)
		seen[utc] = true
	}
	if !seen[local] {
		candidates = append(candidates, local)
		seen[local] = true
	}
	return candidates
}
