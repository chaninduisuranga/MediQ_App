package models

import (
	"time"

	"gorm.io/gorm"
)

type Doctor struct {
	ID             uint           `gorm:"primaryKey" json:"id"`
	UserID         uint           `gorm:"not null" json:"user_id"`
	User           User           `gorm:"foreignKey:UserID" json:"user,omitempty"`
	Specialization string         `gorm:"not null" json:"specialization"`
	SLMCNumber     string         `gorm:"uniqueIndex;not null" json:"slmc_number"`
	ClinicName     string         `gorm:"not null" json:"clinic_name"`
	IsAvailable    bool           `gorm:"default:true" json:"is_available"`
	CreatedAt      time.Time      `json:"created_at"`
	UpdatedAt      time.Time      `json:"updated_at"`
	DeletedAt      gorm.DeletedAt `gorm:"index" json:"-"`
}
