package models

import "time"

type StaffNotification struct {
	ID         uint       `gorm:"primaryKey" json:"id"`
	StaffUserID uint       `gorm:"not null;index" json:"staff_user_id"`
	Title      string     `gorm:"type:varchar(100);not null" json:"title"`
	Message    string     `gorm:"type:text;not null" json:"message"`
	Type       string     `gorm:"type:varchar(30);not null;index" json:"type"`
	IsRead     bool       `gorm:"not null;default:false;index" json:"is_read"`
	CreatedAt  time.Time  `gorm:"not null;index" json:"created_at"`
	ReadAt     *time.Time `json:"read_at,omitempty"`
}

func (StaffNotification) TableName() string {
	return "staff_notifications"
}
