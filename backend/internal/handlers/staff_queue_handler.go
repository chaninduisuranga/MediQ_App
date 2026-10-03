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
)

type StaffQueueHandler struct{}

func NewStaffQueueHandler() *StaffQueueHandler {
	return &StaffQueueHandler{}
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

// SearchQueue searches by queue/token number, NIC, or phone in the assigned room
func (h *StaffQueueHandler) SearchQueue(c *gin.Context) {
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
	h.updateStatusWithValidation(c, models.AppointmentConfirmed)
}

// CallNext sets the appointment status to SERVING
func (h *StaffQueueHandler) CallNext(c *gin.Context) {
	appointment, err := h.validateAppointment(c)
	if err != nil {
		return
	}

	loc := time.FixedZone("IST", 5*3600+30*60)
	now := time.Now().In(loc)

	appointment.Status = models.AppointmentServing
	appointment.StartedAt = &now

	if err := database.DB.Save(&appointment).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to call next patient")
		return
	}
	utils.SendSuccess(c, http.StatusOK, "Patient called", appointment)
}

// UpdateStatus sets status (COMPLETED, SKIPPED, NO_SHOW, RECALL)
func (h *StaffQueueHandler) UpdateStatus(c *gin.Context) {
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

	switch strings.ToUpper(req.Status) {
	case "COMPLETED":
		appointment.Status = models.AppointmentCompleted
		appointment.CompletedAt = &now
	case "SKIPPED":
		appointment.Status = models.AppointmentSkipped
	case "NO_SHOW":
		appointment.Status = models.AppointmentNoShow
	case "RECALL":
		appointment.Status = models.AppointmentConfirmed // Reset to waiting queue
	default:
		utils.SendError(c, http.StatusBadRequest, "Invalid status provided")
		return
	}

	if err := database.DB.Save(&appointment).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to update status")
		return
	}
	utils.SendSuccess(c, http.StatusOK, "Status updated", appointment)
}

// TogglePriority toggles priority
func (h *StaffQueueHandler) TogglePriority(c *gin.Context) {
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
	if err := database.DB.Save(&appointment).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to update priority")
		return
	}
	utils.SendSuccess(c, http.StatusOK, "Priority updated", appointment)
}

// GetDoctors returns doctors assigned to the room
func (h *StaffQueueHandler) GetDoctors(c *gin.Context) {
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
	if err := database.DB.Save(&appointment).Error; err != nil {
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
	if err := database.DB.Save(&appointment).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to update status")
		return
	}
	utils.SendSuccess(c, http.StatusOK, "Success", appointment)
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
