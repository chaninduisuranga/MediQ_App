package handlers

import (
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"mediq-backend/internal/config"
	"mediq-backend/internal/database"
	"mediq-backend/internal/models"
	"mediq-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type MedicalRecordHandler struct {
	cloudinary *utils.CloudinaryUploader
}

func NewMedicalRecordHandler(cfg *config.Config) *MedicalRecordHandler {
	uploader, err := utils.NewCloudinaryUploader(
		cfg.CloudinaryCloud,
		cfg.CloudinaryAPIKey,
		cfg.CloudinaryAPISecret,
	)
	if err != nil {
		fmt.Printf("[MedicalRecordHandler] Cloudinary not configured, using local storage: %v\n", err)
	}
	return &MedicalRecordHandler{cloudinary: uploader}
}

// GetPatientRecords returns all medical records for the authenticated patient
func (h *MedicalRecordHandler) GetPatientRecords(c *gin.Context) {
	userIDVal, exists := c.Get("userID")
	if !exists {
		utils.SendError(c, http.StatusUnauthorized, "Unauthorized")
		return
	}
	userID := userIDVal.(uint)

	recordType := c.Query("type")

	query := database.DB.Where("patient_id = ?", userID)
	if recordType != "" {
		query = query.Where("record_type = ?", recordType)
	}

	var records []models.MedicalRecord
	if err := query.Order("record_date DESC").Find(&records).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to retrieve medical records: "+err.Error())
		return
	}

	utils.SendSuccess(c, http.StatusOK, "Medical records retrieved successfully", records)
}

// UploadPrescription processes prescription photo upload and saves to Cloudinary (or local fallback)
func (h *MedicalRecordHandler) UploadPrescription(c *gin.Context) {
	userIDVal, exists := c.Get("userID")
	if !exists {
		utils.SendError(c, http.StatusUnauthorized, "Unauthorized")
		return
	}
	userID := userIDVal.(uint)

	title := c.PostForm("title")
	if title == "" {
		title = "Prescription Photo"
	}
	notes := c.PostForm("notes")
	doctorName := c.PostForm("doctor_name")
	clinicName := c.PostForm("clinic_name")

	// Parse file header
	file, fileHeader, err := c.Request.FormFile("file")
	var imageURL string

	if err == nil && file != nil {
		defer file.Close()

		// Try Cloudinary upload first
		if h.cloudinary != nil {
			// Build a unique public_id
			publicID := fmt.Sprintf("prescription_%d_%d", userID, time.Now().UnixNano())
			uploadedURL, uploadErr := h.cloudinary.UploadFile(file, publicID)
			if uploadErr != nil {
				utils.SendError(c, http.StatusInternalServerError, "Failed to upload image to cloud: "+uploadErr.Error())
				return
			}
			imageURL = uploadedURL
		} else {
			// Fallback: save locally
			uploadDir := filepath.Join("uploads", "prescriptions")
			if err := os.MkdirAll(uploadDir, 0755); err != nil {
				utils.SendError(c, http.StatusInternalServerError, "Failed to create upload directory")
				return
			}
			ext := filepath.Ext(fileHeader.Filename)
			if ext == "" {
				ext = ".jpg"
			}
			filename := fmt.Sprintf("prescription_%d_%d%s", userID, time.Now().UnixNano(), strings.ToLower(ext))
			targetPath := filepath.Join(uploadDir, filename)
			if saveErr := c.SaveUploadedFile(fileHeader, targetPath); saveErr != nil {
				utils.SendError(c, http.StatusInternalServerError, "Failed to save image: "+saveErr.Error())
				return
			}
			imageURL = "/uploads/prescriptions/" + filename
		}
	}

	record := models.MedicalRecord{
		PatientID:  userID,
		RecordType: models.RecordPatientUpload,
		Title:      strings.TrimSpace(title),
		DoctorName: strings.TrimSpace(doctorName),
		ClinicName: strings.TrimSpace(clinicName),
		Diagnosis:  strings.TrimSpace(notes),
		ImageURL:   imageURL,
		RecordDate: time.Now(),
	}

	if err := database.DB.Create(&record).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to save medical record: "+err.Error())
		return
	}

	utils.SendSuccess(c, http.StatusCreated, "Prescription uploaded successfully", record)
}

// AddDoctorRecord allows a doctor to add a diagnosis record for a patient (by patient NIC)
func (h *MedicalRecordHandler) AddDoctorRecord(c *gin.Context) {
	type DoctorRecordRequest struct {
		PatientNIC string `json:"patient_nic" binding:"required"`
		Title      string `json:"title" binding:"required"`
		DoctorName string `json:"doctor_name" binding:"required"`
		ClinicName string `json:"clinic_name"`
		Diagnosis  string `json:"diagnosis"`
	}

	var req DoctorRecordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.SendError(c, http.StatusBadRequest, "Invalid request: "+err.Error())
		return
	}

	// Find patient by NIC
	var patient models.User
	nic := strings.ToUpper(strings.TrimSpace(req.PatientNIC))
	if err := database.DB.Where("nic = ?", nic).First(&patient).Error; err != nil {
		utils.SendError(c, http.StatusNotFound, "Patient with this NIC not found")
		return
	}

	record := models.MedicalRecord{
		PatientID:  patient.ID,
		RecordType: models.RecordDoctorDiagnosis,
		Title:      strings.TrimSpace(req.Title),
		DoctorName: strings.TrimSpace(req.DoctorName),
		ClinicName: strings.TrimSpace(req.ClinicName),
		Diagnosis:  strings.TrimSpace(req.Diagnosis),
		RecordDate: time.Now(),
	}

	if err := database.DB.Create(&record).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to create doctor record: "+err.Error())
		return
	}

	utils.SendSuccess(c, http.StatusCreated, "Doctor diagnosis record created successfully", record)
}

// DeleteRecord deletes a patient medical record
func (h *MedicalRecordHandler) DeleteRecord(c *gin.Context) {
	userIDVal, exists := c.Get("userID")
	if !exists {
		utils.SendError(c, http.StatusUnauthorized, "Unauthorized")
		return
	}
	userID := userIDVal.(uint)
	recordID := c.Param("id")

	if err := database.DB.Where("id = ? AND patient_id = ?", recordID, userID).Delete(&models.MedicalRecord{}).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to delete record: "+err.Error())
		return
	}

	utils.SendSuccess(c, http.StatusOK, "Record deleted successfully", nil)
}
