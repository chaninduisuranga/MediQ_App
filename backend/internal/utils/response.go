package utils

import "github.com/gin-gonic/gin"

type JSONResponse struct {
	Success bool        `json:"success"`
	Message string      `json:"message,omitempty"`
	Data    interface{} `json:"data,omitempty"`
	Error   string      `json:"error,omitempty"`
}

func SendSuccess(c *gin.Context, statusCode int, message string, data interface{}) {
	c.JSON(statusCode, JSONResponse{
		Success: true,
		Message: message,
		Data:    data,
	})
}

func SendError(c *gin.Context, statusCode int, err string) {
	c.JSON(statusCode, JSONResponse{
		Success: false,
		Error:   err,
	})
}
