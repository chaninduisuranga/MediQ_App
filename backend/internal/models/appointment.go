package models

import (
	"time"

	"gorm.io/gorm"
)

type AppointmentStatus string

const (
	AppointmentPending   AppointmentStatus = "PENDING"
	AppointmentConfirmed AppointmentStatus = "CONFIRMED"
	AppointmentCompleted AppointmentStatus = "COMPLETED"
	AppointmentCancelled AppointmentStatus = "CANCELLED"
)

type Appointment struct {
	ID              uint              `gorm:"primaryKey" json:"id"`
	PatientID       uint              `gorm:"not null" json:"patient_id"`
	Patient         User              `gorm:"foreignKey:PatientID" json:"patient,omitempty"`
	DoctorID        uint              `gorm:"not null" json:"doctor_id"`
	Doctor          Doctor            `gorm:"foreignKey:DoctorID" json:"doctor,omitempty"`
	ClinicName      string            `gorm:"not null" json:"clinic_name"`
	AppointmentDate time.Time         `gorm:"not null" json:"appointment_date"`
	QueueNumber     int               `gorm:"not null" json:"queue_number"`
	Status          AppointmentStatus `gorm:"type:varchar(20);default:'PENDING'" json:"status"`
	QRCodeData      string            `json:"qr_code_data"`
	Notes           string            `json:"notes"`
	CreatedAt       time.Time         `json:"created_at"`
	UpdatedAt       time.Time         `json:"updated_at"`
	DeletedAt       gorm.DeletedAt    `gorm:"index" json:"-"`
}
