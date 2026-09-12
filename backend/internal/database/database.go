package database

import (
	"log"
	"strings"

	"mediq-backend/internal/models"
	"mediq-backend/internal/utils"

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

	// Auto-migrate User, MedicalRecord and OPDAppointment tables
	if err := db.AutoMigrate(&models.User{}, &models.MedicalRecord{}, &models.OPDAppointment{}); err != nil {
		log.Printf("Failed to auto-migrate database schema: %v", err)
	} else {
		log.Println("Database schema auto-migrated successfully (Users, MedicalRecords, OPDAppointments)")
	}

	log.Println("Database connection established successfully")
	DB = db
	seedDefaultUsers(db)
	return db
}

// seedDefaultUsers creates default Doctor, Staff, and Admin accounts if they do not exist
func seedDefaultUsers(db *gorm.DB) {
	type DefaultUser struct {
		Name     string
		NIC      string
		Phone    string
		Password string
		Role     models.UserRole
	}

	defaults := []DefaultUser{
		{Name: "Dr. Suneth Perera", NIC: "198500100200", Phone: "0771112223", Password: "Doctor@123", Role: models.RoleDoctor},
		{Name: "Staff Member (OPD)", NIC: "199000100200", Phone: "0772223334", Password: "Staff@123", Role: models.RoleStaff},
		{Name: "System Admin", NIC: "200305000933", Phone: "0773334445", Password: "Admin@123", Role: models.RoleAdmin},
	}

	for _, d := range defaults {
		var count int64
		db.Model(&models.User{}).Where("nic = ?", d.NIC).Count(&count)
		if count == 0 {
			hashed, err := utils.HashPassword(d.Password)
			if err != nil {
				continue
			}
			user := models.User{
				FullName: strings.TrimSpace(d.Name),
				NIC:      d.NIC,
				Phone:    d.Phone,
				Password: hashed,
				Role:     d.Role,
				Status:   models.StatusActive,
			}
			if err := db.Create(&user).Error; err == nil {
				log.Printf("[Seeder] Created default account: %s (%s) | Role: %s\n", d.Name, d.NIC, d.Role)
			}
		}
	}
}
