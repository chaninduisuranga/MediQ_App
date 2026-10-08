package models

import (
	"time"

	"gorm.io/gorm"
)

// OPD Room types
type OPDRoom string

const (
	RoomDressing   OPDRoom = "DRESSING_ROOM"
	RoomInjection  OPDRoom = "INJECTION_ROOM"
	RoomBleeding   OPDRoom = "BLEEDING_ROOM"
	RoomAnimalBite OPDRoom = "ANIMAL_BITE_ROOM"
	RoomOPDClinic  OPDRoom = "OPD_CLINIC_ROOM"
	RoomDispensary OPDRoom = "DISPENSARY_ROOM"
)

type AppointmentStatus string

const (
	AppointmentPending   AppointmentStatus = "PENDING"
	AppointmentConfirmed AppointmentStatus = "CONFIRMED"
	AppointmentServing   AppointmentStatus = "SERVING"
	AppointmentCompleted AppointmentStatus = "COMPLETED"
	AppointmentCancelled AppointmentStatus = "CANCELLED"
	AppointmentSkipped   AppointmentStatus = "SKIPPED"
	AppointmentNoShow    AppointmentStatus = "NO_SHOW"
)

type OPDAppointment struct {
	ID               uint              `gorm:"primaryKey" json:"id"`
	PatientID        uint              `gorm:"not null;index" json:"patient_id"`
	Patient          User              `gorm:"foreignKey:PatientID" json:"patient,omitempty"`
	Room             OPDRoom           `gorm:"type:varchar(50);not null;index" json:"room"`
	QueueNumber      int               `gorm:"not null" json:"queue_number"`
	AppointmentDate  string            `gorm:"type:varchar(20);not null;index" json:"appointment_date"` // YYYY-MM-DD
	AppointmentTime  string            `gorm:"type:varchar(20)" json:"appointment_time"`                // HH:MM
	PatientName      string            `gorm:"not null" json:"patient_name"`
	PatientNIC       string            `gorm:"not null" json:"patient_nic"`
	PatientPhone     string            `json:"patient_phone"`
	Notes            string            `json:"notes"`
	Status           AppointmentStatus `gorm:"type:varchar(20);default:'PENDING'" json:"status"`
	IsPriority       bool              `gorm:"not null;default:false" json:"is_priority"`
	AssignedDoctorID *uint             `json:"assigned_doctor_id,omitempty"`
	AssignedDoctor   *Doctor           `gorm:"foreignKey:AssignedDoctorID" json:"assigned_doctor,omitempty"`
	StartedAt        *time.Time        `json:"started_at,omitempty"`
	CompletedAt      *time.Time        `json:"completed_at,omitempty"`
	QRCodeData       string            `gorm:"type:text" json:"qr_code_data"`
	CreatedAt        time.Time         `json:"created_at"`
	UpdatedAt        time.Time         `json:"updated_at"`
	DeletedAt        gorm.DeletedAt    `gorm:"index" json:"-"`
}