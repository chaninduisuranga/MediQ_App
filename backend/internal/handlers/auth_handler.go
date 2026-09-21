package handlers

import (
	"net/http"
	"strings"

	"mediq-backend/internal/config"
	"mediq-backend/internal/database"
	"mediq-backend/internal/models"
	"mediq-backend/internal/utils"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type AuthHandler struct {
	cfg *config.Config
}

func NewAuthHandler(cfg *config.Config) *AuthHandler {
	return &AuthHandler{cfg: cfg}
}

type PatientSignupRequest struct {
	FullName              string `json:"full_name" binding:"required"`
	NIC                   string `json:"nic" binding:"required"`
	Email                 string `json:"email"`
	Phone                 string `json:"phone" binding:"required"`
	Password              string `json:"password" binding:"required,min=6"`
	Gender                string `json:"gender"`
	DateOfBirth           string `json:"date_of_birth"`
	CivilStatus           string `json:"civil_status"`
	Address               string `json:"address"`
	District              string `json:"district"`
	EmergencyContactName  string `json:"emergency_contact_name"`
	EmergencyContactPhone string `json:"emergency_contact_phone"`
	BloodGroup            string `json:"blood_group"`
	Allergies             string `json:"allergies"`
	MedicalConditions     string `json:"medical_conditions"`
}

type UpdateProfileRequest struct {
	FullName              string `json:"full_name"`
	Email                 string `json:"email"`
	Phone                 string `json:"phone"`
	Gender                string `json:"gender"`
	DateOfBirth           string `json:"date_of_birth"`
	CivilStatus           string `json:"civil_status"`
	Address               string `json:"address"`
	District              string `json:"district"`
	EmergencyContactName  string `json:"emergency_contact_name"`
	EmergencyContactPhone string `json:"emergency_contact_phone"`
	BloodGroup            string `json:"blood_group"`
	Allergies             string `json:"allergies"`
	MedicalConditions     string `json:"medical_conditions"`
}

type LoginRequest struct {
	NIC      string `json:"nic" binding:"required"`
	Password string `json:"password" binding:"required"`
}

type AuthResponseData struct {
	Token string      `json:"token"`
	User  models.User `json:"user"`
}

// Signup handles patient registration
func (h *AuthHandler) Signup(c *gin.Context) {
	var req PatientSignupRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.SendError(c, http.StatusBadRequest, "Invalid request parameters: "+err.Error())
		return
	}

	nic := strings.ToUpper(strings.TrimSpace(req.NIC))
	phone := strings.TrimSpace(req.Phone)

	if database.DB == nil {
		utils.SendError(c, http.StatusInternalServerError, "Database connection not initialized")
		return
	}

	// Check if user already exists with NIC
	var existingUser models.User
	if err := database.DB.Where("nic = ?", nic).First(&existingUser).Error; err == nil {
		utils.SendError(c, http.StatusConflict, "A patient is already registered with this NIC number")
		return
	}

	// Hash password
	hashedPassword, err := utils.HashPassword(req.Password)
	if err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to process password")
		return
	}

	user := models.User{
		FullName:              strings.TrimSpace(req.FullName),
		NIC:                   nic,
		Email:                 strings.TrimSpace(req.Email),
		Phone:                 phone,
		Password:              hashedPassword,
		Role:                  models.RolePatient,
		Status:                models.StatusActive,
		Gender:                req.Gender,
		DateOfBirth:           req.DateOfBirth,
		CivilStatus:           req.CivilStatus,
		Address:               req.Address,
		District:              req.District,
		EmergencyContactName:  req.EmergencyContactName,
		EmergencyContactPhone: req.EmergencyContactPhone,
		BloodGroup:            req.BloodGroup,
		Allergies:             req.Allergies,
		MedicalConditions:     req.MedicalConditions,
	}

	if err := database.DB.Create(&user).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to register patient: "+err.Error())
		return
	}

	// Generate JWT Token
	token, err := utils.GenerateToken(user.ID, user.NIC, string(user.Role), h.cfg.JWTSecret)
	if err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to generate session token")
		return
	}

	utils.SendSuccess(c, http.StatusCreated, "Patient registered successfully", AuthResponseData{
		Token: token,
		User:  user,
	})
}

// Login handles user authentication using NIC and Password
func (h *AuthHandler) Login(c *gin.Context) {
	var req LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.SendError(c, http.StatusBadRequest, "Please enter your NIC and password")
		return
	}

	nic := strings.ToUpper(strings.TrimSpace(req.NIC))

	if database.DB == nil {
		utils.SendError(c, http.StatusInternalServerError, "Database connection not initialized")
		return
	}

	var user models.User
	if err := database.DB.Where("nic = ?", nic).First(&user).Error; err != nil {
		// Auto-seed demo accounts if missing
		ensureDemoAccountExists(database.DB, nic)
		if err := database.DB.Where("nic = ?", nic).First(&user).Error; err != nil {
			utils.SendError(c, http.StatusUnauthorized, "Invalid NIC or password")
			return
		}
	}

	if !utils.CheckPasswordHash(req.Password, user.Password) {
		utils.SendError(c, http.StatusUnauthorized, "Invalid NIC or password")
		return
	}

	token, err := utils.GenerateToken(user.ID, user.NIC, string(user.Role), h.cfg.JWTSecret)
	if err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to generate session token")
		return
	}

	utils.SendSuccess(c, http.StatusOK, "Login successful", AuthResponseData{
		Token: token,
		User:  user,
	})
}

// GetMe returns current logged in user details
func (h *AuthHandler) GetMe(c *gin.Context) {
	userID, exists := c.Get("userID")
	if !exists {
		utils.SendError(c, http.StatusUnauthorized, "Unauthorized")
		return
	}

	var user models.User
	if err := database.DB.First(&user, userID).Error; err != nil {
		utils.SendError(c, http.StatusNotFound, "User profile not found")
		return
	}

	utils.SendSuccess(c, http.StatusOK, "Profile retrieved successfully", user)
}

// UpdateProfile updates logged in patient profile
func (h *AuthHandler) UpdateProfile(c *gin.Context) {
	userID, exists := c.Get("userID")
	if !exists {
		utils.SendError(c, http.StatusUnauthorized, "Unauthorized")
		return
	}

	var req UpdateProfileRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.SendError(c, http.StatusBadRequest, "Invalid request body: "+err.Error())
		return
	}

	var user models.User
	if err := database.DB.First(&user, userID).Error; err != nil {
		utils.SendError(c, http.StatusNotFound, "User profile not found")
		return
	}

	if req.FullName != "" {
		user.FullName = strings.TrimSpace(req.FullName)
	}
	if req.Email != "" {
		user.Email = strings.TrimSpace(req.Email)
	}
	if req.Phone != "" {
		user.Phone = strings.TrimSpace(req.Phone)
	}
	if req.Gender != "" {
		user.Gender = req.Gender
	}
	if req.DateOfBirth != "" {
		user.DateOfBirth = req.DateOfBirth
	}
	if req.CivilStatus != "" {
		user.CivilStatus = req.CivilStatus
	}
	if req.Address != "" {
		user.Address = req.Address
	}
	if req.District != "" {
		user.District = req.District
	}
	if req.EmergencyContactName != "" {
		user.EmergencyContactName = req.EmergencyContactName
	}
	if req.EmergencyContactPhone != "" {
		user.EmergencyContactPhone = req.EmergencyContactPhone
	}
	if req.BloodGroup != "" {
		user.BloodGroup = req.BloodGroup
	}
	if req.Allergies != "" {
		user.Allergies = req.Allergies
	}
	if req.MedicalConditions != "" {
		user.MedicalConditions = req.MedicalConditions
	}

	if err := database.DB.Save(&user).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to update profile: "+err.Error())
		return
	}

	utils.SendSuccess(c, http.StatusOK, "Profile updated successfully", user)
}

// DeleteAccount deletes logged in patient account
func (h *AuthHandler) DeleteAccount(c *gin.Context) {
	userID, exists := c.Get("userID")
	if !exists {
		utils.SendError(c, http.StatusUnauthorized, "Unauthorized")
		return
	}

	if err := database.DB.Delete(&models.User{}, userID).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to delete account: "+err.Error())
		return
	}

	utils.SendSuccess(c, http.StatusOK, "Account deleted successfully", nil)
}

type GoogleLoginRequest struct {
	Email    string `json:"email" binding:"required"`
	FullName string `json:"full_name"`
	GoogleID string `json:"google_id" binding:"required"`
	PhotoURL string `json:"photo_url"`
}

// GoogleLogin handles patient login or registration via Google OAuth
func (h *AuthHandler) GoogleLogin(c *gin.Context) {
	var req GoogleLoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.SendError(c, http.StatusBadRequest, "Invalid Google user data: "+err.Error())
		return
	}

	email := strings.ToLower(strings.TrimSpace(req.Email))
	googleID := strings.TrimSpace(req.GoogleID)
	fullName := strings.TrimSpace(req.FullName)
	if fullName == "" {
		fullName = "Google Patient"
	}

	if database.DB == nil {
		utils.SendError(c, http.StatusInternalServerError, "Database connection not initialized")
		return
	}

	var user models.User
	// Search by GoogleID or Email
	err := database.DB.Where("google_id = ? OR email = ?", googleID, email).First(&user).Error
	if err != nil {
		// User does not exist, create new patient account with Google details
		dummyNIC := "G-" + googleID
		if len(dummyNIC) > 20 {
			dummyNIC = dummyNIC[:20]
		}

		user = models.User{
			FullName: fullName,
			NIC:      dummyNIC,
			Email:    email,
			GoogleID: googleID,
			Role:     models.RolePatient,
			Status:   models.StatusActive,
		}

		if createErr := database.DB.Create(&user).Error; createErr != nil {
			utils.SendError(c, http.StatusInternalServerError, "Failed to create Google patient account: "+createErr.Error())
			return
		}
	} else {
		// Update GoogleID or Email if missing
		updated := false
		if user.GoogleID == "" {
			user.GoogleID = googleID
			updated = true
		}
		if user.Email == "" {
			user.Email = email
			updated = true
		}
		if updated {
			database.DB.Save(&user)
		}
	}

	// Generate session token
	token, err := utils.GenerateToken(user.ID, user.NIC, string(user.Role), h.cfg.JWTSecret)
	if err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to generate session token")
		return
	}

	utils.SendSuccess(c, http.StatusOK, "Google login successful", AuthResponseData{
		Token: token,
		User:  user,
	})
}

// ensureDemoAccountExists creates a default demo account on demand if requested during login
func ensureDemoAccountExists(db *gorm.DB, nic string) {
	type DefaultUser struct {
		Name     string
		NIC      string
		Phone    string
		Password string
		Role     models.UserRole
	}

	defaults := map[string]DefaultUser{
		"200300702320": {Name: "Sample Patient", NIC: "200300702320", Phone: "0770000000", Password: "722003", Role: models.RolePatient},
		"198500100200": {Name: "Dr. Suneth Perera", NIC: "198500100200", Phone: "0771112223", Password: "Doctor@123", Role: models.RoleDoctor},
		"199000100200": {Name: "Staff Member (OPD)", NIC: "199000100200", Phone: "0772223334", Password: "Staff@123", Role: models.RoleStaff},
		"200305000933": {Name: "System Admin", NIC: "200305000933", Phone: "0773334445", Password: "Admin@123", Role: models.RoleAdmin},
	}

	if demo, exists := defaults[nic]; exists {
		hashed, err := utils.HashPassword(demo.Password)
		if err == nil {
			u := models.User{
				FullName: strings.TrimSpace(demo.Name),
				NIC:      demo.NIC,
				Phone:    demo.Phone,
				Password: hashed,
				Role:     demo.Role,
				Status:   models.StatusActive,
			}
			db.Create(&u)
		}
	}
}
