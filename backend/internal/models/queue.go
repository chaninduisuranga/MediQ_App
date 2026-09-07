package models

import (
	"time"

	"gorm.io/gorm"
)

type QueueStatus string

const (
	QueueWaiting    QueueStatus = "WAITING"
	QueueInProgress QueueStatus = "IN_PROGRESS"
	QueueCompleted  QueueStatus = "COMPLETED"
	QueueSkipped    QueueStatus = "SKIPPED"
)

type QueueSession struct {
	ID             uint           `gorm:"primaryKey" json:"id"`
	DoctorID       uint           `gorm:"not null" json:"doctor_id"`
	ClinicName     string         `gorm:"not null" json:"clinic_name"`
	CurrentNumber  int            `gorm:"default:0" json:"current_number"`
	TotalIssued    int            `gorm:"default:0" json:"total_issued"`
	SessionDate    time.Time      `gorm:"not null" json:"session_date"`
	IsActive       bool           `gorm:"default:true" json:"is_active"`
	CreatedAt      time.Time      `json:"created_at"`
	UpdatedAt      time.Time      `json:"updated_at"`
	DeletedAt      gorm.DeletedAt `gorm:"index" json:"-"`
}
