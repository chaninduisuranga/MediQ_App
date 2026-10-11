package websocket

import (
	"log"
	"net/http"
	"sync"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	// Allow all origins for WebSocket connections (matching CORS setup)
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

// EventPayload represents a real-time event sent over WebSocket
type EventPayload struct {
	Event         string      `json:"event"`
	Room          string      `json:"room,omitempty"`
	AppointmentID uint        `json:"appointment_id,omitempty"`
	QueueNumber   int         `json:"queue_number,omitempty"`
	Status        string      `json:"status,omitempty"`
	Data          interface{} `json:"data,omitempty"`
}

// Client represents a connected WebSocket client
type Client struct {
	Hub  *Hub
	Conn *websocket.Conn
	Send chan EventPayload
}

// Hub maintains the set of active clients and broadcasts messages to them
type Hub struct {
	clients    map[*Client]bool
	broadcast  chan EventPayload
	register   chan *Client
	unregister chan *Client
	mu         sync.RWMutex
}

var GlobalHub *Hub

func init() {
	GlobalHub = NewHub()
	go GlobalHub.Run()
}

func NewHub() *Hub {
	return &Hub{
		clients:    make(map[*Client]bool),
		broadcast:  make(chan EventPayload, 256),
		register:   make(chan *Client),
		unregister: make(chan *Client),
	}
}

func (h *Hub) Run() {
	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			h.clients[client] = true
			h.mu.Unlock()
			log.Printf("[WebSocket] New client connected. Total clients: %d", len(h.clients))

		case client := <-h.unregister:
			h.mu.Lock()
			if _, ok := h.clients[client]; ok {
				delete(h.clients, client)
				close(client.Send)
				log.Printf("[WebSocket] Client disconnected. Total clients: %d", len(h.clients))
			}
			h.mu.Unlock()

		case message := <-h.broadcast:
			h.mu.RLock()
			for client := range h.clients {
				select {
				case client.Send <- message:
				default:
					close(client.Send)
					delete(h.clients, client)
				}
			}
			h.mu.RUnlock()
		}
	}
}

// BroadcastEvent publishes an event to all connected clients
func BroadcastEvent(event string, room string, payload interface{}) {
	if GlobalHub == nil {
		return
	}
	msg := EventPayload{
		Event: event,
		Room:  room,
		Data:  payload,
	}
	GlobalHub.broadcast <- msg
}

// ServeWS handles websocket requests from clients
func ServeWS(c *gin.Context) {
	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		log.Printf("[WebSocket] Failed to upgrade HTTP connection: %v", err)
		return
	}

	client := &Client{
		Hub:  GlobalHub,
		Conn: conn,
		Send: make(chan EventPayload, 256),
	}

	client.Hub.register <- client

	// Start write and read pumps
	go client.writePump()
	go client.readPump()
}

func (c *Client) readPump() {
	defer func() {
		c.Hub.unregister <- c
		c.Conn.Close()
	}()

	for {
		// Read messages from client (pong/ping keepalive or incoming msgs)
		_, _, err := c.Conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("[WebSocket] Read error: %v", err)
			}
			break
		}
	}
}

func (c *Client) writePump() {
	defer func() {
		c.Conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.Send:
			if !ok {
				c.Conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			if err := c.Conn.WriteJSON(message); err != nil {
				log.Printf("[WebSocket] Write error: %v", err)
				return
			}
		}
	}
}
