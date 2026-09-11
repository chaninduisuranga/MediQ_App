package models

import (
	"time"

	"gorm.io/gorm"
)

type UserRole string

const (
	RolePatient UserRole = "PATIENT"
	RoleDoctor  UserRole = "DOCTOR"
	RoleStaff   UserRole = "STAFF"
	RoleAdmin   UserRole = "ADMIN"
)

type UserStatus string

const (
	StatusActive    UserStatus = "ACTIVE"
	StatusInactive  UserStatus = "INACTIVE"
	StatusSuspended UserStatus = "SUSPENDED"
)

type User struct {
	ID                    uint           `gorm:"primaryKey" json:"id"`
	FullName              string         `gorm:"not null" json:"full_name"`
	NIC                   string         `gorm:"unique;not null" json:"nic"`
	Phone                 string         `gorm:"not null" json:"phone"`
	Password              string         `gorm:"not null" json:"-"`
	Role                  UserRole       `gorm:"type:varchar(20);default:'PATIENT'" json:"role"`
	Status                UserStatus     `gorm:"type:varchar(20);default:'ACTIVE'" json:"status"`
	Gender                string         `json:"gender"`
	DateOfBirth           string         `json:"date_of_birth"`
	CivilStatus           string         `json:"civil_status"`
	Address               string         `json:"address"`
	District              string         `json:"district"`
	EmergencyContactName  string         `json:"emergency_contact_name"`
	EmergencyContactPhone string         `json:"emergency_contact_phone"`
	BloodGroup            string         `json:"blood_group"`
	Allergies             string         `json:"allergies"`
	MedicalConditions     string         `json:"medical_conditions"`
	CreatedAt             time.Time      `json:"created_at"`
	UpdatedAt             time.Time      `json:"updated_at"`
	DeletedAt             gorm.DeletedAt `gorm:"index" json:"-"`
}
