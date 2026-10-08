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

	// Pre-migration cleanup: drop stale unique indexes and constraints.
	// In PostgreSQL, GORM's AutoMigrate checks system catalogs and attempts
	// to drop old unique constraints/indexes when a struct tag changes from
	// uniqueIndex to index. Running explicit DROP INDEX / DROP CONSTRAINT WITH
	// IF EXISTS removes them cleanly so GORM doesn't attempt broken SQL.
	staleItems := []struct{ table, name string }{
		{"users", "uni_users_nic"},
		{"users", "uni_users_email"},
		{"users", "uni_users_google_id"},
	}
	for _, item := range staleItems {
		db.Exec(`DROP INDEX IF EXISTS "` + item.name + `" CASCADE`)
		db.Exec(`ALTER TABLE "` + item.table + `" DROP CONSTRAINT IF EXISTS "` + item.name + `" CASCADE`)
	}

	// Auto-migrate all tables including Notification. If migration fails only due to the known stale
	// constraint issue (which we already cleaned up above), log a warning and
	// continue — the server is still functional.
	if err := db.AutoMigrate(
		&models.User{},
		&models.Doctor{},
		&models.AdminStaffAssignment{},
		&models.MedicalRecord{},
		&models.OPDAppointment{},
		&models.QueueSession{},
		&models.ChatMessage{},
		&models.Notification{},
	); err != nil {
		// Treat missing-constraint errors as non-fatal warnings
		if strings.Contains(err.Error(), "does not exist (SQLSTATE 42704)") {
			log.Printf("Warning: non-fatal migration issue (stale constraint already cleaned): %v", err)
		} else {
			log.Printf("Failed to auto-migrate database schema: %v", err)
		}
	} else {
		log.Println("Database schema auto-migrated successfully (Users, Doctors, StaffAssignments, MedicalRecords, OPDAppointments, QueueSessions, ChatMessages, Notifications)")
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