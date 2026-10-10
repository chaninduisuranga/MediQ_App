package models

import (
	"time"

	"gorm.io/gorm"
)

type RecordType string

const (
	RecordDoctorDiagnosis RecordType = "DOCTOR_DIAGNOSIS"
	RecordPatientUpload   RecordType = "PATIENT_UPLOAD"
)

type MedicalRecord struct {
	ID          uint           `gorm:"primaryKey" json:"id"`
	PatientID   uint           `gorm:"not null;index" json:"patient_id"`
	Patient     User           `gorm:"foreignKey:PatientID" json:"patient,omitempty"`
	RecordType  RecordType     `gorm:"type:varchar(50);default:'PATIENT_UPLOAD'" json:"record_type"`
	Title       string         `gorm:"not null" json:"title"`
	DoctorName  string         `json:"doctor_name"`
	ClinicName  string         `json:"clinic_name"`
	Diagnosis   string         `json:"diagnosis"`
	ImageURL    string         `json:"image_url"`
	RecordDate  time.Time      `json:"record_date"`
	CreatedAt   time.Time      `json:"created_at"`
	UpdatedAt   time.Time      `json:"updated_at"`
	DeletedAt   gorm.DeletedAt `gorm:"index" json:"-"`
}
