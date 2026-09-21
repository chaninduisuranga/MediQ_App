package handlers

import (
	"net/http"
	"strings"
	"time"

	"mediq-backend/internal/database"
	"mediq-backend/internal/models"
	"mediq-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type AdminQueueHandler struct{}

func NewAdminQueueHandler() *AdminQueueHandler {
	return &AdminQueueHandler{}
}

type AdminQueueSummary struct {
	Key                string `json:"key"`
	Name               string `json:"name"`
	Waiting            int64  `json:"waiting"`
	Serving            int64  `json:"serving"`
	Completed          int64  `json:"completed"`
	AverageWaitMinutes int64  `json:"average_wait_minutes"`
	CongestionStatus   string `json:"congestion_status"`
	RecommendedAction  string `json:"recommended_action"`
}

type AdminQueueAlert struct {
	QueueKey           string `json:"queue_key"`
	QueueName          string `json:"queue_name"`
	Waiting            int64  `json:"waiting"`
	AverageWaitMinutes int64  `json:"average_wait_minutes"`
	Status             string `json:"status"`
	RecommendedAction  string `json:"recommended_action"`
}

type AdminQueueResponse struct {
	Date   string              `json:"date"`
	Queues []AdminQueueSummary `json:"queues"`
	Alerts []AdminQueueAlert   `json:"alerts"`
}

type adminQueueDefinition struct {
	Key  models.OPDRoom
	Name string
}

var adminQueueDefinitions = []adminQueueDefinition{
	{Key: models.RoomOPDClinic, Name: "General OPD"},
	{Key: models.RoomDressing, Name: "Dressing"},
	{Key: models.RoomInjection, Name: "Injection"},
	{Key: models.RoomAnimalBite, Name: "Animal Bite"},
	{Key: models.RoomBleeding, Name: "Bleeding"},
	{Key: models.RoomDispensary, Name: "Dispensary"},
}

func (h *AdminQueueHandler) GetQueues(c *gin.Context) {
	if database.DB == nil {
		utils.SendError(c, http.StatusInternalServerError, "Database connection not initialized")
		return
	}

	date := strings.TrimSpace(c.Query("date"))
	if date == "" {
		date = currentAdminDate()
	}
	if !isAdminAppointmentDate(date) {
		utils.SendError(c, http.StatusBadRequest, "Invalid date; use YYYY-MM-DD")
		return
	}

	queues := make([]AdminQueueSummary, 0, len(adminQueueDefinitions))
	alerts := make([]AdminQueueAlert, 0)
	for _, definition := range adminQueueDefinitions {
		var waiting, serving, completed int64
		database.DB.Model(&models.OPDAppointment{}).Where("room = ? AND appointment_date = ? AND status IN ?", definition.Key, date, []models.AppointmentStatus{models.AppointmentPending, models.AppointmentConfirmed}).Count(&waiting)
		database.DB.Model(&models.OPDAppointment{}).Where("room = ? AND appointment_date = ? AND status = ?", definition.Key, date, models.AppointmentServing).Count(&serving)
		database.DB.Model(&models.OPDAppointment{}).Where("room = ? AND appointment_date = ? AND status = ?", definition.Key, date, models.AppointmentCompleted).Count(&completed)

		averageWait := h.averageWait(definition.Key, date)
		status, action := queueCongestion(waiting)
		queue := AdminQueueSummary{Key: string(definition.Key), Name: definition.Name, Waiting: waiting, Serving: serving, Completed: completed, AverageWaitMinutes: averageWait, CongestionStatus: status, RecommendedAction: action}
		queues = append(queues, queue)
		if status != "NORMAL" {
			alerts = append(alerts, AdminQueueAlert{QueueKey: queue.Key, QueueName: queue.Name, Waiting: waiting, AverageWaitMinutes: averageWait, Status: status, RecommendedAction: action})
		}
	}

	utils.SendSuccess(c, http.StatusOK, "Queue metrics retrieved successfully", AdminQueueResponse{Date: date, Queues: queues, Alerts: alerts})
}

func (h *AdminQueueHandler) averageWait(room models.OPDRoom, date string) int64 {
	var appointments []models.OPDAppointment
	if err := database.DB.Select("appointment_time, created_at").Where("room = ? AND appointment_date = ? AND status IN ?", room, date, []models.AppointmentStatus{models.AppointmentPending, models.AppointmentConfirmed}).Find(&appointments).Error; err != nil || len(appointments) == 0 {
		return 0
	}

	now := time.Now().In(time.FixedZone("IST", 5*3600+30*60))
	var total int64
	for _, appointment := range appointments {
		wait := int64(0)
		if appointment.AppointmentTime != "" {
			if scheduled, err := time.ParseInLocation("2006-01-02 15:04", date+" "+appointment.AppointmentTime, now.Location()); err == nil && scheduled.Before(now) {
				wait = int64(now.Sub(scheduled).Minutes())
			}
		} else if appointment.CreatedAt.Before(now) {
			wait = int64(now.Sub(appointment.CreatedAt).Minutes())
		}
		if wait > 0 {
			total += wait
		}
	}
	return total / int64(len(appointments))
}

func queueCongestion(waiting int64) (string, string) {
	switch {
	case waiting > 20:
		return "CRITICAL", "Consider allocating another available doctor."
	case waiting > 10:
		return "WARNING", "Monitor the queue and consider reallocating available staff."
	default:
		return "NORMAL", "No immediate action required."
	}
}
