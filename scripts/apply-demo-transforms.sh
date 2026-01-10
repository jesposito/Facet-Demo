#!/bin/bash
set -e

echo "Applying Facet-Demo transformations..."

WORKDIR="${1:-.}"
cd "$WORKDIR"

echo "Working in: $(pwd)"
ls -la

sed -i 's/"demo_profile"/"profile"/g' hooks/demo.go
sed -i 's/"demo_experience"/"experience"/g' hooks/demo.go
sed -i 's/"demo_projects"/"projects"/g' hooks/demo.go
sed -i 's/"demo_education"/"education"/g' hooks/demo.go
sed -i 's/"demo_skills"/"skills"/g' hooks/demo.go
sed -i 's/"demo_certifications"/"certifications"/g' hooks/demo.go
sed -i 's/"demo_posts"/"posts"/g' hooks/demo.go
sed -i 's/"demo_talks"/"talks"/g' hooks/demo.go
sed -i 's/"demo_awards"/"awards"/g' hooks/demo.go
sed -i 's/"demo_views"/"views"/g' hooks/demo.go
sed -i 's/"demo_share_tokens"/"share_tokens"/g' hooks/demo.go
sed -i 's/"demo_contact_methods"/"contact_methods"/g' hooks/demo.go

sed -i 's/changeme123/demo123/g' hooks/seed.go
sed -i 's/changeme123/demo123/g' hooks/auth.go
sed -i 's/changeme123/demo123/g' main.go

cat > hooks/demo_instance_init.go << 'GOEOF'
package hooks

import (
	"os"
	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
	"golang.org/x/crypto/bcrypt"
)

func InitDemoInstance(app *pocketbase.PocketBase) {
	app.OnServe().BindFunc(func(se *core.ServeEvent) error {
		profile, _ := app.FindFirstRecordByFilter("profile", "")
		if profile == nil {
			app.Logger().Info("No profile found, initializing demo data...")
			if err := loadDemoDataIntoShadowTables(app); err != nil {
				app.Logger().Error("Failed to load demo data", "error", err)
			}
			ensureDemoUser(app)
		}
		return se.Next()
	})
}

func ensureDemoUser(app *pocketbase.PocketBase) {
	usersCollection, err := app.FindCollectionByNameOrId("users")
	if err != nil {
		return
	}

	email := os.Getenv("ADMIN_EMAILS")
	if email == "" {
		email = "demo@example.com"
	}

	existingUser, _ := app.FindAuthRecordByEmail(usersCollection, email)
	if existingUser != nil {
		passwordHash, _ := bcrypt.GenerateFromPassword([]byte("demo123"), bcrypt.DefaultCost)
		existingUser.Set("password", string(passwordHash))
		existingUser.Set("passwordChanged", false)
		app.Save(existingUser)
		return
	}

	user := core.NewRecord(usersCollection)
	user.Set("email", email)
	user.Set("verified", true)
	user.Set("passwordChanged", false)
	passwordHash, _ := bcrypt.GenerateFromPassword([]byte("demo123"), bcrypt.DefaultCost)
	user.Set("password", string(passwordHash))
	app.Save(user)
	app.Logger().Info("Created demo user", "email", email)
}
GOEOF

cat > hooks/demo_restrictions.go << 'GOEOF'
package hooks

import (
	"net/http"
	"strings"
	"time"
	"sync"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
)

const (
	demoMaxUploadSize = 512 * 1024
	demoRateLimitWindow = time.Minute
	demoMaxUploadsPerWindow = 3
)

type uploadRateLimiter struct {
	mu      sync.Mutex
	uploads map[string][]time.Time
}

var limiter = &uploadRateLimiter{
	uploads: make(map[string][]time.Time),
}

func (l *uploadRateLimiter) allow(ip string) bool {
	l.mu.Lock()
	defer l.mu.Unlock()

	now := time.Now()
	cutoff := now.Add(-demoRateLimitWindow)

	times := l.uploads[ip]
	var valid []time.Time
	for _, t := range times {
		if t.After(cutoff) {
			valid = append(valid, t)
		}
	}

	if len(valid) >= demoMaxUploadsPerWindow {
		l.uploads[ip] = valid
		return false
	}

	l.uploads[ip] = append(valid, now)
	return true
}

func RegisterDemoRestrictions(app *pocketbase.PocketBase) {
	app.OnServe().BindFunc(func(se *core.ServeEvent) error {
		se.Router.BindFunc(func(e *core.RequestEvent) error {
			path := e.Request.URL.Path
			method := e.Request.Method
			
			if method == http.MethodPost && strings.Contains(path, "/api/resume/upload") {
				return e.JSON(http.StatusForbidden, map[string]interface{}{
					"error":   "Resume upload is disabled in demo mode",
					"message": "This is a public demo. Resume uploads are disabled to prevent abuse. Please try the main Facet application.",
					"demo":    true,
				})
			}

			if method == http.MethodPost && (strings.Contains(path, "/api/files") || strings.Contains(path, "/api/collections") && strings.Contains(path, "/records")) {
				contentType := e.Request.Header.Get("Content-Type")
				if strings.Contains(contentType, "multipart/form-data") {
					ip := e.Request.RemoteAddr
					if forwarded := e.Request.Header.Get("X-Forwarded-For"); forwarded != "" {
						ip = strings.Split(forwarded, ",")[0]
					}

					if !limiter.allow(ip) {
						return e.JSON(http.StatusTooManyRequests, map[string]interface{}{
							"error":   "Upload rate limit exceeded",
							"message": "Demo mode limits uploads to 3 per minute. Please wait before uploading again.",
							"demo":    true,
						})
					}

					e.Request.Body = http.MaxBytesReader(nil, e.Request.Body, demoMaxUploadSize)
				}
			}

			return e.Next()
		})
		return se.Next()
	})
}
GOEOF

if ! grep -q "InitDemoInstance" main.go; then
    sed -i '/hooks.RegisterDemoHandlers(app)/a\    hooks.InitDemoInstance(app)' main.go
fi

if ! grep -q "RegisterDemoRestrictions" main.go; then
    sed -i '/hooks.InitDemoInstance(app)/a\    hooks.RegisterDemoRestrictions(app)' main.go
fi

echo "Transformations complete!"
