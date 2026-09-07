package handlers

import (
	"net/http"

	"mediq-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

func HealthCheck(c *gin.Context) {
	utils.SendSuccess(c, http.StatusOK, "MediQ API is up and running!", gin.H{
		"service": "MediQ Backend",
		"status":  "healthy",
	})
}
