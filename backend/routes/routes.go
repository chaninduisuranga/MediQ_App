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
	doctorHandler := handlers.NewDoctorHandler()

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
			// Public: get rooms and view ticket via QR scan
			appt.GET("/rooms", appointmentHandler.GetRooms)
			appt.GET("/queue/:room", middleware.OptionalAuthMiddleware(cfg), doctorHandler.GetQueueByRoom)
			appt.GET("/view/:id", appointmentHandler.ViewAppointment)

			// Protected: patient booking
			apptAuth := appt.Group("")
			apptAuth.Use(middleware.AuthMiddleware(cfg))
			{
				apptAuth.POST("/book", appointmentHandler.BookAppointment)
				apptAuth.GET("/my", appointmentHandler.GetMyAppointments)
				apptAuth.GET("/:id", doctorHandler.GetAppointmentByID)
				apptAuth.PUT("/:id/checkin", doctorHandler.CheckInAppointment)
				apptAuth.PUT("/:id/cancel", appointmentHandler.CancelAppointment)
			}
		}

		doctor := v1.Group("/doctor")
		doctor.Use(middleware.AuthMiddleware(cfg), middleware.DoctorAuthorizationMiddleware())
		{
			doctor.GET("/appointments/today", doctorHandler.GetTodayAppointments)
			doctor.GET("/appointments/history", doctorHandler.GetPreviousAppointments)
			doctor.PUT("/appointments/:id/status", doctorHandler.UpdateAppointmentStatus)
			doctor.GET("/appointments/:id/consultation-details", doctorHandler.GetConsultationDetails)
			doctor.GET("/availability", doctorHandler.GetAvailability)
			doctor.PUT("/availability", doctorHandler.UpdateAvailability)
			doctor.GET("/profile", doctorHandler.GetDoctorProfile)
			doctor.PUT("/profile", doctorHandler.UpdateDoctorProfile)
			doctor.POST("/change-password", authHandler.ChangePassword)
			doctor.GET("/notifications", doctorHandler.GetNotifications)
			doctor.PUT("/notifications/:id/read", doctorHandler.MarkNotificationRead)
			doctor.GET("/patients/:patient_id/history", doctorHandler.GetPatientHistory)
		}

		// AI Chatbot routes
		chatHandler := handlers.NewChatHandler()
		chat := v1.Group("/chat")
		chat.Use(middleware.AuthMiddleware(cfg))
		{
			chat.GET("/history", chatHandler.GetHistory)
			chat.POST("/message", chatHandler.SendMessage)
			chat.DELETE("/history", chatHandler.ClearHistory)
		}

		// Staff routes
		staff := v1.Group("/staff")
		staff.Use(middleware.AuthMiddleware(cfg))
		staff.Use(middleware.StaffAuthorizationMiddleware())
		{
			staffQueueHandler := handlers.NewStaffQueueHandler()
			staffNotificationHandler := handlers.NewStaffNotificationHandler()
			staff.GET("/notifications", staffNotificationHandler.GetNotifications)
			staff.DELETE("/notifications/clear-all", staffNotificationHandler.ClearAllNotifications)
			staff.DELETE("/notifications/:id", staffNotificationHandler.DeleteNotification)
			staff.PATCH("/notifications/:id/read", staffNotificationHandler.MarkNotificationRead)
			staff.PATCH("/notifications/read-all", staffNotificationHandler.MarkAllNotificationsRead)
			staff.GET("/profile", staffQueueHandler.GetProfile)
			staff.GET("/queue/list", staffQueueHandler.GetQueueList)
			staff.GET("/queue/search", staffQueueHandler.SearchQueue)
			staff.GET("/queue/qr-lookup/:id", staffQueueHandler.LookupQrAppointment)
			staff.GET("/queue/history", staffQueueHandler.GetQueueHistory)
			staff.DELETE("/queue/history/:id", staffQueueHandler.DeleteQueueHistory)
			staff.POST("/queue/checkin/:id", staffQueueHandler.CheckIn)
			staff.POST("/queue/qr-checkin/:id", staffQueueHandler.CheckInQrAppointment)
			staff.POST("/queue/call/:id", staffQueueHandler.CallNext)
			staff.PATCH("/queue/status/:id", staffQueueHandler.UpdateStatus)
			staff.PATCH("/queue/priority/:id", staffQueueHandler.TogglePriority)
			staff.GET("/doctors", staffQueueHandler.GetDoctors)
			staff.POST("/queue/allocate/:id", staffQueueHandler.AllocateDoctor)
		}

		// Admin routes
		admin := v1.Group("/admin")
		admin.Use(middleware.AuthMiddleware(cfg))
		admin.Use(middleware.AdminAuthorizationMiddleware())
		{
			adminHandler := handlers.NewAdminHandler()
			admin.GET("/dashboard", adminHandler.GetDashboardStats)

			adminUserHandler := handlers.NewAdminUserHandler()
			admin.GET("/users", adminUserHandler.ListUsers)
			admin.PATCH("/users/:id", adminUserHandler.UpdateUser)

			adminAppointmentHandler := handlers.NewAdminAppointmentHandler()
			admin.GET("/appointments", adminAppointmentHandler.ListAppointments)
			admin.PATCH("/appointments/:id", adminAppointmentHandler.UpdateAppointment)

			adminDoctorHandler := handlers.NewAdminDoctorHandler()
			admin.GET("/doctors", adminDoctorHandler.ListDoctors)
			admin.POST("/doctors", adminDoctorHandler.CreateDoctor)
			admin.PATCH("/doctors/:id", adminDoctorHandler.UpdateDoctor)
			admin.DELETE("/doctors/:id", adminDoctorHandler.DeleteDoctor)

			adminStaffHandler := handlers.NewAdminStaffHandler()
			admin.GET("/staff", adminStaffHandler.ListStaff)
			admin.POST("/staff", adminStaffHandler.CreateStaff)
			admin.PATCH("/staff/:id", adminStaffHandler.UpdateStaff)
			admin.DELETE("/staff/:id", adminStaffHandler.DeleteStaff)

			adminQueueHandler := handlers.NewAdminQueueHandler()
			admin.GET("/queues", adminQueueHandler.GetQueues)

			adminAnalyticsHandler := handlers.NewAdminAnalyticsHandler()
			admin.GET("/analytics", adminAnalyticsHandler.GetAnalytics)

			// ── AI Chatbot FAQ management ──────────────────────────────────────────
			chatFAQHandler := handlers.NewChatFAQHandler()
			admin.GET("/chat-faqs", chatFAQHandler.ListFAQs)
			admin.POST("/chat-faqs", chatFAQHandler.CreateFAQ)
			admin.PATCH("/chat-faqs/:id", chatFAQHandler.UpdateFAQ)
			admin.DELETE("/chat-faqs/:id", chatFAQHandler.DeleteFAQ)
			admin.POST("/chat-faqs/seed", chatFAQHandler.SeedDefaultFAQs)
		}
	}

	return r
}
