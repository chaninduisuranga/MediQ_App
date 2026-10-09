package handlers

import (
	"testing"
	"time"

	"mediq-backend/internal/models"
)

func TestBuildAdminAnalyticsAggregatesAppointmentAndQueueMetrics(t *testing.T) {
	location := time.FixedZone("IST", 5*3600+30*60)
	start := time.Date(2026, 10, 3, 0, 0, 0, 0, location)
	end := time.Date(2026, 10, 9, 0, 0, 0, 0, location)
	now := time.Date(2026, 10, 9, 12, 0, 0, 0, location)
	startedAt := time.Date(2026, 10, 8, 9, 15, 0, 0, location)
	appointments := []adminAnalyticsAppointment{
		{Room: models.RoomOPDClinic, AppointmentDate: "2026-10-08", AppointmentTime: "09:00", Status: models.AppointmentCompleted, CreatedAt: startedAt.Add(-time.Hour), StartedAt: &startedAt},
		{Room: models.RoomOPDClinic, AppointmentDate: "2026-10-08", AppointmentTime: "09:30", Status: models.AppointmentNoShow, CreatedAt: startedAt.Add(-time.Hour)},
	}
	for index := 0; index < 21; index++ {
		appointments = append(appointments, adminAnalyticsAppointment{
			Room: models.RoomOPDClinic, AppointmentDate: "2026-10-08", AppointmentTime: "10:00",
			Status: models.AppointmentPending, CreatedAt: startedAt.Add(-time.Hour),
		})
	}

	result := buildAdminAnalytics("7d", start, end, now, appointments)
	if result.Appointments.Bookings != 23 || result.Appointments.Completed != 1 || result.Appointments.Missed != 1 {
		t.Fatalf("unexpected appointment totals: %+v", result.Appointments)
	}
	if len(result.Trend) != 7 || result.Trend[5].Bookings != 23 || result.Trend[5].Missed != 1 {
		t.Fatalf("unexpected daily trend bucket: %+v", result.Trend)
	}
	if len(result.QueueServices) != 6 {
		t.Fatalf("expected six service metrics, got %d", len(result.QueueServices))
	}
	general := result.QueueServices[0]
	if general.PeakWaiting != 21 || general.CongestionIncidents != 1 {
		t.Fatalf("unexpected congestion metrics: %+v", general)
	}
	if general.AverageWaitMinutes != 15 || general.WaitSamples != 1 {
		t.Fatalf("unexpected average wait metrics: %+v", general)
	}
}

func TestAnalyticsWaitMinutesIgnoresFutureSlotsAndMissingHistoricalStart(t *testing.T) {
	location := time.FixedZone("IST", 5*3600+30*60)
	date := time.Date(2026, 10, 9, 0, 0, 0, 0, location)
	now := time.Date(2026, 10, 9, 8, 0, 0, 0, location)
	appointment := adminAnalyticsAppointment{AppointmentDate: "2026-10-09", AppointmentTime: "09:00"}
	if _, ok := analyticsWaitMinutes(appointment, date, now); ok {
		t.Fatal("future appointment slot should not contribute a wait sample")
	}

	appointment.AppointmentDate = "2026-10-08"
	if _, ok := analyticsWaitMinutes(appointment, date.AddDate(0, 0, -1), now); ok {
		t.Fatal("historical appointment without a start timestamp should not contribute a wait sample")
	}
}
