package models

import "time"

type AdminStaffFunction string

const (
	StaffFunctionRegistration AdminStaffFunction = "REGISTRATION"
	StaffFunctionNurse        AdminStaffFunction = "NURSE"
	StaffFunctionQueue        AdminStaffFunction = "QUEUE_MANAGEMENT"
)

type AdminStaffAssignment struct {
	ID           uint               `gorm:"primaryKey" json:"id"`
	UserID       uint               `gorm:"uniqueIndex;not null" json:"user_id"`
	User         User               `gorm:"foreignKey:UserID" json:"user,omitempty"`
	Function     AdminStaffFunction `gorm:"type:varchar(30);not null" json:"function"`
	AssignedRoom OPDRoom            `gorm:"type:varchar(50)" json:"assigned_room"`
	IsAvailable  bool               `gorm:"default:true" json:"is_available"`
	CreatedAt    time.Time          `json:"created_at"`
	UpdatedAt    time.Time          `json:"updated_at"`
}
