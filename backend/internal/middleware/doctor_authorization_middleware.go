package middleware

import (
	"net/http"

	"mediq-backend/internal/models"
	"mediq-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

func DoctorAuthorizationMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		role, exists := c.Get("role")
		if !exists || !isDoctorRole(role) {
			utils.SendError(c, http.StatusForbidden, "Doctor access required")
			c.Abort()
			return
		}
		c.Next()
	}
}

func isDoctorRole(role interface{}) bool {
	roleValue, ok := role.(string)
	if !ok {
		return false
	}
	return roleValue == string(models.RoleDoctor) || roleValue == string(models.RoleAdmin)
}
