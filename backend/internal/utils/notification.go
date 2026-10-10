package utils

import (
	"log"
	"mediq-backend/internal/models"

	"gorm.io/gorm"
)

// NotifyDoctorForRoom creates a notification for doctor(s) assigned to a given room.
func NotifyDoctorForRoom(db *gorm.DB, room models.OPDRoom, notifType, title, message string) {
	if db == nil {
		return
	}

	var doctors []models.Doctor
	query := db.Model(&models.Doctor{})

	if room != "" && room != models.RoomOPDClinic && room != "GENERAL_OPD" {
		query = query.Where("room = ?", room)
	}

	if err := query.Find(&doctors).Error; err != nil {
		log.Printf("[Notification] Failed to query doctors for room %s: %v", room, err)
		return
	}

	if len(doctors) == 0 {
		// Fallback: find all doctors
		db.Find(&doctors)
	}

	for _, doc := range doctors {
		if doc.UserID == 0 {
			continue
		}
		notif := models.Notification{
			UserID:  doc.UserID,
			Type:    notifType,
			Title:   title,
			Message: message,
			IsRead:  false,
		}
		if err := db.Create(&notif).Error; err != nil {
			log.Printf("[Notification] Failed to create notification for UserID %d: %v", doc.UserID, err)
		} else {
			log.Printf("[Notification] Created notification (%s) for UserID %d: %s", notifType, doc.UserID, title)
		}
	}
}
