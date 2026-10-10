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

const adminAnalyticsCongestionThreshold = 20

type AdminAnalyticsHandler struct{}

func NewAdminAnalyticsHandler() *AdminAnalyticsHandler {
	return &AdminAnalyticsHandler{}
}

type adminAnalyticsAppointment struct {
	Room            models.OPDRoom
	AppointmentDate string
	AppointmentTime string
	Status          models.AppointmentStatus
	CreatedAt       time.Time
	StartedAt       *time.Time
}

type adminAnalyticsQueueService struct {
	Key                 string `json:"key"`
	Name                string `json:"name"`
	AverageWaitMinutes  int64  `json:"average_wait_minutes"`
	WaitSamples         int64  `json:"wait_samples"`
	PeakWaiting         int64  `json:"peak_waiting"`
	CongestionIncidents int64  `json:"congestion_incidents"`
}

type adminAnalyticsAppointmentBucket struct {
	Label     string `json:"label"`
	StartDate string `json:"start_date"`
	Bookings  int64  `json:"bookings"`
	Completed int64  `json:"completed"`
	Cancelled int64  `json:"cancelled"`
	Missed    int64  `json:"missed"`
}

type adminAnalyticsResponse struct {
	Period        string                            `json:"period"`
	StartDate     string                            `json:"start_date"`
	EndDate       string                            `json:"end_date"`
	Appointments  adminAnalyticsAppointmentTotals   `json:"appointments"`
	QueueServices []adminAnalyticsQueueService      `json:"queue_services"`
	Trend         []adminAnalyticsAppointmentBucket `json:"trend"`
}

type adminAnalyticsAppointmentTotals struct {
	Bookings  int64 `json:"bookings"`
	Completed int64 `json:"completed"`
	Cancelled int64 `json:"cancelled"`
	Missed    int64 `json:"missed"`
}

type adminAnalyticsRoom struct {
	Key  models.OPDRoom
	Name string
}

var adminAnalyticsRooms = []adminAnalyticsRoom{
	{Key: models.RoomOPDClinic, Name: "General OPD"},
	{Key: models.RoomDressing, Name: "Dressing"},
	{Key: models.RoomInjection, Name: "Injection"},
	{Key: models.RoomAnimalBite, Name: "Animal Bite"},
	{Key: models.RoomBleeding, Name: "Bleeding"},
	{Key: models.RoomDispensary, Name: "Dispensary"},
}

func (h *AdminAnalyticsHandler) GetAnalytics(c *gin.Context) {
	if database.DB == nil {
		utils.SendError(c, http.StatusInternalServerError, "Database connection not initialized")
		return
	}

	period := strings.TrimSpace(c.DefaultQuery("period", "30d"))
	periodDays := map[string]int{"7d": 7, "30d": 30, "90d": 90}
	days, valid := periodDays[period]
	if !valid {
		utils.SendError(c, http.StatusBadRequest, "Period must be 7d, 30d, or 90d")
		return
	}

	location := time.FixedZone("IST", 5*3600+30*60)
	today := time.Now().In(location)
	endDate := time.Date(today.Year(), today.Month(), today.Day(), 0, 0, 0, 0, location)
	startDate := endDate.AddDate(0, 0, -(days - 1))
	startKey := startDate.Format("2006-01-02")
	endKey := endDate.Format("2006-01-02")

	var appointments []adminAnalyticsAppointment
	if err := database.DB.Model(&models.OPDAppointment{}).
		Select("room, appointment_date, appointment_time, status, created_at, started_at").
		Where("appointment_date >= ? AND appointment_date <= ?", startKey, endKey).
		Find(&appointments).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to load analytics data")
		return
	}

	response := buildAdminAnalytics(period, startDate, endDate, today, appointments)
	utils.SendSuccess(c, http.StatusOK, "Analytics retrieved successfully", response)
}

func buildAdminAnalytics(period string, startDate, endDate, now time.Time, appointments []adminAnalyticsAppointment) adminAnalyticsResponse {
	days := int(endDate.Sub(startDate).Hours()/24) + 1
	bucketCount := days
	bucketSize := 1
	if days > 7 {
		bucketSize = 7
		bucketCount = (days + bucketSize - 1) / bucketSize
	}
	buckets := make([]adminAnalyticsAppointmentBucket, bucketCount)
	for index := range buckets {
		bucketDate := startDate.AddDate(0, 0, index*bucketSize)
		buckets[index] = adminAnalyticsAppointmentBucket{
			Label: bucketDate.Format("Jan 02"), StartDate: bucketDate.Format("2006-01-02"),
		}
	}

	totals := adminAnalyticsAppointmentTotals{}
	type roomDay struct {
		room string
		date string
	}
	waitingCounts := make(map[roomDay]int64)
	waitDurations := make(map[string][]int64)
	for _, appointment := range appointments {
		date, err := time.ParseInLocation("2006-01-02", appointment.AppointmentDate, startDate.Location())
		if err != nil || date.Before(startDate) || date.After(endDate) {
			continue
		}
		bucketIndex := int(date.Sub(startDate).Hours() / 24 / float64(bucketSize))
		if bucketIndex >= len(buckets) {
			bucketIndex = len(buckets) - 1
		}
		bucket := &buckets[bucketIndex]
		bucket.Bookings++
		totals.Bookings++

		status := strings.ToUpper(strings.TrimSpace(string(appointment.Status)))
		switch status {
		case string(models.AppointmentCompleted):
			bucket.Completed++
			totals.Completed++
		case string(models.AppointmentCancelled):
			bucket.Cancelled++
			totals.Cancelled++
		case string(models.AppointmentNoShow), string(models.AppointmentSkipped):
			bucket.Missed++
			totals.Missed++
		}

		roomKey := string(appointment.Room)
		dayKey := roomDay{room: roomKey, date: appointment.AppointmentDate}
		if status == string(models.AppointmentPending) || status == string(models.AppointmentConfirmed) {
			waitingCounts[dayKey]++
		}
		if wait, ok := analyticsWaitMinutes(appointment, date, now); ok {
			waitDurations[roomKey] = append(waitDurations[roomKey], wait)
		}
	}

	peakByRoom := make(map[string]int64)
	incidentsByRoom := make(map[string]int64)
	for key, count := range waitingCounts {
		if count > peakByRoom[key.room] {
			peakByRoom[key.room] = count
		}
		if count > adminAnalyticsCongestionThreshold {
			incidentsByRoom[key.room]++
		}
	}

	queueServices := make([]adminAnalyticsQueueService, 0, len(adminAnalyticsRooms))
	for _, room := range adminAnalyticsRooms {
		waits := waitDurations[string(room.Key)]
		var totalWait int64
		for _, wait := range waits {
			totalWait += wait
		}
		var average int64
		if len(waits) > 0 {
			average = totalWait / int64(len(waits))
		}
		queueServices = append(queueServices, adminAnalyticsQueueService{
			Key: string(room.Key), Name: room.Name, AverageWaitMinutes: average,
			WaitSamples: int64(len(waits)),
			PeakWaiting: peakByRoom[string(room.Key)], CongestionIncidents: incidentsByRoom[string(room.Key)],
		})
	}

	return adminAnalyticsResponse{
		Period: period, StartDate: startDate.Format("2006-01-02"), EndDate: endDate.Format("2006-01-02"),
		Appointments: totals, QueueServices: queueServices, Trend: buckets,
	}
}

func analyticsWaitMinutes(appointment adminAnalyticsAppointment, appointmentDate, now time.Time) (int64, bool) {
	var start time.Time
	if appointment.StartedAt != nil {
		start = appointment.StartedAt.In(appointmentDate.Location())
	} else if appointmentDate.Format("2006-01-02") == now.In(appointmentDate.Location()).Format("2006-01-02") {
		start = now
	} else {
		return 0, false
	}

	var scheduled time.Time
	if appointment.AppointmentTime != "" {
		parsed, err := time.ParseInLocation("15:04", appointment.AppointmentTime, appointmentDate.Location())
		if err == nil {
			scheduled = time.Date(appointmentDate.Year(), appointmentDate.Month(), appointmentDate.Day(), parsed.Hour(), parsed.Minute(), 0, 0, appointmentDate.Location())
		}
	}
	if scheduled.IsZero() {
		scheduled = appointment.CreatedAt.In(appointmentDate.Location())
	}
	if start.Before(scheduled) {
		return 0, false
	}
	return int64(start.Sub(scheduled).Minutes()), true
}
