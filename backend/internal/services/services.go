package services

import (
	"log"
)

type AppointmentService struct{}

func NewAppointmentService() *AppointmentService {
	return &AppointmentService{}
}

func (s *AppointmentService) CreateAppointment() {
	log.Println("Appointment service placeholder")
}
