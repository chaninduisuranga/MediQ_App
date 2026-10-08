package models

import (
	"time"

	"gorm.io/gorm"
)

// ChatFAQ stores admin-managed keyword-based FAQ responses for the AI chatbot.
// Keywords are stored as a comma-separated string for simplicity (e.g. "appointment,book,channel").
// Answers can be set per language (English, Sinhala, Tamil).
// Category helps organize FAQs for future admin UI display.
type ChatFAQ struct {
	ID             uint           `gorm:"primaryKey" json:"id"`
	Category       string         `gorm:"type:varchar(100);not null" json:"category"`          // e.g. "appointment", "queue", "emergency"
	Keywords       string         `gorm:"type:text;not null" json:"keywords"`                  // comma-separated trigger words
	AnswerEN       string         `gorm:"type:text;not null" json:"answer_en"`                 // English answer
	AnswerSI       string         `gorm:"type:text" json:"answer_si"`                          // Sinhala answer
	AnswerTA       string         `gorm:"type:text" json:"answer_ta"`                          // Tamil answer
	IsLiveData     bool           `gorm:"default:false" json:"is_live_data"`                   // if true, fetch live DB data
	LiveDataType   string         `gorm:"type:varchar(50)" json:"live_data_type"`              // "appointments", "doctors", "rooms", "queue"
	Priority       int            `gorm:"default:0" json:"priority"`                           // higher = matched first
	IsActive       bool           `gorm:"default:true" json:"is_active"`                       // enable/disable FAQ
	CreatedAt      time.Time      `json:"created_at"`
	UpdatedAt      time.Time      `json:"updated_at"`
	DeletedAt      gorm.DeletedAt `gorm:"index" json:"-"`
}
