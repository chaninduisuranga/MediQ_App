package database

import (
	"log"

	"mediq-backend/internal/models"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

var DB *gorm.DB

func InitDB(databaseURL string) *gorm.DB {
	db, err := gorm.Open(postgres.Open(databaseURL), &gorm.Config{})
	if err != nil {
		log.Printf("Warning: Failed to connect to PostgreSQL database: %v", err)
		return nil
	}

	// Auto-migrate only User table
	if err := db.AutoMigrate(&models.User{}); err != nil {
		log.Printf("Failed to auto-migrate database schema: %v", err)
	} else {
		log.Println("Database schema auto-migrated successfully (Users table)")
	}

	log.Println("Database connection established successfully")
	DB = db
	return db
}
