#!/bin/bash
set -e

echo "Applying Facet-Demo transformations..."

cd /build

sed -i 's/"demo_profile"/"profile"/g' backend/hooks/demo.go
sed -i 's/"demo_experience"/"experience"/g' backend/hooks/demo.go
sed -i 's/"demo_projects"/"projects"/g' backend/hooks/demo.go
sed -i 's/"demo_education"/"education"/g' backend/hooks/demo.go
sed -i 's/"demo_skills"/"skills"/g' backend/hooks/demo.go
sed -i 's/"demo_certifications"/"certifications"/g' backend/hooks/demo.go
sed -i 's/"demo_posts"/"posts"/g' backend/hooks/demo.go
sed -i 's/"demo_talks"/"talks"/g' backend/hooks/demo.go
sed -i 's/"demo_awards"/"awards"/g' backend/hooks/demo.go
sed -i 's/"demo_views"/"views"/g' backend/hooks/demo.go
sed -i 's/"demo_share_tokens"/"share_tokens"/g' backend/hooks/demo.go
sed -i 's/"demo_contact_methods"/"contact_methods"/g' backend/hooks/demo.go

sed -i 's/changeme123/demo123/g' backend/hooks/seed.go
sed -i 's/changeme123/demo123/g' backend/hooks/auth.go
sed -i 's/changeme123/demo123/g' backend/main.go

cat > backend/hooks/demo_instance_init.go << 'GOEOF'
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

if ! grep -q "InitDemoInstance" backend/main.go; then
    sed -i '/hooks.RegisterDemoHandlers(app)/a\    hooks.InitDemoInstance(app)' backend/main.go
fi

echo "Transformations complete!"
