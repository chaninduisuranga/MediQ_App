package handlers

import (
	"fmt"
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

type AdminUserHandler struct{}

func NewAdminUserHandler() *AdminUserHandler {
	return &AdminUserHandler{}
}

type AdminUserSummary struct {
	ID        uint              `json:"id"`
	FullName  string            `json:"full_name"`
	NIC       string            `json:"nic"`
	Phone     string            `json:"phone"`
	Role      models.UserRole   `json:"role"`
	Status    models.UserStatus `json:"status"`
	CreatedAt time.Time         `json:"created_at"`
}

type AdminUserListResponse struct {
	Users      []AdminUserSummary `json:"users"`
	Page       int                `json:"page"`
	Limit      int                `json:"limit"`
	Total      int64              `json:"total"`
	TotalPages int                `json:"total_pages"`
}

type AdminUpdateUserRequest struct {
	Role   models.UserRole   `json:"role" binding:"omitempty,oneof=DOCTOR STAFF ADMIN"`
	Status models.UserStatus `json:"status" binding:"omitempty,oneof=ACTIVE INACTIVE SUSPENDED"`
}

func (h *AdminUserHandler) ListUsers(c *gin.Context) {
	if database.DB == nil {
		utils.SendError(c, http.StatusInternalServerError, "Database connection not initialized")
		return
	}

	page := parsePositiveQueryInt(c, "page", 1)
	limit := parsePositiveQueryInt(c, "limit", 20)
	if limit > 100 {
		limit = 100
	}
	search := strings.TrimSpace(c.Query("search"))
	roleFilter := models.UserRole(strings.ToUpper(strings.TrimSpace(c.Query("role"))))
	if roleFilter != "" && roleFilter != models.RoleDoctor && roleFilter != models.RoleStaff && roleFilter != models.RoleAdmin {
		utils.SendError(c, http.StatusBadRequest, "Invalid user role filter")
		return
	}

	query := database.DB.Model(&models.User{}).Where("role <> ?", models.RolePatient)
	if roleFilter != "" {
		query = query.Where("role = ?", roleFilter)
	}
	if search != "" {
		query = query.Where("(full_name ILIKE ? OR nic ILIKE ? OR phone ILIKE ?)", "%"+search+"%", "%"+search+"%", "%"+search+"%")
		if userID, err := strconv.ParseUint(search, 10, 64); err == nil {
			query = query.Where("id = ? OR full_name ILIKE ? OR nic ILIKE ? OR phone ILIKE ?", userID, "%"+search+"%", "%"+search+"%", "%"+search+"%")
		}
	}

	var total int64
	if err := query.Count(&total).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to count users: "+err.Error())
		return
	}

	var users []models.User
	if err := query.Select("id, full_name, nic, phone, role, status, created_at").Order("created_at DESC").Offset((page - 1) * limit).Limit(limit).Find(&users).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to load users: "+err.Error())
		return
	}

	summaries := make([]AdminUserSummary, 0, len(users))
	for _, user := range users {
		summaries = append(summaries, AdminUserSummary{
			ID: user.ID, FullName: user.FullName, NIC: user.NIC, Phone: user.Phone,
			Role: user.Role, Status: user.Status, CreatedAt: user.CreatedAt,
		})
	}

	utils.SendSuccess(c, http.StatusOK, "Users retrieved successfully", AdminUserListResponse{
		Users: summaries, Page: page, Limit: limit, Total: total,
		TotalPages: int((total + int64(limit) - 1) / int64(limit)),
	})
}

func (h *AdminUserHandler) UpdateUser(c *gin.Context) {
	if database.DB == nil {
		utils.SendError(c, http.StatusInternalServerError, "Database connection not initialized")
		return
	}

	userID, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil || userID == 0 {
		utils.SendError(c, http.StatusBadRequest, "Invalid user ID")
		return
	}

	var req AdminUpdateUserRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.SendError(c, http.StatusBadRequest, "Invalid role or status")
		return
	}
	if req.Role == "" && req.Status == "" {
		utils.SendError(c, http.StatusBadRequest, "Role or status is required")
		return
	}

	var user models.User
	if err := database.DB.First(&user, userID).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			utils.SendError(c, http.StatusNotFound, "User not found")
			return
		}
		utils.SendError(c, http.StatusInternalServerError, "Failed to load user: "+err.Error())
		return
	}
	if user.Role == models.RolePatient {
		utils.SendError(c, http.StatusForbidden, "Patient accounts are not managed from this screen")
		return
	}

	if req.Role != "" {
		user.Role = req.Role
	}
	if req.Status != "" {
		user.Status = req.Status
	}
	if err := database.DB.Save(&user).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to update user: "+err.Error())
		return
	}

	utils.SendSuccess(c, http.StatusOK, "User updated successfully", AdminUserSummary{
		ID: user.ID, FullName: user.FullName, NIC: user.NIC, Phone: user.Phone,
		Role: user.Role, Status: user.Status, CreatedAt: user.CreatedAt,
	})
}

func parsePositiveQueryInt(c *gin.Context, key string, fallback int) int {
	value, err := strconv.Atoi(c.DefaultQuery(key, fmt.Sprintf("%d", fallback)))
	if err != nil || value < 1 {
		return fallback
	}
	return value
}
