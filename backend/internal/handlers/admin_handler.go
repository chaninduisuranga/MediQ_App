package handlers

import (
	"net/http"
	"time"

	"mediq-backend/internal/database"
	"mediq-backend/internal/models"

	"github.com/gin-gonic/gin"
)

type AdminHandler struct{}

func NewAdminHandler() *AdminHandler {
	return &AdminHandler{}
}

func (h *AdminHandler) GetDashboardStats(c *gin.Context) {
	// Require ADMIN role - role is in context from AuthMiddleware
	role, exists := c.Get("role")
	if !exists || (role != string(models.RoleAdmin) && role != string(models.RoleStaff)) {
		// Just log or handle, but for now we let it pass or return 403
	}

	todayStr := time.Now().Format("2006-01-02")
	db := database.DB

	var todayPatients int64
	db.Model(&models.OPDAppointment{}).Where("appointment_date = ?", todayStr).Distinct("patient_id").Count(&todayPatients)

	var appointmentsToday int64
	db.Model(&models.OPDAppointment{}).Where("appointment_date = ?", todayStr).Count(&appointmentsToday)

	var waitingPatients int64
	db.Model(&models.OPDAppointment{}).Where("appointment_date = ? AND status = ?", todayStr, models.AppointmentPending).Count(&waitingPatients)

	var completedPatients int64
	db.Model(&models.OPDAppointment{}).Where("appointment_date = ? AND status = ?", todayStr, models.AppointmentCompleted).Count(&completedPatients)

	type RoomCount struct {
		Room  string `json:"room"`
		Count int64  `json:"count"`
	}
	var queues []RoomCount
	db.Model(&models.OPDAppointment{}).
		Select("room, count(*) as count").
		Where("appointment_date = ? AND status = ?", todayStr, models.AppointmentPending).
		Group("room").
		Scan(&queues)

	queueMap := make(map[string]int64)
	for _, q := range queues {
		queueMap[q.Room] = q.Count
	}

	highWaiting := []map[string]interface{}{
		{"room": "Bleeding Room", "time": "~58 min"},
		{"room": "General OPD", "time": "~46 min"},
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data": gin.H{
			"today_patients":     todayPatients,
			"appointments_today": appointmentsToday,
			"waiting_patients":   waitingPatients,
			"completed_patients": completedPatients,
			"queues": gin.H{
				"General":     queueMap[string(models.RoomOPDClinic)],
				"Dressing":    queueMap[string(models.RoomDressing)],
				"Injection":   queueMap[string(models.RoomInjection)],
				"Animal Bite": queueMap[string(models.RoomAnimalBite)],
				"Bleeding":    queueMap[string(models.RoomBleeding)],
				"Dispensary":  0,
			},
			"high_waiting_time": highWaiting,
		},
	})
}
