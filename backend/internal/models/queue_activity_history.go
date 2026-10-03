package models

import "time"

type QueueActivityHistory struct {
	ID            uint              `gorm:"primaryKey" json:"id"`
	AppointmentID uint              `gorm:"not null;index" json:"appointment_id"`
	StaffUserID   uint              `gorm:"not null;index" json:"staff_user_id"`
	Room          OPDRoom           `gorm:"type:varchar(50);not null;index" json:"room"`
	Action        string            `gorm:"type:varchar(30);not null;index" json:"action"`
	Status        AppointmentStatus `gorm:"type:varchar(20);not null" json:"status"`
	Details       *string           `gorm:"type:text" json:"details,omitempty"`
	OccurredAt    time.Time         `gorm:"not null;index" json:"occurred_at"`
}

func (QueueActivityHistory) TableName() string {
	return "staff_queue_activity_histories"
}
