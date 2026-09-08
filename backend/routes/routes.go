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

	// Serve static uploads directory (local fallback)
	r.Static("/uploads", "./uploads")

	authHandler := handlers.NewAuthHandler(cfg)
	medicalHandler := handlers.NewMedicalRecordHandler(cfg)
	appointmentHandler := handlers.NewAppointmentHandler()

	// API v1 Group
	v1 := r.Group("/api/v1")
	{
		v1.GET("/health", handlers.HealthCheck)

		// Auth routes
		auth := v1.Group("/auth")
		{
			auth.POST("/signup", authHandler.Signup)
			auth.POST("/login", authHandler.Login)
			auth.GET("/me", middleware.AuthMiddleware(cfg), authHandler.GetMe)
			auth.PUT("/profile", middleware.AuthMiddleware(cfg), authHandler.UpdateProfile)
			auth.DELETE("/profile", middleware.AuthMiddleware(cfg), authHandler.DeleteAccount)
		}

		// Medical records routes
		records := v1.Group("/medical-records")
		records.Use(middleware.AuthMiddleware(cfg))
		{
			records.GET("", medicalHandler.GetPatientRecords)
			records.POST("/upload", medicalHandler.UploadPrescription)
			records.POST("/doctor", medicalHandler.AddDoctorRecord)
			records.DELETE("/:id", medicalHandler.DeleteRecord)
		}

		// OPD Appointment routes
		appt := v1.Group("/appointments")
		{
			// Public: get rooms, queue status, and view ticket via QR scan
			appt.GET("/rooms", appointmentHandler.GetRooms)
			appt.GET("/queue/:room", appointmentHandler.GetQueueStatus)
			appt.GET("/view/:id", appointmentHandler.ViewAppointment)

			// Protected: patient booking
			apptAuth := appt.Group("")
			apptAuth.Use(middleware.AuthMiddleware(cfg))
			{
				apptAuth.POST("/book", appointmentHandler.BookAppointment)
				apptAuth.GET("/my", appointmentHandler.GetMyAppointments)
				apptAuth.PUT("/:id/cancel", appointmentHandler.CancelAppointment)
			}
		}
	}

	return r
}
