package middleware

import (
	"net/http"

	"mediq-backend/internal/models"
	"mediq-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

func AdminAuthorizationMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		role, exists := c.Get("role")
		if !exists || !isAdminRole(role) {
			utils.SendError(c, http.StatusForbidden, "Admin access required")
			c.Abort()
			return
		}

		c.Next()
	}
}

func isAdminRole(role interface{}) bool {
	roleValue, ok := role.(string)
	if !ok {
		return false
	}

	return roleValue == string(models.RoleStaff) ||
		roleValue == string(models.RoleAdmin) ||
		roleValue == "SUPER_ADMIN"
}
