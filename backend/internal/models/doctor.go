package models

import (
	"time"

	"gorm.io/gorm"
)

type Doctor struct {
	ID                uint           `gorm:"primaryKey" json:"id"`
	UserID            uint           `gorm:"not null" json:"user_id"`
	User              User           `gorm:"foreignKey:UserID" json:"user,omitempty"`
	Specialization    string         `gorm:"not null" json:"specialization"`
	SLMCNumber        string         `gorm:"uniqueIndex;not null" json:"slmc_number"`
	ClinicName        string         `gorm:"not null" json:"clinic_name"`
	Room              OPDRoom        `gorm:"type:varchar(50)" json:"room"`
	IsAvailable       bool           `gorm:"default:true" json:"is_available"`
	WorkingDays       string         `gorm:"type:varchar(255);default:'Monday,Tuesday,Wednesday,Thursday,Friday'" json:"working_days"`
	SessionType       string         `gorm:"type:varchar(100);default:'Morning OPD'" json:"session_type"`
	WorkingHoursStart string         `gorm:"type:varchar(20);default:'08:00 AM'" json:"working_hours_start"`
	WorkingHoursEnd   string         `gorm:"type:varchar(20);default:'04:00 PM'" json:"working_hours_end"`
	MaxPatientsPerDay int            `gorm:"column:max_patients;default:30" json:"max_patients_per_day"`
	CreatedAt         time.Time      `json:"created_at"`
	UpdatedAt         time.Time      `json:"updated_at"`
	DeletedAt         gorm.DeletedAt `gorm:"index" json:"-"`
}
