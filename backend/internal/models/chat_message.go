package models

import (
	"time"

	"gorm.io/gorm"
)

type ChatMessage struct {
	ID        uint           `gorm:"primaryKey" json:"id"`
	UserID    uint           `gorm:"not null;index" json:"user_id"`
	Sender    string         `gorm:"type:varchar(20);not null" json:"sender"` // "user" or "bot"
	Text      string         `gorm:"type:text;not null" json:"text"`
	CreatedAt time.Time      `json:"created_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}
