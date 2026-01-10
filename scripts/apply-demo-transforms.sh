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
	"fmt"
	"os"
	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
	"github.com/spf13/cobra"
	"golang.org/x/crypto/bcrypt"
)

func RegisterSeedDemoCommand(app *pocketbase.PocketBase) {
	app.RootCmd.AddCommand(&cobra.Command{
		Use:   "seed-demo",
		Short: "Seed the database with demo data (The Doctor)",
		Long:  "Loads comprehensive demo data into the database. Use this during Docker build to pre-populate the seed database.",
		RunE: func(cmd *cobra.Command, args []string) error {
			fmt.Println("Bootstrapping app...")
			if err := app.Bootstrap(); err != nil {
				return fmt.Errorf("failed to bootstrap app: %w", err)
			}

			fmt.Println("Running migrations...")
			if err := app.RunAllMigrations(); err != nil {
				return fmt.Errorf("failed to run migrations: %w", err)
			}

			fmt.Println("Checking for existing demo data...")
			profile, err := app.FindFirstRecordByFilter("profile", "")
			if err != nil {
				fmt.Printf("Note: %v (this is expected for fresh database)\n", err)
			}
			if profile != nil {
				fmt.Println("Demo data already exists, skipping...")
				return nil
			}

			fmt.Println("Loading demo data (The Doctor's profile)...")
			if err := loadDemoDataIntoShadowTables(app); err != nil {
				return fmt.Errorf("failed to load demo data: %w", err)
			}

			fmt.Println("Creating demo user...")
			if err := ensureDemoUser(app); err != nil {
				return fmt.Errorf("failed to create demo user: %w", err)
			}

			fmt.Println("========================================")
			fmt.Println("  Demo data seeded successfully!")
			fmt.Println("  Profile: The Doctor")
			fmt.Println("  Login: demo@example.com / demo123")
			fmt.Println("========================================")
			return nil
		},
	})
}

// InitDemoInstance registers a hook to check/load demo data on first request
// This is a fallback in case seed-demo wasn't run during build
func InitDemoInstance(app *pocketbase.PocketBase) {
	app.OnServe().BindFunc(func(se *core.ServeEvent) error {
		// Check if we need to load demo data
		profile, _ := app.FindFirstRecordByFilter("profile", "")
		if profile == nil {
			app.Logger().Info("No profile found, initializing demo data...")
			if err := loadDemoDataIntoShadowTables(app); err != nil {
				app.Logger().Error("Failed to load demo data", "error", err)
			} else {
				app.Logger().Info("Demo data loaded successfully")
			}
			if err := ensureDemoUser(app); err != nil {
				app.Logger().Error("Failed to create demo user", "error", err)
			}
		}
		return se.Next()
	})
}

func ensureDemoUser(app *pocketbase.PocketBase) error {
	usersCollection, err := app.FindCollectionByNameOrId("users")
	if err != nil {
		return fmt.Errorf("users collection not found: %w", err)
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
		if err := app.Save(existingUser); err != nil {
			return err
		}
		app.Logger().Info("Updated demo user password", "email", email)
		return nil
	}

	user := core.NewRecord(usersCollection)
	user.Set("email", email)
	user.Set("verified", true)
	user.Set("passwordChanged", false)
	passwordHash, _ := bcrypt.GenerateFromPassword([]byte("demo123"), bcrypt.DefaultCost)
	user.Set("password", string(passwordHash))
	if err := app.Save(user); err != nil {
		return err
	}
	app.Logger().Info("Created demo user", "email", email)
	return nil
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

# Add RegisterSeedDemoCommand before app.Start() - this adds the CLI command
if ! grep -q "RegisterSeedDemoCommand" main.go; then
    sed -i '/hooks.RegisterDemoHandlers(app)/a\    hooks.RegisterSeedDemoCommand(app)' main.go
fi

if ! grep -q "InitDemoInstance" main.go; then
    sed -i '/hooks.RegisterSeedDemoCommand(app)/a\    hooks.InitDemoInstance(app)' main.go
fi

if ! grep -q "RegisterDemoRestrictions" main.go; then
    sed -i '/hooks.InitDemoInstance(app)/a\    hooks.RegisterDemoRestrictions(app)' main.go
fi

FRONTEND_DIR="../frontend"

if [ -d "$FRONTEND_DIR" ]; then
    echo "Applying frontend transformations..."
    
    sed -i 's/>Facet</>Facet-Demo</g' "$FRONTEND_DIR/src/components/admin/AdminHeader.svelte"
    
    sed -i 's/Sign In | Facet/Sign In | Facet-Demo/g' "$FRONTEND_DIR/src/routes/admin/login/+page.svelte"
    sed -i 's/Sign in to Facet/Sign in to Facet-Demo/g' "$FRONTEND_DIR/src/routes/admin/login/+page.svelte"
    sed -i 's/placeholder="admin@example.com"/placeholder="demo@example.com"/g' "$FRONTEND_DIR/src/routes/admin/login/+page.svelte"
    
    cat > "$FRONTEND_DIR/src/components/admin/DemoBanner.svelte" << 'SVELTE_EOF'
<script lang="ts">
    let dismissed = $state(false);
</script>

{#if !dismissed}
<div class="fixed top-16 left-0 right-0 z-30 bg-amber-500 text-amber-950 text-center py-2 px-4 text-sm font-medium shadow-sm">
    <span>
        🎭 Public Demo — Data resets daily at midnight UTC — 
        <span class="font-semibold">Login: demo@example.com / demo123</span>
    </span>
    <button 
        onclick={() => dismissed = true}
        class="ml-4 text-amber-800 hover:text-amber-950 font-bold"
        aria-label="Dismiss banner"
    >
        ✕
    </button>
</div>
{/if}
SVELTE_EOF

    sed -i "/import AdminHeader from/a\\	import DemoBanner from '\$components/admin/DemoBanner.svelte';" "$FRONTEND_DIR/src/routes/admin/+layout.svelte"
    sed -i 's/<AdminHeader \/>/<AdminHeader \/>\n\t\t<DemoBanner \/>/g' "$FRONTEND_DIR/src/routes/admin/+layout.svelte"
    sed -i 's/mt-16">/mt-28">/g' "$FRONTEND_DIR/src/routes/admin/+layout.svelte"
    
    sed -i 's/<div class="relative flex items-center gap-2 px-3 py-1.5 rounded-lg bg-gray-100 dark:bg-gray-700/<div class="hidden relative flex items-center gap-2 px-3 py-1.5 rounded-lg bg-gray-100 dark:bg-gray-700/g' "$FRONTEND_DIR/src/components/admin/AdminHeader.svelte"
    
    echo "Frontend transformations applied"
else
    echo "Warning: Frontend directory not found at $FRONTEND_DIR"
fi

echo "Transformations complete!"
