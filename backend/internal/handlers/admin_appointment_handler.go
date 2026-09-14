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
	"gorm.io/gorm"
)

type AdminAppointmentHandler struct{}

func NewAdminAppointmentHandler() *AdminAppointmentHandler {
	return &AdminAppointmentHandler{}
}

type AdminAppointmentSummary struct {
	ID              uint                     `json:"id"`
	AppointmentDate string                   `json:"appointment_date"`
	AppointmentTime string                   `json:"appointment_time"`
	PatientName     string                   `json:"patient_name"`
	PatientNIC      string                   `json:"patient_nic"`
	PatientPhone    string                   `json:"patient_phone"`
	Room            models.OPDRoom           `json:"room"`
	RoomDisplayName string                   `json:"room_display_name"`
	QueueNumber     int                      `json:"queue_number"`
	Status          models.AppointmentStatus `json:"status"`
	Notes           string                   `json:"notes"`
	CreatedAt       time.Time                `json:"created_at"`
}

type AdminAppointmentListResponse struct {
	Appointments []AdminAppointmentSummary `json:"appointments"`
	Page         int                       `json:"page"`
	Limit        int                       `json:"limit"`
	Total        int64                     `json:"total"`
	TotalPages   int                       `json:"total_pages"`
}

type AdminUpdateAppointmentRequest struct {
	AppointmentDate string                   `json:"appointment_date"`
	AppointmentTime string                   `json:"appointment_time"`
	Room            models.OPDRoom           `json:"room"`
	Status          models.AppointmentStatus `json:"status"`
}

func (h *AdminAppointmentHandler) ListAppointments(c *gin.Context) {
	if database.DB == nil {
		utils.SendError(c, http.StatusInternalServerError, "Database connection not initialized")
		return
	}

	page := parseAdminAppointmentInt(c, "page", 1)
	limit := parseAdminAppointmentInt(c, "limit", 50)
	if limit > 100 {
		limit = 100
	}

	query := database.DB.Model(&models.OPDAppointment{})
	if date := strings.TrimSpace(c.Query("date")); date != "" {
		if !isAdminAppointmentDate(date) {
			utils.SendError(c, http.StatusBadRequest, "Invalid date; use YYYY-MM-DD")
			return
		}
		query = query.Where("appointment_date = ?", date)
	}
	if service := strings.TrimSpace(c.Query("service")); service != "" {
		room := models.OPDRoom(strings.ToUpper(service))
		if _, ok := validRooms[room]; !ok {
			utils.SendError(c, http.StatusBadRequest, "Invalid service")
			return
		}
		query = query.Where("room = ?", room)
	}
	if status := strings.TrimSpace(c.Query("status")); status != "" {
		appointmentStatus := models.AppointmentStatus(strings.ToUpper(status))
		if !isValidAdminAppointmentStatus(appointmentStatus) {
			utils.SendError(c, http.StatusBadRequest, "Invalid appointment status")
			return
		}
		query = query.Where("status = ?", appointmentStatus)
	}
	if search := strings.TrimSpace(c.Query("search")); search != "" {
		if appointmentID, err := strconv.ParseUint(search, 10, 64); err == nil {
			query = query.Where("id = ? OR patient_name ILIKE ? OR patient_nic ILIKE ? OR patient_phone ILIKE ?", appointmentID, "%"+search+"%", "%"+search+"%", "%"+search+"%")
		} else {
			query = query.Where("patient_name ILIKE ? OR patient_nic ILIKE ? OR patient_phone ILIKE ?", "%"+search+"%", "%"+search+"%", "%"+search+"%")
		}
	}

	var total int64
	if err := query.Count(&total).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to count appointments: "+err.Error())
		return
	}

	var appointments []models.OPDAppointment
	if err := query.Order("appointment_date ASC, appointment_time ASC, queue_number ASC").Offset((page - 1) * limit).Limit(limit).Find(&appointments).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to load appointments: "+err.Error())
		return
	}

	response := make([]AdminAppointmentSummary, 0, len(appointments))
	for _, appointment := range appointments {
		response = append(response, adminAppointmentSummary(appointment))
	}
	utils.SendSuccess(c, http.StatusOK, "Appointments retrieved successfully", AdminAppointmentListResponse{
		Appointments: response,
		Page:         page,
		Limit:        limit,
		Total:        total,
		TotalPages:   int((total + int64(limit) - 1) / int64(limit)),
	})
}

func (h *AdminAppointmentHandler) UpdateAppointment(c *gin.Context) {
	if database.DB == nil {
		utils.SendError(c, http.StatusInternalServerError, "Database connection not initialized")
		return
	}

	appointmentID, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil || appointmentID == 0 {
		utils.SendError(c, http.StatusBadRequest, "Invalid appointment ID")
		return
	}

	var request AdminUpdateAppointmentRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		utils.SendError(c, http.StatusBadRequest, "Invalid appointment update")
		return
	}
	if request.Status == models.AppointmentCancelled && request.AppointmentDate == "" && request.AppointmentTime == "" && request.Room == "" {
		request.AppointmentDate = ""
	}
	if request.Status != "" && !isValidAdminAppointmentStatus(request.Status) {
		utils.SendError(c, http.StatusBadRequest, "Invalid appointment status")
		return
	}
	if request.AppointmentDate != "" && !isAdminAppointmentDate(request.AppointmentDate) {
		utils.SendError(c, http.StatusBadRequest, "Invalid date; use YYYY-MM-DD")
		return
	}
	if request.AppointmentTime != "" && !isAdminAppointmentTime(request.AppointmentTime) {
		utils.SendError(c, http.StatusBadRequest, "Invalid time; use HH:MM")
		return
	}
	if request.Room != "" {
		request.Room = models.OPDRoom(strings.ToUpper(strings.TrimSpace(string(request.Room))))
		if _, ok := validRooms[request.Room]; !ok {
			utils.SendError(c, http.StatusBadRequest, "Invalid service")
			return
		}
	}
	if request.Status == "" && request.AppointmentDate == "" && request.AppointmentTime == "" && request.Room == "" {
		utils.SendError(c, http.StatusBadRequest, "At least one appointment field is required")
		return
	}

	var appointment models.OPDAppointment
	if err := database.DB.First(&appointment, appointmentID).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			utils.SendError(c, http.StatusNotFound, "Appointment not found")
			return
		}
		utils.SendError(c, http.StatusInternalServerError, "Failed to load appointment: "+err.Error())
		return
	}

	if request.AppointmentDate != "" {
		appointment.AppointmentDate = request.AppointmentDate
	}
	if request.AppointmentTime != "" {
		appointment.AppointmentTime = request.AppointmentTime
	}
	if request.Room != "" {
		appointment.Room = request.Room
	}
	if request.Status != "" {
		appointment.Status = request.Status
	}
	if err := database.DB.Save(&appointment).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to update appointment: "+err.Error())
		return
	}

	utils.SendSuccess(c, http.StatusOK, "Appointment updated successfully", adminAppointmentSummary(appointment))
}

func adminAppointmentSummary(appointment models.OPDAppointment) AdminAppointmentSummary {
	return AdminAppointmentSummary{
		ID:              appointment.ID,
		AppointmentDate: appointment.AppointmentDate,
		AppointmentTime: appointment.AppointmentTime,
		PatientName:     appointment.PatientName,
		PatientNIC:      appointment.PatientNIC,
		PatientPhone:    appointment.PatientPhone,
		Room:            appointment.Room,
		RoomDisplayName: validRooms[appointment.Room],
		QueueNumber:     appointment.QueueNumber,
		Status:          appointment.Status,
		Notes:           appointment.Notes,
		CreatedAt:       appointment.CreatedAt,
	}
}

func isValidAdminAppointmentStatus(status models.AppointmentStatus) bool {
	return status == models.AppointmentPending || status == models.AppointmentConfirmed || status == models.AppointmentCompleted || status == models.AppointmentCancelled
}

func isAdminAppointmentDate(value string) bool {
	_, err := time.Parse("2006-01-02", value)
	return err == nil
}

func isAdminAppointmentTime(value string) bool {
	parsed, err := time.Parse("15:04", value)
	return err == nil && parsed.Hour() >= 0 && parsed.Hour() <= 23
}

func parseAdminAppointmentInt(c *gin.Context, key string, fallback int) int {
	value, err := strconv.Atoi(c.DefaultQuery(key, strconv.Itoa(fallback)))
	if err != nil || value < 1 {
		return fallback
	}
	return value
}
