package handlers

import (
	"net/http"
	"strconv"
	"time"

	"mediq-backend/internal/database"
	"mediq-backend/internal/models"
	"mediq-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type StaffNotificationHandler struct{}

func NewStaffNotificationHandler() *StaffNotificationHandler {
	return &StaffNotificationHandler{}
}

func (h *StaffNotificationHandler) GetNotifications(c *gin.Context) {
	if database.DB == nil {
		utils.SendError(c, http.StatusInternalServerError, "Database connection not initialized")
		return
	}

	userID, ok := staffNotificationUserID(c)
	if !ok {
		utils.SendError(c, http.StatusUnauthorized, "Unauthorized")
		return
	}

	notifications := make([]models.StaffNotification, 0)
	if err := database.DB.
		Where("staff_user_id = ?", userID).
		Order("created_at DESC, id DESC").
		Find(&notifications).Error; err != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to load Staff notifications")
		return
	}

	utils.SendSuccess(c, http.StatusOK, "Staff notifications retrieved", notifications)
}

func (h *StaffNotificationHandler) MarkNotificationRead(c *gin.Context) {
	if database.DB == nil {
		utils.SendError(c, http.StatusInternalServerError, "Database connection not initialized")
		return
	}

	userID, ok := staffNotificationUserID(c)
	if !ok {
		utils.SendError(c, http.StatusUnauthorized, "Unauthorized")
		return
	}

	notificationID, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil || notificationID == 0 {
		utils.SendError(c, http.StatusBadRequest, "Invalid notification ID")
		return
	}

	now := time.Now()
	result := database.DB.Model(&models.StaffNotification{}).
		Where("id = ? AND staff_user_id = ?", notificationID, userID).
		Updates(map[string]interface{}{"is_read": true, "read_at": now})
	if result.Error != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to mark notification as read")
		return
	}
	if result.RowsAffected == 0 {
		utils.SendError(c, http.StatusNotFound, "Notification not found")
		return
	}

	utils.SendSuccess(c, http.StatusOK, "Notification marked as read", nil)
}

func (h *StaffNotificationHandler) MarkAllNotificationsRead(c *gin.Context) {
	if database.DB == nil {
		utils.SendError(c, http.StatusInternalServerError, "Database connection not initialized")
		return
	}

	userID, ok := staffNotificationUserID(c)
	if !ok {
		utils.SendError(c, http.StatusUnauthorized, "Unauthorized")
		return
	}

	now := time.Now()
	result := database.DB.Model(&models.StaffNotification{}).
		Where("staff_user_id = ? AND is_read = ?", userID, false).
		Updates(map[string]interface{}{"is_read": true, "read_at": now})
	if result.Error != nil {
		utils.SendError(c, http.StatusInternalServerError, "Failed to mark Staff notifications as read")
		return
	}

	utils.SendSuccess(c, http.StatusOK, "Staff notifications marked as read", gin.H{
		"updated_count": result.RowsAffected,
	})
}

func staffNotificationUserID(c *gin.Context) (uint, bool) {
	userIDValue, exists := c.Get("userID")
	if !exists {
		return 0, false
	}
	userID, ok := userIDValue.(uint)
	return userID, ok && userID != 0
}
