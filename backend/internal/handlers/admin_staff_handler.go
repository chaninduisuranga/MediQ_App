package handlers

import (
	"net/http"
	"strconv"
	"strings"

	"mediq-backend/internal/database"
	"mediq-backend/internal/models"
	"mediq-backend/internal/utils"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type AdminStaffHandler struct{}

func NewAdminStaffHandler() *AdminStaffHandler { return &AdminStaffHandler{} }

type AdminStaffRequest struct {
	UserID       uint                      `json:"user_id" binding:"required"`
	Function     models.AdminStaffFunction `json:"function" binding:"required,oneof=REGISTRATION NURSE QUEUE_MANAGEMENT"`
	AssignedRoom models.OPDRoom            `json:"assigned_room"`
	IsAvailable  *bool                     `json:"is_available"`
	Status       *models.UserStatus        `json:"status"`
}

type AdminStaffSummary struct {
	ID           uint                      `json:"id"`
	UserID       uint                      `json:"user_id"`
	Name         string                    `json:"name"`
	Function     models.AdminStaffFunction `json:"function"`
	AssignedRoom models.OPDRoom            `json:"assigned_room"`
	Status       models.UserStatus         `json:"status"`
	IsAvailable  bool                      `json:"is_available"`
}

func (h *AdminStaffHandler) ListStaff(c *gin.Context) {
	if database.DB == nil {
		utils.SendError(c, http.StatusInternalServerError, "Database connection not initialized")
		return
	}
	var staff []models.AdminStaffAssignment
	query := database.DB.Preload("User")
	if search := strings.TrimSpace(c.Query("search")); search != "" {
		query = query.Joins("JOIN users ON users.id = admin_staff_assignments.user_id").Where("users.full_name ILIKE ? OR admin_staff_assignments.function ILIKE ?", "%"+search+"%", "%"+search+"%")
	}
	if err := query.Order("user_id ASC").Find(&staff).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to load staff: "+err.Error())
		return
	}
	response := make([]AdminStaffSummary, 0, len(staff))
	for _, item := range staff {
		response = append(response, staffSummary(item))
	}
	utils.SendSuccess(c, http.StatusOK, "Staff retrieved successfully", response)
}

func (h *AdminStaffHandler) CreateStaff(c *gin.Context) {
	var request AdminStaffRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		utils.SendError(c, http.StatusBadRequest, "Invalid staff details")
		return
	}
	if !validAdminRoom(request.AssignedRoom) {
		utils.SendError(c, http.StatusBadRequest, "Invalid staff room")
		return
	}
	if request.Status != nil && !validAdminUserStatus(*request.Status) {
		utils.SendError(c, http.StatusBadRequest, "Invalid staff account status")
		return
	}
	var user models.User
	if err := database.DB.First(&user, request.UserID).Error; err != nil {
		utils.SendError(c, http.StatusNotFound, "User not found")
		return
	}
	if user.Role != models.RoleStaff {
		utils.SendError(c, http.StatusBadRequest, "Selected user must have the STAFF role")
		return
	}
	var existing models.AdminStaffAssignment
	if err := database.DB.Where("user_id = ?", request.UserID).First(&existing).Error; err == nil {
		utils.SendError(c, http.StatusConflict, "Staff profile already exists")
		return
	}
	isAvailable := true
	if request.IsAvailable != nil {
		isAvailable = *request.IsAvailable
	}
	item := models.AdminStaffAssignment{UserID: request.UserID, Function: request.Function, AssignedRoom: request.AssignedRoom, IsAvailable: isAvailable}
	if err := database.DB.Create(&item).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to create staff profile: "+err.Error())
		return
	}
	database.DB.Preload("User").First(&item, item.ID)
	utils.SendSuccess(c, http.StatusCreated, "Staff added successfully", staffSummary(item))
}

func (h *AdminStaffHandler) UpdateStaff(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil || id == 0 {
		utils.SendError(c, http.StatusBadRequest, "Invalid staff ID")
		return
	}
	var request AdminStaffRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		utils.SendError(c, http.StatusBadRequest, "Invalid staff details")
		return
	}
	if !validAdminRoom(request.AssignedRoom) {
		utils.SendError(c, http.StatusBadRequest, "Invalid staff room")
		return
	}
	if request.Status != nil && !validAdminUserStatus(*request.Status) {
		utils.SendError(c, http.StatusBadRequest, "Invalid staff account status")
		return
	}
	var item models.AdminStaffAssignment
	if err := database.DB.Preload("User").First(&item, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			utils.SendError(c, http.StatusNotFound, "Staff profile not found")
		} else {
			utils.SendError(c, http.StatusInternalServerError, "Failed to load staff")
		}
		return
	}
	if request.UserID != item.UserID {
		utils.SendError(c, http.StatusBadRequest, "Staff user cannot be changed")
		return
	}
	item.Function = request.Function
	item.AssignedRoom = request.AssignedRoom
	if request.IsAvailable != nil {
		item.IsAvailable = *request.IsAvailable
	}
	if request.Status != nil {
		item.User.Status = *request.Status
		if err := database.DB.Save(&item.User).Error; err != nil {
			utils.SendError(c, http.StatusInternalServerError, "Failed to update staff status: "+err.Error())
			return
		}
	}
	if err := database.DB.Save(&item).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to update staff profile: "+err.Error())
		return
	}
	database.DB.Preload("User").First(&item, item.ID)
	utils.SendSuccess(c, http.StatusOK, "Staff updated successfully", staffSummary(item))
}

func staffSummary(item models.AdminStaffAssignment) AdminStaffSummary {
	return AdminStaffSummary{ID: item.ID, UserID: item.UserID, Name: item.User.FullName, Function: item.Function, AssignedRoom: item.AssignedRoom, Status: item.User.Status, IsAvailable: item.IsAvailable}
}
