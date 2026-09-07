package routes

import (
	"mediq-backend/internal/config"
	"mediq-backend/internal/handlers"
	"mediq-backend/internal/middleware"

	"github.com/gin-gonic/gin"
)

func SetupRouter(cfg *config.Config) *gin.Engine {
	r := gin.Default()

	// Apply CORS
	r.Use(middleware.CORSMiddleware())

	authHandler := handlers.NewAuthHandler(cfg)

	// API v1 Group
	v1 := r.Group("/api/v1")
	{
		v1.GET("/health", handlers.HealthCheck)

		auth := v1.Group("/auth")
		{
			auth.POST("/signup", authHandler.Signup)
			auth.POST("/login", authHandler.Login)
			auth.GET("/me", middleware.AuthMiddleware(cfg), authHandler.GetMe)
			auth.PUT("/profile", middleware.AuthMiddleware(cfg), authHandler.UpdateProfile)
			auth.DELETE("/profile", middleware.AuthMiddleware(cfg), authHandler.DeleteAccount)
		}
	}

	return r
}
