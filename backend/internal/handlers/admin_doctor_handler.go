package handlers

import (
	"net/http"
	"strconv"
	"strings"
	"time"

	"mediq-backend/internal/database"
	"mediq-backend/internal/models"
	"mediq-backend/internal/utils"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type AdminDoctorHandler struct{}

func NewAdminDoctorHandler() *AdminDoctorHandler { return &AdminDoctorHandler{} }

type AdminDoctorRequest struct {
	UserID         uint               `json:"user_id" binding:"required"`
	Specialization string             `json:"specialization" binding:"required"`
	SLMCNumber     string             `json:"slmc_number" binding:"required"`
	ClinicName     string             `json:"clinic_name" binding:"required"`
	Room           models.OPDRoom     `json:"room"`
	IsAvailable    *bool              `json:"is_available"`
	Status         *models.UserStatus `json:"status"`
}

type AdminDoctorSummary struct {
	ID             uint              `json:"id"`
	UserID         uint              `json:"user_id"`
	Name           string            `json:"name"`
	Specialization string            `json:"specialization"`
	SLMCNumber     string            `json:"slmc_number"`
	ClinicName     string            `json:"clinic_name"`
	Room           models.OPDRoom    `json:"room"`
	Status         models.UserStatus `json:"status"`
	IsAvailable    bool              `json:"is_available"`
	CurrentQueue   int64             `json:"current_queue"`
}

func (h *AdminDoctorHandler) ListDoctors(c *gin.Context) {
	if database.DB == nil {
		utils.SendError(c, http.StatusInternalServerError, "Database connection not initialized")
		return
	}
	query := database.DB.Model(&models.Doctor{}).Preload("User")
	if search := strings.TrimSpace(c.Query("search")); search != "" {
		query = query.Joins("JOIN users ON users.id = doctors.user_id").Where("users.full_name ILIKE ? OR doctors.specialization ILIKE ? OR doctors.slmc_number ILIKE ?", "%"+search+"%", "%"+search+"%", "%"+search+"%")
	}
	var doctors []models.Doctor
	if err := query.Order("user_id ASC").Find(&doctors).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to load doctors: "+err.Error())
		return
	}
	response := make([]AdminDoctorSummary, 0, len(doctors))
	for _, doctor := range doctors {
		response = append(response, h.summary(doctor))
	}
	utils.SendSuccess(c, http.StatusOK, "Doctors retrieved successfully", response)
}

func (h *AdminDoctorHandler) CreateDoctor(c *gin.Context) {
	var request AdminDoctorRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		utils.SendError(c, http.StatusBadRequest, "Invalid doctor details")
		return
	}
	if !validAdminRoom(request.Room) {
		utils.SendError(c, http.StatusBadRequest, "Invalid doctor room")
		return
	}
	if request.Status != nil && !validAdminUserStatus(*request.Status) {
		utils.SendError(c, http.StatusBadRequest, "Invalid doctor account status")
		return
	}
	var user models.User
	if err := database.DB.First(&user, request.UserID).Error; err != nil {
		utils.SendError(c, http.StatusNotFound, "User not found")
		return
	}
	if user.Role != models.RoleDoctor {
		utils.SendError(c, http.StatusBadRequest, "Selected user must have the DOCTOR role")
		return
	}
	var existing models.Doctor
	if err := database.DB.Where("user_id = ?", request.UserID).First(&existing).Error; err == nil {
		utils.SendError(c, http.StatusConflict, "Doctor profile already exists")
		return
	}
	isAvailable := true
	if request.IsAvailable != nil {
		isAvailable = *request.IsAvailable
	}
	doctor := models.Doctor{UserID: request.UserID, Specialization: strings.TrimSpace(request.Specialization), SLMCNumber: strings.TrimSpace(request.SLMCNumber), ClinicName: strings.TrimSpace(request.ClinicName), Room: request.Room, IsAvailable: isAvailable}
	if err := database.DB.Create(&doctor).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to create doctor: "+err.Error())
		return
	}
	database.DB.Preload("User").First(&doctor, doctor.ID)
	utils.SendSuccess(c, http.StatusCreated, "Doctor added successfully", h.summary(doctor))
}

func (h *AdminDoctorHandler) UpdateDoctor(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil || id == 0 {
		utils.SendError(c, http.StatusBadRequest, "Invalid doctor ID")
		return
	}
	var request AdminDoctorRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		utils.SendError(c, http.StatusBadRequest, "Invalid doctor details")
		return
	}
	if !validAdminRoom(request.Room) {
		utils.SendError(c, http.StatusBadRequest, "Invalid doctor room")
		return
	}
	if request.Status != nil && !validAdminUserStatus(*request.Status) {
		utils.SendError(c, http.StatusBadRequest, "Invalid doctor account status")
		return
	}
	var doctor models.Doctor
	if err := database.DB.Preload("User").First(&doctor, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			utils.SendError(c, http.StatusNotFound, "Doctor not found")
		} else {
			utils.SendError(c, http.StatusInternalServerError, "Failed to load doctor")
		}
		return
	}
	if request.UserID != doctor.UserID {
		utils.SendError(c, http.StatusBadRequest, "Doctor user cannot be changed")
		return
	}
	doctor.Specialization = strings.TrimSpace(request.Specialization)
	doctor.SLMCNumber = strings.TrimSpace(request.SLMCNumber)
	doctor.ClinicName = strings.TrimSpace(request.ClinicName)
	doctor.Room = request.Room
	if request.IsAvailable != nil {
		doctor.IsAvailable = *request.IsAvailable
	}
	if request.Status != nil {
		doctor.User.Status = *request.Status
		if err := database.DB.Save(&doctor.User).Error; err != nil {
			utils.SendError(c, http.StatusInternalServerError, "Failed to update doctor status: "+err.Error())
			return
		}
	}
	if err := database.DB.Save(&doctor).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to update doctor: "+err.Error())
		return
	}
	database.DB.Preload("User").First(&doctor, doctor.ID)
	utils.SendSuccess(c, http.StatusOK, "Doctor updated successfully", h.summary(doctor))
}

func (h *AdminDoctorHandler) summary(doctor models.Doctor) AdminDoctorSummary {
	var queue int64
	if database.DB != nil {
		database.DB.Model(&models.OPDAppointment{}).Where("room = ? AND appointment_date = ? AND status IN ?", doctor.Room, currentAdminDate(), []models.AppointmentStatus{models.AppointmentPending, models.AppointmentConfirmed}).Count(&queue)
	}
	return AdminDoctorSummary{ID: doctor.ID, UserID: doctor.UserID, Name: doctor.User.FullName, Specialization: doctor.Specialization, SLMCNumber: doctor.SLMCNumber, ClinicName: doctor.ClinicName, Room: doctor.Room, Status: doctor.User.Status, IsAvailable: doctor.IsAvailable, CurrentQueue: queue}
}

func validAdminRoom(room models.OPDRoom) bool {
	if room == "" {
		return true
	}
	_, ok := validRooms[room]
	return ok
}

func currentAdminDate() string {
	return time.Now().In(time.FixedZone("IST", 5*3600+30*60)).Format("2006-01-02")
}

func validAdminUserStatus(status models.UserStatus) bool {
	return status == models.StatusActive || status == models.StatusInactive || status == models.StatusSuspended
}
