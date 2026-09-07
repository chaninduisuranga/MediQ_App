package main

import (
	"log"

	"mediq-backend/internal/config"
	"mediq-backend/internal/database"
	"mediq-backend/routes"
)

func main() {
	// Load Configuration
	cfg := config.LoadConfig()

	// Initialize Database Connection
	database.InitDB(cfg.DatabaseURL)

	// Setup Router
	router := routes.SetupRouter(cfg)

	log.Printf("Starting MediQ Backend Server on port %s...", cfg.Port)
	if err := router.Run(":" + cfg.Port); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
